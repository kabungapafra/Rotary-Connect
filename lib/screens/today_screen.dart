import 'package:flutter/material.dart';
import '../api_client.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/apology_sheet.dart';
import '../widgets/common.dart';

class TodayScreen extends StatelessWidget {
  final AppState state;
  const TodayScreen({super.key, required this.state});

  /// Visiting Rotarians grouped by their own club (most visitors first) —
  /// feeds both "Visiting clubs today" and the CLUB OF THE DAY banner,
  /// which goes to whichever club brought the most visitors.
  List<MapEntry<String, int>> get _visitingClubs {
    final counts = <String, int>{};
    for (final g in state.todayGuests) {
      if (g.type == 'Visiting Rotarian' && g.clubName.isNotEmpty) {
        counts[g.clubName] = (counts[g.clubName] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final visitingClubs = _visitingClubs;
    final clubOfDay = visitingClubs.isEmpty ? null : visitingClubs.first;
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: RCColors.blue,
              padding: EdgeInsets.fromLTRB(
                  20, 18 + MediaQuery.of(context).padding.top, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RCHeader(
                    onBack: state.goHome,
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Today at fellowship',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800)),
                        Text(
                            '${state.todayBadge.replaceFirst('TODAY · ', '')} · ${state.todayMeetingName}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (clubOfDay != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .25)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: RCColors.gold, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text('★',
                                style: TextStyle(
                                    color: RCColors.blue,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('CLUB OF THE DAY',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        letterSpacing: 1.5,
                                        fontWeight: FontWeight.w800,
                                        color: RCColors.gold)),
                                Text(clubOfDay.key,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                                Text(
                                    '${clubOfDay.value} visiting Rotarian${clubOfDay.value == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      RCStatBox(
                          value: '${state.todayCheckedInCount}',
                          label: 'Members in'),
                      const SizedBox(width: 10),
                      RCStatBox(
                          value: '${state.todayGuests.length}',
                          label: 'Guests',
                          valueColor: RCColors.goldOnLight),
                      const SizedBox(width: 10),
                      RCStatBox(
                          value: '${visitingClubs.length}',
                          label: 'Clubs visiting'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const RCSectionHeader(title: 'Members checked in'),
                  const SizedBox(height: 10),
                  if (state.todayCheckedIn.isEmpty)
                    RCCard(
                      child: Text(
                        state.todayLoading
                            ? 'Loading…'
                            : 'No members checked in yet.',
                        style: const TextStyle(
                            fontSize: 12.5, color: RCColors.textMuted),
                      ),
                    )
                  else
                    RCCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < state.todayCheckedIn.length; i++)
                            _CheckedInRow(
                              member: state.todayCheckedIn[i],
                              color: RCColors.avatarColor(i),
                              isLast: i == state.todayCheckedIn.length - 1,
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  const RCSectionHeader(title: 'Guests & visiting Rotarians'),
                  const SizedBox(height: 10),
                  _GuestList(
                    guests: state.todayGuests,
                    loading: state.todayLoading,
                    emptyText: 'No guests or visiting Rotarians yet.',
                  ),
                  if (visitingClubs.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const RCSectionHeader(title: 'Visiting clubs today'),
                    const SizedBox(height: 10),
                    for (var i = 0; i < visitingClubs.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _VisitingClubCard(
                          name: visitingClubs[i].key,
                          count: visitingClubs[i].value,
                          isClubOfDay: i == 0,
                        ),
                      ),
                  ],
                  const SizedBox(height: 10),
                  const RCSectionHeader(title: 'Apologies'),
                  const SizedBox(height: 10),
                  if (state.apologies.isEmpty)
                    RCCard(
                      child: Text(
                        state.apologiesLoading
                            ? 'Loading…'
                            : 'No apologies sent for today.',
                        style: const TextStyle(
                            fontSize: 12.5, color: RCColors.textMuted),
                      ),
                    )
                  else
                    RCCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < state.apologies.length; i++)
                            _ApologyRow(
                              apology: state.apologies[i],
                              color: RCColors.avatarColor(i),
                              isLast: i == state.apologies.length - 1,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (state.apologySheet != null) ApologySheet(state: state),
      ],
    );
  }
}

class _GuestList extends StatelessWidget {
  final List<MeetingGuest> guests;
  final bool loading;
  final String emptyText;
  const _GuestList(
      {required this.guests, required this.loading, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (guests.isEmpty) {
      return RCCard(
        child: Text(
          loading ? 'Loading…' : emptyText,
          style: const TextStyle(fontSize: 12.5, color: RCColors.textMuted),
        ),
      );
    }
    return RCCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < guests.length; i++)
            _GuestRow(
              guest: guests[i],
              color: RCColors.avatarColor(i),
              isLast: i == guests.length - 1,
            ),
        ],
      ),
    );
  }
}

class _GuestRow extends StatelessWidget {
  final MeetingGuest guest;
  final Color color;
  final bool isLast;
  const _GuestRow(
      {required this.guest, required this.color, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isVisitingRotarian = guest.type == 'Visiting Rotarian';
    final detail = guest.via == 'web' ? 'Web · ${guest.time}' : guest.time;
    final subtitle = guest.clubName.isEmpty
        ? detail
        : '${guest.clubName} · $detail';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: RCColors.divider)),
      ),
      child: Row(
        children: [
          RCAvatar(color: color, size: 36),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isVisitingRotarian ? RCColors.amberBg : RCColors.chipBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(guest.type,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color:
                        isVisitingRotarian ? RCColors.amber : RCColors.blue)),
          ),
        ],
      ),
    );
  }
}

