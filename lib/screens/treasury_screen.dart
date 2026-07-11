import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../api_client.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pressable.dart';

String _ugx(int amount) {
  final s = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return 'UGX $buf';
}

class TreasuryScreen extends StatelessWidget {
  final AppState state;
  const TreasuryScreen({super.key, required this.state});

  Future<void> _exportPdf(BuildContext context) async {
    final summary = state.treasurySummary;
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF17458F),
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(999)),
              ),
              child: pw.Text(state.displayClubName.toUpperCase(),
                  style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11)),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Financial Report',
                style: const pw.TextStyle(
                    fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Prepared by the Club Treasurer',
                style:
                    const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            pw.SizedBox(height: 20),
            if (summary != null) ...[
              pw.Text('DUES — ${summary.duesPeriodLabel}',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey600)),
              pw.SizedBox(height: 4),
              _pdfRow('Dues amount per member', _ugx(summary.duesAmount)),
              _pdfRow('Collected', _ugx(summary.duesCollected)),
              _pdfRow('Outstanding', _ugx(summary.duesOutstanding)),
              pw.SizedBox(height: 16),
              pw.Text('CASH POSITION',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey600)),
              pw.SizedBox(height: 4),
              _pdfRow('Total income', _ugx(summary.totalIncome)),
              _pdfRow('Total expenses', _ugx(summary.totalExpenses)),
              _pdfRow('Net position',
                  _ugx(summary.totalIncome - summary.totalExpenses)),
              pw.SizedBox(height: 16),
            ],
            pw.Text('TRANSACTIONS',
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            for (final t in state.transactions)
              _pdfRow(
                  t.label, (t.kind == 'income' ? '+ ' : '- ') + _ugx(t.amount)),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  static pw.Widget _pdfRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
            pw.Text(value,
                style: const pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final summary = state.treasurySummary;
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
                        const Text('Treasury',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        Text(state.displayClubName,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _TreasuryStat(
                              value: summary == null
                                  ? 'UGX 0'
                                  : _ugx(summary.duesCollected),
                              label: 'Dues collected',
                              valueColor: RCColors.gold)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _TreasuryStat(
                              value: summary == null
                                  ? 'UGX 0'
                                  : _ugx(summary.duesOutstanding),
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
                  if (state.treasuryLoading && summary == null)
                    const RCCard(
                      child: Text('Loading…',
                          style: TextStyle(
                              fontSize: 12.5, color: RCColors.textMuted)),
                    )
                  else ...[
                    RCSectionHeader(
                      title:
                          'Dues${summary == null ? '' : ' · ${summary.duesPeriodLabel}'}',
                      actionLabel: state.isTreasurer ? 'Settings' : null,
                      onAction:
                          state.isTreasurer ? state.openDuesSettings : null,
                    ),
                    const SizedBox(height: 10),
                    if (summary == null || summary.duesAmount == 0)
                      RCCard(
                        child: Text(
                          state.isTreasurer
                              ? 'No dues amount set yet. Tap Settings to configure it.'
                              : 'Dues have not been configured yet.',
                          style: const TextStyle(
                              fontSize: 12.5, color: RCColors.textMuted),
                        ),
                      )
                    else if (state.duesList.isEmpty)
                      const RCCard(
                        child: Text('No members yet.',
                            style: TextStyle(
                                fontSize: 12.5, color: RCColors.textMuted)),
                      )
                    else
                      RCCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < state.duesList.length; i++)
                              _DuesRow(
                                due: state.duesList[i],
                                color: RCColors.avatarColor(i),
                                canMarkPaid: state.isTreasurer,
                                isLast: i == state.duesList.length - 1,
                                onMarkPaid: () => state
                                    .markDuesPaid(state.duesList[i].memberId),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    RCSectionHeader(
                      title: 'Transactions',
                      actionLabel: state.isTreasurer ? '+ Record entry' : null,
                      onAction: state.isTreasurer ? state.openTxEntry : null,
                    ),
                    const SizedBox(height: 10),
                    if (state.transactions.isEmpty)
                      const RCCard(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No transactions recorded yet.',
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
                            for (var i = 0; i < state.transactions.length; i++)
                              _TxRow(
                                tx: state.transactions[i],
                                isLast: i == state.transactions.length - 1,
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    PressableScale(
                      child: ElevatedButton(
                        onPressed: () => _exportPdf(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RCColors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('⬇ Export financial report (PDF)',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13.5)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (state.txEntry != null) _TxEntrySheet(state: state),
        if (state.duesSettingEditor != null) _DuesSettingsSheet(state: state),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: valueColor)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _DuesRow extends StatelessWidget {
  final DuesMemberInfo due;
  final Color color;
  final bool canMarkPaid;
  final bool isLast;
  final VoidCallback onMarkPaid;
  const _DuesRow(
      {required this.due,
      required this.color,
      required this.canMarkPaid,
      required this.isLast,
      required this.onMarkPaid});

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
                Text(due.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: RCColors.textDark)),
                Text(due.role,
                    style: const TextStyle(
                        fontSize: 11, color: RCColors.textMuted)),
              ],
            ),
          ),
          if (due.paid)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: RCColors.green.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(999)),
              child: const Text('Paid',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: RCColors.green)),
            )
          else if (canMarkPaid)
            PressableScale(
              child: Material(
                color: RCColors.blue,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: onMarkPaid,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    child: Text('Mark paid',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: RCColors.amberBg,
                  borderRadius: BorderRadius.circular(999)),
              child: const Text('Pending',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: RCColors.amber)),
            ),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final TransactionInfo tx;
  final bool isLast;
  const _TxRow({required this.tx, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isIn = tx.kind == 'income';
    final color = isIn ? RCColors.green : RCColors.red;
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
                color: color.withValues(alpha: .1), shape: BoxShape.circle),
            child: Center(
              child: Text(isIn ? '↓' : '↑',
                  style: TextStyle(
                      color: color, fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: RCColors.textDark)),
                Text(_dateLabel(tx.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: RCColors.textMuted)),
              ],
            ),
          ),
          Text('${isIn ? '+' : '−'} ${_ugx(tx.amount)}',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

/// Shared bottom-sheet chrome (backdrop + white rounded panel) matching the
/// pattern used by the gallery upload sheet and the Today apology sheet.
Widget _sheetScaffold(
    {required BuildContext context,
    required VoidCallback onClose,
    required Widget child}) {
  return Positioned.fill(
    child: Stack(
      children: [
        GestureDetector(
          onTap: onClose,
          child: Container(color: const Color(0x8C0A1223)),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
                20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  child,
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _sheetHeader(String title, VoidCallback onClose) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: RCColors.textDark)),
        Material(
          color: RCColors.chipBg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onClose,
            child: const SizedBox(
              width: 30,
              height: 30,
              child: Center(
                  child: Text('✕',
                      style:
                          TextStyle(fontSize: 13, color: Color(0xFF5A6A85)))),
            ),
          ),
        ),
      ],
    );

Widget _fieldLabel(String text) => Text(text,
    style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: Color(0xFF8B96A8)));

InputDecoration _fieldDecoration(String hint) => InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8B96A8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD4DBE8))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD4DBE8))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: RCColors.blue)),
    );

