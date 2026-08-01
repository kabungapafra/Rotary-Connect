import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import 'date_time_field.dart';
import 'pressable.dart';
import 'synced_text_field.dart';

/// "Visited another club recently?" bottom sheet — opened from the scan
/// screen's post-check-in success view, over the dark scan background it
/// was triggered from. Deliberately no district field: the Secretary only
/// needs the club name to look the visit up.
class VisitReportSheet extends StatelessWidget {
  final AppState state;
  const VisitReportSheet({super.key, required this.state});

  static const _types = [
    'Club meeting',
    'Online meeting',
    'Service project',
    'District event',
  ];

  @override
  Widget build(BuildContext context) {
    final sheet = state.visitReportSheet!;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: state.closeVisitReport,
            child: Container(color: const Color(0x8C0A1223)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * .86),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: RCColors.scanBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: RCColors.scanBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Report a club visit',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        Material(
                          color: RCColors.scanCard,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: state.closeVisitReport,
                            child: const SizedBox(
                              width: 30,
                              height: 30,
                              child: Center(
                                  child: Text('✕',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: RCColors.scanMuted))),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Tell the Secretary about the meeting you attended '
                        'away from ${state.displayClubName} — it counts '
                        'towards your attendance.',
                        style: const TextStyle(
                            fontSize: 12, color: RCColors.scanMuted, height: 1.4)),
                    const SizedBox(height: 16),
                    const Text('CLUB VISITED *',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: RCColors.scanMuted)),
                    const SizedBox(height: 6),
                    SyncedTextField(
                      value: sheet.clubVisited,
                      builder: (context, controller) => TextField(
                        controller: controller,
                        onChanged: state.setVisitReportClub,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                        decoration: _fieldDecoration(
                            hint: 'e.g. Rotary Club of Kampala North'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('DATE OF MEETING',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: RCColors.scanMuted)),
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        final result = await pickRCDate(context,
                            initialDate: sheet.meetingDate,
                            lastDate: DateTime.now());
                        if (result != null) state.setVisitReportDate(result);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: RCColors.scanBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                  formatDateDayMonYear(sheet.meetingDate),
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            ),
                            const Icon(Icons.calendar_today,
                                size: 16, color: RCColors.scanMuted),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('TYPE',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: RCColors.scanMuted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in _types)
                          _VisitTypeChip(
                            label: t,
                            active: sheet.meetingType == t,
                            onTap: () => state.setVisitReportType(t),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('NOTES FOR THE SECRETARY',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: RCColors.scanMuted)),
                    const SizedBox(height: 6),
                    SyncedTextField(
                      value: sheet.notes,
                      builder: (context, controller) => TextField(
                        controller: controller,
                        onChanged: state.setVisitReportNotes,
                        minLines: 2,
                        maxLines: 4,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                        decoration: _fieldDecoration(
                            hint: 'Optional — speaker, host, what you learned…'),
                      ),
                    ),
                    if (sheet.error != null) ...[
                      const SizedBox(height: 10),
                      Text(sheet.error!,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(fontSize: 12, color: Color(0xFFFF9D9D))),
                    ],
                    const SizedBox(height: 14),
                    PressableScale(
                      child: ElevatedButton(
                        onPressed:
                            sheet.saving ? null : state.submitVisitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RCColors.scanAccent,
                          foregroundColor: RCColors.blue,
                          padding: const EdgeInsets.all(13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                            sheet.saving ? 'Submitting…' : 'Submit visit report',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13.5)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: state.closeVisitReport,
                        child: const Text('Not now',
                            style: TextStyle(
                                color: RCColors.scanMuted, fontSize: 12.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hint}) => InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: RCColors.scanMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: RCColors.scanBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: RCColors.scanBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: RCColors.scanAccent)),
      );
}

class _VisitTypeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _VisitTypeChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? RCColors.scanAccent : RCColors.scanCard,
          foregroundColor: active ? RCColors.blue : RCColors.scanMuted,
          side: BorderSide(
              color: active ? RCColors.scanAccent : RCColors.scanBorder),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          shape: const StadiumBorder(),
          elevation: 0,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }
}
