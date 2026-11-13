// A Club Admin is onboarded instead of a President to set the club up: the
// roster (above all, adding the President), events and their registration
// QR, projects, votes and history, so the app must show them those
// controls — but not the Secretary workspace. Mirrors the backend's MEMBER_MANAGER_ROLES /
// CLUB_CONTENT_ROLES / HISTORY_EDITOR_ROLES vs MANAGER_ROLES split.

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

  test('Club Admin manages members, events, projects, votes and history', () {
    final state = stateWithRole('Club Admin');
    expect(state.canManageMembers, isTrue);
    expect(state.canManageEventsAndProjects, isTrue);
    expect(state.canGenerateEventQr, isTrue);
    expect(state.canCreatePoll, isTrue);
    expect(state.canEditClubHistory, isTrue);
  });

  test('Club Admin still cannot use the Secretary workspace', () {
    expect(stateWithRole('Club Admin').isSecretary, isFalse);
  });

  test('a plain member cannot manage events, projects, votes or history', () {
    final state = stateWithRole('Member');
    expect(state.canManageEventsAndProjects, isFalse);
    expect(state.canGenerateEventQr, isFalse);
    expect(state.canCreatePoll, isFalse);
    expect(state.canEditClubHistory, isFalse);
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
