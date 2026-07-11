import 'package:flutter/material.dart';
import '../api_client.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/apology_sheet.dart';
import '../widgets/common.dart';

class TodayScreen extends StatelessWidget {
  final AppState state;
  const TodayScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
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
