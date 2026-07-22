import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'data.dart';
import 'date_labels.dart';
import 'events_controller.dart';
import 'gallery_controller.dart';
import 'members_controller.dart';
import 'poll_controller.dart';
import 'push_service.dart';
import 'secretary_controller.dart';
import 'theme.dart';
import 'treasury_controller.dart';

class CertInfo {
  final String title;
  final String body;
  const CertInfo(this.title, this.body);
}

/// Working copy of the "Send apology" bottom sheet fields.
class ApologyDraft {
  String reason = '';
  bool saving = false;
  String? error;
}

/// Single shared app state, mirroring the design's one-component `state`
/// object and `tab`-based navigation (no push/pop stack — going "back" just
/// sets `tab` to a fixed target screen, exactly as authored).
class AppState extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  // The member token is a 365-day-lived bearer credential (see
  // security.py's create_access_token) — kept in the platform keystore
  // (Keychain/Keystore), not plain SharedPreferences, so it isn't sitting
  // in a plaintext file readable via a device backup or a rooted device.
  static const _secureStorage = FlutterSecureStorage();

  // Treasury's data and logic live in their own single-responsibility
  // class; AppState just composes it in and re-broadcasts its changes,
  // rather than owning treasury state directly alongside everything else.
  late final TreasuryController treasury = TreasuryController(_api, () => authToken)
    ..addListener(notifyListeners);
  late final SecretaryController secretary =
      SecretaryController(_api, () => authToken, () => isSecretary)
        ..addListener(notifyListeners);
  late final GalleryController gallery =
      GalleryController(_api, () => authToken)..addListener(notifyListeners);
  late final PollController polls = PollController(_api, () => authToken)
    ..addListener(notifyListeners);
  late final EventsController eventsController =
      EventsController(_api, () => authToken)..addListener(notifyListeners);
  late final MembersController membersController = MembersController(
      _api, () => authToken, () => canManageClub)
    ..addListener(notifyListeners);

  AppState() {
    // Wake the free-tier backend while the user is still on the splash
    // screen, so login doesn't hit a cold start.
    _api.warmUp();
    // Members sign in once: restore the saved session (cleared only by
    // reinstalling the app or by the server rejecting the token).
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    // Visitor identity is independent of any member session — a phone
    // that's never had a member log in can still have scanned QR codes
    // as a walk-in visitor before, and should still be remembered.
    _update(() {
      visitorName = prefs.getString('visitor_name');
      visitorPhone = prefs.getString('visitor_phone');
      visitorClubId = prefs.getInt('visitor_club_id');
      final savedClubName = prefs.getString('visitor_club_name');
      if (savedClubName != null && savedClubName.isNotEmpty) {
        visitorClubName = savedClubName;
      }
      _visitorRegisteredClubs.addAll(
          (prefs.getStringList('visitor_registered_clubs') ?? [])
              .map(int.tryParse)
              .whereType<int>());
    });
    var token = await _secureStorage.read(key: 'auth_token');
    if (token == null) {
      // One-time migration: everyone signed in before this version kept
      // their token in plain SharedPreferences — fall back to it once and
      // move it over, so an update doesn't silently sign every member out.
      final legacyToken = prefs.getString('auth_token');
      if (legacyToken != null) {
        await _secureStorage.write(key: 'auth_token', value: legacyToken);
        await prefs.remove('auth_token');
        token = legacyToken;
      }
    }
    if (token == null) return;
    _update(() {
      authToken = token;
      currentMemberName = prefs.getString('member_name') ?? '';
      currentMemberRole = prefs.getString('member_role') ?? '';
      currentMemberPhone = prefs.getString('member_phone') ?? '';
      currentMemberIsBoard = prefs.getBool('member_is_board') ?? false;
      needsBoardSetup = prefs.getBool('needs_board_setup') ?? false;
      clubId = prefs.getInt('club_id');
      clubName = prefs.getString('club_name') ?? clubName;
      clubLogo = prefs.getString('club_logo');
      clubType = prefs.getString('club_type') ?? clubType;
      RCColors.setClubType(clubType);
      clubBrandingKnown = true;
      // Stay on the splash screen — its welcome animation plays every
      // launch regardless of login state. Only the login FORM is skipped
      // for a returning member; splash_screen.dart advances straight to
      // Home on its own once the animation settles.
    });
    unawaited(loadClubMembers());
    unawaited(loadSummary());
    unawaited(loadEvents());
    unawaited(loadProjects());
    unawaited(loadMeetings());
    unawaited(_sendPushToken());
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = authToken;
    if (token == null) return;
    await _secureStorage.write(key: 'auth_token', value: token);
    await prefs.setString('member_name', currentMemberName);
    await prefs.setString('member_role', currentMemberRole);
    await prefs.setString('member_phone', currentMemberPhone);
    await prefs.setBool('member_is_board', currentMemberIsBoard);
    await prefs.setBool('needs_board_setup', needsBoardSetup);
    final id = clubId;
    if (id != null) await prefs.setInt('club_id', id);
    await prefs.setString('club_name', clubName);
    await prefs.setString('club_type', clubType);
    final logo = clubLogo;
    if (logo != null) {
      await prefs.setString('club_logo', logo);
    } else {
      await prefs.remove('club_logo');
    }
  }

  // Set by PushService as soon as FCM hands over a token, which can happen
  // before login finishes (or before a restored session loads) — held here
  // so _sendPushToken always has the latest one to register once a member
  // is actually signed in.
  String? _pendingPushToken;

  void registerPushToken(String token) {
    _pendingPushToken = token;
    unawaited(_sendPushToken());
  }

  Future<void> _sendPushToken() async {
    final authTok = authToken;
    final pushTok = _pendingPushToken;
    if (authTok == null || pushTok == null) return;
    try {
      await _api.registerDeviceToken(
          authTok, pushTok, PushService.instance.platform);
    } catch (_) {
      // Best-effort — this device just won't get pushes until the next
      // successful retry (relaunch, token refresh, or next login).
    }
  }

  /// A tapped push notification either brought the app to the foreground
  /// (onMessageOpenedApp) or launched it fresh from a killed state
  /// (getInitialMessage) — either way, jump to the screen it's about.
  void handlePushTap(RemoteMessage message) {
    if (authToken == null) return;
    switch (message.data['type']) {
      case 'event':
        goEvents();
      case 'dues':
        goTreasury();
    }
  }

  /// Called when the server rejects the stored token (e.g. this member was
  /// removed): wipe just their session. Club branding (name/logo/id) is
  /// kept — this device still belongs to that club, it just needs someone
  /// to log in again.
  /// User-chosen sign-out (role badge on the Home header). Same cleanup as
  /// an auth failure: wipe the persisted session and every club cache.
  void signOut() => unawaited(_clearSession());

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: 'auth_token');
    await prefs.remove('member_name');
    await prefs.remove('member_role');
    await prefs.remove('member_phone');
    await prefs.remove('member_is_board');
    await prefs.remove('needs_board_setup');
    _update(() {
      authToken = null;
      currentMemberName = '';
      currentMemberRole = '';
      currentMemberPhone = '';
      currentMemberIsBoard = false;
      needsBoardSetup = false;
      _resetClubData();
      tab = 'splash';
    });
  }

  /// Drops every club-scoped cache so nothing from one session can leak
  /// into the next — the *Loaded flags otherwise stop the loaders from
  /// refetching, showing the previous club's data to a member of another
  /// club who signs in on the same device.
  void _resetClubData() {
    summary = null;
    polls.reset();
    eventsController.reset();
    membersController.reset();
    clubMeetings.clear();
    meetingsLoaded = false;
    apologies = [];
    treasury.reset();
    secretary.reset();
    gallery.reset();
    projects.clear();
    projectsLoaded = false;
  }

  /// Remembered once a walk-in visitor has checked in anywhere, used to
  /// pre-fill the registration form at each NEW club — but the form is
  /// still shown once per club (see [_visitorRegisteredClubs]); only a
  /// club they've already registered at checks them in silently.
  String? visitorName;
  String? visitorPhone;

  /// Clubs this device's visitor has filled the registration form for.
  /// A club in this set never asks for details again; a club not in it
  /// always shows the (pre-filled) form first.
  final Set<int> _visitorRegisteredClubs = {};

  /// The last club this visitor checked in at — its dashboard is what the
  /// splash guest button opens on every launch, until a different club's
  /// QR is scanned.
  int? visitorClubId;
  String? visitorClubName;
  String? visitorClubLogo;
  String visitorClubType = 'rotary';
  List<ClubEvent> visitorEvents = const [];
  bool visitorClubLoading = false;
  String? visitorClubError;

  /// Shows the "you're checked in" banner on the visitor dashboard right
  /// after a check-in this session; not persisted.
  bool visitorJustCheckedIn = false;

  Future<void> _persistVisitorIdentity(String name, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('visitor_name', name);
    await prefs.setString('visitor_phone', phone);
  }

  Future<void> _persistVisitorClub() async {
    final prefs = await SharedPreferences.getInstance();
    final id = visitorClubId;
    if (id != null) await prefs.setInt('visitor_club_id', id);
    await prefs.setString('visitor_club_name', visitorClubName ?? '');
    await prefs.setStringList('visitor_registered_clubs',
        _visitorRegisteredClubs.map((c) => c.toString()).toList());
  }

  bool _isAuthFailure(ApiException e) => e.message.contains('credentials');

  String tab = 'splash';
  // True only when the scan screen was reached via the splash screen's
  // "I'm visiting as a Guest" button — including for an already-logged-in
  // member, who still has a real session (so the generic "no session ->
  // back to splash" rule in goBack() wouldn't otherwise catch this case).
  bool _scanFromSplash = false;
  String scanMode = 'member'; // member | guest
  String scanStep = 'idle'; // idle | success | guestForm | guestDone

  String guestName = '';
  String guestPhone = '';
  String guestHost = '';
  String guestClub = '';
  String guestType = 'Prospective member';
  bool guestFormError = false;

  CertInfo? cert;

  // Greeting and role badge reflect the logged-in member; the design's
  // "Rtn. Peter / TREASURER" preview values remain only as the pre-login
  // fallback so nothing renders empty. The honorific itself flips with
  // club type — "Rtn." (Rotarian) vs "Ract." (Rotaractor).
  String get _honorific => clubType == 'rotaract' ? 'Ract' : 'Rtn';
  String get greeting => currentMemberName.trim().isEmpty
      ? 'Hello, $_honorific. Peter'
      : 'Hello, $_honorific. ${currentMemberName.trim().split(RegExp(r'\s+')).first}';
  String get roleBadge => currentMemberRole.trim().isEmpty
      ? 'TREASURER'
      : currentMemberRole.trim().toUpperCase();

  /// Only a member actually registered with the Treasurer role sees the
  /// Treasury workspace.
  bool get isTreasurer => currentMemberRole.trim() == 'Treasurer';

  /// The Secretary workspace is the Secretary's alone — the President
  /// doesn't share it (matching the backend's `_require_secretary` gate).
  bool get isSecretary => currentMemberRole.trim() == 'Secretary';

  // login
  String loginId = '';
  String loginPin = '';
  bool loginError = false;
  String loginErrorMessage = 'Enter your member number and PIN to continue.';
  bool loginLoading = false;

  String? authToken;
  String currentMemberName = '';
  String currentMemberRole = '';
  String currentMemberPhone = '';
  bool currentMemberIsBoard = false;
  // True right after the July 1 leadership sweep promotes this member to
  // President — shows the dismissible "assign board positions" banner.
  // Refreshed from the roster (see loadClubMembers) as well as at login,
  // so it self-heals even if the transition happens mid-session.
  bool needsBoardSetup = false;

  // Branding for the logged-in member's club, provided by the backend at
  // login. Until then the app brands itself as "Rotary Connect". clubId
  // also lets an unauthenticated guest check-in on this device name the
  // right club, and survives a single member's session being revoked
  // (the device is still "this club's device" even if that member isn't).
  int? clubId;
  String clubName = 'Rotary Club of Mbalwa';
  String? clubLogo; // data URL uploaded by the system admin
  String clubType = 'rotary'; // "rotary" | "rotaract", set by the system admin
  // Not persisted like the branding fields above — always re-read from the
  // backend (at login, and opportunistically whenever loadSummary() runs)
  // so a club suspended mid-session is caught on the next such call.
  String clubStatus = 'active'; // "active" | "suspended"
  bool clubBrandingKnown = false; // true once a login has identified the club

  /// clubName minus a leading "Rotary "/"Rotaract " — whichever is actually
  /// there — so the wordmark's bold first line ("Rotary"/"Rotaract", driven
  /// by clubType) never repeats itself if the stored name already has it.
  String _stripClubPrefix(String n) {
    final lower = n.toLowerCase();
    if (lower.startsWith('rotary ')) return n.substring(7).trim();
    if (lower.startsWith('rotaract ')) return n.substring(9).trim();
    return n;
  }

  /// Second line of the splash wordmark: "Connect" until the member's club
  /// is known, then e.g. "Club of Mbalwa".
  String get wordmarkClubLine =>
      clubBrandingKnown ? _stripClubPrefix(clubName.trim()) : 'Connect';

  /// clubName re-prefixed to always agree with clubType, so a club whose
  /// stored name hasn't been updated to match a Rotary<->Rotaract switch
  /// still displays correctly everywhere (headers, PDFs, splash) — not
  /// just in the wordmark, which already derives its "Rotary"/"Rotaract"
  /// word from clubType rather than the stored name. Only re-prefixes a
  /// name that already starts with "Rotary "/"Rotaract " — clubs whose
  /// stored name doesn't follow that convention at all are shown verbatim
  /// rather than getting a fabricated prefix stitched onto their real name.
  String get displayClubName {
    final n = clubName.trim();
    final lower = n.toLowerCase();
    if (!lower.startsWith('rotary ') && !lower.startsWith('rotaract ')) {
      return n;
    }
    return '${clubType == 'rotaract' ? 'Rotaract' : 'Rotary'} '
        '${_stripClubPrefix(n)}';
  }

  /// Splash subtitle, generic until the club is known.
  String get splashSubtitle => clubBrandingKnown
      ? 'Check in, follow projects, and stay connected with the $displayClubName.'
      : 'Check in, follow projects, and stay connected with your Rotary club.';

  /// "President" is the role dropdown's label; "Club President" is the
  /// legacy value existing president rows already carry — both count.
  static const Set<String> _presidentRoles = {'Club President', 'President'};
  bool get isPresident => _presidentRoles.contains(currentMemberRole.trim());

  /// The Secretary shares the President's management powers (add/manage
  /// members, events, projects, votes) — matches the backend's
  /// `MANAGER_ROLES`. The reverse doesn't hold: the Secretary workspace
  /// stays the Secretary's alone (see [isSecretary]).
  bool get canManageClub => isPresident || isSecretary;

  /// Generating an event's registration QR/link is limited to the club's
  /// executive roles, not every member.
  static const Set<String> _eventRegistrationRoles = {
    'Club President',
    'President',
    'Sergeant-at-Arms',
    'President-Elect',
    'Secretary',
    'Immediate Past President',
    'Treasurer',
    'Board Director',
  };
  bool get canGenerateEventQr =>
      _eventRegistrationRoles.contains(currentMemberRole.trim());

  /// Club history (milestones) is normally the Secretary's alone to edit,
  /// but the President and Immediate Past President — who'd know the
  /// club's own history best — can too. Matches the backend's
  /// `HISTORY_EDITOR_ROLES` gate.
  static const Set<String> _historyEditorRoles = {
    'Club President',
    'President',
    'Immediate Past President',
    'Secretary',
  };
  bool get canEditClubHistory =>
      _historyEditorRoles.contains(currentMemberRole.trim());

  /// Creating and resolving club votes is limited to the President and
  /// Secretary — plain board members can't. Matches the backend's
  /// `_require_manager` gate in polls.py.
  bool get canCreatePoll => canManageClub;

  // check-in (member scan)
  bool checkInLoading = false;
  String? checkInError;
  String checkInMeetingName = '';
  DateTime? checkInAt;
  bool checkInAlready = false;

  // today
  bool todayLoading = false;
  String todayMeetingName = 'Weekly Fellowship Meeting';
  int todayCheckedInCount = 0;
  List<TodayCheckedInMember> todayCheckedIn = [];
  List<MeetingGuest> todayGuests = [];

  // apologies — who's apologised for today's meeting
  ApologyDraft? apologySheet;
  bool apologiesLoading = false;
  List<ApologyInfo> apologies = [];

  // ── polls ────────────────────────────────────────────────────────────
  // State and logic live in [polls]; these forward to it so every screen
  // that already reads `state.activePoll` etc. keeps working unchanged
  // (see PollController for the actual implementation).
  PollInfo? get activePoll => polls.active;
  bool get pollLoading => polls.loading;
  PollDraft? get voteEditor => polls.voteEditor;
  bool get drawSpinning => polls.drawSpinning;
  String get drawSpinName => polls.drawSpinName;

  // ── events ───────────────────────────────────────────────────────────
  // State and logic live in [eventsController]; these forward to it so
  // every screen that already reads `state.events` etc. keeps working
  // unchanged (see EventsController for the actual implementation).
  List<EventItem> get events => eventsController.events;
  bool get eventsLoaded => eventsController.loaded;
  bool get eventsLoading => eventsController.loading;
  String? get selectedDay => eventsController.selectedDay;
  EventItem? get eventEditor => eventsController.editor;
  bool get editorIsNew => eventsController.editorIsNew;
  String get calendarView => eventsController.calendarView;
  int get calendarYear => eventsController.calendarYear;
  int get calendarMonth => eventsController.calendarMonth;
  DateTime? get selectedMonthDate => eventsController.selectedMonthDate;
  EventItem? get eventQR => eventsController.qrEvent;
  EventRegistration? get eventRegistration => eventsController.registration;
  bool get eventRegistrationLoading => eventsController.registrationLoading;
  String? get eventRegistrationError => eventsController.registrationError;
  bool get qrCopied => eventsController.qrCopied;
  List<EventItem> get visibleEvents => eventsController.visibleEvents;
  String get eventsSectionLabel => eventsController.sectionLabel;
  bool get canDeleteEvent => eventsController.canDeleteEvent;
  NextMeeting? get nextMeeting => eventsController.nextMeeting;
  bool get nextMeetingLoaded => eventsController.nextMeetingLoaded;
  bool get nextMeetingLoading => eventsController.nextMeetingLoading;
  String get nextMeetingBadge => eventsController.nextMeetingBadge;

  // ── members ──────────────────────────────────────────────────────────
  // State and logic live in [membersController]; these forward to it so
  // every screen that already reads `state.clubMembers` etc. keeps
  // working unchanged (see MembersController for the actual
  // implementation).
  String get search => membersController.search;
  String get memberFilter => membersController.filter;
  List<Member> get extraMembers => membersController.extraMembers;
  MemberDraft? get memberEditor => membersController.editor;
  Member? get memberProfile => membersController.profile;
  List<Member> get clubMembers => membersController.roster;
  bool get clubMembersLoaded => membersController.loaded;
  bool get clubMembersLoading => membersController.loading;
  String? get clubMembersError => membersController.error;

  // ── real club data loaders ─────────────────────────────────────────
  MemberSummary? summary;
  bool get checkedInToday => summary?.checkedInToday ?? false;
  final List<ClubMeeting> clubMeetings = [];
  bool meetingsLoaded = false;

  // ── treasury ─────────────────────────────────────────────────────────
  // State and logic live in [treasury]; these forward to it so every
  // screen that already reads `state.treasurySummary` etc. keeps working
  // unchanged (see TreasuryController for the actual implementation).
  TreasurySummary? get treasurySummary => treasury.summary;
  List<DuesMemberInfo> get duesList => treasury.duesList;
  List<TransactionInfo> get transactions => treasury.transactions;
  bool get treasuryLoaded => treasury.loaded;
  bool get treasuryLoading => treasury.loading;
  TxDraft? get txEntry => treasury.txEntry;
  DuesSettingDraft? get duesSettingEditor => treasury.duesSettingEditor;

  // ── secretary workspace ─────────────────────────────────────────────
  // State and logic live in [secretary]; these forward to it so every
  // screen that already reads `state.minutes` etc. keeps working
  // unchanged (see SecretaryController for the actual implementation).
  List<MinuteInfo> get minutes => secretary.minutes;
  List<MilestoneInfo> get milestones => secretary.milestones;
  ReportInfo? get monthlyReport => secretary.monthlyReport;
  ReportInfo? get annualReport => secretary.annualReport;
  List<ClubDocumentInfo> get clubDocuments => secretary.clubDocuments;
  bool get documentUploading => secretary.documentUploading;
  String? get documentError => secretary.documentError;
  MinuteInfo? get minuteOpen => secretary.minuteOpen;
  bool get minuteBodySaving => secretary.minuteBodySaving;
  bool get minuteAudioUploading => secretary.minuteAudioUploading;
  String? get minuteAudioError => secretary.minuteAudioError;
  bool get secretaryLoaded => secretary.loaded;
  bool get secretaryLoading => secretary.loading;
  MinuteDraft? get minuteEditor => secretary.minuteEditor;
  MilestoneDraft? get milestoneEditor => secretary.milestoneEditor;
  String get milestoneFilter => secretary.milestoneFilter;
  String get secretaryTab => secretary.tab;
  List<MilestoneInfo> get visibleMilestones => secretary.visibleMilestones;

  Future<void> loadSummary() async {
    final token = authToken;
    if (token == null) return;
    try {
      final s = await _api.fetchMySummary(token);
      _update(() {
        summary = s;
        clubStatus = s.clubStatus;
        if (clubStatus == 'suspended' && tab != 'suspended') tab = 'suspended';
      });
    } on ApiException catch (e) {
      // A rejected token means the member no longer exists (or the session
      // is invalid) — sign out. Other errors: retry on next navigation.
      if (_isAuthFailure(e)) unawaited(_clearSession());
    }
  }

  Future<void> loadNextMeeting() => eventsController.loadNextMeeting();
  Future<void> loadEvents() => eventsController.load();

  Future<void> loadGallery() => gallery.load();

  Future<void> loadProjects() async {
    final token = authToken;
    if (token == null) return;
    _update(() => projectsLoading = true);
    try {
      final list = await _api.fetchProjects(token);
      _update(() {
        projects
          ..clear()
          ..addAll([
            for (final p in list)
              Project(
                id: p.id,
                name: p.name,
                icon: p.name.isEmpty ? 'P' : p.name[0].toUpperCase(),
                area: p.area,
                pct: p.pct,
                desc: p.desc,
                deadline: p.deadline,
                photo: p.image,
                areaOfFocus: p.areaOfFocus,
                beneficiariesReached: p.beneficiariesReached,
                updates: [
                  for (final u in p.updates)
                    ProjectUpdateEntry(
                        u.id, u.pct, u.note, u.authorName, u.createdAt),
                ],
              ),
          ]);
        projectsLoaded = true;
        projectsLoading = false;
      });
    } on ApiException {
      _update(() => projectsLoading = false);
    }
  }

  Future<void> loadMeetings() async {
    final token = authToken;
    if (token == null) return;
    try {
      final list = await _api.fetchMeetings(token);
      _update(() {
        clubMeetings
          ..clear()
          ..addAll(list);
        meetingsLoaded = true;
      });
    } on ApiException {
      // Attendance shows an empty history; retried on next navigation.
    }
  }

  Future<void> loadClubMembers() async {
    await membersController.load();
    // Self-heal from the fresh roster (matched by phone, since the app
    // doesn't otherwise track its own member id) — catches a leadership
    // transition that happened server-side while this session stayed
    // logged in, not just what login returned at sign-in time.
    final phone = currentMemberPhone.trim();
    if (phone.isEmpty) return;
    final matches = membersController.roster.where((m) => m.phone == phone);
    if (matches.isEmpty) return;
    final self = matches.first;
    if (self.needsBoardSetup != needsBoardSetup ||
        self.role != currentMemberRole ||
        self.isBoard != currentMemberIsBoard) {
      _update(() {
        needsBoardSetup = self.needsBoardSetup;
        currentMemberRole = self.role;
        currentMemberIsBoard = self.isBoard;
      });
      unawaited(_persistSession());
    }
  }

  Future<void> dismissBoardSetup() async {
    final token = authToken;
    if (token == null) return;
    _update(() => needsBoardSetup = false);
    unawaited(_persistSession());
    try {
      await _api.dismissBoardSetup(token);
    } catch (_) {
      // Best-effort — worst case the banner reappears next roster sync,
      // which is a mild annoyance, not a correctness problem.
    }
  }

  // projects — real club data, loaded from the backend after login
  final List<Project> projects = [];
  bool projectsLoaded = false;
  bool projectsLoading = false;
  Project? projectEditor; // a working copy while the editor sheet is open
  bool projectEditorIsNew = false;

  // attendance
  String attView = 'mine'; // mine | club
  String registerTab = 'members'; // members | guests | apologies | clubs
  int selectedMeeting = 0;
  bool reportToast = false;
  Timer? _reportTimer;
  List<ApologyInfo> registerApologies = [];
  bool registerApologiesLoading = false;

  // ── gallery ──────────────────────────────────────────────────────────
  // State and logic live in [gallery]; these forward to it so every
  // screen that already reads `state.galleryUploads` etc. keeps working
  // unchanged (see GalleryController for the actual implementation).
  UploadSheet? get uploadSheet => gallery.uploadSheet;
  List<GalleryUpload> get galleryUploads => gallery.uploads;
  bool get galleryLoaded => gallery.loaded;
  bool get galleryLoading => gallery.loading;
  String? get downloadToast => gallery.downloadToast;
  PhotoInfo? get photo => gallery.photo;

  void _update(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  void go(String newTab) {
    _update(() {
      tab = newTab;
      if (scanStep == 'success' || scanStep == 'guestDone') {
        scanStep = 'idle';
      }
    });
  }

  void goHome() {
    go('home');
    if (authToken != null) {
      loadSummary();
      loadActivePoll();
      if (!galleryLoaded && !galleryLoading) loadGallery();
      // Unlike gallery (static until someone uploads), the next meeting is
      // time-sensitive — its check-in window closes and the "next" one
      // rolls over to next week while the session is still open, so this
      // always refetches rather than trusting a stale cached value.
      if (!nextMeetingLoading) loadNextMeeting();
    }
  }

  void goScan() {
    // Entered from Home's "Check in" — swiping back from here belongs to
    // goHome(), not the splash guest-entry case below.
    _scanFromSplash = false;
    go('scan');
  }

  void goAttendance() {
    go('attendance');
    if (authToken != null) {
      loadMeetings();
      loadSummary();
    }
  }

  void goEvents() {
    go('events');
    if (authToken != null && !eventsLoaded && !eventsLoading) loadEvents();
  }

  void goMembers() {
    go('members');
    if (authToken != null && !clubMembersLoaded && !clubMembersLoading) {
      loadClubMembers();
    }
  }

  void goProjects() {
    go('projects');
    if (authToken != null && !projectsLoaded && !projectsLoading) {
      loadProjects();
    }
  }

  void goToday() {
    go('today');
    loadToday();
    loadApologies();
  }

  Future<void> loadToday() async {
    _update(() => todayLoading = true);
    try {
      final summary = await _api.fetchToday(token: authToken);
      _update(() {
        todayMeetingName = summary.meetingName;
        todayCheckedInCount = summary.memberCount;
        todayCheckedIn = summary.members;
        todayGuests = summary.guests;
        todayLoading = false;
      });
    } on ApiException {
      // Keep whatever was last loaded (or the static fallback) rather than
      // blanking the screen on a transient network error.
      _update(() => todayLoading = false);
    }
  }

  Future<void> loadApologies() async {
    final token = authToken;
    if (token == null) return;
    _update(() => apologiesLoading = true);
    try {
      final list = await _api.fetchApologies(token);
      _update(() {
        apologies = list;
        apologiesLoading = false;
      });
    } on ApiException {
      _update(() => apologiesLoading = false);
    }
  }

  void openApology() => _update(() => apologySheet = ApologyDraft());
  void closeApology() => _update(() => apologySheet = null);
  void onApologyReason(String v) => _update(() => apologySheet?.reason = v);

  Future<void> sendApology() async {
    final sheet = apologySheet;
    final token = authToken;
    if (sheet == null || token == null) return;
    _update(() {
      sheet.saving = true;
      sheet.error = null;
    });
    try {
      // The apology is for the upcoming fellowship (the Home card the
      // button sits on), falling back to today when none is scheduled.
      final result = await _api.submitApology(token, sheet.reason.trim(),
          meetingDate: nextMeeting?.dateIso);
      _update(() {
        apologies.removeWhere((a) => a.id == result.id);
        apologies.add(result);
        apologySheet = null;
      });
    } on ApiException catch (e) {
      _update(() {
        sheet.saving = false;
        sheet.error = e.message;
      });
    }
  }

  // ── polls ────────────────────────────────────────────────────────────
  // Thin forwards to [polls] — kept here so every screen's existing
  // `state.loadActivePoll()` / `state.castVote()` etc. call sites don't
  // need to change.
  Future<void> loadActivePoll() => polls.load();
  void openVoteEditor() => polls.openVoteEditor();
  void closeVoteEditor() => polls.closeVoteEditor();
  void setVoteType(String v) => polls.setVoteType(v);
  void setVoteTitle(String v) => polls.setVoteTitle(v);
  void setVoteSub(String v) => polls.setVoteSub(v);
  void setVoteCloses(String v) => polls.setVoteCloses(v);
  void setVoteOptions(String v) => polls.setVoteOptions(v);
  Future<void> saveVoteEditor() => polls.saveVoteEditor();
  Future<void> castVote(String choice) => polls.castVote(choice);
  void runDraw() => polls.runDraw();

  void goGallery() {
    go('gallery');
    if (authToken != null && !galleryLoaded && !galleryLoading) loadGallery();
  }

  void goTreasury() {
    go('treasury');
    if (authToken != null && !treasuryLoaded && !treasuryLoading) {
      loadTreasury();
    }
  }

  void goSecretary() {
    go('secretary');
    // The President can view/export reports here too, but Minutes/Docs
    // stay Secretary-only (their mutation endpoints 403 for anyone else)
    // — never land a non-Secretary viewer on a tab they can't see.
    if (!isSecretary &&
        secretary.tab != 'monthly' &&
        secretary.tab != 'annual') {
      secretary.pickTab('monthly');
    }
    if (authToken != null && !secretaryLoaded && !secretaryLoading) {
      loadSecretaryWorkspace();
    }
  }

  void goClubHistory() {
    go('history');
    if (authToken != null) loadMilestones();
  }

  void goSplash() => go('splash');

  /// Every screen in this app is reached directly from Home (or from the
  /// bottom nav), so "back" always resolves to Home — matching what each
  /// screen's own visible back button already does. Open overlays (photo
  /// viewer / certificate / event editor / upload sheet) close first.
  bool get canGoBack =>
      photo != null ||
      cert != null ||
      eventEditor != null ||
      eventQR != null ||
      uploadSheet != null ||
      projectEditor != null ||
      projectUpdateSheet != null ||
      memberEditor != null ||
      memberProfile != null ||
      apologySheet != null ||
      txEntry != null ||
      duesSettingEditor != null ||
      voteEditor != null ||
      minuteEditor != null ||
      milestoneEditor != null ||
      (tab != 'home' && tab != 'splash' && tab != 'suspended');

  void goBack() {
    if (photo != null) {
      closePhoto();
    } else if (cert != null) {
      closeCert();
    } else if (eventEditor != null) {
      closeEditor();
    } else if (eventQR != null) {
      closeQR();
    } else if (uploadSheet != null) {
      closeUpload();
    } else if (apologySheet != null) {
      closeApology();
    } else if (txEntry != null) {
      closeTxEntry();
    } else if (duesSettingEditor != null) {
      closeDuesSettings();
    } else if (voteEditor != null) {
      closeVoteEditor();
    } else if (minuteEditor != null) {
      closeMinuteEditor();
    } else if (milestoneEditor != null) {
      closeMilestoneEditor();
    } else if (projectEditor != null) {
      closeProjectEditor();
    } else if (projectUpdateSheet != null) {
      closeProjectUpdate();
    } else if (memberEditor != null) {
      closeMemberEditor();
    } else if (memberProfile != null) {
      closeMemberProfile();
    } else if (tab == 'login') {
      goSplash();
    } else if (tab == 'scan' && authToken == null && visitorClubId != null) {
      // A visitor with a remembered club backs out of the scanner onto
      // that club's dashboard, mirroring how they got here.
      _update(() => tab = 'visitorHome');
    } else if (tab == 'scan' && (authToken == null || _scanFromSplash)) {
      // A walk-in visitor (no session) or a logged-in member who chose
      // "I'm visiting as a Guest" both started this from the splash
      // screen's guest button — back should undo that choice, not drop
      // a still-logged-in member onto their own dashboard.
      goSplash();
    } else if (tab == 'visitorHome') {
      goSplash();
    } else if (tab != 'home' && tab != 'splash' && tab != 'suspended') {
      goHome();
    }
  }

  // ── login ──────────────────────────────────────────────────────────────
  void enterMember() {
    // Login credentials are asked for only once: with a live session
    // "Continue as Member" goes straight to the dashboard, skipping
    // the login form. The splash itself never auto-advances.
    if (authToken != null) {
      goHome();
      return;
    }
    _update(() {
      tab = 'login';
      scanMode = 'member';
      loginError = false;
    });
  }

  void setLoginId(String v) => _update(() {
        loginId = v;
        loginError = false;
      });

  void setLoginPin(String v) => _update(() {
        loginPin = v;
        loginError = false;
      });

  Future<void> submitLogin() async {
    if (loginId.trim().isEmpty || loginPin.trim().isEmpty) {
      _update(() {
        loginError = true;
        loginErrorMessage = 'Enter your member number and PIN to continue.';
      });
      return;
    }
    _update(() {
      loginLoading = true;
      loginError = false;
    });
    try {
      final result = await _api.login(loginId.trim(), loginPin.trim());
      _update(() {
        authToken = result.token;
        currentMemberName = result.member.name;
        currentMemberRole = result.member.role;
        currentMemberPhone = result.member.phone;
        currentMemberIsBoard = result.member.isBoard;
        needsBoardSetup = result.member.needsBoardSetup;
        clubId = result.clubId;
        clubName = result.clubName;
        clubLogo = result.clubLogo;
        clubType = result.clubType;
        RCColors.setClubType(clubType);
        clubStatus = result.clubStatus;
        clubBrandingKnown = true;
        _resetClubData();
        tab = clubStatus == 'suspended' ? 'suspended' : 'home';
        loginError = false;
        loginLoading = false;
        loginPin = '';
      });
      unawaited(_persistSession());
      unawaited(loadClubMembers());
      unawaited(loadSummary());
      unawaited(loadEvents());
      unawaited(loadProjects());
      unawaited(loadMeetings());
      unawaited(_sendPushToken());
      unawaited(loadActivePoll());
      unawaited(loadNextMeeting());
      unawaited(loadGallery());
    } on ApiException catch (e) {
      _update(() {
        loginError = true;
        loginErrorMessage = e.message;
        loginLoading = false;
      });
    }
  }

  /// Self-service PIN reset. Returns whether the request actually reached
  /// the server — the server's own response is always the same generic
  /// message regardless of whether the identifier matched a real member,
  /// so there's nothing account-specific to report back here either way.
  Future<bool> requestPinReset(String identifier) async {
    try {
      await _api.forgotPin(identifier);
      return true;
    } on ApiException {
      return false;
    }
  }

  void enterGuest() {
    // A returning visitor goes straight back to the dashboard of the last
    // club they checked in at — they only see the scanner again when they
    // choose to check in (or scan a different club) from there.
    if (authToken == null && visitorClubId != null) {
      _update(() => tab = 'visitorHome');
      unawaited(loadVisitorClub());
      return;
    }
    _update(() {
      tab = 'scan';
      scanMode = 'guest';
      scanStep = 'idle';
      _scanFromSplash = true;
    });
  }

  /// Fetch (or refresh) the visited club's public profile for the visitor
  /// dashboard. Stale data is kept on-screen while refreshing.
  Future<void> loadVisitorClub() async {
    final id = visitorClubId;
    if (id == null || visitorClubLoading) return;
    _update(() {
      visitorClubLoading = true;
      visitorClubError = null;
    });
    try {
      final club = await _api.fetchVisitorClub(id);
      _update(() {
        visitorClubLoading = false;
        visitorClubName = club.name;
        visitorClubLogo = club.logo;
        visitorClubType = club.clubType;
        visitorEvents = club.events;
      });
      unawaited(_persistVisitorClub());
    } on ApiException catch (e) {
      _update(() {
        visitorClubLoading = false;
        visitorClubError = e.message;
      });
    }
  }

  /// The visitor dashboard's "Check in" button — opens the scanner in
  /// guest mode; back from there returns to the dashboard.
  void visitorScan() => _update(() {
        tab = 'scan';
        scanMode = 'guest';
        scanStep = 'idle';
        _scanFromSplash = false;
        visitorJustCheckedIn = false;
      });

  // ── scan ───────────────────────────────────────────────────────────────
  void pickMember() => _update(() {
        scanMode = 'member';
        scanStep = 'idle';
      });

  void pickGuest() => _update(() {
        scanMode = 'guest';
        scanStep = 'idle';
      });

  Future<void> simulateScan() async {
    if (scanMode == 'guest') {
      _update(() {
        // A logged-in member using this isn't a walk-in guest — they're
        // registering themselves as a visitor at a club that isn't their
        // own, so their name is already known.
        if (authToken != null && guestName.trim().isEmpty) {
          guestName = currentMemberName;
        }
        scanStep = 'guestForm';
      });
      return;
    }
    await _checkInMember();
  }

  /// club_id decoded from a real, printed club QR code (scanned via the
  /// camera). Distinct from "Simulate scan"/typed-club-name — a real scan
  /// always identifies the exact club, so nobody needs to type it.
  int? scannedClubId;

  /// Called when the camera decodes a real Rotary Connect club QR while in
  /// Guest mode. Anyone — a first-time visitor or an already-logged-in
  /// member checking into a club that isn't their own — can use this with
  /// no account and no login: a known identity (member session, or a
  /// visitor who's checked in anywhere before) skips the form entirely.
  Future<void> handleClubQrScanned(int clubId) async {
    if (scanMode != 'guest' || scanStep != 'idle') return;
    _update(() => scannedClubId = clubId);

    final knownName = authToken != null ? currentMemberName : visitorName;
    final knownPhone = authToken != null ? currentMemberPhone : visitorPhone;
    // Silent check-in only at a club this identity is already known to:
    // a member session (their account is the identity), or a walk-in who
    // has registered at THIS club before. A visitor scanning a NEW club
    // always fills the form once — pre-filled with their remembered
    // details, so it's a confirm-and-submit, not a retype.
    final registeredHere =
        authToken != null || _visitorRegisteredClubs.contains(clubId);
    if (registeredHere &&
        knownName != null &&
        knownName.trim().isNotEmpty &&
        knownPhone != null &&
        knownPhone.trim().isNotEmpty) {
      await _submitVisitorCheckIn(
        clubId: clubId,
        name: knownName,
        phone: knownPhone,
        hostName: '',
        guestType: guestType,
        // A logged-in member visiting another club is a Rotarian from
        // their own club — name it on the host club's register.
        memberClub: authToken != null ? displayClubName : '',
      );
      return;
    }
    _update(() {
      if (authToken != null) {
        guestName = currentMemberName;
      } else {
        if (guestName.trim().isEmpty) guestName = visitorName ?? '';
        if (guestPhone.trim().isEmpty) guestPhone = visitorPhone ?? '';
      }
      scanStep = 'guestForm';
    });
  }

  Future<void> _checkInMember() async {
    final token = authToken;
    if (token == null) {
      _update(() => checkInError = 'Please log in again to check in.');
      return;
    }
    _update(() {
      checkInLoading = true;
      checkInError = null;
    });
    try {
      final result = await _api.checkIn(token);
      _update(() {
        checkInMeetingName = result.meetingName;
        checkInAt = result.checkedInAt;
        checkInAlready = result.alreadyCheckedIn;
        checkInLoading = false;
        scanStep = 'success';
      });
      unawaited(loadSummary());
      unawaited(loadMeetings());
    } on ApiException catch (e) {
      _update(() {
        checkInLoading = false;
        checkInError = e.message;
      });
    }
  }

  void resetScan() => _update(() {
        scanStep = 'idle';
        guestName = '';
        guestPhone = '';
        guestHost = '';
        guestClub = '';
        guestFormError = false;
        guestSubmitError = null;
        guestVisitedClubName = null;
        scannedClubId = null;
        checkInError = null;
      });

  String get checkInTimeLabel {
    final t = checkInAt?.toLocal();
    if (t == null) return '';
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '${t.day} ${monthNames[t.month - 1].substring(0, 3)} ${t.year}, $hour12:$minute $ampm';
  }

  void setGuestName(String v) => _update(() {
        guestName = v;
        guestFormError = false;
      });

  void setGuestPhone(String v) => _update(() {
        guestPhone = v;
        guestFormError = false;
      });
  void setGuestHost(String v) => _update(() => guestHost = v);
  void setGuestClub(String v) => _update(() => guestClub = v);
  void setGuestType(String v) => _update(() => guestType = v);

  bool guestSubmitting = false;
  String? guestSubmitError;

  /// Set once a guest/visitor check-in succeeds, so the confirmation
  /// screen can name the actual club — which for a logged-in member
  /// visiting elsewhere isn't the same as [clubName].
  String? guestVisitedClubName;

  Future<void> submitGuest() async {
    if (guestName.trim().isEmpty || guestPhone.trim().isEmpty) {
      _update(() => guestFormError = true);
      return;
    }
    // A real scanned QR always identifies the exact club — nothing else
    // to resolve. Otherwise (the "Simulate scan" fallback, used when
    // there's no camera/printed QR to test with): a logged-in member
    // has to type which club they're visiting, since this device's own
    // clubId is their own club, not the one in front of them.
    final scanned = scannedClubId;
    final visitingElsewhere = scanned == null && authToken != null;
    if (visitingElsewhere && guestClub.trim().isEmpty) {
      _update(() => guestFormError = true);
      return;
    }
    final id = scanned ?? (visitingElsewhere ? null : clubId);
    if (id == null && !visitingElsewhere) {
      _update(() => guestSubmitError =
          "This device isn't linked to a club yet — ask a member to log in first.");
      return;
    }
    await _submitVisitorCheckIn(
      clubId: id,
      clubName: id == null && visitingElsewhere ? guestClub.trim() : null,
      name: guestName.trim(),
      phone: guestPhone.trim(),
      hostName: guestHost.trim(),
      guestType: guestType,
      // The visitor's own club: a logged-in member's comes from their
      // account; a walk-in Visiting Rotarian typed theirs into the
      // "Home club" field (which is also guestClub — the field doubles as
      // the visited club's name only in the visitingElsewhere case above).
      memberClub: authToken != null
          ? displayClubName
          : (isVisitingRotarian ? guestClub.trim() : ''),
    );
  }

  /// Shared by the manual guest form and the silent auto-check-in that
  /// fires when a QR scan resolves to an already-known identity.
  Future<void> _submitVisitorCheckIn({
    int? clubId,
    String? clubName,
    required String name,
    required String phone,
    required String hostName,
    required String guestType,
    String memberClub = '',
  }) async {
    _update(() {
      guestSubmitting = true;
      guestSubmitError = null;
    });
    try {
      final visited = await _api.guestCheckIn(
        clubId: clubId,
        clubName: clubName,
        name: name,
        phone: phone,
        hostName: hostName,
        guestType: guestType,
        memberClub: memberClub,
      );
      // A logged-in member's identity always comes from their account —
      // only remember a *visitor* identity for devices with no member
      // session, so it isn't mixed up with the real member's own details.
      if (authToken == null) {
        unawaited(_persistVisitorIdentity(name, phone));
        _update(() {
          visitorName = name;
          visitorPhone = phone;
        });
      }
      _update(() {
        guestSubmitting = false;
        guestVisitedClubName = visited.clubName;
      });
      if (authToken == null) {
        // Walk-in visitor: this club is now "theirs" — remember it and
        // land on its dashboard instead of a one-off confirmation.
        _update(() {
          _visitorRegisteredClubs.add(visited.clubId);
          visitorClubId = visited.clubId;
          visitorClubName = visited.clubName;
          visitorJustCheckedIn = true;
          tab = 'visitorHome';
          scanStep = 'idle';
        });
        unawaited(_persistVisitorClub());
        unawaited(loadVisitorClub());
      } else {
        _update(() => scanStep = 'guestDone');
      }
    } on ApiException catch (e) {
      _update(() {
        guestSubmitting = false;
        guestSubmitError = e.message;
      });
    }
  }

  bool get isVisitingRotarian => guestType == 'Visiting Rotarian';

  String get guestNameShown =>
      guestName.trim().isNotEmpty ? guestName.trim() : 'Guest';
  String get guestTypeShown => guestType;
  String get guestClubShown => isVisitingRotarian && guestClub.trim().isNotEmpty
      ? ' from ${guestClub.trim()}'
      : '';
  String get guestStreakLine => 'A thank-you text is on its way to your phone.';

  /// The second confirmation line — different wording for a member
  /// checking into a club that isn't their own vs. a walk-in guest.
  String get guestConfirmationLine {
    final visited = guestVisitedClubName;
    if (visited != null) return 'Checked in as a visitor at $visited';
    return 'Registered as $guestTypeShown$guestClubShown · attendance recorded';
  }

  // ── overlays ───────────────────────────────────────────────────────────
  /// Which album the open photo belongs to — forwards to [gallery], the
  /// only place that opens this viewer.
  String? get photoAlbum => gallery.photoAlbum;

  void openPhoto(PhotoInfo p, {String? album}) => gallery.openPhoto(p, album: album);
  void closePhoto() => gallery.closePhoto();
  void showAlbumPhotoAt(int index) => gallery.showAlbumPhotoAt(index);

  void openCert(CertInfo c) => _update(() => cert = c);
  void closeCert() => _update(() => cert = null);

  // ── members ────────────────────────────────────────────────────────────
  // Thin forwards to [membersController] — kept here so every screen's
  // existing `state.setSearch()` / `state.saveMember()` etc. call sites
  // don't need to change.
  void setSearch(String v) => membersController.setSearch(v);
  void setMemberFilter(String v) => membersController.setFilter(v);

  /// Logged in → the real club roster from the backend; otherwise the
  /// static design list (pre-login preview only).
  List<Member> get allMembers =>
      membersController.membersFor(authToken != null);

  void openAddMember() => membersController.openAddMember();
  void closeMemberEditor() => membersController.closeMemberEditor();
  void setMemberName(String v) => membersController.setMemberName(v);
  void setMemberRole(String v) => membersController.setMemberRole(v);
  void setMemberEmail(String v) => membersController.setMemberEmail(v);
  void setMemberPhone(String v) => membersController.setMemberPhone(v);
  void setMemberIsBoard(bool v) => membersController.setMemberIsBoard(v);
  void setMemberDob(String v) => membersController.setMemberDob(v);
  Future<AddedClubMember?> saveMember() => membersController.saveMember();
  void openMemberProfile(Member m) => membersController.openMemberProfile(m);
  void closeMemberProfile() => membersController.closeMemberProfile();

  Member? get roleEditTarget => membersController.roleEditTarget;
  String get roleEditRole => membersController.roleEditRole;
  bool get roleEditIsBoard => membersController.roleEditIsBoard;
  void openRoleEditor(Member m) => membersController.openRoleEditor(m);
  void closeRoleEditor() => membersController.closeRoleEditor();
  void setRoleEditRole(String v) => membersController.setRoleEditRole(v);
  void setRoleEditIsBoard(bool v) => membersController.setRoleEditIsBoard(v);
  Future<void> saveRoleEdit() => membersController.saveRoleEdit();
  Future<void> setMemberStatus(int memberId, String status) =>
      membersController.setMemberStatus(memberId, status);

  // ── projects ───────────────────────────────────────────────────────────
  void openAddProject() => _update(() {
        projectEditor = Project(
            id: 0,
            name: '',
            icon: 'P',
            area: '',
            pct: 0,
            desc: '',
            deadline: '');
        projectEditorIsNew = true;
      });

  void openEditProject(Project p) => _update(() {
        projectEditor = p.copy();
        projectEditorIsNew = false;
      });

  void setProjectName(String v) => _update(() {
        final ed = projectEditor;
        if (ed == null) return;
        ed.name = v;
        ed.icon = v.trim().isEmpty ? 'P' : v.trim()[0].toUpperCase();
      });

  void setProjectArea(String v) => _update(() => projectEditor?.area = v);
  void setProjectAreaOfFocus(String? v) =>
      _update(() => projectEditor?.areaOfFocus = v);
  void setProjectDesc(String v) => _update(() => projectEditor?.desc = v);
  void setProjectDeadline(String v) =>
      _update(() => projectEditor?.deadline = v);
  void setProjectPct(int v) => _update(() => projectEditor?.pct = v);
  void setProjectBeneficiariesReached(int v) =>
      _update(() => projectEditor?.beneficiariesReached = v);
  void setProjectPhoto(Uint8List bytes) => _update(() {
        projectEditor?.pendingPhotoBytes = bytes;
        projectEditor?.photoRemoved = false;
      });
  void removeProjectPhoto() => _update(() {
        projectEditor?.photo = null;
        projectEditor?.pendingPhotoBytes = null;
        projectEditor?.photoRemoved = true;
      });
  void closeProjectEditor() => _update(() => projectEditor = null);

  bool get canDeleteProject => projectEditor != null && !projectEditorIsNew;

  Future<void> deleteProject() async {
    final p = projectEditor;
    final token = authToken;
    if (p == null || token == null) return;
    try {
      await _api.deleteProject(token, p.id);
    } on ApiException {
      // fall through — list reload below reflects the server's truth
    }
    _update(() => projectEditor = null);
    await loadProjects();
  }

  Future<void> saveProject() async {
    final p = projectEditor;
    final token = authToken;
    if (p == null || p.name.trim().isEmpty || token == null) return;
    final area = p.area.trim().isEmpty ? 'Club project' : p.area.trim();
    final desc = p.desc.trim().isEmpty ? 'New club project.' : p.desc.trim();
    final deadline = p.deadline.trim().isEmpty
        ? (p.pct >= 100 ? 'Completed' : 'Not set')
        : p.deadline.trim();
    // null leaves the photo untouched; a data URL sets/replaces it; the
    // "__remove__" sentinel clears it.
    final String? image = p.pendingPhotoBytes != null
        ? 'data:image/jpeg;base64,${base64Encode(p.pendingPhotoBytes!)}'
        : (p.photoRemoved ? '__remove__' : null);
    try {
      await _api.saveProject(token,
          id: projectEditorIsNew ? null : p.id,
          name: p.name.trim(),
          area: area,
          pct: p.pct,
          desc: desc,
          deadline: deadline,
          image: image,
          areaOfFocus: p.areaOfFocus,
          beneficiariesReached: p.beneficiariesReached);
      _update(() => projectEditor = null);
      await loadProjects();
    } on ApiException {
      _update(() => projectEditor = null);
    }
  }

  /// Working copy while the "Add progress update" sheet is open — the
  /// lightweight flow for logging what's been done and the current %,
  /// separate from [projectEditor]'s full name/area/desc/deadline fields.
  ProjectUpdateDraft? projectUpdateSheet;

  void openProjectUpdate(Project p) => _update(
      () => projectUpdateSheet = ProjectUpdateDraft(projectId: p.id, pct: p.pct));
  void closeProjectUpdate() => _update(() => projectUpdateSheet = null);
  void setProjectUpdatePct(int v) =>
      _update(() => projectUpdateSheet?.pct = v);
  void setProjectUpdateNote(String v) =>
      _update(() => projectUpdateSheet?.note = v);

  Future<void> submitProjectUpdate() async {
    final draft = projectUpdateSheet;
    final token = authToken;
    if (draft == null || token == null) return;
    _update(() {
      draft.saving = true;
      draft.error = null;
    });
    try {
      await _api.addProjectUpdate(token, draft.projectId,
          pct: draft.pct, note: draft.note.trim());
      _update(() => projectUpdateSheet = null);
      await loadProjects();
    } on ApiException catch (e) {
      _update(() {
        draft.saving = false;
        draft.error = e.message;
      });
    }
  }

  // ── treasury ─────────────────────────────────────────────────────────
  // Thin forwards to [treasury] — kept here so every screen's existing
  // `state.loadTreasury()` / `state.saveTxEntry()` etc. call sites don't
  // need to change.
  Future<void> loadTreasury() => treasury.load();
  Future<void> markDuesPaid(int memberId) => treasury.markDuesPaid(memberId);
  void openTxEntry() => treasury.openTxEntry();
  void closeTxEntry() => treasury.closeTxEntry();
  void setTxKind(String kind) => treasury.setTxKind(kind);
  void setTxLabel(String v) => treasury.setTxLabel(v);
  void setTxAmount(String v) => treasury.setTxAmount(v);
  Future<void> saveTxEntry() => treasury.saveTxEntry();
  void openDuesSettings() => treasury.openDuesSettings();
  void closeDuesSettings() => treasury.closeDuesSettings();
  void setDuesAmount(String v) => treasury.setDuesAmount(v);
  void setDuesPeriod(String v) => treasury.setDuesPeriod(v);
  Future<void> saveDuesSettings() => treasury.saveDuesSettings();

  // ── secretary workspace ───────────────────────────────────────────────
  // Thin forwards to [secretary] — kept here so every screen's existing
  // `state.loadSecretaryWorkspace()` / `state.saveMinuteEditor()` etc.
  // call sites don't need to change.
  Future<void> loadMilestones() => secretary.loadMilestones();
  Future<void> loadSecretaryWorkspace() => secretary.load();
  void pickSecretaryTab(String tab) => secretary.pickTab(tab);
  void openMinuteEditor() => secretary.openMinuteEditor();
  void closeMinuteEditor() => secretary.closeMinuteEditor();
  void setMinuteTitle(String v) => secretary.setMinuteTitle(v);
  void setMinuteDate(String v) => secretary.setMinuteDate(v);
  Future<void> saveMinuteEditor() => secretary.saveMinuteEditor();
  void openMinuteBody(MinuteInfo minute) => secretary.openMinuteBody(minute);
  void closeMinuteBody() => secretary.closeMinuteBody();
  Future<void> saveMinuteBody(String body) => secretary.saveMinuteBody(body);
  Future<void> deleteMinute(int id) => secretary.deleteMinute(id);
  Future<void> uploadMinuteAudio(
          String title, String meetingDate, String filePath) =>
      secretary.uploadMinuteAudio(title, meetingDate, filePath);
  Future<void> toggleMinuteStatus(MinuteInfo minute) =>
      secretary.toggleMinuteStatus(minute);
  void pickMilestoneFilter(String cat) => secretary.pickMilestoneFilter(cat);
  void openMilestoneEditor() => secretary.openMilestoneEditor();
  void closeMilestoneEditor() => secretary.closeMilestoneEditor();
  void setMilestoneYear(String v) => secretary.setMilestoneYear(v);
  void setMilestoneTitle(String v) => secretary.setMilestoneTitle(v);
  void setMilestoneCategory(String v) => secretary.setMilestoneCategory(v);
  void setMilestoneText(String v) => secretary.setMilestoneText(v);
  Future<void> saveMilestoneEditor() => secretary.saveMilestoneEditor();
  Future<void> deleteMilestone(int id) => secretary.deleteMilestone(id);
  Future<void> uploadClubDocument(String title, List<int> pdfBytes) =>
      secretary.uploadClubDocument(title, pdfBytes);
  Future<void> deleteClubDocument(int id) => secretary.deleteClubDocument(id);

  /// Real "Wednesday 8 July · Service Above Self" line for the home header.
  String get todayLine {
    final now = DateTime.now();
    return '${weekdayNames[now.weekday - 1]} ${now.day} '
        '${monthNames[now.month - 1]} · Service Above Self';
  }

  /// Real "TODAY · 8 Jul" badge for the meeting card.
  String get todayBadge {
    final now = DateTime.now();
    return 'TODAY · ${now.day} ${monthNames[now.month - 1].substring(0, 3)}';
  }

  // ── events ───────────────────────────────────────────────────────────
  // Thin forwards to [eventsController] — kept here so every screen's
  // existing `state.pickDay()` / `state.saveEvent()` etc. call sites
  // don't need to change.
  void pickDay(String dow) => eventsController.pickDay(dow);
  bool dayHasEvents(String dow) => eventsController.dayHasEvents(dow);
  bool isNextEventOccurrence(DateTime date) =>
      eventsController.isNextOccurrence(date);
  void pickCalendarWeek() => eventsController.pickCalendarWeek();
  void pickCalendarMonth() => eventsController.pickCalendarMonth();
  void pickMonthDate(DateTime date, String dow) =>
      eventsController.pickMonthDate(date, dow);
  void goPrevMonth() => eventsController.goPrevMonth();
  void goNextMonth() => eventsController.goNextMonth();
  void openAddEvent() => eventsController.openAddEvent();
  void openEditEvent(EventItem e) => eventsController.openEditEvent(e);
  void setEditorTitle(String v) => eventsController.setEditorTitle(v);
  void setEditorTime(String v) => eventsController.setEditorTime(v);
  void setEditorEndTime(String v) => eventsController.setEditorEndTime(v);
  void setEditorVenue(String v) => eventsController.setEditorVenue(v);
  void setEditorDay(String dow) => eventsController.setEditorDay(dow);
  void setEditorPhoto(Uint8List bytes) => eventsController.setEditorPhoto(bytes);
  void removeEventPhoto() => eventsController.removeEventPhoto();
  Future<void> saveEvent() => eventsController.saveEvent();
  Future<void> deleteEvent() => eventsController.deleteEvent();
  void closeEditor() => eventsController.closeEditor();

  // ── event registration QR ─────────────────────────────────────────────
  void openQR(EventItem e) => eventsController.openQR(e);
  void closeQR() => eventsController.closeQR();
  void copyQRLink() => eventsController.copyQRLink();

  // ── attendance ─────────────────────────────────────────────────────────
  void pickAttMine() => _update(() => attView = 'mine');
  void pickAttClub() => _update(() => attView = 'club');

  void pickRegisterTab(String v) {
    _update(() => registerTab = v);
    if (v == 'apologies') _loadRegisterApologies();
  }

  void pickMeeting(int i) {
    _update(() {
      selectedMeeting = i;
      registerTab = 'members';
      registerApologies = [];
    });
  }

  /// Apologies for the selected past meeting's date — fetched lazily
  /// since the club register loads every meeting's attendees/guests up
  /// front but apologies are a separate endpoint, queried per date.
  Future<void> _loadRegisterApologies() async {
    final token = authToken;
    if (token == null || clubMeetings.isEmpty) return;
    final sel = clubMeetings[selectedMeeting.clamp(0, clubMeetings.length - 1)];
    _update(() => registerApologiesLoading = true);
    try {
      final list = await _api.fetchApologies(token, meetingDate: sel.dateIso);
      _update(() {
        registerApologies = list;
        registerApologiesLoading = false;
      });
    } on ApiException {
      _update(() => registerApologiesLoading = false);
    }
  }

  String get reportName {
    if (clubMeetings.isEmpty) return 'attendance-report.pdf';
    final sel = clubMeetings[selectedMeeting.clamp(0, clubMeetings.length - 1)];
    return 'attendance-${sel.date.toLowerCase().split(' ').join('-')}.pdf';
  }

  void downloadReport() {
    _reportTimer?.cancel();
    _update(() => reportToast = true);
    _reportTimer = Timer(const Duration(milliseconds: 2400), () {
      _update(() => reportToast = false);
    });
  }

  // ── gallery ────────────────────────────────────────────────────────────
  // Thin forwards to [gallery] — kept here so every screen's existing
  // `state.openUpload()` / `state.downloadPhoto()` etc. call sites don't
  // need to change.
  void openUpload() => gallery.openUpload();
  void closeUpload() => gallery.closeUpload();
  void pickUploadAlbum(String album) => gallery.pickUploadAlbum(album);
  void addUploadPhotos(List<Uint8List> photos) =>
      gallery.addUploadPhotos(photos);
  Future<void> saveUpload() => gallery.saveUpload();
  List<GalleryUpload> uploadsFor(String album) => gallery.uploadsFor(album);
  Future<void> downloadPhoto() => gallery.downloadPhoto();
  Future<void> deletePhoto() => gallery.deletePhoto();

  @override
  void dispose() {
    _reportTimer?.cancel();
    treasury.removeListener(notifyListeners);
    treasury.dispose();
    secretary.removeListener(notifyListeners);
    secretary.dispose();
    gallery.removeListener(notifyListeners);
    gallery.dispose();
    polls.removeListener(notifyListeners);
    polls.dispose();
    eventsController.removeListener(notifyListeners);
    eventsController.dispose();
    membersController.removeListener(notifyListeners);
    membersController.dispose();
    super.dispose();
  }
}
