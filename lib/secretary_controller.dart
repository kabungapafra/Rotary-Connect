import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Working copy of the "Add minute" bottom sheet fields.
class MinuteDraft {
  String title = '';
  String meetingDate = ''; // "YYYY-MM-DD"
  bool saving = false;
  String? error;
}

/// Working copy of the "Add milestone" bottom sheet fields.
class MilestoneDraft {
  String year = '';
  String title = '';
  String category = 'Milestones';
  String text = '';
  bool saving = false;
  String? error;
}

/// The Secretary workspace's data and logic (minutes, milestones, the
/// monthly/annual reports, club documents) — split out of AppState so this
/// one role's concern isn't tangled with treasury, events, gallery, and
/// everything else the god object used to own together. Depends only on
/// [ApiClient] and a token provider, not on AppState.
class SecretaryController extends ChangeNotifier {
  final ApiClient _api;
  final String? Function() _getToken;
  final bool Function() _isSecretary;
  SecretaryController(this._api, this._getToken, this._isSecretary);

  List<MinuteInfo> minutes = [];
  List<MilestoneInfo> milestones = [];
  ReportInfo? monthlyReport;
  ReportInfo? annualReport;
  List<ClubDocumentInfo> clubDocuments = [];
  bool documentUploading = false;
  String? documentError;
  MinuteInfo? minuteOpen; // minute whose body is being viewed/edited
  bool minuteBodySaving = false;
  bool minuteAudioUploading = false;
  String? minuteAudioError;
  Timer? _minutesPollTimer;
  bool loaded = false;
  bool loading = false;
  MinuteDraft? minuteEditor;
  MilestoneDraft? milestoneEditor;
  String milestoneFilter = 'All';
  String tab = 'minutes'; // minutes | monthly | annual | docs

