/// Thin client for the Rotary Connect backend (FastAPI + PostgreSQL),
/// deployed at https://rotaryapi.digiflecttech.dev.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

// Overridable for local testing:
//   flutter build web --debug --dart-define=API_BASE_URL=http://localhost:8000
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'https://rotaryapi.digiflecttech.dev');

const Duration _requestTimeout = Duration(seconds: 30);

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class LoggedInMember {
  final String name;
  final String role;
  final String phone;
  final bool isBoard;
  // True right after the Rotary-year leadership sweep promotes this member
  // to President — prompts the "assign board positions" banner.
  final bool needsBoardSetup;
  const LoggedInMember(
      this.name, this.role, this.phone, this.isBoard, this.needsBoardSetup);
}

class LoginResult {
  final String token;
  final LoggedInMember member;
  final int clubId;
  final String clubName;
  final String? clubLogo; // data URL uploaded by the system admin
  final String clubType; // "rotary" | "rotaract"
  final String clubStatus; // "active" | "suspended"
  const LoginResult(this.token, this.member, this.clubId, this.clubName,
      this.clubLogo, this.clubType, this.clubStatus);
}

class AddedClubMember {
  final String name;
  final String memberNumber;
  final String pin;
  const AddedClubMember(this.name, this.memberNumber, this.pin);
}

class ClubMemberInfo {
  final int id;
  final String name;
  final String role;
  final bool isBoard;
  final String status;
  final String email;
  final String phone;
  final String dob;
  final String? terminatedAt;
  final bool needsBoardSetup;
  const ClubMemberInfo(this.id, this.name, this.role, this.isBoard,
      this.status, this.email, this.phone, this.dob, this.terminatedAt,
      {this.needsBoardSetup = false});
}

class ClubEvent {
  final int id;
  final String dow;
  final String name;
  final String meta;
  final String? image; // public R2 URL, null until a banner is uploaded
  // False once today's occurrence is within 15 minutes of its end time —
  // the Register/QR button hides. Always true without an end time.
  final bool registrationOpen;
  const ClubEvent(this.id, this.dow, this.name, this.meta, this.image,
      this.registrationOpen);
}

class GuestCheckInResult {
  final int clubId;
  final String clubName;
  const GuestCheckInResult(this.clubId, this.clubName);
}

/// Public profile of a club for the visitor dashboard — display data only
/// (branding + events), fetched without any login.
class VisitorClubInfo {
  final int id;
  final String name;
  final String? logo;
  final String clubType; // "rotary" | "rotaract"
  final List<ClubEvent> events;
  const VisitorClubInfo(
      this.id, this.name, this.logo, this.clubType, this.events);
}

class GalleryPhotoInfo {
  final int id;
  final String album;
  final String image; // "data:image/jpeg;base64,..."
  final String? thumb; // small WebP R2 URL for grid tiles; null on old rows
  const GalleryPhotoInfo(this.id, this.album, this.image, this.thumb);
}

class EventRegistration {
  final String link;
  final String qrImage; // "data:image/png;base64,..."
  const EventRegistration(this.link, this.qrImage);
}

class NextMeeting {
  final int eventId;
  final String name;
  final String venue;
  final String timeLabel;
  final String dateIso;
  final bool ongoing;
  const NextMeeting(this.eventId, this.name, this.venue, this.timeLabel,
      this.dateIso, this.ongoing);
}

// Rotary International's 7 official areas of focus — mirrors the
// backend's schemas.ROTARY_AREAS_OF_FOCUS, used for the project editor's
// area-of-focus dropdown and validated again server-side.
const List<String> rotaryAreasOfFocus = [
  'Peacebuilding and Conflict Prevention',
  'Disease Prevention and Treatment',
  'Water, Sanitation, and Hygiene',
  'Maternal and Child Health',
  'Basic Education and Literacy',
  'Community Economic Development',
  'Environment',
];

class ClubProject {
  final int id;
  final String name;
  final String area;
  final int pct;
  final String desc;
  final String deadline;
  final String? image; // public R2 URL, null until a photo is uploaded
  final String? areaOfFocus;
  final int hoursVolunteered;
  final int beneficiariesReached;
  const ClubProject(
      this.id,
      this.name,
      this.area,
      this.pct,
      this.desc,
      this.deadline,
      this.image,
      this.areaOfFocus,
      this.hoursVolunteered,
      this.beneficiariesReached);
}

class MeetingAttendee {
  final String name;
  final String role;
  final String time;
  const MeetingAttendee(this.name, this.role, this.time);
}

