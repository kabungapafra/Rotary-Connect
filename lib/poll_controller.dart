import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Working copy of the "New vote" bottom sheet fields.
class PollDraft {
  String type = 'motion'; // motion | election | draw
  String title = '';
  String sub = '';
  String closes = '';
  String options = ''; // newline/comma separated, election & draw only
  bool saving = false;
  String? error;
}

/// The club's current (or most recently closed) vote — motion, election,
/// or random draw — split out of AppState. Depends only on [ApiClient]
/// and a token provider, not on AppState.
class PollController extends ChangeNotifier {
  final ApiClient _api;
  final String? Function() _getToken;
  PollController(this._api, this._getToken);

  PollInfo? active;
  bool loading = false;
  PollDraft? voteEditor;
  bool drawSpinning = false;
  String drawSpinName = '';
  Timer? _drawTimer;

  void _update(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  /// Drops the cached poll so a member of a different club signing in on
  /// the same device never sees a stale vote.
  void reset() {
    active = null;
    _drawTimer?.cancel();
    drawSpinning = false;
  }

  Future<void> load() async {
    final token = _getToken();
    if (token == null) return;
    _update(() => loading = true);
    try {
      final poll = await _api.fetchActivePoll(token);
      _update(() {
        active = poll;
        loading = false;
      });
    } on ApiException {
      _update(() => loading = false);
    }
  }

  void openVoteEditor() => _update(() => voteEditor = PollDraft());
  void closeVoteEditor() => _update(() => voteEditor = null);
  void setVoteType(String v) => _update(() => voteEditor?.type = v);
  void setVoteTitle(String v) => _update(() => voteEditor?.title = v);
  void setVoteSub(String v) => _update(() => voteEditor?.sub = v);
  void setVoteCloses(String v) => _update(() => voteEditor?.closes = v);
  void setVoteOptions(String v) => _update(() => voteEditor?.options = v);

  Future<void> saveVoteEditor() async {
    final draft = voteEditor;
    final token = _getToken();
    if (draft == null || token == null) return;
    if (draft.title.trim().isEmpty) {
      _update(() => draft.error = 'Enter a title.');
      return;
    }
    final options = draft.options
        .split(RegExp(r'[\n,]'))
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    if (draft.type == 'election' && options.length < 2) {
      _update(() => draft.error = 'An election needs at least 2 candidates.');
      return;
    }
    _update(() {
      draft.saving = true;
      draft.error = null;
    });
    try {
      final poll = await _api.createPoll(
        token,
        type: draft.type,
        title: draft.title.trim(),
        sub: draft.sub.trim(),
        closesLabel: draft.closes.trim(),
        options: options,
      );
      _update(() {
        active = poll;
        voteEditor = null;
      });
    } on ApiException catch (e) {
      _update(() {
        draft.saving = false;
        draft.error = e.message;
      });
    }
  }

  Future<void> castVote(String choice) async {
    final poll = active;
    final token = _getToken();
    if (poll == null || token == null) return;
    try {
      final updated = await _api.castVote(token, poll.id, choice);
      _update(() => active = updated);
    } on ApiException {
      // Leave the ballot showing so the member can try again.
    }
  }

  /// A few seconds of purely local suspense (mirroring the source design's
  /// spinning-name animation) before the server-resolved winner lands.
  void runDraw() {
    final poll = active;
    final token = _getToken();
    if (poll == null || token == null || drawSpinning || poll.options.isEmpty) {
      return;
    }
    _drawTimer?.cancel();
    var tick = 0;
    _update(() {
      drawSpinning = true;
      drawSpinName = poll.options[0];
    });
    _drawTimer =
        Timer.periodic(const Duration(milliseconds: 90), (timer) async {
      tick++;
      if (tick > 22) {
        timer.cancel();
        try {
          final updated = await _api.runDraw(token, poll.id);
          _update(() {
            active = updated;
            drawSpinning = false;
          });
        } on ApiException {
          _update(() => drawSpinning = false);
        }
      } else {
        _update(() =>
            drawSpinName = poll.options[Random().nextInt(poll.options.length)]);
      }
    });
  }

  @override
  void dispose() {
    _drawTimer?.cancel();
    super.dispose();
  }
}
