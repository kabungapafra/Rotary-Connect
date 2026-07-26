import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'data.dart';
import 'date_labels.dart';
import 'widgets/date_time_field.dart' show formatDateYmd;

/// The club's events — calendar, the event editor sheet, registration QR
/// generation, and the Home screen's "Next meeting" card — split out of
/// AppState. Depends only on [ApiClient] and a token provider, not on
/// AppState.
class EventsController extends ChangeNotifier {
  final ApiClient _api;
  final String? Function() _getToken;
  EventsController(this._api, this._getToken);

  final List<EventItem> events = [];
  bool loaded = false;
  bool loading = false;
  String? selectedDay;
  EventItem? editor; // a working copy while the editor sheet is open
  bool editorIsNew = false;
  String calendarView = 'week'; // week | month
  int calendarYear = DateTime.now().year;
  int calendarMonth = DateTime.now().month; // 1-12, shown in the Month grid
  // The exact date tapped in the Month grid — kept separate from
  // [selectedDay] (a day-of-week name) so tapping one day only highlights
  // that single cell, not every occurrence of that weekday in the month.
  DateTime? selectedMonthDate;
  EventItem? qrEvent;
  // Backend-generated registration link + QR image for the open event.
  EventRegistration? registration;
  bool registrationLoading = false;
  String? registrationError;
  bool qrCopied = false;
  Timer? _qrCopyTimer;

  // Home screen's "Next meeting" card — the real soonest upcoming
  // fellowship (date/time/venue), computed by the backend from the club's
  // events. Null once loaded means the club has none scheduled yet.
  NextMeeting? nextMeeting;
  bool nextMeetingLoaded = false;
  bool nextMeetingLoading = false;

