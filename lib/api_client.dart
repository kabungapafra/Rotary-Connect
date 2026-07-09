/// Thin client for the Rotary Connect backend (FastAPI + PostgreSQL),
/// deployed at https://rotary-connect-backend.onrender.com.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

const String apiBaseUrl = 'https://rotary-connect-backend.onrender.com';

// Long enough to ride out Render's free-tier cold start (~30-60s after the
// service has been idle), which is far longer than a normal request.
const Duration _requestTimeout = Duration(seconds: 75);

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
  const LoggedInMember(this.name, this.role, this.phone);
}

class LoginResult {
  final String token;
  final LoggedInMember member;
  final int clubId;
  final String clubName;
  final String? clubLogo; // data URL uploaded by the system admin
  const LoginResult(
      this.token, this.member, this.clubId, this.clubName, this.clubLogo);
}

class AddedClubMember {
  final String name;
  final String memberNumber;
  final String pin;
  const AddedClubMember(this.name, this.memberNumber, this.pin);
}

class ClubMemberInfo {
  final String name;
  final String role;
  final bool isBoard;
  final String status;
  final String email;
  final String phone;
  final String dob;
  const ClubMemberInfo(this.name, this.role, this.isBoard, this.status,
      this.email, this.phone, this.dob);
}

class ClubEvent {
  final int id;
  final String dow;
  final String name;
  final String meta;
  const ClubEvent(this.id, this.dow, this.name, this.meta);
}

class ClubProject {
  final int id;
  final String name;
  final String area;
  final int pct;
  final String desc;
  final String deadline;
  const ClubProject(
      this.id, this.name, this.area, this.pct, this.desc, this.deadline);
}

class MeetingAttendee {
  final String name;
  final String role;
  final String time;
  const MeetingAttendee(this.name, this.role, this.time);
}

class ClubMeeting {
  final String date;
  final String name;
  final int checkinCount;
  final bool attended;
  final List<MeetingAttendee> attendees;
  const ClubMeeting(
      this.date, this.name, this.checkinCount, this.attended, this.attendees);
}

class MemberSummary {
  final int checkInCount;
  final int meetingsTotal;
  final int attendancePercent;
  final String todayMeetingName;
  final int memberCount;
  const MemberSummary(this.checkInCount, this.meetingsTotal,
      this.attendancePercent, this.todayMeetingName, this.memberCount);
}

class CheckInResult {
  final bool alreadyCheckedIn;
  final DateTime checkedInAt;
  final String meetingName;
  const CheckInResult(this.alreadyCheckedIn, this.checkedInAt, this.meetingName);
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
  const TodaySummary(this.meetingName, this.memberCount, this.members);
}

class ApiClient {
  /// Fire-and-forget ping that wakes a sleeping free-tier backend while the
  /// user is still on the splash/login screens.
  void warmUp() {
    http.get(Uri.parse('$apiBaseUrl/health')).timeout(_requestTimeout).ignore();
  }

  Future<LoginResult> login(String identifier, String pin) async {
    final res = await _post('/auth/login', {'identifier': identifier, 'pin': pin});
    final member = res['member'] as Map<String, dynamic>;
    return LoginResult(
      res['access_token'] as String,
      LoggedInMember(member['name'] as String, member['role'] as String,
          member['phone'] as String? ?? ''),
      res['club_id'] as int,
      res['club_name'] as String? ?? 'Rotary Club of Mbalwa',
      res['club_logo'] as String?,
    );
  }

  /// Unauthenticated endpoint: a walk-in guest registers themselves, or a
  /// logged-in member checks in as a visitor at a club that isn't their
  /// own. Exactly one of [clubId] (this device's own club — the front-desk
  /// case) or [clubName] (a member naming the club they're visiting) is
  /// given. Returns the resolved club's name for display.
  Future<String> guestCheckIn({
    int? clubId,
    String? clubName,
    required String name,
    required String phone,
    required String hostName,
    required String guestType,
  }) async {
    final res = await _post('/checkin/guest', {
      if (clubId != null) 'club_id': clubId,
      if (clubName != null) 'club_name': clubName,
      'name': name,
      'phone': phone,
      'host_name': hostName,
      'guest_type': guestType,
    });
    return res['club_name'] as String;
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
          m['name'] as String,
          m['role'] as String,
          m['is_board'] as bool,
          m['status'] as String? ?? 'active',
          m['email'] as String,
          m['phone'] as String,
          m['dob'] as String,
        ),
    ];
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
            e['meta'] as String),
    ];
  }

  Future<ClubEvent> saveEvent(String token,
      {int? id, required String dow, required String name, required String meta}) async {
    final body = {'dow': dow, 'name': name, 'meta': meta};
    final res = id == null
        ? await _post('/club/events', body, token: token)
        : await _patch('/club/events/$id', body, token: token);
    return ClubEvent(res['id'] as int, res['dow'] as String,
        res['name'] as String, res['meta'] as String);
  }

  Future<void> deleteEvent(String token, int id) =>
      _delete('/club/events/$id', token);

  Future<List<ClubProject>> fetchProjects(String token) async {
    final list = await _getList('/club/projects', token);
    return [
      for (final p in list.cast<Map<String, dynamic>>())
        ClubProject(p['id'] as int, p['name'] as String, p['area'] as String,
            p['pct'] as int, p['desc'] as String, p['deadline'] as String),
    ];
  }

  Future<ClubProject> saveProject(String token,
      {int? id,
      required String name,
      required String area,
      required int pct,
      required String desc,
      required String deadline}) async {
    final body = {
      'name': name,
      'area': area,
      'pct': pct,
      'desc': desc,
      'deadline': deadline,
    };
    final res = id == null
        ? await _post('/club/projects', body, token: token)
        : await _patch('/club/projects/$id', body, token: token);
    return ClubProject(res['id'] as int, res['name'] as String,
        res['area'] as String, res['pct'] as int, res['desc'] as String,
        res['deadline'] as String);
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
            for (final a in (m['attendees'] as List).cast<Map<String, dynamic>>())
              MeetingAttendee(
                  a['name'] as String, a['role'] as String, a['time'] as String),
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

  Future<TodaySummary> fetchToday() async {
    final res = await _get('/checkin/today');
    final members = (res['members'] as List)
        .map((m) => TodayCheckedInMember(
              m['name'] as String,
              m['role'] as String,
              DateTime.parse(m['checked_in_at'] as String),
            ))
        .toList();
    return TodaySummary(res['meeting_name'] as String, res['member_count'] as int, members);
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
      res = await http.get(Uri.parse('$apiBaseUrl$path')).timeout(_requestTimeout);
    } catch (_) {
      throw ApiException('Could not reach the server. Check your connection.');
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _getAuthed(String path, String token) async {
    final http.Response res;
    try {
      res = await http
          .get(Uri.parse('$apiBaseUrl$path'),
              headers: {'Authorization': 'Bearer $token'})
          .timeout(_requestTimeout);
    } catch (_) {
      throw ApiException('Could not reach the server. Check your connection.');
    }
    return _decode(res);
  }

  Future<List<dynamic>> _getList(String path, String token) async {
    final http.Response res;
    try {
      res = await http
          .get(Uri.parse('$apiBaseUrl$path'),
              headers: {'Authorization': 'Bearer $token'})
          .timeout(_requestTimeout);
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
      res = await http
          .delete(Uri.parse('$apiBaseUrl$path'),
              headers: {'Authorization': 'Bearer $token'})
          .timeout(_requestTimeout);
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
