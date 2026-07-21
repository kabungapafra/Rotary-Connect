import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/apology_sheet.dart';
import '../widgets/club_logo.dart';
import '../widgets/common.dart';
import '../widgets/poll_card.dart';
import '../widgets/pressable.dart';
import '../widgets/wordmark.dart';

class HomeScreen extends StatelessWidget {
  final AppState state;
  const HomeScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(state: state),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.needsBoardSetup) ...[
                    _BoardSetupBanner(state: state),
                    const SizedBox(height: 20),
                  ],
                  _StatsCard(state: state),
                  const SizedBox(height: 20),
                  if (state.isTreasurer) ...[
                    _TreasuryCard(state: state),
                    const SizedBox(height: 20),
                  ],
                  if (state.isSecretary || state.isPresident) ...[
                    _SecretaryCard(state: state),
                    const SizedBox(height: 20),
                  ],
                  // A closed motion/election has nothing left to show —
                  // hide the card once it's done. A closed draw is the
                  // exception: "closed" is exactly when its assignments
                  // (the whole point of running it) become visible.
                  if (state.activePoll != null &&
                      (state.activePoll!.status == 'open' ||
                          state.activePoll!.assignments != null)) ...[
                    RCSectionHeader(
                        title: 'Club vote',
                        actionLabel: state.canCreatePoll ? '+ New vote' : null,
                        onAction:
                            state.canCreatePoll ? state.openVoteEditor : null),
                    const SizedBox(height: 10),
                    PollCard(state: state, poll: state.activePoll!),
                    const SizedBox(height: 20),
                  ] else if (state.canCreatePoll) ...[
                    RCSectionHeader(
                        title: 'Club vote',
                        actionLabel: '+ New vote',
                        onAction: state.openVoteEditor),
                    const SizedBox(height: 10),
                    const RCCard(
                      child: Text('No club vote right now.',
                          style: TextStyle(
                              fontSize: 12.5, color: RCColors.textMuted)),
                    ),
                    const SizedBox(height: 20),
                  ],
                  RCSectionHeader(
                      title: 'Club history',
                      actionLabel: 'View timeline',
                      onAction: state.goClubHistory),
                  const SizedBox(height: 10),
                  RCCard(
                    onTap: state.goClubHistory,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            state.milestones.isEmpty
                                ? 'See milestones, awards, and events from the club\'s past.'
                                : '${state.milestones.length} entr${state.milestones.length == 1 ? 'y' : 'ies'} recorded',
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: RCColors.textMuted),
                          ),
                        ),
                        Text('›',
                            style: TextStyle(
                                color: RCColors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
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
                                      child: CachedNetworkImage(
                                          imageUrl:
                                              state.galleryUploads[i].thumb ??
                                                  state.galleryUploads[i].image,
                                          fit: BoxFit.cover,
                                          fadeInDuration: const Duration(
                                              milliseconds: 150),
                                          placeholder: (context, _) =>
                                              Container(
                                                  color: const Color(
                                                      0xFFE8EDF5))),
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
                                boxShadow: [
                                  BoxShadow(
                                      color: RCColors.blue.withAlpha(0x14),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2))
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    height: 96,
                                    child: e.photo != null
                                        ? Image.network(e.photo!,
                                            fit: BoxFit.cover)
                                        : RCPhotoPlaceholder(
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
                                style: TextStyle(
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
                                        fontSize: 11,
                                        color: RCColors.textMuted)),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            child: Text(state.projects[i].pctLabel,
                                textAlign: TextAlign.right,
                                style: TextStyle(
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
        ),
        if (state.apologySheet != null) ApologySheet(state: state),
        if (state.voteEditor != null) VoteEditorSheet(state: state),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final AppState state;
  const _Header({required this.state});

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out?',
            style: TextStyle(
                color: RCColors.textDark,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
        content: const Text(
            'You will need your member number and PIN to sign back in.',
            style: TextStyle(color: RCColors.textMuted, fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
                style: TextStyle(
                    color: RCColors.textMuted, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Sign out',
                style: TextStyle(
                    color: RCColors.blue, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed == true) state.signOut();
  }

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
                // Original card footprint held fixed — the logo inside is
                // bigger than the card and deliberately spills past it.
                // OverflowBox is what permits that (a plain child gets
                // clamped to the parent's height), but it must be given
                // BOUNDED constraints — hence the SizedBox — or it blows
                // up the whole header row's layout.
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10)),
                child: SizedBox(
                  width: 96,
                  height: 40,
                  // The spill treatment only suits real logo artwork; the
                  // wordmark fallback (no uploaded logo) must stay inside
                  // the card or its club line bleeds onto the blue header.
                  child: state.clubLogo == null
                      ? FittedBox(
                          fit: BoxFit.contain,
                          child: Wordmark(state: state),
                        )
                      : OverflowBox(
                          maxWidth: 140,
                          maxHeight: 64,
                          child: ClubLogoImage(state: state, height: 64),
                        ),
                ),
              ),
              // Tapping the role badge is the app's sign-out affordance —
              // confirmed first, since login needs the one-time PIN again.
              PressableScale(
                child: GestureDetector(
                  onTap: () => _confirmSignOut(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      border:
                          Border.all(color: Colors.white.withValues(alpha: .3)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(state.roleBadge,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5)),
                  ),
                ),
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
                    Text('NEXT MEETING',
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
                            style: TextStyle(
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
                    style: TextStyle(
                        color: RCColors.blue,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                    state.nextMeeting == null
                        ? state.displayClubName
                        : [
                            state.nextMeeting!.timeLabel,
                            state.nextMeeting!.venue
                          ].where((s) => s.isNotEmpty).join(' · '),
                    style: TextStyle(
                        color: RCColors.blue.withValues(alpha: .85),
                        fontSize: 12.5)),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: PressableScale(
                        child: ElevatedButton(
                          onPressed:
                              state.checkedInToday ? null : state.goScan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: state.checkedInToday
                                ? RCColors.chipBg
                                : RCColors.blue,
                            foregroundColor: state.checkedInToday
                                ? RCColors.textMuted
                                : Colors.white,
                            disabledBackgroundColor: RCColors.chipBg,
                            disabledForegroundColor: RCColors.textMuted,
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(
                              state.checkedInToday
                                  ? 'Checked in ✓'
                                  : 'Check in',
                              style: const TextStyle(
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
                // No apology option once checked in to the meeting shown —
                // "can't attend" from someone already in the room. Only for
                // today's meeting: an apology for a FUTURE meeting is still
                // fine after today's check-in.
                if (state.nextMeeting != null &&
                    !(state.checkedInToday &&
                        state.nextMeeting!.dateIso ==
                            DateTime.now()
                                .toLocal()
                                .toIso8601String()
                                .substring(0, 10))) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: GestureDetector(
                      onTap: state.openApology,
                      child: Text("Can't attend? Send apology",
                          style: TextStyle(
                              color: RCColors.blue.withValues(alpha: .8),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline)),
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
        boxShadow: [
          BoxShadow(
              color: RCColors.cardShadow, blurRadius: 8, offset: const Offset(0, 2))
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
  final Color? valueColor;
  final bool divider;
  const _Stat(
      {required this.value,
      required this.label,
      this.valueColor,
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
                  color: valueColor ?? RCColors.blue)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: RCColors.textMuted)),
        ],
      ),
    );
  }
}

class _BoardSetupBanner extends StatelessWidget {
  final AppState state;
  const _BoardSetupBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RCColors.amberBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RCColors.amber.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your term as President has begun',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: RCColors.textDark)),
                const SizedBox(height: 3),
                const Text(
                    'The board was cleared for the new year — assign positions and a President-Elect from Members.',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: RCColors.textMuted,
                        height: 1.35)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: state.goMembers,
                  child: const Text('Assign positions →',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: RCColors.amber)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => state.dismissBoardSetup(),
            icon: const Icon(Icons.close, size: 18, color: RCColors.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
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
                child: Text('₵',
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
                    const Text('Treasury workspace',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    Text('Dues, fines & collections',
                        style:
                            TextStyle(fontSize: 11, color: RCColors.blueMuted)),
                  ],
                ),
              ),
              Text('›',
                  style: TextStyle(color: RCColors.gold, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecretaryCard extends StatelessWidget {
  final AppState state;
  const _SecretaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RCColors.blue,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: state.goSecretary,
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
                child: Text('S',
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
                    Text(state.isSecretary ? 'Secretary workspace' : 'Club reports',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    Text(
                        state.isSecretary
                            ? 'Minutes, club history & reports'
                            : 'Monthly & annual reports',
                        style:
                            TextStyle(fontSize: 11, color: RCColors.blueMuted)),
                  ],
                ),
              ),
              Text('›',
                  style: TextStyle(color: RCColors.gold, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
