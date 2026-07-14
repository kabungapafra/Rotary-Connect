import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'data.dart';
import 'gallery_controller.dart';
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

/// Working copy of the "New vote" bottom sheet fields.
class PollDraft {
  String type = 'motion'; // motion | election | draw
  String title = '';
  String sub = '';
  String closes = '';
  String options = ''; // newline/comma separated, election & draw only
  bool saving = false;
  String? error;
}

/// Working copy of the "Add member" bottom sheet fields.
class MemberDraft {
  String name = '';
  String role = '';
  String email = '';
  String phone = '';
  String dob = '';
  bool isBoard = false;
  String? error; // validation / save error shown inside the sheet
  bool saving = false;
}

/// Single shared app state, mirroring the design's one-component `state`
/// object and `tab`-based navigation (no push/pop stack — going "back" just
/// sets `tab` to a fixed target screen, exactly as authored).
class AppState extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  // Treasury's data and logic live in their own single-responsibility
  // class; AppState just composes it in and re-broadcasts its changes,
  // rather than owning treasury state directly alongside everything else.
  late final TreasuryController treasury = TreasuryController(_api, () => authToken)
    ..addListener(notifyListeners);
  late final SecretaryController secretary =
      SecretaryController(_api, () => authToken)..addListener(notifyListeners);
  late final GalleryController gallery =
      GalleryController(_api, () => authToken)..addListener(notifyListeners);

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
    });
    final token = prefs.getString('auth_token');
    if (token == null) return;
    _update(() {
      authToken = token;
      currentMemberName = prefs.getString('member_name') ?? '';
      currentMemberRole = prefs.getString('member_role') ?? '';
      currentMemberPhone = prefs.getString('member_phone') ?? '';
      currentMemberIsBoard = prefs.getBool('member_is_board') ?? false;
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
    await prefs.setString('auth_token', token);
    await prefs.setString('member_name', currentMemberName);
    await prefs.setString('member_role', currentMemberRole);
    await prefs.setString('member_phone', currentMemberPhone);
    await prefs.setBool('member_is_board', currentMemberIsBoard);
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
    await prefs.remove('auth_token');
    await prefs.remove('member_name');
    await prefs.remove('member_role');
    await prefs.remove('member_phone');
    await prefs.remove('member_is_board');
    _update(() {
      authToken = null;
      currentMemberName = '';
      currentMemberRole = '';
      currentMemberPhone = '';
      currentMemberIsBoard = false;
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
    activePoll = null;
    events.clear();
    eventsLoaded = false;
    clubMembers = [];
    clubMembersLoaded = false;
    clubMembersError = null;
    clubMeetings.clear();
    meetingsLoaded = false;
    nextMeeting = null;
    nextMeetingLoaded = false;
    apologies = [];
    treasury.reset();
    secretary.reset();
    gallery.reset();
    projects.clear();
    projectsLoaded = false;
  }

  /// Remembered once a walk-in visitor has checked in anywhere, so a QR
  /// scan at any club (the same one again, or a different one) never asks
  /// them to re-enter their details.
  String? visitorName;
  String? visitorPhone;

  Future<void> _persistVisitorIdentity(String name, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('visitor_name', name);
    await prefs.setString('visitor_phone', phone);
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

  String search = '';

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
  };
  bool get canGenerateEventQr =>
      _eventRegistrationRoles.contains(currentMemberRole.trim());

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

  // apologies — who's apologised for today's meeting
  ApologyDraft? apologySheet;
  bool apologiesLoading = false;
  List<ApologyInfo> apologies = [];

  // polls — the club's current (or most recently closed) vote
  PollInfo? activePoll;
  bool pollLoading = false;
  PollDraft? voteEditor;
  bool drawSpinning = false;
  String drawSpinName = '';
  Timer? _drawTimer;

  // events — real club data, loaded from the backend after login
  final List<EventItem> events = [];
  bool eventsLoaded = false;
  bool eventsLoading = false;
  String? selectedDay;
  EventItem? eventEditor; // a working copy while the editor sheet is open
  bool editorIsNew = false;
  String calendarView = 'week'; // week | month
  int calendarYear = DateTime.now().year;
  int calendarMonth = DateTime.now().month; // 1-12, shown in the Month grid
  // The exact date tapped in the Month grid — kept separate from
  // [selectedDay] (a day-of-week name) so tapping one day only highlights
  // that single cell, not every occurrence of that weekday in the month.
  DateTime? selectedMonthDate;
  EventItem? eventQR;
  // Backend-generated registration link + QR image for the open event.
  EventRegistration? eventRegistration;
  bool eventRegistrationLoading = false;
  String? eventRegistrationError;
  bool qrCopied = false;
  Timer? _qrCopyTimer;

  // members
  String memberFilter = 'all'; // all | board | gen
  final List<Member> extraMembers = [];
  MemberDraft? memberEditor;
  Member? memberProfile;

  // Real club roster, fetched from the backend once logged in. The static
  // design list remains only as the pre-login/demo fallback.
  List<Member> clubMembers = [];
  bool clubMembersLoaded = false;
  bool clubMembersLoading = false;
  String? clubMembersError;

  // ── real club data loaders ─────────────────────────────────────────
  MemberSummary? summary;
  bool get checkedInToday => summary?.checkedInToday ?? false;
  final List<ClubMeeting> clubMeetings = [];
  bool meetingsLoaded = false;

  // Home screen's "Next meeting" card — the real soonest upcoming
  // fellowship (date/time/venue), computed by the backend from the club's
  // events. Null once loaded means the club has none scheduled yet.
  NextMeeting? nextMeeting;
  bool nextMeetingLoaded = false;
  bool nextMeetingLoading = false;

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

  Future<void> loadNextMeeting() async {
    final token = authToken;
    if (token == null) return;
    _update(() => nextMeetingLoading = true);
    try {
      final nm = await _api.fetchNextMeeting(token);
      _update(() {
        nextMeeting = nm;
        nextMeetingLoaded = true;
        nextMeetingLoading = false;
      });
    } on ApiException {
      _update(() => nextMeetingLoading = false);
    }
  }

  /// "TODAY · 8 JUL" / "TOMORROW · 9 JUL" / "WED · 15 JUL" for the Next
  /// meeting card, computed from the real date the backend returned —
  /// never assumes the next fellowship is today.
  String get nextMeetingBadge {
    final nm = nextMeeting;
    if (nm == null) return '';
    final date = DateTime.parse(nm.dateIso);
    final today = DateTime.now();
    final diffDays = DateTime(date.year, date.month, date.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    final monthShort =
        _monthNames[date.month - 1].substring(0, 3).toUpperCase();
    if (diffDays == 0) return 'TODAY · ${date.day} $monthShort';
    if (diffDays == 1) return 'TOMORROW · ${date.day} $monthShort';
    final weekdayShort =
        _weekdayNames[date.weekday - 1].substring(0, 3).toUpperCase();
    return '$weekdayShort · ${date.day} $monthShort';
  }

  Future<void> loadEvents() async {
    final token = authToken;
    if (token == null) return;
    _update(() => eventsLoading = true);
    try {
      final list = await _api.fetchEvents(token);
      _update(() {
        events
          ..clear()
          ..addAll([
            for (final e in list)
              EventItem(
                  id: e.id,
                  dow: e.dow,
                  name: e.name,
                  meta: e.meta,
                  photo: e.image),
          ]);
        eventsLoaded = true;
        eventsLoading = false;
      });
    } on ApiException {
      _update(() => eventsLoading = false);
    }
  }

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
    final token = authToken;
    if (token == null) return;
    _update(() {
      clubMembersLoading = true;
      clubMembersError = null;
    });
    try {
      final list = await _api.fetchClubMembers(token);
      _update(() {
        clubMembers = [
          for (final m in list)
            Member(m.name, m.role, m.isBoard,
                email: m.email, phone: m.phone, dob: m.dob),
        ];
        clubMembersLoaded = true;
        clubMembersLoading = false;
      });
    } on ApiException catch (e) {
      _update(() {
        clubMembersLoading = false;
        clubMembersError = e.message;
      });
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
  String registerTab = 'members'; // members | guests | clubs
  int selectedMeeting = 0;
  bool reportToast = false;
  Timer? _reportTimer;

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
      if (!nextMeetingLoaded && !nextMeetingLoading) loadNextMeeting();
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
      final summary = await _api.fetchToday();
      _update(() {
        todayMeetingName = summary.meetingName;
        todayCheckedInCount = summary.memberCount;
        todayCheckedIn = summary.members;
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
  Future<void> loadActivePoll() async {
    final token = authToken;
    if (token == null) return;
    _update(() => pollLoading = true);
    try {
      final poll = await _api.fetchActivePoll(token);
      _update(() {
        activePoll = poll;
        pollLoading = false;
      });
    } on ApiException {
      _update(() => pollLoading = false);
    }
  }

  void openVoteEditor() => _update(() => voteEditor = PollDraft());
  void closeVoteEditor() => _update(() => voteEditor = null);
  void setVoteType(String v) => _update(() => voteEditor?.type = v);
  void setVoteTitle(String v) => _update(() => voteEditor?.title = v);
  void setVoteSub(String v) => _update(() => voteEditor?.sub = v);
  void setVoteCloses(String v) => _update(() => voteEditor?.closes = v);
  void setVoteOptions(String v) => _update(() => voteEditor?.options = v);

  Future<void> saveVoteEditor() async {
    final draft = voteEditor;
    final token = authToken;
    if (draft == null || token == null) return;
    if (draft.title.trim().isEmpty) {
      _update(() => draft.error = 'Enter a title.');
      return;
    }
    final options = draft.options
        .split(RegExp(r'[\n,]'))
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    if (draft.type == 'election' && options.length < 2) {
      _update(() => draft.error = 'An election needs at least 2 candidates.');
      return;
    }
    _update(() {
      draft.saving = true;
      draft.error = null;
    });
    try {
      final poll = await _api.createPoll(
        token,
        type: draft.type,
        title: draft.title.trim(),
        sub: draft.sub.trim(),
        closesLabel: draft.closes.trim(),
        options: options,
      );
      _update(() {
        activePoll = poll;
        voteEditor = null;
      });
    } on ApiException catch (e) {
      _update(() {
        draft.saving = false;
        draft.error = e.message;
      });
    }
  }

  Future<void> castVote(String choice) async {
    final poll = activePoll;
    final token = authToken;
    if (poll == null || token == null) return;
    try {
      final updated = await _api.castVote(token, poll.id, choice);
      _update(() => activePoll = updated);
    } on ApiException {
      // Leave the ballot showing so the member can try again.
    }
  }

  /// A few seconds of purely local suspense (mirroring the source design's
  /// spinning-name animation) before the server-resolved winner lands.
  void runDraw() {
    final poll = activePoll;
    final token = authToken;
    if (poll == null || token == null || drawSpinning || poll.options.isEmpty) {
      return;
    }
    _drawTimer?.cancel();
    var tick = 0;
    _update(() {
      drawSpinning = true;
      drawSpinName = poll.options[0];
    });
    _drawTimer =
        Timer.periodic(const Duration(milliseconds: 90), (timer) async {
      tick++;
      if (tick > 22) {
        timer.cancel();
        try {
          final updated = await _api.runDraw(token, poll.id);
          _update(() {
            activePoll = updated;
            drawSpinning = false;
          });
        } on ApiException {
          _update(() => drawSpinning = false);
        }
      } else {
        _update(() =>
            drawSpinName = poll.options[Random().nextInt(poll.options.length)]);
      }
    });
  }

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
    } else if (memberEditor != null) {
      closeMemberEditor();
    } else if (memberProfile != null) {
      closeMemberProfile();
    } else if (tab == 'login') {
      goSplash();
    } else if (tab == 'scan' && (authToken == null || _scanFromSplash)) {
      // A walk-in visitor (no session) or a logged-in member who chose
      // "I'm visiting as a Guest" both started this from the splash
      // screen's guest button — back should undo that choice, not drop
      // a still-logged-in member onto their own dashboard.
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

  void enterGuest() => _update(() {
        tab = 'scan';
        scanMode = 'guest';
        scanStep = 'idle';
        _scanFromSplash = true;
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
    if (knownName != null &&
        knownName.trim().isNotEmpty &&
        knownPhone != null &&
        knownPhone.trim().isNotEmpty) {
      await _submitVisitorCheckIn(
        clubId: clubId,
        name: knownName,
        phone: knownPhone,
        hostName: '',
        guestType: guestType,
      );
      return;
    }
    // First time this device has ever checked in as a visitor — collect
    // name and phone once; every scan after this is silent.
    _update(() {
      if (authToken != null) guestName = currentMemberName;
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
    return '${t.day} ${_monthNames[t.month - 1].substring(0, 3)} ${t.year}, $hour12:$minute $ampm';
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
  }) async {
    _update(() {
      guestSubmitting = true;
      guestSubmitError = null;
    });
    try {
      final visitedClub = await _api.guestCheckIn(
        clubId: clubId,
        clubName: clubName,
        name: name,
        phone: phone,
        hostName: hostName,
        guestType: guestType,
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
        guestVisitedClubName = visitedClub;
        scanStep = 'guestDone';
      });
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
  void setSearch(String v) => _update(() => search = v);
  void setMemberFilter(String v) => _update(() => memberFilter = v);

  /// Logged in → the real club roster from the backend; otherwise the
  /// static design list (pre-login preview only).
  List<Member> get allMembers => authToken != null ? clubMembers : const [];

  void openAddMember() => _update(() => memberEditor = MemberDraft());
  void closeMemberEditor() => _update(() => memberEditor = null);
  void setMemberName(String v) => _update(() {
        memberEditor?.name = v;
        memberEditor?.error = null;
      });
  void setMemberRole(String v) => _update(() => memberEditor?.role = v);
  void setMemberEmail(String v) => _update(() => memberEditor?.email = v);
  void setMemberPhone(String v) => _update(() {
        memberEditor?.phone = v;
        memberEditor?.error = null;
      });
  void setMemberIsBoard(bool v) => _update(() => memberEditor?.isBoard = v);
  void setMemberDob(String v) => _update(() => memberEditor?.dob = v);

  /// Saves the new member. When the logged-in user is the Club President,
  /// the member is persisted through the backend (which generates their
  /// member number and one-time PIN, returned here for the president to
  /// hand over); the local list is updated either way so the UI matches.
  Future<AddedClubMember?> saveMember() async {
    final m = memberEditor;
    if (m == null) return null;
    if (m.name.trim().isEmpty) {
      _update(() => m.error = 'Enter the member\'s name.');
      return null;
    }

    AddedClubMember? added;
    final token = authToken;
    if (token != null && canManageClub) {
      if (m.phone.trim().isEmpty) {
        _update(() => m.error = 'Phone number is required.');
        return null;
      }
      _update(() {
        m.saving = true;
        m.error = null;
      });
      try {
        added = await _api.addClubMember(
          token,
          name: m.name.trim(),
          role: m.role.trim().isEmpty ? 'Member' : m.role.trim(),
          email: m.email.trim(),
          phone: m.phone.trim(),
          dob: m.dob.trim(),
          isBoard: m.isBoard,
        );
      } on ApiException catch (e) {
        _update(() {
          m.saving = false;
          m.error = e.message;
        });
        return null;
      }
      _update(() => memberEditor = null);
      await loadClubMembers(); // roster now includes the new member
      return added;
    }

    _update(() {
      extraMembers.add(Member(
        m.name.trim(),
        m.role.trim().isEmpty ? 'Member' : m.role.trim(),
        m.isBoard,
        email: m.email.trim(),
        phone: m.phone.trim(),
        dob: m.dob.trim(),
      ));
      memberEditor = null;
    });
    return added;
  }

  void openMemberProfile(Member m) => _update(() => memberProfile = m);
  void closeMemberProfile() => _update(() => memberProfile = null);

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
  void setProjectDesc(String v) => _update(() => projectEditor?.desc = v);
  void setProjectDeadline(String v) =>
      _update(() => projectEditor?.deadline = v);
  void setProjectPct(int v) => _update(() => projectEditor?.pct = v);
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
          image: image);
      _update(() => projectEditor = null);
      await loadProjects();
    } on ApiException {
      _update(() => projectEditor = null);
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

  // ── events ─────────────────────────────────────────────────────────────
  List<EventItem> get visibleEvents {
    final list = selectedDay == null
        ? List.of(events)
        : events.where((e) => e.dow == selectedDay).toList();
    list.sort(
        (a, b) => weekOrder.indexOf(a.dow).compareTo(weekOrder.indexOf(b.dow)));
    return list;
  }

  String get eventsSectionLabel {
    final d = selectedMonthDate;
    if (d != null) {
      return '${dayNames[weekOrder[d.weekday - 1]]} ${d.day} ${_monthName(d.month)}';
    }
    if (selectedDay == null) {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      final range = monday.month == sunday.month
          ? '${monday.day} – ${sunday.day} ${_monthName(sunday.month)}'
          : '${monday.day} ${_monthName(monday.month)} – ${sunday.day} ${_monthName(sunday.month)}';
      return 'This week · $range';
    }
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final idx = weekOrder.indexOf(selectedDay!);
    final date = monday.add(Duration(days: idx < 0 ? 0 : idx));
    return '${dayNames[selectedDay]} ${date.day} ${_monthName(date.month)}';
  }

  static const _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// Real "Wednesday 8 July · Service Above Self" line for the home header.
  String get todayLine {
    final now = DateTime.now();
    return '${_weekdayNames[now.weekday - 1]} ${now.day} '
        '${_monthNames[now.month - 1]} · Service Above Self';
  }

  /// Real "TODAY · 8 Jul" badge for the meeting card.
  String get todayBadge {
    final now = DateTime.now();
    return 'TODAY · ${now.day} ${_monthNames[now.month - 1].substring(0, 3)}';
  }

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  String _monthName(int m) => _monthNames[m - 1];

  void pickDay(String dow) => _update(() {
        selectedDay = selectedDay == dow ? null : dow;
        selectedMonthDate = null;
      });

  bool dayHasEvents(String dow) => events.any((e) => e.dow == dow);

  void pickCalendarWeek() => _update(() => calendarView = 'week');
  void pickCalendarMonth() => _update(() => calendarView = 'month');

  /// Tapping a Month-grid cell selects that exact date only (highlighting
  /// every same-weekday cell was the bug) while still filtering the event
  /// list by weekday, since events are only tracked by day-of-week.
  void pickMonthDate(DateTime date, String dow) => _update(() {
        final same = selectedMonthDate != null &&
            selectedMonthDate!.year == date.year &&
            selectedMonthDate!.month == date.month &&
            selectedMonthDate!.day == date.day;
        selectedMonthDate = same ? null : date;
        selectedDay = same ? null : dow;
      });

  void goPrevMonth() => _update(() {
        var m = calendarMonth - 1;
        var y = calendarYear;
        if (m < 1) {
          m = 12;
          y--;
        }
        calendarMonth = m;
        calendarYear = y;
        selectedMonthDate = null;
        selectedDay = null;
      });

  void goNextMonth() => _update(() {
        var m = calendarMonth + 1;
        var y = calendarYear;
        if (m > 12) {
          m = 1;
          y++;
        }
        calendarMonth = m;
        calendarYear = y;
        selectedMonthDate = null;
        selectedDay = null;
      });

  void openAddEvent() => _update(() {
        eventEditor =
            EventItem(id: 0, dow: selectedDay ?? 'WED', name: '', meta: '');
        editorIsNew = true;
      });

  void openEditEvent(EventItem e) => _update(() {
        eventEditor = EventItem.fromMeta(
            id: e.id, dow: e.dow, name: e.name, meta: e.meta, photo: e.photo);
        editorIsNew = false;
      });

  void setEditorTitle(String v) => _update(() => eventEditor?.name = v);
  void setEditorTime(String v) => _update(() => eventEditor?.time = v);
  void setEditorVenue(String v) => _update(() => eventEditor?.venue = v);
  void setEditorDay(String dow) => _update(() => eventEditor?.dow = dow);
  void setEditorPhoto(Uint8List bytes) => _update(() {
        eventEditor?.pendingPhotoBytes = bytes;
        eventEditor?.photoRemoved = false;
      });
  void removeEventPhoto() => _update(() {
        eventEditor?.photo = null;
        eventEditor?.pendingPhotoBytes = null;
        eventEditor?.photoRemoved = true;
      });

  bool get canDeleteEvent => eventEditor != null && !editorIsNew;

  Future<void> saveEvent() async {
    final cur = eventEditor;
    final token = authToken;
    if (cur == null || cur.name.trim().isEmpty || token == null) return;
    // The backend (and every list/card display) still reads one "TIME ·
    // VENUE" string — the editor just offers it as two fields and joins
    // them back together here.
    final meta = [cur.time.trim(), cur.venue.trim()]
        .where((s) => s.isNotEmpty)
        .join(' · ');
    // null leaves the banner untouched; a data URL sets/replaces it; the
    // "__remove__" sentinel clears it.
    final String? image = cur.pendingPhotoBytes != null
        ? 'data:image/jpeg;base64,${base64Encode(cur.pendingPhotoBytes!)}'
        : (cur.photoRemoved ? '__remove__' : null);
    try {
      await _api.saveEvent(token,
          id: editorIsNew ? null : cur.id,
          dow: cur.dow,
          name: cur.name.trim(),
          meta: meta,
          image: image);
      _update(() => eventEditor = null);
      await loadEvents();
      await loadNextMeeting();
    } on ApiException {
      _update(() => eventEditor = null);
    }
  }

  Future<void> deleteEvent() async {
    final cur = eventEditor;
    final token = authToken;
    if (cur == null || token == null) return;
    try {
      await _api.deleteEvent(token, cur.id);
    } on ApiException {
      // fall through — list reload below reflects the server's truth
    }
    _update(() => eventEditor = null);
    await loadEvents();
    await loadNextMeeting();
  }

  void closeEditor() => _update(() => eventEditor = null);

  // ── event registration QR ─────────────────────────────────────────────
  // The link and QR image are both generated by the backend
  // (GET /club/events/{id}/registration) — this just displays whatever it
  // returns, never fabricates either one itself.
  void openQR(EventItem e) {
    _update(() {
      eventQR = e;
      eventRegistration = null;
      eventRegistrationError = null;
      eventRegistrationLoading = true;
    });
    final token = authToken;
    if (token == null) return;
    _api.fetchEventRegistration(token, e.id).then((reg) {
      if (eventQR?.id != e.id) return; // sheet closed/changed while in flight
      _update(() {
        eventRegistration = reg;
        eventRegistrationLoading = false;
      });
    }).catchError((error) {
      if (eventQR?.id != e.id) return;
      _update(() {
        eventRegistrationError = error is ApiException
            ? error.message
            : 'Could not load the QR code.';
        eventRegistrationLoading = false;
      });
    });
  }

  void closeQR() => _update(() {
        eventQR = null;
        eventRegistration = null;
        eventRegistrationError = null;
      });

  void copyQRLink() {
    // Caller (widget) performs the actual Clipboard.setData; this just
    // drives the "Copied ✓" label for 1.8s, mirroring the design.
    _qrCopyTimer?.cancel();
    _update(() => qrCopied = true);
    _qrCopyTimer = Timer(const Duration(milliseconds: 1800), () {
      _update(() => qrCopied = false);
    });
  }

  // ── attendance ─────────────────────────────────────────────────────────
  void pickAttMine() => _update(() => attView = 'mine');
  void pickAttClub() => _update(() => attView = 'club');
  void pickRegisterTab(String v) => _update(() => registerTab = v);
  void pickMeeting(int i) => _update(() => selectedMeeting = i);

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
    _qrCopyTimer?.cancel();
    treasury.removeListener(notifyListeners);
    treasury.dispose();
    secretary.removeListener(notifyListeners);
    secretary.dispose();
    gallery.removeListener(notifyListeners);
    gallery.dispose();
    super.dispose();
  }
}
