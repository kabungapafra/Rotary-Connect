import 'package:flutter/material.dart';
import '../api_client.dart';
import '../app_state.dart';
import '../poll_controller.dart' show PollDraft;
import '../theme.dart';
import '../widgets/date_time_field.dart';
import 'pressable.dart';
import 'synced_text_field.dart';

/// The club's current vote — motion/election ballot or random draw.
/// Shown on Home so every member sees it.
class PollCard extends StatelessWidget {
  final AppState state;
  final PollInfo poll;
  const PollCard({super.key, required this.state, required this.poll});

  static const _typeLabels = {
    'motion': 'MOTION',
    'election': 'ELECTION',
    'draw': 'RANDOM DRAW',
  };

  @override
  Widget build(BuildContext context) {
    final isDraw = poll.type == 'draw';
    return Container(
      decoration: BoxDecoration(
        color: RCColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: RCColors.cardShadow, blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: RCColors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      color: isDraw
                          ? RCColors.gold
                          : Colors.white.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(_typeLabels[poll.type] ?? poll.type.toUpperCase(),
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: isDraw ? RCColors.blue : Colors.white)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    poll.status == 'closed'
                        ? 'CLOSED'
                        : (poll.closesLabel.isNotEmpty
                            ? 'CLOSES ${poll.closesLabel.toUpperCase()}'
                            : ''),
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .5,
                        color: Colors.white.withValues(alpha: .7)),
                  ),
                ),
                if (poll.status == 'open' && state.canCreatePoll)
                  Material(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: state.openVoteEditor,
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Text('＋ New',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(poll.title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: RCColors.textDark,
                        height: 1.3)),
                if (poll.sub.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(poll.sub,
                      style: const TextStyle(
                          fontSize: 11.5, color: RCColors.textMuted)),
                ],
                const SizedBox(height: 12),
                if (isDraw)
                  _DrawBody(state: state, poll: poll)
                else
                  _BallotBody(state: state, poll: poll),
                // President/Secretary can end a vote before its closing
                // date — e.g. once a quorum's already in, no need to wait
                // it out.
                if (poll.status == 'open' && state.canManageClub) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: PressableScale(
                      child: OutlinedButton(
                        onPressed: state.closePoll,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: RCColors.red,
                          side: const BorderSide(color: Color(0xFFF3C9C4)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                            poll.type == 'election'
                                ? 'End election'
                                : 'End vote',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawBody extends StatelessWidget {
  final AppState state;
  final PollInfo poll;
  const _DrawBody({required this.state, required this.poll});

  @override
  Widget build(BuildContext context) {
    final assignments = poll.assignments;
    if (assignments != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: RCColors.amberBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('WHO GOT WHO',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: RCColors.amber)),
            const SizedBox(height: 8),
            for (final a in assignments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(a.giver,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: RCColors.textDark)),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('→',
                          style:
                              TextStyle(fontSize: 12, color: RCColors.amber)),
                    ),
                    Expanded(
                      child: Text(a.recipient,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: RCColors.textDark)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    if (state.drawSpinning) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: RCColors.blue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text('DRAWING…',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: RCColors.gold)),
            const SizedBox(height: 6),
            Text(state.drawSpinName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ],
        ),
      );
    }
    if (!state.canCreatePoll) {
      return const Text('The draw hasn\'t been run yet.',
          style: TextStyle(fontSize: 12, color: RCColors.textMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFD4DBE8), width: 1.5),
          ),
          child: Column(
            children: [
              const Text('🎲', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text('${poll.options.length} entrants in the hat',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4A5670))),
            ],
          ),
        ),
        const SizedBox(height: 10),
        PressableScale(
          child: ElevatedButton(
            onPressed: state.runDraw,
            style: ElevatedButton.styleFrom(
              backgroundColor: RCColors.gold,
              foregroundColor: RCColors.blue,
              padding: const EdgeInsets.all(13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                // A subtle outline in the text color keeps the button
                // reading as a button even when gold is white (Rotaract)
                // and it would otherwise blend straight into the white
                // card behind it.
                side: BorderSide(color: RCColors.blue.withValues(alpha: .18)),
              ),
              elevation: 0,
            ),
            child: const Text('Start draw',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          ),
        ),
      ],
    );
  }
}

class _BallotBody extends StatelessWidget {
  final AppState state;
  final PollInfo poll;
  const _BallotBody({required this.state, required this.poll});

