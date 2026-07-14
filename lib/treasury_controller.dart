import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Working copy of the "Record entry" (income/expense) bottom sheet fields.
class TxDraft {
  String kind = 'income'; // income | expense
  String label = '';
  String amount = '';
  bool saving = false;
  String? error;
}

/// Working copy of the Treasurer's "Dues settings" bottom sheet fields.
class DuesSettingDraft {
  String amount;
  String period; // quarterly | monthly | annual
  bool saving = false;
  String? error;
  DuesSettingDraft({required this.amount, required this.period});
}

/// Everything the Treasury workspace needs — summary, dues roster,
/// transaction ledger, and the two edit sheets — split out of AppState so
/// this one screen's concern isn't tangled with the other dozen the god
/// object used to own. Depends only on [ApiClient] and a token provider,
/// not on AppState itself, so it has no reason to change when unrelated
/// parts of the app (events, gallery, polls...) do.
class TreasuryController extends ChangeNotifier {
  final ApiClient _api;
  final String? Function() _getToken;
  TreasuryController(this._api, this._getToken);

  TreasurySummary? summary;
  List<DuesMemberInfo> duesList = [];
  List<TransactionInfo> transactions = [];
  bool loaded = false;
  bool loading = false;
  TxDraft? txEntry;
  DuesSettingDraft? duesSettingEditor;

  void _update(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  /// Drops every cached value so a member of a different club signing in
  /// on the same device never sees a stale treasury.
  void reset() {
    summary = null;
    duesList = [];
    transactions = [];
    loaded = false;
    txEntry = null;
    duesSettingEditor = null;
  }

  Future<void> load() async {
    final token = _getToken();
    if (token == null) return;
    _update(() => loading = true);
    try {
      final results = await Future.wait([
        _api.fetchTreasurySummary(token),
        _api.fetchDues(token),
        _api.fetchTransactions(token),
      ]);
      _update(() {
        summary = results[0] as TreasurySummary;
        duesList = results[1] as List<DuesMemberInfo>;
        transactions = results[2] as List<TransactionInfo>;
        loaded = true;
        loading = false;
      });
    } on ApiException {
      _update(() => loading = false);
    }
  }

  Future<void> markDuesPaid(int memberId) async {
    final token = _getToken();
    if (token == null) return;
    try {
      final updated = await _api.markDuesPaid(token, memberId);
      _update(() {
        duesList = [
          for (final d in duesList)
            if (d.memberId == memberId) updated else d,
        ];
      });
      await load();
    } on ApiException {
      // Leave the list as-is — the row's "Mark paid" button stays tappable
      // so the treasurer can retry.
    }
  }

  void openTxEntry() => _update(() => txEntry = TxDraft());
  void closeTxEntry() => _update(() => txEntry = null);
  void setTxKind(String kind) => _update(() => txEntry?.kind = kind);
  void setTxLabel(String v) => _update(() => txEntry?.label = v);
  void setTxAmount(String v) => _update(() => txEntry?.amount = v);

  Future<void> saveTxEntry() async {
    final entry = txEntry;
    final token = _getToken();
    if (entry == null || token == null) return;
    final amount =
        int.tryParse(entry.amount.trim().replaceAll(RegExp(r'[^0-9]'), ''));
    if (entry.label.trim().isEmpty || amount == null || amount <= 0) {
      _update(() => entry.error = 'Enter a label and a valid amount.');
      return;
    }
    _update(() {
      entry.saving = true;
      entry.error = null;
    });
    try {
      final tx = await _api.recordTransaction(
          token, entry.kind, entry.label.trim(), amount);
      _update(() {
        transactions.insert(0, tx);
        txEntry = null;
      });
      await load();
    } on ApiException catch (e) {
      _update(() {
        entry.saving = false;
        entry.error = e.message;
      });
    }
  }

  void openDuesSettings() => _update(() => duesSettingEditor = DuesSettingDraft(
        amount: summary?.duesAmount.toString() ?? '',
        period: summary?.duesPeriod ?? 'quarterly',
      ));
  void closeDuesSettings() => _update(() => duesSettingEditor = null);
  void setDuesAmount(String v) => _update(() => duesSettingEditor?.amount = v);
  void setDuesPeriod(String v) => _update(() => duesSettingEditor?.period = v);

  Future<void> saveDuesSettings() async {
    final draft = duesSettingEditor;
    final token = _getToken();
    if (draft == null || token == null) return;
    final amount =
        int.tryParse(draft.amount.trim().replaceAll(RegExp(r'[^0-9]'), ''));
    if (amount == null || amount < 0) {
      _update(() => draft.error = 'Enter a valid amount.');
      return;
    }
    _update(() {
      draft.saving = true;
      draft.error = null;
    });
    try {
      final result = await _api.saveDuesSettings(token, amount, draft.period);
      _update(() {
        summary = result;
        duesSettingEditor = null;
      });
      await load();
    } on ApiException catch (e) {
      _update(() {
        draft.saving = false;
        draft.error = e.message;
      });
    }
  }
}
