import 'package:flutter/material.dart';
import '../theme.dart';

const List<String> _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDateYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String formatDateDayMonYear(DateTime d) =>
    '${d.day} ${_monthAbbr[d.month - 1]} ${d.year}';

String formatMonthYear(DateTime d) => '${_monthAbbr[d.month - 1]} ${d.year}';

String formatTimeOfDay(TimeOfDay t) {
  final hour12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final minute = t.minute.toString().padLeft(2, '0');
  final period = t.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

/// Best-effort parse of "14 Mar 1990" — falls back to null on anything else.
DateTime? tryParseDayMonYear(String s) {
  final parts = s.trim().split(RegExp(r'\s+'));
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = _monthAbbr.indexOf(parts[1]) + 1;
  final year = int.tryParse(parts[2]);
  if (day == null || month == 0 || year == null) return null;
  return DateTime(year, month, day);
}

/// Best-effort parse of "Sep 2026" — falls back to null on anything else.
DateTime? tryParseMonthYear(String s) {
  final parts = s.trim().split(RegExp(r'\s+'));
  if (parts.length != 2) return null;
  final month = _monthAbbr.indexOf(parts[0]) + 1;
  final year = int.tryParse(parts[1]);
  if (month == 0 || year == null) return null;
  return DateTime(year, month);
}

/// Best-effort parse of "6:00 PM" — falls back to null on anything else.
TimeOfDay? tryParseTimeOfDay(String s) {
  final match =
      RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
          .firstMatch(s.trim());
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final isPm = match.group(3)!.toUpperCase() == 'PM';
  if (hour == 12) hour = 0;
  return TimeOfDay(hour: isPm ? hour + 12 : hour, minute: minute);
}

Widget _rcPickerTheme(BuildContext context, Widget? child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme:
            Theme.of(context).colorScheme.copyWith(primary: RCColors.blue),
      ),
      child: child!,
    );

Future<DateTime?> pickRCDate(BuildContext context,
    {DateTime? initialDate, DateTime? firstDate, DateTime? lastDate}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initialDate ?? now,
    firstDate: firstDate ?? DateTime(now.year - 100),
    lastDate: lastDate ?? DateTime(now.year + 20),
    builder: _rcPickerTheme,
  );
}

Future<TimeOfDay?> pickRCTime(BuildContext context, {TimeOfDay? initialTime}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime ?? TimeOfDay.now(),
    builder: _rcPickerTheme,
  );
}
