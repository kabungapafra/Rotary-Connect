import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_client.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/date_time_field.dart';
import '../widgets/pressable.dart';

Future<void> _exportReportPdf(String clubName, ReportInfo report) async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF17458F),
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(999)),
            ),
            child: pw.Text(clubName.toUpperCase(),
                style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11)),
          ),
          pw.SizedBox(height: 16),
          pw.Text(report.title,
              style: const pw.TextStyle(
                  fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(report.subtitle,
              style:
                  const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 20),
          for (final section in report.sections) ...[
            pw.Text(section.section.toUpperCase(),
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            for (final row in section.rows)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(row.label, style: const pw.TextStyle(fontSize: 12)),
                    pw.Text(row.value,
                        style: const pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            pw.SizedBox(height: 16),
          ],
        ],
      ),
    ),
  );
  await Printing.layoutPdf(onLayout: (format) async => doc.save());
}

class SecretaryScreen extends StatelessWidget {
  final AppState state;
  const SecretaryScreen({super.key, required this.state});

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
                        const Text('Secretary workspace',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800)),
                        Text(state.displayClubName,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
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
                        for (final t in const [
                          ['minutes', 'Minutes'],
                          ['monthly', 'Monthly'],
                          ['annual', 'Annual'],
                          ['docs', 'Docs'],
                        ])
                          Expanded(
                            child: _SecTab(
                              label: t[1],
                              active: state.secretaryTab == t[0],
                              onTap: () => state.pickSecretaryTab(t[0]),
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
              child: state.secretaryLoading && !state.secretaryLoaded
                  ? const RCCard(
                      child: Text('Loading…',
                          style: TextStyle(
                              fontSize: 12.5, color: RCColors.textMuted)),
                    )
                  : switch (state.secretaryTab) {
                      'monthly' => _ReportTab(
                          state: state,
                          report: state.monthlyReport,
                        ),
                      'annual' => _ReportTab(
                          state: state,
                          report: state.annualReport,
                        ),
                      'docs' => _DocumentsTab(state: state),
                      _ => _MinutesTab(state: state),
                    },
            ),
          ],
        ),
        if (state.minuteEditor != null) _MinuteEditorSheet(state: state),
        if (state.minuteOpen != null)
          _MinuteBodySheet(
              key: ValueKey(state.minuteOpen!.id), state: state),
      ],
    );
  }
}

class _SecTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SecTab(
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
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active ? RCColors.blue : Colors.white)),
        ),
      ),
    );
  }
}

class _MinutesTab extends StatelessWidget {
  final AppState state;
  const _MinutesTab({required this.state});

