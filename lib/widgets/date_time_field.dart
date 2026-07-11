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

/// Best-effort parse of "14 Mar 1990" — falls back to trying a couple of
/// other formats a member's DOB might have been typed in before this field
/// became a picker (e.g. "14/03/1990", "1990-03-14"), then null.
DateTime? tryParseDayMonYear(String s) {
  final trimmed = s.trim();
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length == 3) {
    final day = int.tryParse(parts[0]);
    final month = _monthAbbr.indexOf(parts[1]) + 1;
    final year = int.tryParse(parts[2]);
    if (day != null && month != 0 && year != null) {
      return DateTime(year, month, day);
    }
  }
  final slash = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(trimmed);
  if (slash != null) {
    return DateTime(int.parse(slash.group(3)!), int.parse(slash.group(2)!),
        int.parse(slash.group(1)!));
  }
  return DateTime.tryParse(trimmed); // e.g. "1990-03-14"
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

/// Best-effort parse of "6:00 PM" — also accepts a plain 24-hour "18:00"
/// (what an event's TIME & VENUE could already contain; the backend's own
/// parse_event_time has always accepted this form), then null.
TimeOfDay? tryParseTimeOfDay(String s) {
  final trimmed = s.trim();
  final ampm = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
      .firstMatch(trimmed);
  if (ampm != null) {
    var hour = int.parse(ampm.group(1)!);
    final minute = int.parse(ampm.group(2)!);
    final isPm = ampm.group(3)!.toUpperCase() == 'PM';
    if (hour == 12) hour = 0;
    return TimeOfDay(hour: isPm ? hour + 12 : hour, minute: minute);
  }
  final h24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
  if (h24 != null) {
    final hour = int.parse(h24.group(1)!);
    final minute = int.parse(h24.group(2)!);
    if (hour <= 23 && minute <= 59) return TimeOfDay(hour: hour, minute: minute);
  }
  return null;
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
  final first = firstDate ?? DateTime(now.year - 100);
  final last = lastDate ?? DateTime(now.year + 20);
  // showDatePicker asserts initialDate falls within [first, last] — a
  // parsed-but-implausible stored value (e.g. a mistyped future DOB) must
  // not crash the picker that's meant to let someone fix it.
  var initial = initialDate ?? now;
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
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