class _VisitingClubCard extends StatelessWidget {
  final String name;
  final int count;
  final bool isClubOfDay;
  const _VisitingClubCard(
      {required this.name, required this.count, required this.isClubOfDay});

  /// "Rotary Club of Naalya" -> "RN"-style tile initials: first letters of
  /// the two most distinctive words (skipping filler like "of"/"club").
  String get _abbr {
    final words = name
        .split(RegExp(r'\s+'))
        .where((w) =>
            w.isNotEmpty && !{'of', 'the', 'club'}.contains(w.toLowerCase()))
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words.first[0] + words.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return RCCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: RCColors.chipBg,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(_abbr,
                style: TextStyle(
                    color: RCColors.blue,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: RCColors.textDark)),
                Text('$count visiting Rotarian${count == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 11, color: RCColors.textMuted)),
              ],
            ),
          ),
          if (isClubOfDay)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: RCColors.amberBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('CLUB OF THE DAY',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: RCColors.amber)),
            ),
        ],
      ),
    );
  }
}

class _CheckedInRow extends StatelessWidget {
  final TodayCheckedInMember member;
  final Color color;
  final bool isLast;
  const _CheckedInRow(
      {required this.member, required this.color, required this.isLast});

  String get _timeLabel {
    final t = member.checkedInAt.toLocal();
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: RCColors.divider)),
      ),
      child: Row(
        children: [
          RCAvatar(color: color, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: RCColors.textDark)),
                Text(member.role,
                    style: const TextStyle(
                        fontSize: 11, color: RCColors.textMuted)),
              ],
            ),
          ),
          Text(_timeLabel,
              style: const TextStyle(
                  fontSize: 11,
                  color: RCColors.green,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ApologyRow extends StatelessWidget {
  final ApologyInfo apology;
  final Color color;
  final bool isLast;
  const _ApologyRow(
      {required this.apology, required this.color, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: RCColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RCAvatar(color: color, size: 36),
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
                Text(apology.memberRole,
                    style: const TextStyle(
                        fontSize: 11, color: RCColors.textMuted)),
                if (apology.reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(apology.reason,
                      style: const TextStyle(
                          fontSize: 11.5, color: RCColors.textDark)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