  void _update(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  /// Drops every cached value so a member of a different club signing in
  /// on the same device never sees stale events.
  void reset() {
    events.clear();
    loaded = false;
    nextMeeting = null;
    nextMeetingLoaded = false;
  }

  Future<void> load() async {
    final token = _getToken();
    if (token == null) return;
    _update(() => loading = true);
    try {
      final list = await _api.fetchEvents(token);
      _update(() {
        events
          ..clear()
          ..addAll([
            for (final e in list)
              EventItem.fromMeta(
                  id: e.id,
                  dow: e.dow,
                  date: e.date,
                  name: e.name,
                  meta: e.meta,
                  registrationOpen: e.registrationOpen,
                  editable: e.editable,
                  photo: e.image),
          ]);
        loaded = true;
        loading = false;
      });
    } on ApiException {
      _update(() => loading = false);
    }
  }

  Future<void> loadNextMeeting() async {
    final token = _getToken();
    if (token == null) return;
    _update(() => nextMeetingLoading = true);
    try {
      final nm = await _api.fetchNextMeeting(token);
      _update(() {
        nextMeeting = nm;
        nextMeetingLoaded = true;
        nextMeetingLoading = false;
      });
    } on ApiException {
      _update(() => nextMeetingLoading = false);
    }
  }

  /// "ONGOING" while the backend says the meeting's check-in window is
  /// still open, else "TODAY · 8 JUL" / "TOMORROW · 9 JUL" / "WED · 15 JUL"
  /// for the Next meeting card, computed from the real date the backend
  /// returned — never assumes the next fellowship is today.
  String get nextMeetingBadge {
    final nm = nextMeeting;
    if (nm == null) return '';
    if (nm.ongoing) return 'ONGOING';
    final date = DateTime.parse(nm.dateIso);
    final today = DateTime.now();
    final diffDays = DateTime(date.year, date.month, date.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    final monthShort = monthNames[date.month - 1].substring(0, 3).toUpperCase();
    if (diffDays == 0) return 'TODAY · ${date.day} $monthShort';
    if (diffDays == 1) return 'TOMORROW · ${date.day} $monthShort';
    final weekdayShort =
        weekdayNames[date.weekday - 1].substring(0, 3).toUpperCase();
    return '$weekdayShort · ${date.day} $monthShort';
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// A recurring event occurs on [date] whenever its dow matches; a
  /// one-time event only on its own exact date — never on some other
  /// date that merely shares its weekday.
  bool _occursOn(EventItem e, DateTime date) {
    if (e.date != null) return _isSameDate(e.date!, date);
    return e.dow == weekOrder[date.weekday - 1];
  }

  List<EventItem> get visibleEvents {
    List<EventItem> list;
    final monthDate = selectedMonthDate;
    if (monthDate != null) {
      // A specific date was tapped in the Month grid — only what actually
      // occurs on that exact date, not every event sharing its weekday.
      list = events.where((e) => _occursOn(e, monthDate)).toList();
    } else if (selectedDay != null) {
      // A weekday was tapped in the Week strip — resolve it to its real
      // date this week before checking occurrence.
      final idx = weekOrder.indexOf(selectedDay!);
      final date = mondayOfThisWeek().add(Duration(days: idx < 0 ? 0 : idx));
      list = events.where((e) => _occursOn(e, date)).toList();
    } else if (calendarView == 'week') {
      // Nothing selected in Week view: everything happening this week —
      // every recurring event (they all land somewhere in the week) plus
      // any one-time event whose date falls inside it.
      final monday = mondayOfThisWeek();
      list = events.where((e) {
        if (e.date == null) return true;
        final diff = e.date!.difference(monday).inDays;
        return diff >= 0 && diff < 7;
      }).toList();
    } else {
      // Nothing selected in Month view: everything happening this month.
      list = events.where((e) {
        if (e.date == null) return true;
        return e.date!.year == calendarYear && e.date!.month == calendarMonth;
      }).toList();
    }
    list.sort(
        (a, b) => weekOrder.indexOf(a.dow).compareTo(weekOrder.indexOf(b.dow)));
    return list;
  }

  String _monthName(int m) => monthNames[m - 1];

  String get sectionLabel {
    final d = selectedMonthDate;
    if (d != null) {
      return '${dayNames[weekOrder[d.weekday - 1]]} ${d.day} ${_monthName(d.month)}';
    }
    if (selectedDay == null) {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      final range = monday.month == sunday.month
          ? '${monday.day} – ${sunday.day} ${_monthName(sunday.month)}'
          : '${monday.day} ${_monthName(monday.month)} – ${sunday.day} ${_monthName(sunday.month)}';
      return 'This week · $range';
    }
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final idx = weekOrder.indexOf(selectedDay!);
    final date = monday.add(Duration(days: idx < 0 ? 0 : idx));
    return '${dayNames[selectedDay]} ${date.day} ${_monthName(date.month)}';
  }

  void pickDay(String dow) => _update(() {
        selectedDay = selectedDay == dow ? null : dow;
        selectedMonthDate = null;
      });

  bool dayHasEvents(String dow) {
    final idx = weekOrder.indexOf(dow);
    final date = mondayOfThisWeek().add(Duration(days: idx < 0 ? 0 : idx));
    return events.any((e) => _occursOn(e, date));
  }

  /// True for the single nearest upcoming date (today or later) that
  /// matches some recurring event's day-of-week — used by the Month
  /// calendar's dot, which used to mark every date sharing that weekday
  /// (so one weekly recurring event lit up the whole month) instead of
  /// just the next time it actually happens — plus true for a one-time
  /// event's own exact date, wherever in the month it falls.
  bool isNextOccurrence(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    if (events.any((e) => e.date != null && _isSameDate(e.date!, dateOnly))) {
      return true;
    }
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dows = events.where((e) => e.date == null).map((e) => e.dow).toSet();
    return dows.any((dow) => nextOccurrenceOfDow(dow, todayOnly) == dateOnly);
  }

  void pickCalendarWeek() => _update(() => calendarView = 'week');
  void pickCalendarMonth() => _update(() => calendarView = 'month');

  /// Tapping a Month-grid cell selects that exact date only (highlighting
  /// every same-weekday cell was the bug) while still filtering the event
  /// list by weekday, since events are only tracked by day-of-week.
  void pickMonthDate(DateTime date, String dow) => _update(() {
        final same = selectedMonthDate != null &&
            selectedMonthDate!.year == date.year &&
            selectedMonthDate!.month == date.month &&
            selectedMonthDate!.day == date.day;
        selectedMonthDate = same ? null : date;
        selectedDay = same ? null : dow;
      });

  void goPrevMonth() => _update(() {
        var m = calendarMonth - 1;
        var y = calendarYear;
        if (m < 1) {
          m = 12;
          y--;
        }
        calendarMonth = m;
        calendarYear = y;
        selectedMonthDate = null;
        selectedDay = null;
      });

  void goNextMonth() => _update(() {
        var m = calendarMonth + 1;
        var y = calendarYear;
        if (m > 12) {
          m = 1;
          y++;
        }
        calendarMonth = m;
        calendarYear = y;
        selectedMonthDate = null;
        selectedDay = null;
      });

  // Every event is pinned to one exact date — a date already tapped in the
  // Month grid carries straight into the new event, otherwise it defaults
  // to today so the DATE field is never left blank.
  void openAddEvent() => _update(() {
        final date = selectedMonthDate ?? DateTime.now();
        editor = EventItem(
            id: 0, dow: weekOrder[date.weekday - 1], date: date, name: '', meta: '');
        editorIsNew = true;
      });

  void openEditEvent(EventItem e) => _update(() {
        editor = EventItem.fromMeta(
            id: e.id,
            dow: e.dow,
            date: e.date,
            name: e.name,
            meta: e.meta,
            photo: e.photo);
        editorIsNew = false;
      });

  void setEditorTitle(String v) => _update(() => editor?.name = v);
  void setEditorTime(String v) => _update(() => editor?.time = v);
  void setEditorEndTime(String v) => _update(() => editor?.endTime = v);
  void setEditorVenue(String v) => _update(() => editor?.venue = v);

  /// Picks the event's date — also keeps `dow` in sync so the
  /// event card's weekday label is right immediately, before the save
  /// round-trip returns the backend-derived value.
  void setEditorDate(DateTime d) => _update(() {
        editor?.date = d;
        editor?.dow = weekOrder[d.weekday - 1];
      });
  void setEditorPhoto(Uint8List bytes) => _update(() {
        editor?.pendingPhotoBytes = bytes;
        editor?.photoRemoved = false;
      });
  void removeEventPhoto() => _update(() {
        editor?.photo = null;
        editor?.pendingPhotoBytes = null;
        editor?.photoRemoved = true;
      });

  bool get canDeleteEvent => editor != null && !editorIsNew;

  // Guards Save/Delete against double-taps — without this, tapping twice
  // before the sheet closes fired two create requests and left two events
  // on the calendar.
  bool savingEvent = false;
  bool deletingEvent = false;

  Future<void> saveEvent() async {
    final cur = editor;
    final token = _getToken();
    if (cur == null ||
        cur.name.trim().isEmpty ||
        token == null ||
        savingEvent) {
      return;
    }
    if (cur.date == null) return;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    // Defensive: the date picker's firstDate already blocks picking a
    // past day — this mirrors the backend's own belt-and-suspenders check
    // in case of clock drift or a stale in-memory session.
    if (cur.date!.isBefore(todayOnly)) return;
    _update(() => savingEvent = true);
    // The backend (and every list/card display) still reads one "TIME ·
    // VENUE" string — the editor just offers separate fields and joins
    // them back together here. Times join with "to" ("6:00 PM to 8:00
    // PM"), never a dash: the dash is the legacy time/venue separator.
    final timePart = cur.endTime.trim().isEmpty
        ? cur.time.trim()
        : '${cur.time.trim()} to ${cur.endTime.trim()}';
    final meta =
        [timePart, cur.venue.trim()].where((s) => s.isNotEmpty).join(' · ');
    // null leaves the banner untouched; a data URL sets/replaces it; the
    // "__remove__" sentinel clears it.
    final String? image = cur.pendingPhotoBytes != null
        ? 'data:image/jpeg;base64,${base64Encode(cur.pendingPhotoBytes!)}'
        : (cur.photoRemoved ? '__remove__' : null);
    try {
      await _api.saveEvent(token,
          id: editorIsNew ? null : cur.id,
          dow: cur.dow,
          name: cur.name.trim(),
          meta: meta,
          image: image,
          date: formatDateYmd(cur.date!));
      _update(() {
        editor = null;
        savingEvent = false;
      });
      await load();
      await loadNextMeeting();
    } on ApiException {
      _update(() {
        editor = null;
        savingEvent = false;
      });
    }
  }

  Future<void> deleteEvent() async {
    final cur = editor;
    final token = _getToken();
    if (cur == null || token == null || deletingEvent) return;
    _update(() => deletingEvent = true);
    try {
      await _api.deleteEvent(token, cur.id);
    } on ApiException {
      // fall through — list reload below reflects the server's truth
    }
    _update(() {
      editor = null;
      deletingEvent = false;
    });
    await load();
    await loadNextMeeting();
  }

  void closeEditor() => _update(() => editor = null);

  // ── event registration QR ─────────────────────────────────────────────
  // The link and QR image are both generated by the backend
  // (GET /club/events/{id}/registration) — this just displays whatever it
  // returns, never fabricates either one itself.
  void openQR(EventItem e) {
    _update(() {
      qrEvent = e;
      registration = null;
      registrationError = null;
      registrationLoading = true;
    });
    final token = _getToken();
    if (token == null) return;
    _api.fetchEventRegistration(token, e.id).then((reg) {
      if (qrEvent?.id != e.id) return; // sheet closed/changed while in flight
      _update(() {
        registration = reg;
        registrationLoading = false;
      });
    }).catchError((error) {
      if (qrEvent?.id != e.id) return;
      _update(() {
        registrationError = error is ApiException
            ? error.message
            : 'Could not load the QR code.';
        registrationLoading = false;
      });
    });
  }

  void closeQR() => _update(() {
        qrEvent = null;
        registration = null;
        registrationError = null;
      });

  void copyQRLink() {
    // Caller (widget) performs the actual Clipboard.setData; this just
    // drives the "Copied ✓" label for 1.8s, mirroring the design.
    _qrCopyTimer?.cancel();
    _update(() => qrCopied = true);
    _qrCopyTimer = Timer(const Duration(milliseconds: 1800), () {
      _update(() => qrCopied = false);
    });
  }

  @override
  void dispose() {
    _qrCopyTimer?.cancel();
    super.dispose();
  }
}
