import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'data.dart';

class PhotoInfo {
  final String label;
  final String activity;
  final String date;
  final Uint8List? src;
  const PhotoInfo(this.label, this.activity, this.date, {this.src});
}

class CertInfo {
  final String title;
  final String body;
  const CertInfo(this.title, this.body);
}

/// A photo uploaded into a gallery album from the Upload sheet.
class GalleryUpload {
  final String album;
  final Uint8List src;
  const GalleryUpload(this.album, this.src);
}

/// State of the gallery "Upload photos" bottom sheet while it is open.
class UploadSheet {
  String album;
  final List<Uint8List> srcs = [];
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

  // Branding for the logged-in member's club, provided by the backend at
  // login. Defaults keep the pre-login splash exactly as designed.
  String clubName = 'Rotary Club of Mbalwa';
  String? clubLogo; // data URL uploaded by the system admin

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

  // events
  final List<EventItem> events = initialEvents();
  String? selectedDay;
  EventItem? eventEditor; // a working copy while the editor sheet is open
  bool editorIsNew = false;
  String calendarView = 'week'; // week | month
  int calendarYear = 2026;
  int calendarMonth = 7; // 1-12, the month shown in the Month grid
  // The exact date tapped in the Month grid — kept separate from
  // [selectedDay] (a day-of-week name) so tapping one day only highlights
  // that single cell, not every occurrence of that weekday in the month.
  DateTime? selectedMonthDate;
  EventItem? eventQR;
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

  // projects
  final List<Project> projects = initialProjects();
  Project? projectEditor; // a working copy while the editor sheet is open
  bool projectEditorIsNew = false;

  // attendance
  String attView = 'mine'; // mine | club
  String registerTab = 'members'; // members | guests | clubs
  int selectedMeeting = 0;
  bool reportToast = false;
  Timer? _reportTimer;

  // gallery
  UploadSheet? uploadSheet;
  final List<GalleryUpload> galleryUploads = [];

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