/// A non-member on the register: a walk-in who scanned the club QR
/// ("scan") or someone who registered through an event's public web RSVP
/// form ("web").
class MeetingGuest {
  final String name;
  final String type;
  final String clubName; // a Visiting Rotarian's own club, else ''
  final String time;
  final String via; // 'scan' | 'web'
  const MeetingGuest(this.name, this.type, this.clubName, this.time, this.via);
}

class ClubMeeting {
  final String date;
  final String name;
  final int checkinCount;
  final bool attended;
  final List<MeetingAttendee> attendees;
  final List<MeetingGuest> guests;
  const ClubMeeting(this.date, this.name, this.checkinCount, this.attended,
      this.attendees, this.guests);
}

class MemberSummary {
  final int checkInCount;
  final int meetingsTotal;
  final int attendancePercent;
  final String todayMeetingName;
  final int memberCount;
  final String clubStatus; // "active" | "suspended"
  final bool checkedInToday;
  final int weekStreak;
  const MemberSummary(
      this.checkInCount,
      this.meetingsTotal,
      this.attendancePercent,
      this.todayMeetingName,
      this.memberCount,
      this.clubStatus,
      this.checkedInToday,
      this.weekStreak);
}

class CheckInResult {
  final bool alreadyCheckedIn;
  final DateTime checkedInAt;
  final String meetingName;
  const CheckInResult(
      this.alreadyCheckedIn, this.checkedInAt, this.meetingName);
}

class TodayCheckedInMember {
  final String name;
  final String role;
  final DateTime checkedInAt;
  const TodayCheckedInMember(this.name, this.role, this.checkedInAt);
}

class TodaySummary {
  final String meetingName;
  final int memberCount;
  final List<TodayCheckedInMember> members;
  final List<MeetingGuest> guests;
  const TodaySummary(
      this.meetingName, this.memberCount, this.members, this.guests);
}

class ApologyInfo {
  final int id;
  final String memberName;
  final String memberRole;
  final String meetingDate;
  final String reason;
  const ApologyInfo(
      this.id, this.memberName, this.memberRole, this.meetingDate, this.reason);
}

class TreasurySummary {
  final int duesAmount;
  final String duesPeriod;
  final String duesPeriodLabel;
  final int duesCollected;
  final int duesOutstanding;
  final int totalIncome;
  final int totalExpenses;
  const TreasurySummary(
      this.duesAmount,
      this.duesPeriod,
      this.duesPeriodLabel,
      this.duesCollected,
      this.duesOutstanding,
      this.totalIncome,
      this.totalExpenses);
}

class DuesMemberInfo {
  final int memberId;
  final String name;
  final String role;
  final bool paid;
  const DuesMemberInfo(this.memberId, this.name, this.role, this.paid);
}

class TransactionInfo {
  final int id;
  final String kind; // income | expense
  final String label;
  final int amount;
  final DateTime createdAt;
  const TransactionInfo(
      this.id, this.kind, this.label, this.amount, this.createdAt);
}

class PollOptionResult {
  final String label;
  final int count;
  const PollOptionResult(this.label, this.count);
}

class MinuteInfo {
  final int id;
  final String title;
  final String meetingDate;
  final String status; // draft | approved | processing | failed
  final String body; // the minutes text (markdown); empty on legacy rows
  const MinuteInfo(this.id, this.title, this.meetingDate, this.status,
      [this.body = '']);
}

class ClubDocumentInfo {
  final int id;
  final String title;
  final String url; // public R2 URL of the PDF
  final String createdAt; // ISO timestamp
  const ClubDocumentInfo(this.id, this.title, this.url, this.createdAt);
}

class MilestoneInfo {
  final int id;
  final String year;
  final String title;
  final String category;
  final String text;
  const MilestoneInfo(this.id, this.year, this.title, this.category, this.text);
}

class ReportRowInfo {
  final String label;
  final String value;
  const ReportRowInfo(this.label, this.value);
}

class ReportSectionInfo {
  final String section;
  final List<ReportRowInfo> rows;
  const ReportSectionInfo(this.section, this.rows);
}

class ReportInfo {
  final String title;
  final String subtitle;
  final List<ReportSectionInfo> sections;
  const ReportInfo(this.title, this.subtitle, this.sections);
}

class DrawAssignment {
  final String giver;
  final String recipient;
  const DrawAssignment(this.giver, this.recipient);
}

