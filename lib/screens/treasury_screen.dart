import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class TreasuryScreen extends StatelessWidget {
  final AppState state;
  const TreasuryScreen({super.key, required this.state});

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Treasury',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    Text(state.clubName,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(
                      child: _TreasuryStat(
                          value: 'UGX 0',
                          label: 'Dues collected',
                          valueColor: RCColors.gold)),
                  SizedBox(width: 10),
                  Expanded(
                      child: _TreasuryStat(
                          value: 'UGX 0',
                          label: 'Outstanding',
                          valueColor: Colors.white)),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: RCCard(
            padding: EdgeInsets.all(28),
            child: Text(
              'No dues or transactions recorded yet.\n'
              'Treasury records will appear here once collections begin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: RCColors.textMuted,
                  height: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _TreasuryStat extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  const _TreasuryStat(
      {required this.value, required this.label, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        border: Border.all(color: Colors.white.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: valueColor)),
          const Text('', style: TextStyle(fontSize: 0)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
