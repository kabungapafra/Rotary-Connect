import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'data.dart';

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

/// The club roster — the member list, search/filter, the add-member
/// sheet, and the profile viewer — split out of AppState. Depends only
/// on [ApiClient], a token provider, and a manager-permission check, not
/// on AppState itself.
class MembersController extends ChangeNotifier {
  final ApiClient _api;
  final String? Function() _getToken;
  final bool Function() _canManageClub;
  MembersController(this._api, this._getToken, this._canManageClub);

  String search = '';
  String filter = 'all'; // all | board | gen
  final List<Member> extraMembers = [];
  MemberDraft? editor;
  Member? profile;

  // Real club roster, fetched from the backend once logged in. The static
  // design list remains only as the pre-login/demo fallback.
  List<Member> roster = [];
  bool loaded = false;
  bool loading = false;
  String? error;

  void _update(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  /// Drops the cached roster so a member of a different club signing in
  /// on the same device never sees a stale one.
  void reset() {
    roster = [];
    loaded = false;
  }

  Future<void> load() async {
    final token = _getToken();
    if (token == null) return;
    _update(() {
      loading = true;
      error = null;
    });
    try {
      final list = await _api.fetchClubMembers(token);
      _update(() {
        roster = [
          for (final m in list)
            Member(m.id, m.name, m.role, m.isBoard,
                status: m.status,
                email: m.email,
                phone: m.phone,
                dob: m.dob,
                terminatedAt: m.terminatedAt),
        ];
        loaded = true;
        loading = false;
      });
    } on ApiException catch (e) {
      _update(() {
        loading = false;
        error = e.message;
      });
    }
  }

  void setSearch(String v) => _update(() => search = v);
  void setFilter(String v) => _update(() => filter = v);

  /// Logged in → the real club roster from the backend; otherwise the
  /// static design list (pre-login preview only).
  List<Member> membersFor(bool loggedIn) => loggedIn ? roster : const [];

  void openAddMember() => _update(() => editor = MemberDraft());
  void closeMemberEditor() => _update(() => editor = null);
  void setMemberName(String v) => _update(() {
        editor?.name = v;
        editor?.error = null;
      });
  void setMemberRole(String v) => _update(() => editor?.role = v);
  void setMemberEmail(String v) => _update(() => editor?.email = v);
  void setMemberPhone(String v) => _update(() {
        editor?.phone = v;
        editor?.error = null;
      });
  void setMemberIsBoard(bool v) => _update(() => editor?.isBoard = v);
  void setMemberDob(String v) => _update(() => editor?.dob = v);

  /// Saves the new member. When the logged-in user is the Club President,
  /// the member is persisted through the backend (which generates their
  /// member number and one-time PIN, returned here for the president to
  /// hand over); the local list is updated either way so the UI matches.
  Future<AddedClubMember?> saveMember() async {
    final m = editor;
    if (m == null) return null;
    if (m.name.trim().isEmpty) {
      _update(() => m.error = 'Enter the member\'s name.');
      return null;
    }

    AddedClubMember? added;
    final token = _getToken();
    if (token != null && _canManageClub()) {
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
      _update(() => editor = null);
      await load(); // roster now includes the new member
      return added;
    }

    _update(() {
      extraMembers.add(Member(
        0, // not persisted to the backend — pre-login/demo-only entry
        m.name.trim(),
        m.role.trim().isEmpty ? 'Member' : m.role.trim(),
        m.isBoard,
        email: m.email.trim(),
        phone: m.phone.trim(),
        dob: m.dob.trim(),
      ));
      editor = null;
    });
    return added;
  }

  void openMemberProfile(Member m) => _update(() => profile = m);
  void closeMemberProfile() => _update(() => profile = null);

  /// President/Secretary only: end (`'terminated'`) or restore
  /// (`'active'`) a member's membership. Reloads the roster and, if the
  /// profile sheet is open on this same member, refreshes it in place
  /// rather than leaving it showing stale status. Lets [ApiException]
  /// propagate — the caller shows it.
  Future<void> setMemberStatus(int memberId, String status) async {
    final token = _getToken();
    if (token == null) return;
    await _api.updateMemberStatus(token, memberId, status);
    await load();
    if (profile?.id == memberId) {
      Member? updated;
      for (final m in roster) {
        if (m.id == memberId) {
          updated = m;
          break;
        }
      }
      if (updated != null) _update(() => profile = updated);
    }
  }
}