  Future<void> _pickAudioAndUpload(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final file = result?.files.firstOrNull;
    final path = file?.path;
    if (file == null || path == null || !context.mounted) return;
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(
            text: file.name.replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), ''));
        return AlertDialog(
          title: const Text('Draft minutes from audio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Minutes title'),
              ),
              const SizedBox(height: 10),
              const Text(
                'The recording will be transcribed and drafted into '
                'minutes for today\'s meeting. This takes a few minutes.',
                style: TextStyle(fontSize: 12, color: RCColors.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Upload')),
          ],
        );
      },
    );
    if (title == null || title.isEmpty) return;
    await state.uploadMinuteAudio(
        title, formatDateYmd(DateTime.now()), path);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RCSectionHeader(
          title: 'Meeting minutes',
          actionLabel: '+ Add minute',
          onAction: state.openMinuteEditor,
        ),
        const SizedBox(height: 10),
        PressableScale(
          child: OutlinedButton.icon(
            onPressed: state.minuteAudioUploading
                ? null
                : () => _pickAudioAndUpload(context),
            icon: state.minuteAudioUploading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.mic_none, size: 18),
            style: OutlinedButton.styleFrom(
              foregroundColor: RCColors.blue,
              side: BorderSide(color: RCColors.blue.withValues(alpha: .4)),
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            label: Text(
                state.minuteAudioUploading
                    ? 'Uploading recording…'
                    : 'Draft minutes from a recording',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 12.5)),
          ),
        ),
        if (state.minuteAudioError != null) ...[
          const SizedBox(height: 8),
          Text(state.minuteAudioError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: RCColors.red)),
        ],
        const SizedBox(height: 10),
        if (state.minutes.isEmpty)
          const RCCard(
            padding: EdgeInsets.all(24),
            child: Text(
              'No minutes recorded yet.',
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
                for (var i = 0; i < state.minutes.length; i++)
                  _MinuteRow(
                    minute: state.minutes[i],
                    isLast: i == state.minutes.length - 1,
                    onToggle: () => state.toggleMinuteStatus(state.minutes[i]),
                    onOpen: () => state.openMinuteBody(state.minutes[i]),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MinuteRow extends StatelessWidget {
  final MinuteInfo minute;
  final bool isLast;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  const _MinuteRow(
      {required this.minute,
      required this.isLast,
      required this.onToggle,
      required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (minute.status) {
      'approved' => ('Approved', RCColors.green, RCColors.green.withValues(alpha: .1)),
      'processing' => ('Transcribing…', RCColors.blue, RCColors.blue.withValues(alpha: .1)),
      'failed' => ('Failed', RCColors.red, RCColors.red.withValues(alpha: .1)),
      _ => ('Draft', RCColors.amber, RCColors.amberBg),
    };
    final toggleable = minute.status == 'approved' || minute.status == 'draft';
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: RCColors.divider)),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(minute.title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: RCColors.textDark)),
                    Text(minute.meetingDate,
                        style: const TextStyle(
                            fontSize: 11, color: RCColors.textMuted)),
                  ],
                ),
              ),
              PressableScale(
                child: Material(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: toggleable ? onToggle : onOpen,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinuteBodySheet extends StatefulWidget {
  final AppState state;
  const _MinuteBodySheet({super.key, required this.state});

  @override
  State<_MinuteBodySheet> createState() => _MinuteBodySheetState();
}

class _MinuteBodySheetState extends State<_MinuteBodySheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.state.minuteOpen?.body ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final minute = state.minuteOpen!;
    final processing = minute.status == 'processing';
    return _sheetScaffold(
      context: context,
      onClose: state.closeMinuteBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetHeader(minute.title, state.closeMinuteBody),
          const SizedBox(height: 4),
          Text(minute.meetingDate,
              style: const TextStyle(fontSize: 11.5, color: RCColors.textMuted)),
          const SizedBox(height: 12),
          if (processing)
            const RCCard(
              padding: EdgeInsets.all(24),
              child: Text(
                'Transcribing the recording and drafting the minutes…\n'
                'This usually takes a few minutes. Check back shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: RCColors.textMuted),
              ),
            )
          else ...[
            if (minute.status == 'failed') ...[
              const Text(
                'Transcription failed — the recording may be too quiet or '
                'in an unsupported format. You can write the minutes below '
                'or try uploading again.',
                style: TextStyle(fontSize: 12, color: RCColors.red),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _controller,
              maxLines: 14,
              minLines: 8,
              style: const TextStyle(fontSize: 13, color: RCColors.textDark),
              decoration: _fieldDecoration(
                  'Write or paste the meeting minutes here…'),
            ),
            const SizedBox(height: 12),
            PressableScale(
              child: ElevatedButton(
                onPressed: state.minuteBodySaving
                    ? null
                    : () => state.saveMinuteBody(_controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RCColors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                    state.minuteBodySaving ? 'Saving…' : 'Save minutes',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13.5)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  final AppState state;
  const _DocumentsTab({required this.state});

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    final title = file.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    await state.uploadClubDocument(title, bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RCSectionHeader(
          title: 'Club documents',
          actionLabel: state.documentUploading ? 'Uploading…' : '+ Upload PDF',
          onAction: state.documentUploading ? null : _pickAndUpload,
        ),
        const SizedBox(height: 10),
        if (state.documentError != null) ...[
          Text(state.documentError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: RCColors.red)),
          const SizedBox(height: 10),
        ],
        if (state.clubDocuments.isEmpty)
          const RCCard(
            padding: EdgeInsets.all(24),
            child: Text(
              'No documents uploaded yet.\nKeep the club constitution, bylaws and policies here as PDFs.',
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
                for (var i = 0; i < state.clubDocuments.length; i++)
                  _DocumentRow(
                    doc: state.clubDocuments[i],
                    isLast: i == state.clubDocuments.length - 1,
                    onDelete: () =>
                        state.deleteClubDocument(state.clubDocuments[i].id),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DocumentRow extends StatelessWidget {
  final ClubDocumentInfo doc;
  final bool isLast;
  final VoidCallback onDelete;
  const _DocumentRow(
      {required this.doc, required this.isLast, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: RCColors.divider)),
      ),
      child: InkWell(
        onTap: () => launchUrl(Uri.parse(doc.url),
            mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined,
                  size: 20, color: RCColors.red),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: RCColors.textDark)),
                    Text(
                        doc.createdAt.length >= 10
                            ? doc.createdAt.substring(0, 10)
                            : doc.createdAt,
                        style: const TextStyle(
                            fontSize: 11, color: RCColors.textMuted)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: RCColors.textMuted),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete document?'),
                      content: Text('"${doc.title}" will be removed for good.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete',
                                style: TextStyle(color: RCColors.red))),
                      ],
                    ),
                  );
                  if (confirmed == true) onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportTab extends StatelessWidget {
  final AppState state;
  final ReportInfo? report;
  const _ReportTab({required this.state, required this.report});

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return const RCCard(
        child: Text('Report unavailable.',
            style: TextStyle(fontSize: 12.5, color: RCColors.textMuted)),
      );
    }
    final r = report!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(r.title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: RCColors.textDark)),
        const SizedBox(height: 3),
        Text(r.subtitle,
            style: const TextStyle(fontSize: 11.5, color: RCColors.textMuted)),
        const SizedBox(height: 14),
        for (final section in r.sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: RCCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section.section.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5,
                          color: RCColors.textMuted)),
                  const SizedBox(height: 8),
                  for (final row in section.rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(row.label,
                              style: const TextStyle(
                                  fontSize: 12.5, color: RCColors.textDark)),
                          Text(row.value,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: RCColors.blue)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        PressableScale(
          child: ElevatedButton(
            onPressed: () => _exportReportPdf(state.displayClubName, r),
            style: ElevatedButton.styleFrom(
              backgroundColor: RCColors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('⬇ Export as PDF',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          ),
        ),
      ],
    );
  }
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

InputDecoration _fieldDecoration(String hint, {IconData? icon}) =>
    InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8B96A8)),
      suffixIcon:
          icon == null ? null : Icon(icon, size: 18, color: RCColors.blue),
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
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * .86),
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

