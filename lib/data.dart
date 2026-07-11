/// Shared model types and calendar helpers for the club app. All lists of
/// real data (members, events, projects, meetings, photos) are fetched from
/// the backend — nothing here seeds demo content.
library;

import 'dart:typed_data';

/// The club's standard positions, offered as a dropdown on Add Member
/// instead of free text — keeps role strings consistent with the ones
/// permission checks compare against (AppState.isPresident,
/// canGenerateEventQr, isTreasurer). "Rotary Foundation Chair" becomes
/// "Rotaract Foundation Chair" for a Rotaract club's clubType.
List<String> clubPositions(String clubType) => [
      'Member',
      'President',
      'President-Elect',
      'Immediate Past President',
      'Secretary',
      'Treasurer',
      'Sergeant-at-Arms',
      'Club Trainer',
      'Club Administration Chair',
      'Membership Chair',
      'Public Image Chair',
      clubType == 'rotaract'
          ? 'Rotaract Foundation Chair'
          : 'Rotary Foundation Chair',
      'Service Projects Chair',
      'Youth Service Chair',
      'Vocational Service Chair',
      'International Service Chair',
      'Board Director',
      'Committee Member',
      'Auditor',
      'Legal Advisor',
    ];

class Member {
  final String name;
  final String role;
  final bool isBoard;
  final String email;
  final String phone;
  final String dob;
  const Member(this.name, this.role, this.isBoard,
      {this.email = '', this.phone = '', this.dob = ''});

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
  // The saved photo's public URL (from the backend/R2), null until one is
  // uploaded. Distinct from [pendingPhotoBytes], which holds a freshly
  // picked-but-not-yet-saved photo on the editor's working copy.
  String? photo;
  Uint8List? pendingPhotoBytes;
  bool photoRemoved = false;
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
  // `meta` is the single "6:00 PM · Gardens Hall" string the backend
  // stores and every list/card display already reads. `time`/`venue` only
  // exist on the *editor's* working copy, so the Add Event sheet can offer
  // two separate fields — they're combined back into `meta` on save (see
  // AppState.setEditorTime/setEditorVenue and saveEvent).
  String meta;
  String time;
  String venue;
  // The saved banner's public URL (from the backend/R2), null until one is
  // uploaded. Distinct from [pendingPhotoBytes], which holds a freshly
  // picked-but-not-yet-saved photo on the editor's working copy.
  String? photo;
  Uint8List? pendingPhotoBytes;
  bool photoRemoved = false;
  EventItem(
      {required this.id,
      required this.dow,
      required this.name,
      required this.meta,
      this.time = '',
      this.venue = '',
      this.photo});

  String get num => dayNums[dow] ?? '';

  /// Splits `meta` into (time, venue) for the editor fields — mirrors the
  /// backend's parse_event_time/venue_from_meta so a re-opened event shows
  /// the same split it was announced/reminded with.
  factory EventItem.fromMeta(
      {required int id,
      required String dow,
      required String name,
      required String meta,
      String? photo}) {
    final parts = meta.split(RegExp(r'[-–—·,]'));
    final looksLikeTime = parts.isNotEmpty &&
        RegExp(r'^\d{1,2}(:\d{2})?\s*([AaPp][Mm])?$').hasMatch(parts[0].trim());
    final time = parts.length >= 2 && looksLikeTime ? parts[0].trim() : '';
    final venue = parts.length >= 2 && looksLikeTime
        ? parts.sublist(1).join(',').trim()
        : meta.trim();
    return EventItem(
        id: id,
        dow: dow,
        name: name,
        meta: meta,
        time: time,
        venue: venue,
        photo: photo);
  }

  EventItem copy() => EventItem(
      id: id,
      dow: dow,
      name: name,
      meta: meta,
      time: time,
      venue: venue,
      photo: photo);
}

const List<String> guestTypes = [
  'Prospective member',
  'Visiting Rotarian',
  'Friend & family',
  'Speaker / partner',
];