class PollInfo {
  final int id;
  final String type; // motion | election | draw
  final String title;
  final String sub;
  final String closesLabel;
  final List<String> options;
  final String status; // open | closed
  final String? winner;
  final List<PollOptionResult> results;
  final String? myVote;
  final int totalVotes;
  // "draw" polls only: every member paired with a different member, set
  // once the draw has run.
  final List<DrawAssignment>? assignments;
  const PollInfo(
      this.id,
      this.type,
      this.title,
      this.sub,
      this.closesLabel,
      this.options,
      this.status,
      this.winner,
      this.results,
      this.myVote,
      this.totalVotes,
      this.assignments);
}

class ApiClient {
  /// Fire-and-forget ping that wakes a sleeping free-tier backend while the
  /// user is still on the splash/login screens.
  void warmUp() {
    http.get(Uri.parse('$apiBaseUrl/health')).timeout(_requestTimeout).ignore();
  }

  Future<void> forgotPin(String identifier) async {
    await _post('/auth/forgot-pin', {'identifier': identifier});
  }

  Future<LoginResult> login(String identifier, String pin) async {
    final res =
        await _post('/auth/login', {'identifier': identifier, 'pin': pin});
    final member = res['member'] as Map<String, dynamic>;
    return LoginResult(
      res['access_token'] as String,
      LoggedInMember(
          member['name'] as String,
          member['role'] as String,
          member['phone'] as String? ?? '',
          member['is_board'] as bool? ?? false,
          member['needs_board_setup'] as bool? ?? false),
      res['club_id'] as int,
      res['club_name'] as String? ?? 'Rotary Club of Mbalwa',
      res['club_logo'] as String?,
      res['club_type'] as String? ?? 'rotary',
      res['club_status'] as String? ?? 'active',
    );
  }

  /// Unauthenticated endpoint: a walk-in guest registers themselves, or a
  /// logged-in member checks in as a visitor at a club that isn't their
  /// own. Exactly one of [clubId] (this device's own club — the front-desk
  /// case) or [clubName] (a member naming the club they're visiting) is
  /// given. Returns the resolved club (id + name) for display and for
  /// remembering which club's visitor dashboard to show.
  Future<GuestCheckInResult> guestCheckIn({
    int? clubId,
    String? clubName,
    required String name,
    required String phone,
    required String hostName,
    required String guestType,
    String memberClub = '',
  }) async {
    final res = await _post('/checkin/guest', {
      if (clubId != null) 'club_id': clubId,
      if (clubName != null) 'club_name': clubName,
      'name': name,
      'phone': phone,
      'host_name': hostName,
      'guest_type': guestType,
      'member_club': memberClub,
    });
    return GuestCheckInResult(
        res['club_id'] as int, res['club_name'] as String);
  }

