import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'data.dart';
import 'date_labels.dart';

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
              EventItem(
                  id: e.id,
                  dow: e.dow,
                  name: e.name,
                  meta: e.meta,
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

  /// "TODAY · 8 JUL" / "TOMORROW · 9 JUL" / "WED · 15 JUL" for the Next
  /// meeting card, computed from the real date the backend returned —
  /// never assumes the next fellowship is today.
  String get nextMeetingBadge {
    final nm = nextMeeting;
    if (nm == null) return '';
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

  List<EventItem> get visibleEvents {
    final list = selectedDay == null
        ? List.of(events)
        : events.where((e) => e.dow == selectedDay).toList();
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

  bool dayHasEvents(String dow) => events.any((e) => e.dow == dow);

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

  void openAddEvent() => _update(() {
        editor = EventItem(id: 0, dow: selectedDay ?? 'WED', name: '', meta: '');
        editorIsNew = true;
      });

  void openEditEvent(EventItem e) => _update(() {
        editor = EventItem.fromMeta(
            id: e.id, dow: e.dow, name: e.name, meta: e.meta, photo: e.photo);
        editorIsNew = false;
      });

  void setEditorTitle(String v) => _update(() => editor?.name = v);
  void setEditorTime(String v) => _update(() => editor?.time = v);
  void setEditorVenue(String v) => _update(() => editor?.venue = v);
  void setEditorDay(String dow) => _update(() => editor?.dow = dow);
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

  Future<void> saveEvent() async {
    final cur = editor;
    final token = _getToken();
    if (cur == null || cur.name.trim().isEmpty || token == null) return;
    // The backend (and every list/card display) still reads one "TIME ·
    // VENUE" string — the editor just offers it as two fields and joins
    // them back together here.
    final meta = [cur.time.trim(), cur.venue.trim()]
        .where((s) => s.isNotEmpty)
        .join(' · ');
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
          image: image);
      _update(() => editor = null);
      await load();
      await loadNextMeeting();
    } on ApiException {
      _update(() => editor = null);
    }
  }

  Future<void> deleteEvent() async {
    final cur = editor;
    final token = _getToken();
    if (cur == null || token == null) return;
    try {
      await _api.deleteEvent(token, cur.id);
    } on ApiException {
      // fall through — list reload below reflects the server's truth
    }
    _update(() => editor = null);
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