  @override
  Widget build(BuildContext context) {
    if (poll.myVote == null && poll.status == 'open') {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in poll.options)
            PressableScale(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => state.castVote(option),
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 90),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xFFD4DBE8), width: 1.5),
                    ),
                    child: Text(option,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: RCColors.blue)),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    final total = poll.totalVotes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in poll.results) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                    '${r.label} · ${total == 0 ? 0 : (r.count / total * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: RCColors.textDark)),
              ),
              Text('${r.count} vote${r.count == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF8B96A8))),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : r.count / total,
              minHeight: 6,
              backgroundColor: RCColors.divider,
              color: RCColors.blue,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (poll.myVote != null) ...[
          const SizedBox(height: 2),
          Text('✓ Your vote — ${poll.myVote} — has been recorded',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: RCColors.green)),
        ],
      ],
    );
  }
}

class VoteEditorSheet extends StatelessWidget {
  final AppState state;
  const VoteEditorSheet({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final draft = state.voteEditor!;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: state.closeVoteEditor,
            child: Container(color: const Color(0x8C0A1223)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * .86),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4DBE8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('New vote',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: RCColors.textDark)),
                        Material(
                          color: RCColors.chipBg,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: state.closeVoteEditor,
                            child: const SizedBox(
                              width: 30,
                              height: 30,
                              child: Center(
                                  child: Text('✕',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF5A6A85)))),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (final t in const [
                          ['motion', 'Motion'],
                          ['election', 'Election'],
                          ['draw', 'Random draw'],
                        ])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _TypeChip(
                                label: t[1],
                                active: draft.type == t[0],
                                onTap: () => state.setVoteType(t[0]),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('TITLE',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: Color(0xFF8B96A8))),
                    const SizedBox(height: 6),
                    SyncedTextField(
                      value: draft.title,
                      builder: (context, controller) => TextField(
                        controller: controller,
                        onChanged: state.setVoteTitle,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: RCColors.textDark),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: draft.type == 'motion'
                              ? 'e.g. Adopt UGX 12M budget for Solar Lights'
                              : draft.type == 'election'
                                  ? 'e.g. Next Secretary'
                                  : 'e.g. Raffle draw',
                          hintStyle: const TextStyle(
                              fontSize: 13, color: Color(0xFF8B96A8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFD4DBE8))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFD4DBE8))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: RCColors.blue)),
                        ),
                      ),
                    ),
                    if (draft.type == 'draw') ...[
                      const SizedBox(height: 12),
                      const Text(
                          'Draws among every current club member — nobody gets '
                          'themselves, nobody is picked twice.',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF8B96A8),
                              height: 1.4)),
                    ],
                    if (draft.type == 'election') ...[
                      const SizedBox(height: 12),
                      const Text('CANDIDATES (SELECT AT LEAST 2 MEMBERS)',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .5,
                              color: Color(0xFF8B96A8))),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final m in state.clubMembers
                              .where((m) => m.status == 'active'))
                            _TypeChip(
                              label: m.name,
                              active: draft.candidates.contains(m.name),
                              onTap: () => state.toggleVoteCandidate(m.name),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text('CLOSES (OPTIONAL)',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5,
                            color: Color(0xFF8B96A8))),
                    const SizedBox(height: 6),
                    _ClosesDateField(state: state, draft: draft),
                    if (draft.error != null) ...[
                      const SizedBox(height: 10),
                      Text(draft.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12, color: RCColors.red)),
                    ],
                    const SizedBox(height: 14),
                    PressableScale(
                      child: ElevatedButton(
                        onPressed: draft.saving ? null : state.saveVoteEditor,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RCColors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(draft.saving ? 'Starting…' : 'Start vote',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TypeChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? RCColors.blue : RCColors.chipBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : const Color(0xFF5A6A85))),
        ),
      ),
    );
  }
}

/// The vote editor's "closes" field — a date picker (never a past date),
/// not free text, so it can't be typed as something unparseable.
class _ClosesDateField extends StatelessWidget {
  final AppState state;
  final PollDraft draft;
  const _ClosesDateField({required this.state, required this.draft});

  @override
  Widget build(BuildContext context) {
    final picked = draft.closesDate;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final result = await pickRCDate(context,
            initialDate: picked ?? DateTime.now(), firstDate: DateTime.now());
        if (result != null) state.setVoteClosesDate(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD4DBE8)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                  picked != null ? formatDateDayMonYear(picked) : 'No closing date set',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: picked != null
                          ? RCColors.textDark
                          : const Color(0xFF8B96A8))),
            ),
            Icon(Icons.calendar_today, size: 16, color: RCColors.blue),
          ],
        ),
      ),
    );
  }
}
