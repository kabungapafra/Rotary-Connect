import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'data.dart';

class PhotoInfo {
  final String label;
  final String activity;
  final String date;
  // Public R2 URL — gallery photos are fetched over the network, not held
  // as local bytes.
  final String? imageUrl;
  // Backend gallery photo id — set only when this photo came from the
  // club gallery, which is what lets the viewer offer to delete it.
  final int? id;
  const PhotoInfo(this.label, this.activity, this.date,
      {this.imageUrl, this.id});
}

class CertInfo {
  final String title;
  final String body;
  const CertInfo(this.title, this.body);
}

/// A photo in a gallery album, fetched from the backend. `image` is the
/// public R2 URL the app displays directly with Image.network.
class GalleryUpload {
  final int id;
  final String album;
  final String image;
  const GalleryUpload(this.id, this.album, this.image);
}

/// State of the gallery "Upload photos" bottom sheet while it is open.
class UploadSheet {
  String album;
  final List<Uint8List> srcs = [];
  bool saving = false;
  String? error;
  UploadSheet(this.album);
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
      clubId = prefs.getInt('club_id');
      clubName = prefs.getString('club_name') ?? clubName;
      clubLogo = prefs.getString('club_logo');
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
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = authToken;
    if (token == null) return;
    await prefs.setString('auth_token', token);
    await prefs.setString('member_name', currentMemberName);
    await prefs.setString('member_role', currentMemberRole);
    await prefs.setString('member_phone', currentMemberPhone);
    final id = clubId;
    if (id != null) await prefs.setInt('club_id', id);
    await prefs.setString('club_name', clubName);
    final logo = clubLogo;
    if (logo != null) {
      await prefs.setString('club_logo', logo);
    } else {
      await prefs.remove('club_logo');
    }
  }

  /// Called when the server rejects the stored token (e.g. this member was
  /// removed): wipe just their session. Club branding (name/logo/id) is
  /// kept — this device still belongs to that club, it just needs someone
  /// to log in again.
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('member_name');
    await prefs.remove('member_role');
    await prefs.remove('member_phone');
    _update(() {
      authToken = null;
      currentMemberName = '';
      currentMemberRole = '';
      currentMemberPhone = '';
      tab = 'splash';
    });
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

  bool _isAuthFailure(ApiException e) =>
      e.message.contains('credentials');

  String tab = 'splash';
  String scanMode = 'member'; // member | guest
  String scanStep = 'idle'; // idle | success | guestForm | guestDone

  String guestName = '';
  String guestPhone = '';
  String guestHost = '';
  String guestClub = '';
  String guestType = 'Prospective member';
  bool guestFormError = false;

  PhotoInfo? photo;
  CertInfo? cert;

  final List<int> paidIds = [];
  String search = '';

  // Greeting and role badge reflect the logged-in member; the design's
  // "Rtn. Peter / TREASURER" preview values remain only as the pre-login
  // fallback so nothing renders empty.
  String get greeting => currentMemberName.trim().isEmpty
      ? 'Hello, Rtn. Peter'
      : 'Hello, Rtn. ${currentMemberName.trim().split(RegExp(r'\s+')).first}';
  String get roleBadge => currentMemberRole.trim().isEmpty
      ? 'TREASURER'
      : currentMemberRole.trim().toUpperCase();
  static const bool isTreasurer = true;

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

  // Branding for the logged-in member's club, provided by the backend at
  // login. Until then the app brands itself as "Rotary Connect". clubId
  // also lets an unauthenticated guest check-in on this device name the
  // right club, and survives a single member's session being revoked
  // (the device is still "this club's device" even if that member isn't).
  int? clubId;
  String clubName = 'Rotary Club of Mbalwa';
  String? clubLogo; // data URL uploaded by the system admin
  bool clubBrandingKnown = false; // true once a login has identified the club

  /// Second line of the splash wordmark: "Connect" until the member's club
  /// is known, then e.g. "Club of Mbalwa" (the club name minus "Rotary",
  /// which the wordmark's first line already says).
  String get wordmarkClubLine {
    if (!clubBrandingKnown) return 'Connect';
    final n = clubName.trim();
    if (n.toLowerCase().startsWith('rotary ')) return n.substring(7).trim();
    return n;
  }

  /// Splash subtitle, generic until the club is known.
  String get splashSubtitle => clubBrandingKnown
      ? 'Check in, follow projects, and stay connected with the $clubName.'
      : 'Check in, follow projects, and stay connected with your Rotary club.';

  /// Only the Club President can add and manage members.
  bool get isPresident => currentMemberRole == 'Club President';

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
  final List<ClubMeeting> clubMeetings = [];
  bool meetingsLoaded = false;

  // Home screen's "Next meeting" card — the real soonest upcoming
  // fellowship (date/time/venue), computed by the backend from the club's
  // events. Null once loaded means the club has none scheduled yet.
  NextMeeting? nextMeeting;
  bool nextMeetingLoaded = false;
  bool nextMeetingLoading = false;

  Future<void> loadSummary() async {
    final token = authToken;
    if (token == null) return;
    try {
      final s = await _api.fetchMySummary(token);
      _update(() => summary = s);
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
    final monthShort = _monthNames[date.month - 1].substring(0, 3).toUpperCase();
    if (diffDays == 0) return 'TODAY · ${date.day} $monthShort';
    if (diffDays == 1) return 'TOMORROW · ${date.day} $monthShort';
    final weekdayShort = _weekdayNames[date.weekday - 1].substring(0, 3).toUpperCase();
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
              EventItem(id: e.id, dow: e.dow, name: e.name, meta: e.meta),
          ]);
        eventsLoaded = true;
        eventsLoading = false;
      });
    } on ApiException {
      _update(() => eventsLoading = false);
    }
  }

  Future<void> loadGallery() async {
    final token = authToken;
    if (token == null) return;
    _update(() => galleryLoading = true);
    try {
      final list = await _api.fetchGalleryPhotos(token);
      _update(() {
        galleryUploads
          ..clear()
          ..addAll([
            for (final p in list) GalleryUpload(p.id, p.album, p.image),
          ]);
        galleryLoaded = true;
        galleryLoading = false;
      });
    } on ApiException {
      _update(() => galleryLoading = false);
    }
  }

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

  // gallery — real club data, loaded from the backend after login
  UploadSheet? uploadSheet;
  final List<GalleryUpload> galleryUploads = [];
  bool galleryLoaded = false;
  bool galleryLoading = false;
  String? downloadToast;
  Timer? _downloadToastTimer;

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
      if (!galleryLoaded && !galleryLoading) loadGallery();
      if (!nextMeetingLoaded && !nextMeetingLoading) loadNextMeeting();
    }
  }

  void goScan() => go('scan');

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
    if (authToken != null && !projectsLoaded && !projectsLoading) loadProjects();
  }
  void goToday() {
    go('today');
    loadToday();
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
  void goGallery() {
    go('gallery');
    if (authToken != null && !galleryLoaded && !galleryLoading) loadGallery();
  }
  void goTreasury() => go('treasury');
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
      (tab != 'home' && tab != 'splash');

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
    } else if (projectEditor != null) {
      closeProjectEditor();
    } else if (memberEditor != null) {
      closeMemberEditor();
    } else if (memberProfile != null) {
      closeMemberProfile();
    } else if (tab == 'login') {
      goSplash();
    } else if (tab == 'scan' && authToken == null) {
      // An unauthenticated visitor (QR check-in) has no home screen to
      // return to — send them back to the splash they started from.
      goSplash();
    } else if (tab != 'home' && tab != 'splash') {
      goHome();
    }
  }

  // ── login ──────────────────────────────────────────────────────────────
  void enterMember() => _update(() {
        // Login credentials are asked for only once: with a live session
        // "Continue as Member" goes straight to the dashboard, skipping
        // the login form. The splash itself never auto-advances.
        if (authToken != null) {
          tab = 'home';
          loadSummary();
          return;
        }
        tab = 'login';
        scanMode = 'member';
        loginError = false;
      });

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
        clubId = result.clubId;
        clubName = result.clubName;
        clubLogo = result.clubLogo;
        clubBrandingKnown = true;
        clubMembers = [];
        clubMembersLoaded = false;
        tab = 'home';
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
  void openPhoto(PhotoInfo p) => _update(() => photo = p);
  void closePhoto() => _update(() => photo = null);

  void openCert(CertInfo c) => _update(() => cert = c);
  void closeCert() => _update(() => cert = null);

  // ── members ────────────────────────────────────────────────────────────
  void setSearch(String v) => _update(() => search = v);
  void setMemberFilter(String v) => _update(() => memberFilter = v);

  /// Logged in → the real club roster from the backend; otherwise the
  /// static design list (pre-login preview only).
  List<Member> get allMembers =>
      authToken != null ? clubMembers : const [];

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
    if (token != null && isPresident) {
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
  void setProjectPhoto(Uint8List bytes) =>
      _update(() => projectEditor?.photo = bytes);
  void removeProjectPhoto() => _update(() => projectEditor?.photo = null);
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
    try {
      await _api.saveProject(token,
          id: projectEditorIsNew ? null : p.id,
          name: p.name.trim(),
          area: area,
          pct: p.pct,
          desc: desc,
          deadline: deadline);
      _update(() => projectEditor = null);
      await loadProjects();
    } on ApiException {
      _update(() => projectEditor = null);
    }
  }

  // ── treasury ───────────────────────────────────────────────────────────
  void markPaid(int index) => _update(() => paidIds.add(index));
  bool isPaid(int index, bool paidInitially) =>
      paidInitially || paidIds.contains(index);

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
  void setEditorPhoto(Uint8List bytes) =>
      _update(() => eventEditor?.photo = bytes);
  void removeEventPhoto() => _update(() => eventEditor?.photo = null);

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
    try {
      await _api.saveEvent(token,
          id: editorIsNew ? null : cur.id,
          dow: cur.dow,
          name: cur.name.trim(),
          meta: meta);
      _update(() => eventEditor = null);
      await loadEvents();
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
        eventRegistrationError =
            error is ApiException ? error.message : 'Could not load the QR code.';
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
  void openUpload() =>
      _update(() => uploadSheet = UploadSheet('Club album'));
  void closeUpload() => _update(() => uploadSheet = null);
  void pickUploadAlbum(String album) =>
      _update(() => uploadSheet?.album = album);
  void addUploadPhotos(List<Uint8List> photos) =>
      _update(() => uploadSheet?.srcs.addAll(photos));

  Future<void> saveUpload() async {
    final u = uploadSheet;
    final token = authToken;
    if (u == null || u.srcs.isEmpty || token == null) return;
    _update(() {
      u.saving = true;
      u.error = null;
    });
    try {
      final dataUrls = [
        for (final src in u.srcs) 'data:image/jpeg;base64,${base64Encode(src)}',
      ];
      final uploaded = await _api.uploadGalleryPhotos(token, u.album, dataUrls);
      _update(() {
        galleryUploads.insertAll(0, [
          for (final p in uploaded) GalleryUpload(p.id, p.album, p.image),
        ]);
        uploadSheet = null;
      });
    } on ApiException catch (e) {
      _update(() {
        u.saving = false;
        u.error = e.message;
      });
    }
  }

  List<GalleryUpload> uploadsFor(String album) =>
      galleryUploads.where((g) => g.album == album).toList();

  /// Saves the currently-open full-screen photo to the device's own photo
  /// gallery (separate from the club's in-app gallery).
  Future<void> downloadPhoto() async {
    final url = photo?.imageUrl;
    if (url == null) return;
    String message;
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (res.statusCode >= 400) throw ApiException('Download failed');
      await Gal.putImageBytes(res.bodyBytes,
          name: 'rotary_connect_${DateTime.now().millisecondsSinceEpoch}');
      message = 'Saved to your photos';
    } catch (_) {
      message = 'Could not save photo';
    }
    _downloadToastTimer?.cancel();
    _update(() => downloadToast = message);
    _downloadToastTimer = Timer(const Duration(seconds: 2), () {
      _update(() => downloadToast = null);
    });
  }

  /// Removes the currently-open photo from the club gallery (backend +
  /// local list) and closes the viewer.
  Future<void> deletePhoto() async {
    final id = photo?.id;
    final token = authToken;
    if (id == null || token == null) return;
    try {
      await _api.deleteGalleryPhoto(token, id);
      _update(() {
        galleryUploads.removeWhere((g) => g.id == id);
        photo = null;
      });
    } on ApiException {
      _downloadToastTimer?.cancel();
      _update(() => downloadToast = 'Could not delete photo');
      _downloadToastTimer = Timer(const Duration(seconds: 2), () {
        _update(() => downloadToast = null);
      });
    }
  }

  @override
  void dispose() {
    _reportTimer?.cancel();
    _qrCopyTimer?.cancel();
    _downloadToastTimer?.cancel();
    super.dispose();
  }
}