  /// Unauthenticated: the visited club's public profile (branding +
  /// events) shown on the visitor dashboard.
  Future<VisitorClubInfo> fetchVisitorClub(int clubId) async {
    final res = await _get('/checkin/club/$clubId');
    final events = (res['events'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .map((e) => ClubEvent(
            e['id'] as int,
            e['dow'] as String,
            e['name'] as String,
            e['meta'] as String,
            e['image'] as String?,
            e['registration_open'] as bool? ?? true))
        .toList();
    return VisitorClubInfo(
      res['club_id'] as int,
      res['name'] as String,
      res['logo'] as String?,
      res['club_type'] as String? ?? 'rotary',
      events,
    );
  }

  /// The logged-in member's club roster.
  Future<List<ClubMemberInfo>> fetchClubMembers(String token) async {
    final headers = {'Authorization': 'Bearer $token'};
    final http.Response res;
    try {
      res = await http
          .get(Uri.parse('$apiBaseUrl/club/members'), headers: headers)
          .timeout(_requestTimeout);
    } catch (_) {
      throw ApiException('Could not reach the server. Check your connection.');
    }
    if (res.statusCode >= 400) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(data['detail'] as String? ?? 'Something went wrong.');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return [
      for (final m in list.cast<Map<String, dynamic>>())
        ClubMemberInfo(
          m['id'] as int,
          m['name'] as String,
          m['role'] as String,
          m['is_board'] as bool,
          m['status'] as String? ?? 'active',
          m['email'] as String,
          m['phone'] as String,
          m['dob'] as String,
          m['terminated_at'] as String?,
          needsBoardSetup: m['needs_board_setup'] as bool? ?? false,
        ),
    ];
  }

  /// President/Secretary only: end (or restore) a member's membership.
  /// `status` is 'active' | 'suspended' | 'terminated'.
  Future<void> updateMemberStatus(
      String token, int memberId, String status) async {
    await _patch('/club/members/$memberId', {'status': status}, token: token);
  }

  /// President/Secretary only: reassign an existing member's position —
  /// e.g. promoting someone to President-Elect, or clearing/filling a
  /// board seat after the July 1 leadership handover.
  Future<void> updateMemberRole(
      String token, int memberId, String role, bool isBoard) async {
    await _patch('/club/members/$memberId',
        {'role': role, 'is_board': isBoard},
        token: token);
  }

  /// Dismisses the "assign board positions" prompt shown to whoever the
  /// leadership sweep just promoted to President.
  Future<void> dismissBoardSetup(String token) async {
    await _post('/club/members/dismiss-board-setup', null, token: token);
  }

  /// Registers (or re-registers) this device's FCM token against the
  /// logged-in member, so the backend knows where to push notifications.
  Future<void> registerDeviceToken(
      String token, String deviceToken, String platform) async {
    await _post('/push/register',
        {'token': deviceToken, 'platform': platform},
        token: token);
  }

  /// Club President only: create a member of the president's club.
  /// Returns the generated member number and one-time PIN.
  Future<AddedClubMember> addClubMember(
    String token, {
    required String name,
    required String role,
    required String email,
    required String phone,
    required String dob,
    required bool isBoard,
  }) async {
    final res = await _post(
      '/club/members',
      {
        'name': name,
        'role': role,
        'email': email,
        'phone': phone,
        'dob': dob,
        'is_board': isBoard,
      },
      token: token,
    );
    final member = res['member'] as Map<String, dynamic>;
    return AddedClubMember(
      member['name'] as String,
      member['member_number'] as String,
      res['pin'] as String,
    );
  }

  // ── club data (events / projects / meetings / summary) ─────────────
  Future<List<ClubEvent>> fetchEvents(String token) async {
    final list = await _getList('/club/events', token);
    return [
      for (final e in list.cast<Map<String, dynamic>>())
        ClubEvent(e['id'] as int, e['dow'] as String, e['name'] as String,
            e['meta'] as String, e['image'] as String?,
            e['registration_open'] as bool? ?? true),
    ];
  }

  /// [image] is a "data:image/...;base64,..." URL to set/replace the
  /// banner, the sentinel "__remove__" to clear it, or null to leave it
  /// as-is.
  Future<ClubEvent> saveEvent(String token,
      {int? id,
      required String dow,
      required String name,
      required String meta,
      String? image}) async {
    final body = {
      'dow': dow,
      'name': name,
      'meta': meta,
      if (image != null) 'image': image,
    };
    final res = id == null
        ? await _post('/club/events', body, token: token)
        : await _patch('/club/events/$id', body, token: token);
    return ClubEvent(
        res['id'] as int,
        res['dow'] as String,
        res['name'] as String,
        res['meta'] as String,
        res['image'] as String?,
        res['registration_open'] as bool? ?? true);
  }

  Future<void> deleteEvent(String token, int id) =>
      _delete('/club/events/$id', token);

  Future<List<ClubProject>> fetchProjects(String token) async {
    final list = await _getList('/club/projects', token);
    return [
      for (final p in list.cast<Map<String, dynamic>>())
        ClubProject(
            p['id'] as int,
            p['name'] as String,
            p['area'] as String,
            p['pct'] as int,
            p['desc'] as String,
            p['deadline'] as String,
            p['image'] as String?,
            p['area_of_focus'] as String?,
            p['hours_volunteered'] as int? ?? 0,
            p['beneficiaries_reached'] as int? ?? 0),
    ];
  }

  /// [image] is a "data:image/...;base64,..." URL to set/replace the
  /// photo, the sentinel "__remove__" to clear it, or null to leave it
  /// as-is. [areaOfFocus] must be one of [rotaryAreasOfFocus] or null
  /// ("Uncategorized" in reports).
  Future<ClubProject> saveProject(String token,
      {int? id,
      required String name,
      required String area,
      required int pct,
      required String desc,
      required String deadline,
      String? image,
      String? areaOfFocus,
      int hoursVolunteered = 0,
      int beneficiariesReached = 0}) async {
    final body = {
      'name': name,
      'area': area,
      'pct': pct,
      'desc': desc,
      'deadline': deadline,
      if (image != null) 'image': image,
      'area_of_focus': areaOfFocus,
      'hours_volunteered': hoursVolunteered,
      'beneficiaries_reached': beneficiariesReached,
    };
    final res = id == null
        ? await _post('/club/projects', body, token: token)
        : await _patch('/club/projects/$id', body, token: token);
    return ClubProject(
        res['id'] as int,
        res['name'] as String,
        res['area'] as String,
        res['pct'] as int,
        res['desc'] as String,
        res['deadline'] as String,
        res['image'] as String?,
        res['area_of_focus'] as String?,
        res['hours_volunteered'] as int? ?? 0,
        res['beneficiaries_reached'] as int? ?? 0);
  }

  Future<void> deleteProject(String token, int id) =>
      _delete('/club/projects/$id', token);

  Future<List<ClubMeeting>> fetchMeetings(String token) async {
    final list = await _getList('/club/meetings', token);
    return [
      for (final m in list.cast<Map<String, dynamic>>())
        ClubMeeting(
          m['date'] as String,
          m['name'] as String,
          m['checkin_count'] as int,
          m['attended'] as bool,
          [
            for (final a
                in (m['attendees'] as List).cast<Map<String, dynamic>>())
              MeetingAttendee(a['name'] as String, a['role'] as String,
                  a['time'] as String),
          ],
          [
            for (final g in ((m['guests'] as List?) ?? const [])
                .cast<Map<String, dynamic>>())
              MeetingGuest(
                  g['name'] as String,
                  g['type'] as String,
                  g['club_name'] as String? ?? '',
                  g['time'] as String? ?? '',
                  g['via'] as String? ?? 'scan'),
          ],
        ),
    ];
  }

  Future<MemberSummary> fetchMySummary(String token) async {
    final res = await _getAuthed('/club/me/summary', token);
    return MemberSummary(
      res['check_in_count'] as int,
      res['meetings_total'] as int,
      res['attendance_percent'] as int,
      res['today_meeting_name'] as String,
      res['member_count'] as int,
      res['club_status'] as String? ?? 'active',
      res['checked_in_today'] as bool? ?? false,
      res['week_streak'] as int? ?? 0,
    );
  }

  Future<CheckInResult> checkIn(String token) async {
    final res = await _post('/checkin', null, token: token);
    return CheckInResult(
      res['already_checked_in'] as bool,
      DateTime.parse(res['checked_in_at'] as String),
      res['meeting_name'] as String,
    );
  }

  // ── gallery ──────────────────────────────────────────────────────────
  Future<List<GalleryPhotoInfo>> fetchGalleryPhotos(String token) async {
    final list = await _getList('/club/gallery', token);
    return [
      for (final p in list.cast<Map<String, dynamic>>())
        GalleryPhotoInfo(p['id'] as int, p['album'] as String,
            p['image'] as String, p['thumb'] as String?),
    ];
  }

  Future<List<GalleryPhotoInfo>> uploadGalleryPhotos(
      String token, String album, List<String> imageDataUrls) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode([
      for (final image in imageDataUrls) {'album': album, 'image': image},
    ]);
    final http.Response res;
    try {
      res = await http
          .post(Uri.parse('$apiBaseUrl/club/gallery'),
              headers: headers, body: body)
          .timeout(_requestTimeout);
    } catch (_) {
      throw ApiException('Could not reach the server. Check your connection.');
    }
    if (res.statusCode >= 400) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(data['detail'] as String? ?? 'Something went wrong.');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return [
      for (final p in list.cast<Map<String, dynamic>>())
        GalleryPhotoInfo(p['id'] as int, p['album'] as String,
            p['image'] as String, p['thumb'] as String?),
    ];
  }

  Future<void> deleteGalleryPhoto(String token, int photoId) =>
      _delete('/club/gallery/$photoId', token);

  // ── event registration ──────────────────────────────────────────────
  Future<EventRegistration> fetchEventRegistration(
      String token, int eventId) async {
    final res = await _getAuthed('/club/events/$eventId/registration', token);
    return EventRegistration(res['link'] as String, res['qr_image'] as String);
  }

  // ── next meeting ─────────────────────────────────────────────────────
  /// Null when the club has no events scheduled yet (backend returns 404).
  Future<NextMeeting?> fetchNextMeeting(String token) async {
    final http.Response res;
    try {
      res = await http.get(Uri.parse('$apiBaseUrl/club/events/next'),
          headers: {'Authorization': 'Bearer $token'}).timeout(_requestTimeout);
    } catch (_) {
      throw ApiException('Could not reach the server. Check your connection.');
    }
    if (res.statusCode == 404) return null;
    final data = _decode(res);
    return NextMeeting(
      data['event_id'] as int,
      data['name'] as String,
      data['venue'] as String,
      data['time_label'] as String,
      data['date_iso'] as String,
      data['ongoing'] as bool? ?? false,
    );
  }

  // ── apologies ────────────────────────────────────────────────────────
  Future<ApologyInfo> submitApology(String token, String reason,
      {String? meetingDate}) async {
    final res = await _post(
      '/club/apologies',
      {'reason': reason, if (meetingDate != null) 'meeting_date': meetingDate},
      token: token,
    );
    return ApologyInfo(
      res['id'] as int,
      res['member_name'] as String,
      res['member_role'] as String,
      res['meeting_date'] as String,
      res['reason'] as String,
    );
  }

  Future<List<ApologyInfo>> fetchApologies(String token) async {
    final list = await _getList('/club/apologies', token);
    return [
      for (final a in list.cast<Map<String, dynamic>>())
        ApologyInfo(
          a['id'] as int,
          a['member_name'] as String,
          a['member_role'] as String,
          a['meeting_date'] as String,
          a['reason'] as String,
        ),
    ];
  }

  // ── treasury ─────────────────────────────────────────────────────────
  Future<TreasurySummary> fetchTreasurySummary(String token) async {
    final res = await _getAuthed('/club/treasury/summary', token);
    return _treasurySummaryFromJson(res);
  }

  Future<TreasurySummary> saveDuesSettings(
      String token, int amount, String period) async {
    final res = await _post(
      '/club/treasury/dues/settings',
      {'amount': amount, 'period': period},
      token: token,
    );
    return _treasurySummaryFromJson(res);
  }

  TreasurySummary _treasurySummaryFromJson(Map<String, dynamic> res) =>
      TreasurySummary(
        res['dues_amount'] as int,
        res['dues_period'] as String,
        res['dues_period_label'] as String,
        res['dues_collected'] as int,
        res['dues_outstanding'] as int,
        res['total_income'] as int,
        res['total_expenses'] as int,
      );

  Future<List<DuesMemberInfo>> fetchDues(String token) async {
    final list = await _getList('/club/treasury/dues', token);
    return [
      for (final d in list.cast<Map<String, dynamic>>())
        DuesMemberInfo(d['member_id'] as int, d['name'] as String,
            d['role'] as String, d['paid'] as bool),
    ];
  }

  Future<DuesMemberInfo> markDuesPaid(String token, int memberId) async {
    final res =
        await _post('/club/treasury/dues/$memberId/pay', null, token: token);
    return DuesMemberInfo(res['member_id'] as int, res['name'] as String,
        res['role'] as String, res['paid'] as bool);
  }

  Future<List<TransactionInfo>> fetchTransactions(String token) async {
    final list = await _getList('/club/treasury/transactions', token);
    return [
      for (final t in list.cast<Map<String, dynamic>>())
        TransactionInfo(
          t['id'] as int,
          t['kind'] as String,
          t['label'] as String,
          t['amount'] as int,
          DateTime.parse(t['created_at'] as String),
        ),
    ];
  }

  Future<TransactionInfo> recordTransaction(
      String token, String kind, String label, int amount) async {
    final res = await _post(
      '/club/treasury/transactions',
      {'kind': kind, 'label': label, 'amount': amount},
      token: token,
    );
    return TransactionInfo(
      res['id'] as int,
      res['kind'] as String,
      res['label'] as String,
      res['amount'] as int,
      DateTime.parse(res['created_at'] as String),
    );
  }

  // ── polls ────────────────────────────────────────────────────────────
  PollInfo _pollFromJson(Map<String, dynamic> res) => PollInfo(
        res['id'] as int,
        res['type'] as String,
        res['title'] as String,
        res['sub'] as String,
        res['closes_label'] as String,
        (res['options'] as List).cast<String>(),
        res['status'] as String,
        res['winner'] as String?,
        [
          for (final r in (res['results'] as List).cast<Map<String, dynamic>>())
            PollOptionResult(r['label'] as String, r['count'] as int),
        ],
        res['my_vote'] as String?,
        res['total_votes'] as int,
        res['assignments'] == null
            ? null
            : [
                for (final a in (res['assignments'] as List)
                    .cast<Map<String, dynamic>>())
                  DrawAssignment(
                      a['giver'] as String, a['recipient'] as String),
              ],
      );

  /// Null when the club has never created a poll (the backend responds
  /// with a literal JSON `null` body, not a 404, in that case).
  Future<PollInfo?> fetchActivePoll(String token) async {
    final http.Response res;
    try {
      res = await http.get(Uri.parse('$apiBaseUrl/club/polls/active'),
          headers: {'Authorization': 'Bearer $token'}).timeout(_requestTimeout);
    } catch (_) {
      throw ApiException('Could not reach the server. Check your connection.');
    }
    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      final data = decoded as Map<String, dynamic>;
      throw ApiException(data['detail'] as String? ?? 'Something went wrong.');
    }
    if (decoded == null) return null;
    return _pollFromJson(decoded as Map<String, dynamic>);
  }

