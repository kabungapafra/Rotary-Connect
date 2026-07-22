import 'package:flutter/material.dart';
import '../api_client.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pressable.dart';

class AttendanceScreen extends StatelessWidget {
  final AppState state;
  const AttendanceScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final mine = state.attView == 'mine';
    final s = state.summary;
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: RCColors.blue,
              padding: EdgeInsets.fromLTRB(
                  20, 18 + MediaQuery.of(context).padding.top, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Attendance',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      Material(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: state.downloadReport,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: .35)),
                            ),
                            child: const Text('⬇ Report',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                            child: _AttTab(
                                label: 'My record',
                                active: mine,
                                onTap: state.pickAttMine)),
                        const SizedBox(width: 4),
                        Expanded(
                            child: _AttTab(
                                label: 'Club register',
                                active: !mine,
                                onTap: state.pickAttClub)),
                      ],
                    ),
                  ),
                  if (mine) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _HeaderStat(
                            value: s == null ? '—' : '${s.attendancePercent}%',
                            label: 'Attendance'),
                        const SizedBox(width: 20),
                        _HeaderStat(
                            value: s == null ? '—' : '${s.weekStreak}',
                            label: 'Week streak'),
                        const SizedBox(width: 20),
                        _HeaderStat(
                            value: s == null ? '—' : '${s.meetingsTotal}',
                            label: 'Club meetings',
                            valueColor: RCColors.gold),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (mine) _MyRecord(state: state) else _ClubRegister(state: state),
          ],
        ),
        if (state.reportToast)
          Positioned(
            left: 24,
            right: 24,
            bottom: 88,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: RCColors.textDark,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x590A1223),
                      blurRadius: 24,
                      offset: Offset(0, 10))
                ],
              ),
              child: Row(
                children: [
                  const Text('✓',
                      style: TextStyle(
                          color: Color(0xFF4ADE80),
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Report downloaded · ${state.reportName}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AttTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _AttTab(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: active ? RCColors.blue : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  const _HeaderStat(
      {required this.value,
      required this.label,
      this.valueColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                color: valueColor, fontSize: 22, fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

/// The member's own per-meeting history, derived from their real check-ins.
class _MyRecord extends StatelessWidget {
  final AppState state;
  const _MyRecord({required this.state});

  @override
  Widget build(BuildContext context) {
    final meetings = state.clubMeetings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RCSectionHeader(title: 'History'),
          const SizedBox(height: 10),
          if (meetings.isEmpty)
            const RCCard(
              padding: EdgeInsets.all(24),
              child: Text(
                'No meetings held yet — your record starts with your first check-in.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: RCColors.textMuted),
              ),
            )
          else
            RCCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < meetings.length; i++)
                    _HistoryRow(
                        meeting: meetings[i], isLast: i == meetings.length - 1),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The club-wide register: pick a past meeting, see who checked in.
class _ClubRegister extends StatelessWidget {
  final AppState state;
  const _ClubRegister({required this.state});

  @override
  Widget build(BuildContext context) {
    final meetings = state.clubMeetings;
    if (meetings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: RCCard(
          padding: EdgeInsets.all(24),
          child: Text(
            'No meetings held yet — the register fills in as members check in.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: RCColors.textMuted),
          ),
        ),
      );
    }

    final selIndex = state.selectedMeeting.clamp(0, meetings.length - 1);
    final sel = meetings[selIndex];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Past fellowships & events',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: RCColors.textDark)),
          const SizedBox(height: 8),
          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: meetings.length,
              separatorBuilder: (_, sep) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final m = meetings[i];
                final active = i == selIndex;
                return Material(
                  color: active ? RCColors.blue : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => state.pickMeeting(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(m.name,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: active
                                      ? Colors.white
                                      : RCColors.textDark)),
                          const SizedBox(height: 2),
                          Text(m.date,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: (active
                                          ? Colors.white
                                          : RCColors.textDark)
                                      .withValues(alpha: .75))),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: RCColors.cardShadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(sel.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: RCColors.textDark)),
                    ),
                    Text(sel.date,
                        style: const TextStyle(
                            fontSize: 11, color: RCColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 10),
                _RegisterTabs(state: state),
                const SizedBox(height: 12),
                _RegisterTabContent(state: state, meeting: sel),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PressableScale(
            child: ElevatedButton(
              onPressed: state.downloadReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: RCColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('⬇ Download attendance report (PDF)',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegRow extends StatelessWidget {
  final MeetingAttendee attendee;
  final int index;
  final bool isLast;
  const _RegRow(
      {required this.attendee, required this.index, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: RCColors.divider)),
      ),
      child: Row(
        children: [
          RCAvatar(color: RCColors.avatarColor(index), size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(attendee.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: RCColors.textDark)),
                Text(attendee.role,
                    style: const TextStyle(
                        fontSize: 11, color: RCColors.textMuted)),
              ],
            ),
          ),
          Text(attendee.time,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: RCColors.green)),
        ],
      ),
    );
  }
}

/// Filter chips that switch the selected meeting's register between its
/// four categories — mirrors the source design's Members/Guests/
/// Apologies/Clubs tabs instead of stacking every group at once.
class _RegisterTabs extends StatelessWidget {
  final AppState state;
  const _RegisterTabs({required this.state});

  static const _tabs = [
    ('members', 'Members'),
    ('guests', 'Guests'),
    ('apologies', 'Apologies'),
    ('clubs', 'Clubs'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _RegisterTabChip(
              label: _tabs[i].$2,
              active: state.registerTab == _tabs[i].$1,
              onTap: () => state.pickRegisterTab(_tabs[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

class _RegisterTabChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _RegisterTabChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? RCColors.blue : const Color(0xFFEEF2F9),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : const Color(0xFF5A6A85),
            ),
          ),
        ),
      ),
    );
  }
}

const _emptyRegisterNote = TextStyle(fontSize: 12, color: RCColors.textMuted);

class _RegisterTabContent extends StatelessWidget {
  final AppState state;
  final ClubMeeting meeting;
  const _RegisterTabContent({required this.state, required this.meeting});

  @override
  Widget build(BuildContext context) {
    switch (state.registerTab) {
      case 'guests':
        return _guests();
      case 'apologies':
        return _apologies();
      case 'clubs':
        return _clubs();
      default:
        return _members();
    }
  }

  Widget _members() {
    if (meeting.attendees.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No check-ins recorded for this meeting.',
            textAlign: TextAlign.center, style: _emptyRegisterNote),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < meeting.attendees.length; i++)
          _RegRow(
              isLast: i == meeting.attendees.length - 1,
              attendee: meeting.attendees[i],
              index: i),
      ],
    );
  }

  Widget _guests() {
    final guests = meeting.guests;
    if (guests.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No guests or visiting Rotarians for this meeting.',
            textAlign: TextAlign.center, style: _emptyRegisterNote),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < guests.length; i++)
          _GuestRow(
              isLast: i == guests.length - 1, guest: guests[i], index: i),
      ],
    );
  }

  Widget _apologies() {
    if (state.registerApologiesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Loading…',
            textAlign: TextAlign.center, style: _emptyRegisterNote),
      );
    }
    final apologies = state.registerApologies;
    if (apologies.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No apologies sent for this meeting.',
            textAlign: TextAlign.center, style: _emptyRegisterNote),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < apologies.length; i++)
          _ApologyRegRow(
              isLast: i == apologies.length - 1,
              apology: apologies[i],
              index: i),
      ],
    );
  }

  Widget _clubs() {
    final counts = <String, int>{};
    for (final g in meeting.guests) {
      if (g.type == 'Visiting Rotarian' && g.clubName.isNotEmpty) {
        counts[g.clubName] = (counts[g.clubName] ?? 0) + 1;
      }
    }
    final clubs = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (clubs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No visiting clubs for this meeting.',
            textAlign: TextAlign.center, style: _emptyRegisterNote),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < clubs.length; i++)
          _ClubRow(
              isLast: i == clubs.length - 1,
              clubName: clubs[i].key,
              visitorCount: clubs[i].value,
              isClubOfDay: i == 0),
      ],
    );
  }
}

