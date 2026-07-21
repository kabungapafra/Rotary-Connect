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
  final int id;
  final String name;
  final String role;
  final bool isBoard;
  final String status; // active | suspended | terminated
  final String email;
  final String phone;
  final String dob;
  final String? terminatedAt;
  final bool needsBoardSetup;
  const Member(this.id, this.name, this.role, this.isBoard,
      {this.status = 'active',
      this.email = '',
      this.phone = '',
      this.dob = '',
      this.terminatedAt,
      this.needsBoardSetup = false});

  /// "phone · email", omitting whichever is empty — shown under the role.
  String get contact => [phone, email].where((s) => s.isNotEmpty).join(' · ');
}

/// A progress log entry on a project — what was done and the completion %
/// as of that update. Read-only history; posted via ProjectUpdateDraft.
class ProjectUpdateEntry {
  final int id;
  final int pct;
  final String note;
  final String authorName;
  final DateTime createdAt;
  const ProjectUpdateEntry(
      this.id, this.pct, this.note, this.authorName, this.createdAt);
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
  // Report-only fields — one of Rotary's 7 official areas of focus (see
  // rotaryAreasOfFocus in api_client.dart), or null ("Uncategorized" in
  // reports); separate from the free-text [area] above.
  String? areaOfFocus;
  int beneficiariesReached;
  // Progress history, newest first — posted via the lightweight "Add
  // update" flow rather than the full project editor.
  List<ProjectUpdateEntry> updates;
  Project({
    required this.id,
    required this.name,
    required this.icon,
    required this.area,
    required this.pct,
    required this.desc,
    required this.deadline,
    this.photo,
    this.areaOfFocus,
    this.beneficiariesReached = 0,
    this.updates = const [],
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
      photo: photo,
      areaOfFocus: areaOfFocus,
      beneficiariesReached: beneficiariesReached,
      updates: updates);
}

/// Working copy of the "Add progress update" bottom sheet fields.
class ProjectUpdateDraft {
  final int projectId;
  int pct;
  String note = '';
  bool saving = false;
  String? error;
  ProjectUpdateDraft({required this.projectId, required this.pct});
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

/// The next date (today or later) that falls on [dow] (e.g. "WED") —
/// today itself if today already matches. Used by the Month calendar to
/// mark only the single nearest occurrence of a recurring weekly event,
/// not every date that shares its weekday.
DateTime nextOccurrenceOfDow(String dow, DateTime from) {
  final targetWeekday = weekOrder.indexOf(dow) + 1; // 1=Mon..7=Sun
  var d = DateTime(from.year, from.month, from.day);
  while (d.weekday != targetWeekday) {
    d = d.add(const Duration(days: 1));
  }
  return d;
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
  // `meta` is the single "6:00 PM to 8:00 PM · Gardens Hall" string the
  // backend stores and every list/card display already reads.
  // `time`/`endTime`/`venue` only exist on the *editor's* working copy, so
  // the Add Event sheet can offer separate fields — they're combined back
  // into `meta` on save (see setEditorTime/setEditorEndTime/setEditorVenue
  // and saveEvent). "to" joins the times on purpose: the dash is already
  // the legacy time/venue separator ("6:00 PM - Hall").
  String meta;
  String time;
  String endTime;
  String venue;
  // False once today's occurrence is within 15 minutes of its end time —
  // the Register/QR button hides (mirrors the backend's gate).
  bool registrationOpen;
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
      this.endTime = '',
      this.venue = '',
      this.registrationOpen = true,
      this.photo});

  String get num => dayNums[dow] ?? '';

  /// Splits `meta` into (time, endTime, venue) for the editor fields —
  /// mirrors the backend's parse_event_time/parse_event_end_time/
  /// venue_from_meta so a re-opened event shows the same split it was
  /// announced/reminded with.
  factory EventItem.fromMeta(
      {required int id,
      required String dow,
      required String name,
      required String meta,
      bool registrationOpen = true,
      String? photo}) {
    final parts = meta.split(RegExp(r'[-–—·,]'));
    final head = parts.isNotEmpty ? parts[0].trim() : '';
    final range = head.split(RegExp(r'\s+to\s+', caseSensitive: false));
    final timeRe = RegExp(r'^\d{1,2}(:\d{2})?\s*([AaPp][Mm])?$');
    final looksLikeTime = timeRe.hasMatch(range[0].trim());
    final hasEnd = looksLikeTime &&
        range.length >= 2 &&
        timeRe.hasMatch(range[1].trim());
    final time = parts.length >= 2 && looksLikeTime ? range[0].trim() : '';
    final endTime =
        parts.length >= 2 && hasEnd ? range[1].trim() : '';
    final venue = parts.length >= 2 && looksLikeTime
        ? parts.sublist(1).join(',').trim()
        : meta.trim();
    return EventItem(
        id: id,
        dow: dow,
        name: name,
        meta: meta,
        time: time,
        endTime: endTime,
        venue: venue,
        registrationOpen: registrationOpen,
        photo: photo);
  }

  EventItem copy() => EventItem(
      id: id,
      dow: dow,
      name: name,
      meta: meta,
      time: time,
      endTime: endTime,
      venue: venue,
      registrationOpen: registrationOpen,
      photo: photo);
}

const List<String> guestTypes = [
  'Prospective member',
  'Visiting Rotarian',
  'Friend & family',
  'Speaker / partner',
];
