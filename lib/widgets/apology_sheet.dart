import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import 'pressable.dart';

/// "Can't attend? Send apology" bottom sheet — opened from the Home
/// screen's next-meeting card; the apology lands on the register for the
/// upcoming fellowship's date.
class ApologySheet extends StatelessWidget {
  final AppState state;
  const ApologySheet({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final sheet = state.apologySheet!;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: state.closeApology,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Send apology',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: RCColors.textDark)),
                      Material(
                        color: RCColors.chipBg,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: state.closeApology,
                          child: const SizedBox(
                            width: 30,
                            height: 30,
                            child: Center(
                                child: Text('✕',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF5A6A85)))),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('REASON (OPTIONAL)',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: Color(0xFF8B96A8))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: TextEditingController(text: sheet.reason)
                      ..selection =
                          TextSelection.collapsed(offset: sheet.reason.length),
                    onChanged: state.onApologyReason,
                    minLines: 2,
                    maxLines: 4,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: RCColors.textDark),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'e.g. Travelling upcountry for work',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: Color(0xFF8B96A8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFD4DBE8))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFD4DBE8))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: RCColors.blue)),
                    ),
                  ),
                  if (sheet.error != null) ...[
                    const SizedBox(height: 10),
                    Text(sheet.error!,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(fontSize: 12, color: RCColors.red)),
                  ],
                  const SizedBox(height: 14),
                  PressableScale(
                    child: ElevatedButton(
                      onPressed: sheet.saving ? null : state.sendApology,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RCColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(sheet.saving ? 'Sending…' : 'Send apology',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
