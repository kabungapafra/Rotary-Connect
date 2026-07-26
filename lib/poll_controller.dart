import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'widgets/date_time_field.dart' show formatDateDayMonYear;

/// Working copy of the "New vote" bottom sheet fields.
class PollDraft {
  String type = 'motion'; // motion | election | draw
  String title = '';
  String sub = '';
  // Picked via a date field (not typed), and never a past date — see
  // EventsController's saveEvent for the same pattern on events.
  DateTime? closesDate;
  // Election only: the selected candidates' member names — picked from
  // the actual club roster instead of typed in free text, so a name can't
  // be misspelled or refer to someone who isn't a member.
  final Set<String> candidates = {};
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
  void setVoteClosesDate(DateTime d) =>
      _update(() => voteEditor?.closesDate = d);
  void toggleVoteCandidate(String memberName) => _update(() {
        final candidates = voteEditor?.candidates;
        if (candidates == null) return;
        if (!candidates.remove(memberName)) candidates.add(memberName);
      });

  Future<void> saveVoteEditor() async {
    final draft = voteEditor;
    final token = _getToken();
    if (draft == null || token == null) return;
    if (draft.title.trim().isEmpty) {
      _update(() => draft.error = 'Enter a title.');
      return;
    }
    final options = draft.type == 'election'
        ? draft.candidates.map((name) => 'Rtn. $name').toList()
        : <String>[];
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
        closesLabel:
            draft.closesDate != null ? formatDateDayMonYear(draft.closesDate!) : '',
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

  /// Ends a motion/election before its closing date — President, Secretary,
  /// or the poll's own creator (enforced server-side; the button that
  /// calls this is gated the same way client-side).
  Future<void> closePoll() async {
    final poll = active;
    final token = _getToken();
    if (poll == null || token == null || poll.status != 'open') return;
    try {
      final updated = await _api.closePoll(token, poll.id);
      _update(() => active = updated);
    } on ApiException {
      // leave the poll showing as open — the member can try again
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
