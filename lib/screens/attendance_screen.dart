import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AttendanceScreen extends StatelessWidget {
  final AppState state;
  const AttendanceScreen({super.key, required this.state});

  static const _statusColor = {
    'Present': RCColors.green,
    'Made up': RCColors.amber,
    'Absent': RCColors.red,
  };

  @override
  Widget build(BuildContext context) {
    final mine = state.attView == 'mine';
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
                    const Row(
                      children: [
                        _HeaderStat(value: '92%', label: 'This quarter'),
                        SizedBox(width: 20),
                        _HeaderStat(value: '7', label: 'Week streak'),
                        SizedBox(width: 20),
                        _HeaderStat(
                            value: '33',
                            label: 'Meetings this year',
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

class _MyRecord extends StatelessWidget {
  final AppState state;
  const _MyRecord({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RCSectionHeader(title: 'Certificates'),
          const SizedBox(height: 10),
          for (var i = 0; i < certs.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _CertRow(
                cert: certs[i],
                onTap: () =>
                    state.openCert(CertInfo(certs[i].title, certs[i].body))),
          ],
          const SizedBox(height: 20),
          const RCSectionHeader(title: 'History'),
          const SizedBox(height: 10),
          RCCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < history.length; i++)
                  _HistoryRow(
                      entry: history[i], isLast: i == history.length - 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubRegister extends StatelessWidget {
  final AppState state;
  const _ClubRegister({required this.state});

  @override
  Widget build(BuildContext context) {
    final sel = state.selMeeting;
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
              itemCount: registerMeetings.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final m = registerMeetings[i];
                final active = i == state.selectedMeeting;
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
                          Text(m.short,
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
              boxShadow: const [
                BoxShadow(
                    color: RCColors.cardShadow,
                    blurRadius: 8,
                    offset: Offset(0, 2))
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
                    Text('${sel.date} 2026',
                        style: const TextStyle(
                            fontSize: 11, color: RCColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _RegChip(
                        label: 'Members · ${sel.members}',
                        active: state.registerTab == 'members',
                        onTap: () => state.pickRegisterTab('members')),
                    const SizedBox(width: 6),
                    _RegChip(
                        label: 'Guests · ${sel.guests}',
                        active: state.registerTab == 'guests',
                        onTap: () => state.pickRegisterTab('guests')),
                    const SizedBox(width: 6),
                    _RegChip(
                        label: 'Clubs · ${sel.clubs}',
                        active: state.registerTab == 'clubs',
                        onTap: () => state.pickRegisterTab('clubs')),
                  ],
                ),
                const SizedBox(height: 4),
                if (state.registerTab == 'members')
                  for (var i = 0; i < todayMembers.length; i++)
                    _RegRow(
                      isLast: i == todayMembers.length - 1,
                      leading: RCAvatar(
                          initials: todayMembers[i].initials,
                          color: RCColors.avatarColor(i),
                          size: 36),
                      title: todayMembers[i].name,
                      sub: todayMembers[i].role,
                      trailing: Text(todayMembers[i].time,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: RCColors.green)),
                    ),
                if (state.registerTab == 'guests')
                  for (var i = 0; i < todayGuests.length; i++)
                    _RegRow(
                      isLast: i == todayGuests.length - 1,
                      leading: RCAvatar(
                          initials: todayGuests[i].initials,
                          color: todayGuests[i].type == 'Visiting Rotarian'
                              ? RCColors.amber
                              : const Color(0xFF3A6EA5),
                          size: 36),
                      title: todayGuests[i].name,
                      sub: todayGuests[i].sub,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: todayGuests[i].type == 'Visiting Rotarian'
                              ? RCColors.amberBg
                              : RCColors.chipBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(todayGuests[i].type,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color:
                                    todayGuests[i].type == 'Visiting Rotarian'
                                        ? RCColors.amber
                                        : RCColors.blue)),
                      ),
                    ),
                if (state.registerTab == 'clubs')
                  for (var i = 0; i < todayClubs.length; i++)
                    _RegRow(
                      isLast: i == todayClubs.length - 1,
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: RCColors.chipBg,
                            borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: Text(todayClubs[i].abbr,
                            style: const TextStyle(
                                color: RCColors.blue,
                                fontWeight: FontWeight.w800,
                                fontSize: 11)),
                      ),
                      title: todayClubs[i].name,
                      sub: todayClubs[i].sub,
                      trailing: todayClubs[i].isClubOfDay
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: RCColors.amberBg,
                                  borderRadius: BorderRadius.circular(999)),
                              child: const Text('CLUB OF THE DAY',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: RCColors.amber)),
                            )
                          : null,
                    ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
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
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

class _RegChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _RegChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: active ? RCColors.blue : RCColors.chipBg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : const Color(0xFF5A6A85),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String sub;
  final Widget? trailing;
  final bool isLast;
  const _RegRow({
    required this.leading,
    required this.title,
    required this.sub,
    this.trailing,
    required this.isLast,
  });

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
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: RCColors.textDark)),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 11, color: RCColors.textMuted)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _CertRow extends StatelessWidget {
  final Cert cert;
  final VoidCallback onTap;
  const _CertRow({required this.cert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return RCCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: RCColors.gold, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('★',
                style: TextStyle(color: Colors.white, fontSize: 17)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cert.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: RCColors.textDark)),
                Text(cert.sub,
                    style: const TextStyle(
                        fontSize: 11, color: RCColors.textMuted)),
              ],
            ),
          ),
          const Text('View',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: RCColors.blue)),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final HistoryEntry entry;
  final bool isLast;
  const _HistoryRow({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = AttendanceScreen._statusColor[entry.status]!;
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
                Text(entry.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: RCColors.textDark)),
                Text(entry.date,
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
            child: Text(entry.status,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}
