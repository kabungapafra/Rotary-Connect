/// Shared model types and calendar helpers for the club app. All lists of
/// real data (members, events, projects, meetings, photos) are fetched from
/// the backend — nothing here seeds demo content.
library;

import 'dart:typed_data';

class Member {
  final String name;
  final String role;
  final bool isBoard;
  final String email;
  final String phone;
  final String dob;
  const Member(this.name, this.role, this.isBoard,
      {this.email = '', this.phone = '', this.dob = ''});

  String get initials => name
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0])
      .join()
      .toUpperCase();

  /// "phone · email", omitting whichever is empty — shown under the role.
  String get contact => [phone, email].where((s) => s.isNotEmpty).join(' · ');
}

class Project {
  final int id;
  String name;
  String icon;
  String area;
  int pct;
  String desc;
  String deadline;
  Uint8List? photo;
  Project({
    required this.id,
    required this.name,
    required this.icon,
    required this.area,
    required this.pct,
    required this.desc,
    required this.deadline,
    this.photo,
  });

  String get pctLabel => '$pct%';
  bool get isDone => pct >= 100;

  Project copy() => Project(
      id: id,
      name: name,
      icon: icon,
      area: area,
      pct: pct,
      desc: desc,
      deadline: deadline,
      photo: photo);
}

// ── calendar helpers (real current week, not a fixed demo week) ─────────

const List<String> weekOrder = [
  'MON',
  'TUE',
  'WED',
  'THU',
  'FRI',
  'SAT',
  'SUN'
];

const Map<String, String> dayNames = {
  'MON': 'Monday',
  'TUE': 'Tuesday',
  'WED': 'Wednesday',
  'THU': 'Thursday',
  'FRI': 'Friday',
  'SAT': 'Saturday',
  'SUN': 'Sunday',
};

DateTime _mondayOfThisWeek() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
}

/// Day-of-month for each weekday of the *current* week.
Map<String, String> get dayNums {
  final monday = _mondayOfThisWeek();
  return {
    for (var i = 0; i < 7; i++)
      weekOrder[i]: '${monday.add(Duration(days: i)).day}',
  };
}

class WeekDay {
  final String dow;
  final String num;
  const WeekDay(this.dow, this.num);
  bool get isToday => dow == weekOrder[DateTime.now().weekday - 1];
}

/// The current week's strip for the Events calendar.
List<WeekDay> get weekDays {
  final nums = dayNums;
  return [for (final d in weekOrder) WeekDay(d, nums[d]!)];
}

/// Editable event — kept in app state so it can be added, edited and
/// deleted from the Events editor sheet (persisted via the backend).
class EventItem {
  final int id;
  String dow;
  String name;
  String meta;
  Uint8List? photo;
  EventItem(
      {required this.id,
      required this.dow,
      required this.name,
      required this.meta,
      this.photo});

  String get num => dayNums[dow] ?? '';

  EventItem copy() =>
      EventItem(id: id, dow: dow, name: name, meta: meta, photo: photo);
}

const List<String> guestTypes = [
  'Prospective member',
  'Visiting Rotarian',
  'Friend & family',
  'Speaker / partner',
];
