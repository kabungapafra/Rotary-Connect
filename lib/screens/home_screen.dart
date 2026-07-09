import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/club_logo.dart';
import '../widgets/common.dart';
import '../widgets/pressable.dart';

class HomeScreen extends StatelessWidget {
  final AppState state;
  const HomeScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Header(state: state),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatsCard(state: state),
              const SizedBox(height: 20),
              if (state.isTreasurer) ...[
                _TreasuryCard(state: state),
                const SizedBox(height: 20),
              ],
              RCSectionHeader(
                  title: 'Club gallery',
                  actionLabel: 'See all photos',
                  onAction: state.goGallery),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: state.goGallery,
                child: state.galleryUploads.isEmpty
                    ? const SizedBox(
                        height: 86,
                        child: RCPhotoPlaceholder(
                          label: 'No photos yet — upload the first',
                          labelAlignment: Alignment.center,
                        ),
                      )
                    : Row(
                        children: [
                          for (var i = 0;
                              i < 3 && i < state.galleryUploads.length;
                              i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 86,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                      state.galleryUploads[i].image,
                                      fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              RCSectionHeader(
                  title: 'Upcoming events',
                  actionLabel: 'See calendar',
                  onAction: state.goEvents),
              const SizedBox(height: 10),
              if (state.events.isEmpty)
                RCCard(
                  onTap: state.goEvents,
                  child: const Text(
                    'No events on the calendar yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: RCColors.textMuted),
                  ),
                )
              else
                SizedBox(
                  height: 168,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.events.length.clamp(0, 6),
                    separatorBuilder: (_, sep) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final e = state.events[i];
                      return SizedBox(
                        width: 150,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x1417458F),
                                  blurRadius: 8,
                                  offset: Offset(0, 2))
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: 96,
                                child: RCPhotoPlaceholder(
                                    label: e.dow,
                                    borderRadius: BorderRadius.zero),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(e.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: RCColors.textDark,
                                            height: 1.3)),
                                    const SizedBox(height: 2),
                                    Text(e.meta,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: RCColors.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
              RCSectionHeader(
                  title: 'Club projects',
                  actionLabel: 'See all',
                  onAction: state.goProjects),
              const SizedBox(height: 10),
              for (var i = 0; i < 2 && i < state.projects.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                RCCard(
                  onTap: state.goProjects,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: RCColors.chipBg,
                            borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: Text(state.projects[i].icon,
                            style: const TextStyle(
                                color: RCColors.blue,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(state.projects[i].name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: RCColors.textDark)),
                            Text(state.projects[i].area,
                                style: const TextStyle(
                                    fontSize: 11, color: RCColors.textMuted)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(state.projects[i].pctLabel,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: RCColors.blue)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final AppState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: RCColors.blue,
      padding: EdgeInsets.fromLTRB(
          20, 18 + MediaQuery.of(context).padding.top, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: ClubLogoImage(state: state, height: 60),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  border: Border.all(color: Colors.white.withValues(alpha: .3)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(state.roleBadge,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(state.greeting,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -.3)),
          const SizedBox(height: 3),
          Text(state.todayLine,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: .8), fontSize: 13)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RCColors.gold,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x2E000000),
                    blurRadius: 24,
                    offset: Offset(0, 10))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('NEXT MEETING',
                        style: TextStyle(
                            color: RCColors.blue,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5)),
                    if (state.nextMeeting != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: RCColors.blue.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(state.nextMeetingBadge,
                            style: const TextStyle(
                                color: RCColors.blue,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                const SizedBox(height: 11),
                Text(
                    state.nextMeeting?.name ??
                        (state.nextMeetingLoading
                            ? 'Loading…'
                            : 'No fellowship scheduled yet'),
                    style: const TextStyle(
                        color: RCColors.blue,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                    state.nextMeeting == null
                        ? state.clubName
                        : [state.nextMeeting!.timeLabel, state.nextMeeting!.venue]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                    style: TextStyle(
                        color: RCColors.blue.withValues(alpha: .85),
                        fontSize: 12.5)),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: PressableScale(
                        child: ElevatedButton(
                          onPressed: state.goScan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RCColors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Check in',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PressableScale(
                        child: OutlinedButton(
                          onPressed: state.goToday,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: RCColors.blue,
                            side: BorderSide(
                                color: RCColors.blue.withValues(alpha: .35),
                                width: 1.5),
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Who's here ›",
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single white card with three stat columns separated by hairline dividers,
/// showing the logged-in member's real numbers from the backend.
class _StatsCard extends StatelessWidget {
  final AppState state;
  const _StatsCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state.summary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: RCColors.cardShadow, blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Expanded(
              child: _Stat(
                  value: s == null ? '—' : '${s.attendancePercent}%',
                  label: 'Attendance',
                  divider: true)),
          Expanded(
              child: _Stat(
                  value: s == null ? '—' : '${s.checkInCount}',
                  label: 'Check-ins',
                  divider: true)),
          Expanded(
              child: _Stat(
                  value: s == null ? '—' : '${s.memberCount}',
                  label: 'Members',
                  valueColor: RCColors.amber)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  final bool divider;
  const _Stat(
      {required this.value,
      required this.label,
      this.valueColor = RCColors.blue,
      this.divider = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: divider
            ? const Border(right: BorderSide(color: Color(0xFFEEF1F7)))
            : null,
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: valueColor)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: RCColors.textMuted)),
        ],
      ),
    );
  }
}

class _TreasuryCard extends StatelessWidget {
  final AppState state;
  const _TreasuryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RCColors.blue,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: state.goTreasury,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: RCColors.gold,
                    borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: const Text('₵',
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
                    Text('Treasury workspace',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    Text('Dues, fines & collections',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFFB9C8E4))),
                  ],
                ),
              ),
              const Text('›',
                  style: TextStyle(color: RCColors.gold, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