class _TxEntrySheet extends StatelessWidget {
  final AppState state;
  const _TxEntrySheet({required this.state});

  @override
  Widget build(BuildContext context) {
    final entry = state.txEntry!;
    return _sheetScaffold(
      context: context,
      onClose: state.closeTxEntry,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetHeader('Record entry', state.closeTxEntry),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _KindChip(
                  label: 'Income',
                  active: entry.kind == 'income',
                  onTap: () => state.setTxKind('income'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KindChip(
                  label: 'Expense',
                  active: entry.kind == 'expense',
                  onTap: () => state.setTxKind('expense'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _fieldLabel('LABEL'),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: entry.label)
              ..selection = TextSelection.collapsed(offset: entry.label.length),
            onChanged: state.setTxLabel,
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: RCColors.textDark),
            decoration: _fieldDecoration('e.g. Venue hire'),
          ),
          const SizedBox(height: 12),
          _fieldLabel('AMOUNT (UGX)'),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: entry.amount)
              ..selection =
                  TextSelection.collapsed(offset: entry.amount.length),
            onChanged: state.setTxAmount,
            keyboardType: TextInputType.number,
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: RCColors.textDark),
            decoration: _fieldDecoration('e.g. 200000'),
          ),
          if (entry.error != null) ...[
            const SizedBox(height: 10),
            Text(entry.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: RCColors.red)),
          ],
          const SizedBox(height: 14),
          PressableScale(
            child: ElevatedButton(
              onPressed: entry.saving ? null : state.saveTxEntry,
              style: ElevatedButton.styleFrom(
                backgroundColor: RCColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(entry.saving ? 'Saving…' : 'Save entry',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DuesSettingsSheet extends StatelessWidget {
  final AppState state;
  const _DuesSettingsSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    final draft = state.duesSettingEditor!;
    return _sheetScaffold(
      context: context,
      onClose: state.closeDuesSettings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetHeader('Dues settings', state.closeDuesSettings),
          const SizedBox(height: 14),
          _fieldLabel('AMOUNT PER MEMBER (UGX)'),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: draft.amount)
              ..selection =
                  TextSelection.collapsed(offset: draft.amount.length),
            onChanged: state.setDuesAmount,
            keyboardType: TextInputType.number,
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: RCColors.textDark),
            decoration: _fieldDecoration('e.g. 150000'),
          ),
          const SizedBox(height: 12),
          _fieldLabel('PERIOD'),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final p in const ['monthly', 'quarterly', 'annual'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _KindChip(
                      label: p[0].toUpperCase() + p.substring(1),
                      active: draft.period == p,
                      onTap: () => state.setDuesPeriod(p),
                    ),
                  ),
                ),
            ],
          ),
          if (draft.error != null) ...[
            const SizedBox(height: 10),
            Text(draft.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: RCColors.red)),
          ],
          const SizedBox(height: 14),
          PressableScale(
            child: ElevatedButton(
              onPressed: draft.saving ? null : state.saveDuesSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: RCColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(draft.saving ? 'Saving…' : 'Save settings',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _KindChip(
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
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : const Color(0xFF5A6A85))),
        ),
      ),
    );
  }
}