  Future<PollInfo> createPoll(
    String token, {
    required String type,
    required String title,
    String sub = '',
    String closesLabel = '',
    List<String> options = const [],
  }) async {
    final res = await _post(
      '/club/polls',
      {
        'type': type,
        'title': title,
        'sub': sub,
        'closes_label': closesLabel,
        'options': options,
      },
      token: token,
    );
    return _pollFromJson(res);
  }

  Future<PollInfo> castVote(String token, int pollId, String choice) async {
    final res = await _post('/club/polls/$pollId/vote', {'choice': choice},
        token: token);
    return _pollFromJson(res);
  }

  Future<PollInfo> runDraw(String token, int pollId) async {
    final res = await _post('/club/polls/$pollId/draw', null, token: token);
    return _pollFromJson(res);
  }

  // ── secretary workspace ─────────────────────────────────────────────
  MinuteInfo _minuteFromJson(Map<String, dynamic> m) => MinuteInfo(
      m['id'] as int,
      m['title'] as String,
      m['meeting_date'] as String,
      m['status'] as String,
      m['body'] as String? ?? '');

  Future<List<MinuteInfo>> fetchMinutes(String token) async {
    final list = await _getList('/club/secretary/minutes', token);
    return [
      for (final m in list.cast<Map<String, dynamic>>()) _minuteFromJson(m),
    ];
  }

