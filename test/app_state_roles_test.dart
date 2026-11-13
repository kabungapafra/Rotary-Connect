// A Club Admin is onboarded instead of a President to set the club up: their
// whole job is the roster (above all, adding the President), so the app must
// show them the member-management controls — but none of the President's
// other powers (events, projects, polls). Mirrors the backend's
// MEMBER_MANAGER_ROLES vs MANAGER_ROLES split.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rotary_connect/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppState stateWithRole(String role) => AppState()..currentMemberRole = role;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('Club Admin can manage members but not the rest of the club', () {
    final state = stateWithRole('Club Admin');
    expect(state.canManageMembers, isTrue);
    expect(state.canManageClub, isFalse);
    expect(state.canCreatePoll, isFalse);
  });

  test('President and Secretary still manage members', () {
    expect(stateWithRole('President').canManageMembers, isTrue);
    expect(stateWithRole('Club President').canManageMembers, isTrue);
    expect(stateWithRole('Secretary').canManageMembers, isTrue);
  });

  test('a plain member cannot manage members', () {
    expect(stateWithRole('Member').canManageMembers, isFalse);
  });
}