class _MinuteEditorSheet extends StatelessWidget {
  final AppState state;
  const _MinuteEditorSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    final draft = state.minuteEditor!;
    return _sheetScaffold(
      context: context,
      onClose: state.closeMinuteEditor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetHeader('Add minute', state.closeMinuteEditor),
          const SizedBox(height: 14),
          _fieldLabel('TITLE'),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: draft.title)
              ..selection = TextSelection.collapsed(offset: draft.title.length),
            onChanged: state.setMinuteTitle,
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: RCColors.textDark),
            decoration: _fieldDecoration('e.g. Weekly Fellowship Meeting'),
          ),
          const SizedBox(height: 12),
          _fieldLabel('MEETING DATE'),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: draft.meetingDate)
              ..selection =
                  TextSelection.collapsed(offset: draft.meetingDate.length),
            onChanged: state.setMinuteDate,
            readOnly: true,
            onTap: () async {
              final picked = await pickRCDate(
                context,
                initialDate:
                    DateTime.tryParse(draft.meetingDate) ?? DateTime.now(),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                state.setMinuteDate(formatDateYmd(picked));
              }
            },
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: RCColors.textDark),
            decoration: _fieldDecoration('e.g. 2026-07-08',
                icon: Icons.calendar_today_outlined),
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
              onPressed: draft.saving ? null : state.saveMinuteEditor,
              style: ElevatedButton.styleFrom(
                backgroundColor: RCColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(draft.saving ? 'Saving…' : 'Save minute',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13.5)),
            ),
          ),
        ],
      ),
    );
  }
}