  void _update(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  /// Drops every cached value so a member of a different club signing in
  /// on the same device never sees a stale workspace. Milestones are kept
  /// out of the wipe by [reset]'s caller when appropriate — Club History
  /// reloads them on its own via [loadMilestones].
  void reset() {
    minutes = [];
    milestones = [];
    monthlyReport = null;
    annualReport = null;
    clubDocuments = [];
    minuteOpen = null;
    loaded = false;
    _minutesPollTimer?.cancel();
  }

  /// Milestones alone — the Club history screen is open to every member,
  /// unlike the rest of the Secretary workspace.
  Future<void> loadMilestones() async {
    final token = _getToken();
    if (token == null) return;
    try {
      final list = await _api.fetchMilestones(token);
      _update(() => milestones = list);
    } on ApiException {
      // Keep whatever was last loaded on a transient network error.
    }
  }

  Future<void> load() async {
    final token = _getToken();
    if (token == null) return;
    _update(() => loading = true);
    try {
      // Documents are the Secretary's alone (GET 403s for anyone else) —
      // skip that call entirely for a President, rather than let one
      // guaranteed 403 sink the whole Future.wait and leave them with no
      // reports either.
      final isSecretary = _isSecretary();
      final results = await Future.wait([
        _api.fetchMinutes(token),
        _api.fetchMilestones(token),
        _api.fetchMonthlyReport(token),
        _api.fetchAnnualReport(token),
        if (isSecretary) _api.fetchClubDocuments(token),
      ]);
      _update(() {
        minutes = results[0] as List<MinuteInfo>;
        milestones = results[1] as List<MilestoneInfo>;
        monthlyReport = results[2] as ReportInfo;
        annualReport = results[3] as ReportInfo;
        if (isSecretary) clubDocuments = results[4] as List<ClubDocumentInfo>;
        loaded = true;
        loading = false;
      });
      if (minutes.any((m) => m.status == 'processing')) {
        _pollMinutesWhileProcessing();
      }
    } on ApiException {
      _update(() => loading = false);
    }
  }

  void pickTab(String v) => _update(() => tab = v);

  void openMinuteEditor() => _update(() => minuteEditor = MinuteDraft());
  void closeMinuteEditor() => _update(() => minuteEditor = null);
  void setMinuteTitle(String v) => _update(() => minuteEditor?.title = v);
  void setMinuteDate(String v) => _update(() => minuteEditor?.meetingDate = v);

  Future<void> saveMinuteEditor() async {
    final draft = minuteEditor;
    final token = _getToken();
    if (draft == null || token == null) return;
    if (draft.title.trim().isEmpty || draft.meetingDate.trim().isEmpty) {
      _update(() => draft.error = 'Enter a title and date.');
      return;
    }
    _update(() {
      draft.saving = true;
      draft.error = null;
    });
    try {
      final minute = await _api.createMinute(
          token, draft.title.trim(), draft.meetingDate.trim());
      _update(() {
        minutes.insert(0, minute);
        minuteEditor = null;
      });
    } on ApiException catch (e) {
      _update(() {
        draft.saving = false;
        draft.error = e.message;
      });
    }
  }

  void openMinuteBody(MinuteInfo minute) => _update(() => minuteOpen = minute);
  void closeMinuteBody() => _update(() => minuteOpen = null);

  Future<void> saveMinuteBody(String body) async {
    final minute = minuteOpen;
    final token = _getToken();
    if (minute == null || token == null) return;
    _update(() => minuteBodySaving = true);
    try {
      final updated = await _api.updateMinuteBody(token, minute.id, body);
      _update(() {
        minutes = [
          for (final m in minutes)
            if (m.id == minute.id) updated else m,
        ];
        minuteOpen = null;
        minuteBodySaving = false;
      });
    } on ApiException {
      // Leave the editor open so nothing typed is lost; the save button
      // becomes tappable again.
      _update(() => minuteBodySaving = false);
    }
  }

  Future<void> deleteMinute(int id) async {
    final token = _getToken();
    if (token == null) return;
    try {
      await _api.deleteMinute(token, id);
      _update(() {
        minutes.removeWhere((m) => m.id == id);
        if (minuteOpen?.id == id) minuteOpen = null;
      });
    } on ApiException {
      // Leave the row showing so the secretary can retry.
    }
  }

  Future<void> uploadMinuteAudio(
      String title, String meetingDate, String filePath) async {
    final token = _getToken();
    if (token == null) return;
    _update(() {
      minuteAudioUploading = true;
      minuteAudioError = null;
    });
    try {
      final minute = await _api.uploadMinuteAudio(token,
          title: title, meetingDate: meetingDate, filePath: filePath);
      _update(() {
        minutes.insert(0, minute);
        minuteAudioUploading = false;
      });
      _pollMinutesWhileProcessing();
    } on ApiException catch (e) {
      _update(() {
        minuteAudioUploading = false;
        minuteAudioError = e.message;
      });
    }
  }

  /// While any minute is still `processing` (transcription running on the
  /// server), re-fetch the list every 15s so the row flips to draft/failed
  /// without the secretary having to leave and come back.
  void _pollMinutesWhileProcessing() {
    _minutesPollTimer?.cancel();
    _minutesPollTimer =
        Timer.periodic(const Duration(seconds: 15), (timer) async {
      final token = _getToken();
      if (token == null || !minutes.any((m) => m.status == 'processing')) {
        timer.cancel();
        return;
      }
      try {
        final list = await _api.fetchMinutes(token);
        _update(() => minutes = list);
      } on ApiException {
        // Transient network error — the next tick retries.
      }
    });
  }

  Future<void> toggleMinuteStatus(MinuteInfo minute) async {
    final token = _getToken();
    if (token == null) return;
    final next = minute.status == 'approved' ? 'draft' : 'approved';
    try {
      final updated = await _api.setMinuteStatus(token, minute.id, next);
      _update(() {
        minutes = [
          for (final m in minutes)
            if (m.id == minute.id) updated else m,
        ];
      });
    } on ApiException {
      // Leave the row as-is so the toggle stays tappable to retry.
    }
  }

  void pickMilestoneFilter(String cat) => _update(() => milestoneFilter = cat);

  List<MilestoneInfo> get visibleMilestones => milestoneFilter == 'All'
      ? milestones
      : milestones.where((m) => m.category == milestoneFilter).toList();

  void openMilestoneEditor() =>
      _update(() => milestoneEditor = MilestoneDraft());
  void closeMilestoneEditor() => _update(() => milestoneEditor = null);
  void setMilestoneYear(String v) => _update(() => milestoneEditor?.year = v);
  void setMilestoneTitle(String v) => _update(() => milestoneEditor?.title = v);
  void setMilestoneCategory(String v) =>
      _update(() => milestoneEditor?.category = v);
  void setMilestoneText(String v) => _update(() => milestoneEditor?.text = v);

  Future<void> saveMilestoneEditor() async {
    final draft = milestoneEditor;
    final token = _getToken();
    if (draft == null || token == null) return;
    if (draft.year.trim().isEmpty || draft.title.trim().isEmpty) {
      _update(() => draft.error = 'Enter a year and title.');
      return;
    }
    _update(() {
      draft.saving = true;
      draft.error = null;
    });
    try {
      final milestone = await _api.createMilestone(
        token,
        year: draft.year.trim(),
        title: draft.title.trim(),
        category: draft.category,
        text: draft.text.trim(),
      );
      _update(() {
        milestones.insert(0, milestone);
        milestoneEditor = null;
      });
    } on ApiException catch (e) {
      _update(() {
        draft.saving = false;
        draft.error = e.message;
      });
    }
  }

  Future<void> deleteMilestone(int id) async {
    final token = _getToken();
    if (token == null) return;
    try {
      await _api.deleteMilestone(token, id);
      _update(() => milestones.removeWhere((m) => m.id == id));
    } on ApiException {
      // Leave the entry showing so the secretary can retry.
    }
  }

  /// Documents travel as base64 JSON like gallery photos, so cap the file
  /// size well below anything that would stall a mobile upload.
  static const int _maxDocumentBytes = 15 * 1024 * 1024;

  Future<void> uploadClubDocument(String title, List<int> pdfBytes) async {
    final token = _getToken();
    if (token == null) return;
    if (pdfBytes.length > _maxDocumentBytes) {
      _update(() => documentError = 'PDF is too large — keep it under 15 MB.');
      return;
    }
    _update(() {
      documentUploading = true;
      documentError = null;
    });
    try {
      final doc = await _api.uploadClubDocument(token, title,
          'data:application/pdf;base64,${base64Encode(pdfBytes)}');
      _update(() {
        clubDocuments.insert(0, doc);
        documentUploading = false;
      });
    } on ApiException catch (e) {
      _update(() {
        documentUploading = false;
        documentError = e.message;
      });
    }
  }

  Future<void> deleteClubDocument(int id) async {
    final token = _getToken();
    if (token == null) return;
    try {
      await _api.deleteClubDocument(token, id);
      _update(() => clubDocuments.removeWhere((d) => d.id == id));
    } on ApiException {
      // Leave the entry showing so the secretary can retry.
    }
  }

  @override
  void dispose() {
    _minutesPollTimer?.cancel();
    super.dispose();
  }
}