  Future<MinuteInfo> createMinute(
      String token, String title, String meetingDate) async {
    final res = await _post(
      '/club/secretary/minutes',
      {'title': title, 'meeting_date': meetingDate},
      token: token,
    );
    return _minuteFromJson(res);
  }

  Future<MinuteInfo> setMinuteStatus(
      String token, int minuteId, String status) async {
    final res = await _patch(
      '/club/secretary/minutes/$minuteId',
      {'status': status},
      token: token,
    );
    return _minuteFromJson(res);
  }

  Future<void> deleteMinute(String token, int minuteId) =>
      _delete('/club/secretary/minutes/$minuteId', token);

  Future<MinuteInfo> updateMinuteBody(
      String token, int minuteId, String body) async {
    final res = await _patch(
      '/club/secretary/minutes/$minuteId',
      {'body': body},
      token: token,
    );
    return _minuteFromJson(res);
  }

  /// Uploads a meeting recording; the server transcribes it and drafts the
  /// minutes in the background. Returns the placeholder `processing` minute.
  Future<MinuteInfo> uploadMinuteAudio(String token,
      {required String title,
      required String meetingDate,
      required String filePath}) async {
    final req = http.MultipartRequest(
        'POST', Uri.parse('$apiBaseUrl/club/secretary/minutes/from-audio'))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['title'] = title
      ..fields['meeting_date'] = meetingDate
      ..files.add(await http.MultipartFile.fromPath('audio', filePath));
    final http.StreamedResponse streamed;
    try {
      // No timeout: a long recording on club-hall wifi can take minutes.
      streamed = await req.send();
    } catch (_) {
      throw ApiException('Could not reach the server. Check your connection.');
    }
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode >= 400) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(data['detail'] as String? ?? 'Upload failed.');
    }
    return _minuteFromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<MilestoneInfo>> fetchMilestones(String token) async {
    final list = await _getList('/club/secretary/milestones', token);
    return [
      for (final m in list.cast<Map<String, dynamic>>())
        MilestoneInfo(m['id'] as int, m['year'] as String, m['title'] as String,
            m['category'] as String, m['text'] as String),
    ];
  }

  Future<MilestoneInfo> createMilestone(String token,
      {required String year,
      required String title,
      required String category,
      required String text}) async {
    final res = await _post(
      '/club/secretary/milestones',
      {'year': year, 'title': title, 'category': category, 'text': text},
      token: token,
    );
    return MilestoneInfo(
        res['id'] as int,
        res['year'] as String,
        res['title'] as String,
        res['category'] as String,
        res['text'] as String);
  }

  Future<void> deleteMilestone(String token, int id) =>
      _delete('/club/secretary/milestones/$id', token);

  Future<List<ClubDocumentInfo>> fetchClubDocuments(String token) async {
    final list = await _getList('/club/secretary/documents', token);
    return [
      for (final d in list.cast<Map<String, dynamic>>())
        ClubDocumentInfo(d['id'] as int, d['title'] as String,
            d['url'] as String, d['created_at'] as String),
    ];
  }

  Future<ClubDocumentInfo> uploadClubDocument(
      String token, String title, String pdfDataUrl) async {
    final res = await _post(
      '/club/secretary/documents',
      {'title': title, 'file': pdfDataUrl},
      token: token,
    );
    return ClubDocumentInfo(res['id'] as int, res['title'] as String,
        res['url'] as String, res['created_at'] as String);
  }

  Future<void> deleteClubDocument(String token, int id) =>
      _delete('/club/secretary/documents/$id', token);

  ReportInfo _reportFromJson(Map<String, dynamic> res) => ReportInfo(
        res['title'] as String,
        res['subtitle'] as String,
        [
          for (final s
              in (res['sections'] as List).cast<Map<String, dynamic>>())
            ReportSectionInfo(s['section'] as String, [
              for (final r in (s['rows'] as List).cast<Map<String, dynamic>>())
                ReportRowInfo(r['label'] as String, r['value'] as String),
            ]),
        ],
      );

  Future<ReportInfo> fetchMonthlyReport(String token) async {
    final res = await _getAuthed('/club/secretary/monthly-report', token);
    return _reportFromJson(res);
  }

  Future<ReportInfo> fetchAnnualReport(String token) async {
    final res = await _getAuthed('/club/secretary/annual-report', token);
    return _reportFromJson(res);
  }

  Future<TodaySummary> fetchToday({String? token}) async {
    final res = token == null
        ? await _get('/checkin/today')
        : await _getAuthed('/checkin/today', token);
    final members = (res['members'] as List)
        .map((m) => TodayCheckedInMember(
              m['name'] as String,
              m['role'] as String,
              DateTime.parse(m['checked_in_at'] as String),
            ))
        .toList();
    final guests = [
      for (final g
          in ((res['guests'] as List?) ?? const []).cast<Map<String, dynamic>>())
        MeetingGuest(
            g['name'] as String,
            g['type'] as String,
            g['club_name'] as String? ?? '',
            g['time'] as String? ?? '',
            g['via'] as String? ?? 'scan'),
    ];
    return TodaySummary(res['meeting_name'] as String,
        res['member_count'] as int, members, guests);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic>? body,
      {String? token}) async {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final http.Response res;
    try {
      res = await http
          .post(Uri.parse('$apiBaseUrl$path'),
              headers: headers, body: body == null ? null : jsonEncode(body))
          .timeout(_requestTimeout);
    } catch (_) {
      throw ApiException('Could not reach the server. Check your connection.');
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final http.Response res;
    try {
      res = await http
          .get(Uri.parse('$apiBaseUrl$path'))
          .timeout(_requestTimeout);
    } catch (_) {
      throw ApiException('Could not reach the server. Check your connection.');
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _getAuthed(String path, String token) async {
    final http.Response res;
    try {
      res = await http.get(Uri.parse('$apiBaseUrl$path'),
          headers: {'Authorization': 'Bearer $token'}).timeout(_requestTimeout);
    } catch (_) {
      throw ApiException('Could not reach the server. Check your connection.');
    }
    return _decode(res);
  }

  Future<List<dynamic>> _getList(String path, String token) async {
    final http.Response res;
    try {
      res = await http.get(Uri.parse('$apiBaseUrl$path'),
          headers: {'Authorization': 'Bearer $token'}).timeout(_requestTimeout);
    } catch (_) {
      throw ApiException('Could not reach the server. Check your connection.');
    }
    if (res.statusCode >= 400) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(data['detail'] as String? ?? 'Something went wrong.');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body,
      {String? token}) async {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final http.Response res;
    try {
      res = await http
          .patch(Uri.parse('$apiBaseUrl$path'),
              headers: headers, body: jsonEncode(body))
          .timeout(_requestTimeout);
    } catch (_) {
      throw ApiException('Could not reach the server. Check your connection.');
    }
    return _decode(res);
  }

  Future<void> _delete(String path, String token) async {
    final http.Response res;
    try {
      res = await http.delete(Uri.parse('$apiBaseUrl$path'),
          headers: {'Authorization': 'Bearer $token'}).timeout(_requestTimeout);
    } catch (_) {
      throw ApiException('Could not reach the server. Check your connection.');
    }
    if (res.statusCode >= 400) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(data['detail'] as String? ?? 'Something went wrong.');
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(data['detail'] as String? ?? 'Something went wrong.');
    }
    return data;
  }
}
