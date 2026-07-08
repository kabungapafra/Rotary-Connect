import 'package:flutter/material.dart';
import '../api_client.dart';
import '../app_state.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class TodayScreen extends StatelessWidget {
  final AppState state;
  const TodayScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListView(
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
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today at fellowship',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800)),
                    Text('Wed 8 Jul 2026 · Mbalwa Gardens Hall',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .25)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                          color: RCColors.gold, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Text('★',
                          style: TextStyle(
                              color: RCColors.blue,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CLUB OF THE DAY',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w800,
                                  color: RCColors.gold)),
                          Text('Rotary Club of Naalya',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          Text('2 visiting Rotarians · District 9213',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                  const RCStatBox(
                      value: '4', label: 'Guests', valueColor: RCColors.gold),
                  const SizedBox(width: 10),
                  const RCStatBox(value: '3', label: 'Clubs visiting'),
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
              RCCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < todayGuests.length; i++)
                      _GuestRow(
                          guest: todayGuests[i],
                          isLast: i == todayGuests.length - 1),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const RCSectionHeader(title: 'Visiting clubs today'),
              const SizedBox(height: 10),
              for (var i = 0; i < todayClubs.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _ClubRow(club: todayClubs[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckedInRow extends StatelessWidget {
  final TodayCheckedInMember member;
  final Color color;
  final bool isLast;
  const _CheckedInRow(
      {required this.member, required this.color, required this.isLast});

  String get _initials =>
      member.name.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).join();

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
          RCAvatar(initials: _initials, color: color, size: 36),
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

class _GuestRow extends StatelessWidget {
  final TodayGuest guest;
  final bool isLast;
  const _GuestRow({required this.guest, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isRotarian = guest.type == 'Visiting Rotarian';
    final avatarColor = isRotarian ? RCColors.amber : const Color(0xFF3A6EA5);
    final badgeBg = isRotarian ? RCColors.amberBg : RCColors.chipBg;
    final badgeFg = isRotarian ? RCColors.amber : RCColors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: RCColors.divider)),
      ),
      child: Row(
        children: [
          RCAvatar(initials: guest.initials, color: avatarColor, size: 36),
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
                Text(guest.sub,
                    style: const TextStyle(
                        fontSize: 11, color: RCColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: badgeBg, borderRadius: BorderRadius.circular(999)),
            child: Text(guest.type,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: badgeFg)),
          ),
        ],
      ),
    );
  }
}

class _ClubRow extends StatelessWidget {
  final TodayClub club;
  const _ClubRow({required this.club});

  @override
  Widget build(BuildContext context) {
    return RCCard(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: RCColors.chipBg,
                borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text(club.abbr,
                style: const TextStyle(
                    color: RCColors.blue,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(club.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: RCColors.textDark)),
                Text(club.sub,
                    style: const TextStyle(
                        fontSize: 11, color: RCColors.textMuted)),
              ],
            ),
          ),
          if (club.isClubOfDay)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: RCColors.amberBg,
                  borderRadius: BorderRadius.circular(999)),
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
