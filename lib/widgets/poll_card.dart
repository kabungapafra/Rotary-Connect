import 'package:flutter/material.dart';
import '../api_client.dart';
import '../app_state.dart';
import '../theme.dart';
import 'common.dart';
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
    return RCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                    color: RCColors.chipBg,
                    borderRadius: BorderRadius.circular(999)),
                child: Text(_typeLabels[poll.type] ?? poll.type.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                        color: RCColors.blue)),
              ),
              if (poll.status == 'closed') ...[
                const SizedBox(width: 6),
                const Text('CLOSED',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: RCColors.textMuted)),
              ],
              const Spacer(),
              if (poll.closesLabel.isNotEmpty)
                Text('Closes ${poll.closesLabel}',
                    style: const TextStyle(
                        fontSize: 10.5, color: RCColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Text(poll.title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: RCColors.textDark)),
          if (poll.sub.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(poll.sub,
                style:
                    const TextStyle(fontSize: 11.5, color: RCColors.textMuted)),
          ],
          const SizedBox(height: 12),
          if (poll.type == 'draw')
            _DrawBody(state: state, poll: poll)
          else
            _BallotBody(state: state, poll: poll),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: RCColors.goldOnLight.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('WHO GOT WHO',
                style: TextStyle(
                    fontSize: 10,
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: RCColors.chipBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(state.drawSpinName,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: RCColors.blue)),
      );
    }
    if (!state.canCreatePoll) {
      return const Text('The draw hasn\'t been run yet.',
          style: TextStyle(fontSize: 12, color: RCColors.textMuted));
    }
    return PressableScale(
      child: ElevatedButton(
        onPressed: state.runDraw,
        style: ElevatedButton.styleFrom(
          backgroundColor: RCColors.gold,
          foregroundColor: RCColors.blue,
          padding: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            // A subtle outline in the text color keeps the button reading
            // as a button even when gold is white (Rotaract) and it would
            // otherwise blend straight into the white card behind it.
            side: BorderSide(color: RCColors.blue.withValues(alpha: .18)),
          ),
          elevation: 0,
        ),
        child: const Text('Start draw',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      ),
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
                color: RCColors.chipBg,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => state.castVote(option),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Text(option,
                        style: TextStyle(
                            fontSize: 12.5,
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
                child: Text(r.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: poll.myVote == r.label
                            ? RCColors.blue
                            : RCColors.textDark)),
              ),
              Text('${r.count} vote${r.count == 1 ? '' : 's'}',
                  style:
                      const TextStyle(fontSize: 11, color: RCColors.textMuted)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : r.count / total,
              minHeight: 6,
              backgroundColor: RCColors.divider,
              color: RCColors.blue,
            ),
          ),
          const SizedBox(height: 10),
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
                      const Text('CANDIDATES (ONE PER LINE, AT LEAST 2)',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .5,
                              color: Color(0xFF8B96A8))),
                      const SizedBox(height: 6),
                      SyncedTextField(
                        value: draft.options,
                        builder: (context, controller) => TextField(
                          controller: controller,
                          onChanged: state.setVoteOptions,
                          minLines: 2,
                          maxLines: 4,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: RCColors.textDark),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'One per line',
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
                                borderSide:
                                    BorderSide(color: RCColors.blue)),
                          ),
                        ),
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
                    SyncedTextField(
                      value: draft.closes,
                      builder: (context, controller) => TextField(
                        controller: controller,
                        onChanged: state.setVoteCloses,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: RCColors.textDark),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'e.g. Fri 19 Jul',
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