  void goHome() => go('home');
  void goScan() => go('scan');
  void goAttendance() => go('attendance');
  void goEvents() => go('events');
  void goMembers() {
    go('members');
    if (authToken != null && !clubMembersLoaded && !clubMembersLoading) {
      loadClubMembers();
    }
  }
  void goProjects() => go('projects');
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
  void goGallery() => go('gallery');
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
    } else if (tab != 'home' && tab != 'splash') {
      goHome();
    }
  }

  // ── login ──────────────────────────────────────────────────────────────
  void enterMember() => _update(() {
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
        clubName = result.clubName;
        clubLogo = result.clubLogo;
        clubMembers = [];
        clubMembersLoaded = false;
        tab = 'home';
        loginError = false;
        loginLoading = false;
        loginPin = '';
      });
      unawaited(loadClubMembers());
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
      _update(() => scanStep = 'guestForm');
      return;
    }
    await _checkInMember();
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

  void setGuestPhone(String v) => _update(() => guestPhone = v);
  void setGuestHost(String v) => _update(() => guestHost = v);
  void setGuestClub(String v) => _update(() => guestClub = v);
  void setGuestType(String v) => _update(() => guestType = v);

  void submitGuest() {
    if (guestName.trim().isEmpty) {
      _update(() => guestFormError = true);
      return;
    }
    _update(() => scanStep = 'guestDone');
  }

  bool get isVisitingRotarian => guestType == 'Visiting Rotarian';

  String get guestNameShown =>
      guestName.trim().isNotEmpty ? guestName.trim() : 'Guest';
  String get guestTypeShown => guestType;
  String get guestClubShown => isVisitingRotarian && guestClub.trim().isNotEmpty
      ? ' from ${guestClub.trim()}'
      : '';
  String get guestStreakLine => isVisitingRotarian
      ? 'Make-up attendance noted for your home club'
      : 'Your 3rd visit this year — 2 more to qualify for membership!';

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
      authToken != null ? clubMembers : [...members, ...extraMembers];

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

  void deleteProject() => _update(() {
        projects.removeWhere((p) => p.id == projectEditor?.id);
        projectEditor = null;
      });

  void saveProject() {
    final p = projectEditor;
    if (p == null || p.name.trim().isEmpty) return;
    _update(() {
      p.name = p.name.trim();
      if (p.area.trim().isEmpty) p.area = 'Club project';
      if (p.desc.trim().isEmpty) p.desc = 'New club project.';
      if (p.deadline.trim().isEmpty) {
        p.deadline = p.pct >= 100 ? 'Completed' : 'Not set';
      }
      if (projectEditorIsNew) {
        projects.add(Project(
            id: DateTime.now().millisecondsSinceEpoch,
            name: p.name,
            icon: p.icon,
            area: p.area,
            pct: p.pct,
            desc: p.desc,
            deadline: p.deadline,
            photo: p.photo));
      } else {
        final i = projects.indexWhere((pr) => pr.id == p.id);
        if (i != -1) projects[i] = p;
      }
      projectEditor = null;
    });
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
    if (selectedDay == null) return 'This week · 6 – 12 July';
    return '${dayNames[selectedDay]} ${dayNums[selectedDay]} July';
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
        eventEditor = e.copy();
        editorIsNew = false;
      });

  void setEditorTitle(String v) => _update(() => eventEditor?.name = v);
  void setEditorMeta(String v) => _update(() => eventEditor?.meta = v);
  void setEditorDay(String dow) => _update(() => eventEditor?.dow = dow);
  void setEditorPhoto(Uint8List bytes) =>
      _update(() => eventEditor?.photo = bytes);
  void removeEventPhoto() => _update(() => eventEditor?.photo = null);

  bool get canDeleteEvent => eventEditor != null && !editorIsNew;

  void saveEvent() {
    final cur = eventEditor;
    if (cur == null || cur.name.trim().isEmpty) return;
    _update(() {
      if (editorIsNew) {
        events.add(EventItem(
            id: DateTime.now().millisecondsSinceEpoch,
            dow: cur.dow,
            name: cur.name,
            meta: cur.meta,
            photo: cur.photo));
      } else {
        final i = events.indexWhere((e) => e.id == cur.id);
        if (i != -1) events[i] = cur;
      }
      eventEditor = null;
    });
  }

  void deleteEvent() => _update(() {
        events.removeWhere((e) => e.id == eventEditor?.id);
        eventEditor = null;
      });

  void closeEditor() => _update(() => eventEditor = null);

  // ── event registration QR ─────────────────────────────────────────────
  void openQR(EventItem e) => _update(() => eventQR = e);
  void closeQR() => _update(() => eventQR = null);

  String _slug(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'(^-|-$)'), '');

  String get qrLink {
    final e = eventQR;
    if (e == null) return '';
    return 'https://mbalwarotary.org/rsvp/${_slug(e.name)}-${e.id}';
  }

  String qrImageUrl(int size) =>
      'https://api.qrserver.com/v1/create-qr-code/?size=${size}x$size&margin=8&color=17458F&data=${Uri.encodeComponent(qrLink)}';

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

  RegisterMeeting get selMeeting => registerMeetings[selectedMeeting];

  String get reportName =>
      'attendance-${selMeeting.date.toLowerCase().split(' ').join('-')}.pdf';

  void downloadReport() {
    _reportTimer?.cancel();
    _update(() => reportToast = true);
    _reportTimer = Timer(const Duration(milliseconds: 2400), () {
      _update(() => reportToast = false);
    });
  }

  // ── gallery ────────────────────────────────────────────────────────────
  void openUpload() =>
      _update(() => uploadSheet = UploadSheet('Community Health Camp'));
  void closeUpload() => _update(() => uploadSheet = null);
  void pickUploadAlbum(String album) =>
      _update(() => uploadSheet?.album = album);
  void addUploadPhotos(List<Uint8List> photos) =>
      _update(() => uploadSheet?.srcs.addAll(photos));

  void saveUpload() {
    final u = uploadSheet;
    if (u == null || u.srcs.isEmpty) return;
    _update(() {
      galleryUploads.addAll(u.srcs.map((src) => GalleryUpload(u.album, src)));
      uploadSheet = null;
    });
  }

  List<GalleryUpload> uploadsFor(String album) =>
      galleryUploads.where((g) => g.album == album).toList();

  @override
  void dispose() {
    _reportTimer?.cancel();
    _qrCopyTimer?.cancel();
    super.dispose();
  }
}
