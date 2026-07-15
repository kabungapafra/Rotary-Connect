// The member JWT moved from plaintext SharedPreferences to
// flutter_secure_storage this session. Locks in the one-time migration:
// an install that already has a token in the old location must not be
// silently signed out by the update, and the legacy copy must actually be
// removed (not left sitting in plaintext alongside the secure copy).

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rotary_connect/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> store = {};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async =>
      store[key] = value;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      store[key];

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      store.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async =>
      store.remove(key);

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      Map.of(store);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      store.clear();
}

// AppState._restoreSession fires several real API calls once a token is
// found (loadSummary, loadEvents, loadProjects, ...), unawaited. A blanket
// 401 here would be wrong, not just unrealistic — loadSummary's own catch
// block treats 401 as "this token was rejected" and signs the session back
// out, which is correct app behavior but defeats what this test is
// checking. So every request gets a neutral 200 shaped like what each
// endpoint actually expects, keeping this test isolated from the real
// network without exercising unrelated error-handling paths.
final _neutralClient = MockClient((request) async {
  if (request.url.path == '/club/me/summary') {
    return http.Response(
      '{"check_in_count": 0, "meetings_total": 0, "attendance_percent": 0, '
      '"today_meeting_name": "", "member_count": 0, "club_status": "active", '
      '"checked_in_today": false}',
      200,
      headers: {'content-type': 'application/json'},
    );
  }
  if (request.method == 'GET') {
    return http.Response('[]', 200, headers: {'content-type': 'application/json'});
  }
  return http.Response('{"ok": true}', 200, headers: {'content-type': 'application/json'});
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates a legacy plaintext token into secure storage and deletes it',
      () async {
    final fake = _FakeSecureStorage();
    FlutterSecureStoragePlatform.instance = fake;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'legacy-jwt-value',
      'member_name': 'Test Member',
      'club_id': 1,
      'club_name': 'Rotary Club of Mbalwa',
      'club_type': 'rotary',
    });

    await http.runWithClient(() async {
      AppState();
      // _restoreSession() runs unawaited from the constructor — its actual
      // storage reads/writes are local (no network), so a short delay is
      // enough for them to settle.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }, () => _neutralClient);

    expect(fake.store['auth_token'], 'legacy-jwt-value',
        reason: 'token should now live in secure storage');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull,
        reason: 'legacy plaintext copy must be removed, not just duplicated');
  });

  test('reads straight from secure storage once already migrated', () async {
    final fake = _FakeSecureStorage()..store['auth_token'] = 'already-secure-token';
    FlutterSecureStoragePlatform.instance = fake;
    SharedPreferences.setMockInitialValues({
      'member_name': 'Test Member',
      'club_id': 1,
      'club_name': 'Rotary Club of Mbalwa',
      'club_type': 'rotary',
    });

    late AppState state;
    await http.runWithClient(() async {
      state = AppState();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }, () => _neutralClient);

    expect(state.authToken, 'already-secure-token');
  });
}