class _ApologyRegRow extends StatelessWidget {
  final ApologyInfo apology;
  final int index;
  final bool isLast;
  const _ApologyRegRow(
      {required this.apology, required this.index, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: RCColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RCAvatar(color: RCColors.avatarColor(index), size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(apology.memberName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: RCColors.textDark)),
                if (apology.reason.isNotEmpty)
                  Text(apology.reason,
                      style: const TextStyle(
                          fontSize: 11, color: RCColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF5E0),
                borderRadius: BorderRadius.circular(999)),
            child: const Text('APOLOGY',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB57708))),
          ),
        ],
      ),
    );
  }
}

class _ClubRow extends StatelessWidget {
  final String clubName;
  final int visitorCount;
  final bool isClubOfDay;
  final bool isLast;
  const _ClubRow(
      {required this.clubName,
      required this.visitorCount,
      required this.isClubOfDay,
      required this.isLast});

  String get _abbr {
    final words =
        clubName.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final letters = words.take(3).map((w) => w[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: RCColors.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: const Color(0xFFEEF2F9),
                borderRadius: BorderRadius.circular(10)),
            child: Text(_abbr,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: RCColors.blue)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clubName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: RCColors.textDark)),
                Text(
                    '$visitorCount visiting Rotarian${visitorCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 11, color: RCColors.textMuted)),
              ],
            ),
          ),
          if (isClubOfDay)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF5E0),
                  borderRadius: BorderRadius.circular(999)),
              child: const Text('CLUB OF THE DAY',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB57708))),
            ),
        ],
      ),
    );
  }
}

class _GuestRow extends StatelessWidget {
  final MeetingGuest guest;
  final int index;
  final bool isLast;
  const _GuestRow(
      {required this.guest, required this.index, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final subtitle = guest.clubName.isEmpty
        ? guest.type
        : '${guest.type} · ${guest.clubName}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: RCColors.divider)),
      ),
      child: Row(
        children: [
          RCAvatar(color: RCColors.avatarColor(index), size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guest.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: RCColors.textDark)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: RCColors.textMuted)),
              ],
            ),
          ),
          Text(guest.via == 'web' ? 'Web · ${guest.time}' : guest.time,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: RCColors.green)),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final ClubMeeting meeting;
  final bool isLast;
  const _HistoryRow({required this.meeting, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = meeting.attended ? RCColors.green : RCColors.red;
    final status = meeting.attended ? 'Present' : 'Absent';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: RCColors.divider)),
      ),
      child: Row(
        children: [
          Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meeting.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: RCColors.textDark)),
                Text(meeting.date,
                    style: const TextStyle(
                        fontSize: 11, color: RCColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
                color: color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(999)),
            child: Text(status,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}
