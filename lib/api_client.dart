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
  const LoggedInMember(this.name, this.role);
}

class LoginResult {
  final String token;
  final LoggedInMember member;
  final String clubName;
  final String? clubLogo; // data URL uploaded by the system admin
  const LoginResult(this.token, this.member, this.clubName, this.clubLogo);
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
      LoggedInMember(member['name'] as String, member['role'] as String),
      res['club_name'] as String? ?? 'Rotary Club of Mbalwa',
      res['club_logo'] as String?,
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

  Map<String, dynamic> _decode(http.Response res) {
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(data['detail'] as String? ?? 'Something went wrong.');
    }
    return data;
  }
}
