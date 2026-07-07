import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data.dart';
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
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Treasury',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    Text('Rtn. Peter Okello · Club Treasurer',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(
                      child: _TreasuryStat(
                          value: 'UGX 4.2M',
                          label: 'Dues collected · Q3',
                          valueColor: RCColors.gold)),
                  SizedBox(width: 10),
                  Expanded(
                      child: _TreasuryStat(
                          value: 'UGX 1.8M',
                          label: 'Outstanding',
                          valueColor: Colors.white)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RCSectionHeader(title: 'Member dues · July 2026'),
              const SizedBox(height: 10),
              RCCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < duesList.length; i++)
                      _DuesRow(
                        entry: duesList[i],
                        index: i,
                        color: RCColors.avatarColor(i),
                        state: state,
                        isLast: i == duesList.length - 1,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const RCSectionHeader(title: 'Recent transactions'),
              const SizedBox(height: 10),
              RCCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < transactions.length; i++)
                      _TxRow(
                          tx: transactions[i],
                          isLast: i == transactions.length - 1),
                  ],
                ),
              ),
            ],
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

class _DuesRow extends StatelessWidget {
  final DuesEntry entry;
  final int index;
  final Color color;
  final AppState state;
  final bool isLast;
  const _DuesRow({
    required this.entry,
    required this.index,
    required this.color,
    required this.state,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final paid = state.isPaid(index, entry.paidInitially);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: RCColors.divider)),
      ),
      child: Row(
        children: [
          RCAvatar(initials: entry.initials, color: color, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: RCColors.textDark)),
                Text(entry.detail,
                    style: const TextStyle(
                        fontSize: 11, color: RCColors.textMuted)),
              ],
            ),
          ),
          if (paid)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0x1F1F9D55),
                  borderRadius: BorderRadius.circular(999)),
              child: const Text('Paid',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: RCColors.green)),
            )
          else
            ElevatedButton(
              onPressed: () => state.markPaid(index),
              style: ElevatedButton.styleFrom(
                backgroundColor: RCColors.gold,
                foregroundColor: RCColors.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Record payment',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final TransactionEntry tx;
  final bool isLast;
  const _TxRow({required this.tx, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = tx.isIn ? RCColors.green : RCColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: RCColors.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: color.withValues(alpha: .09), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(tx.sign,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: RCColors.textDark)),
                Text(tx.date,
                    style: const TextStyle(
                        fontSize: 11, color: RCColors.textMuted)),
              ],
            ),
          ),
          Text(tx.amount,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
