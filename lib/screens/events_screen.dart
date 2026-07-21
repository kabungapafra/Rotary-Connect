import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../app_state.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/date_time_field.dart';
import '../widgets/pressable.dart';
import '../widgets/synced_text_field.dart';

class EventsScreen extends StatelessWidget {
  final AppState state;
  const EventsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final visible = state.visibleEvents;
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: RCColors.blue,
              padding: EdgeInsets.fromLTRB(
                  20, 18 + MediaQuery.of(context).padding.top, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Events',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('Tap a date to filter',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: .8),
                                  fontSize: 12)),
                        ],
                      ),
                      if (state.canManageClub)
                        PressableScale(
                          child: ElevatedButton(
                            onPressed: state.openAddEvent,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: RCColors.gold,
                              foregroundColor: RCColors.blue,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('＋ Add event',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5)),
                          ),
                        ),
                    ],
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
                        Expanded(
                          child: _CalTab(
                              label: 'Week',
                              active: state.calendarView == 'week',
                              onTap: state.pickCalendarWeek),
                        ),
                        Expanded(
                          child: _CalTab(
                              label: 'Month',
                              active: state.calendarView == 'month',
                              onTap: state.pickCalendarMonth),
                        ),
                      ],
                    ),
                  ),
                  if (state.calendarView == 'week') ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (var i = 0; i < weekDays.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                              child:
                                  _WeekDayBox(day: weekDays[i], state: state)),
                        ],
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    _MonthGrid(state: state),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(state.eventsSectionLabel,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: RCColors.textDark)),
                      const Text('Tap an event to edit',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF8B96A8))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (visible.isEmpty)
                    RCCard(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
                      child: Column(
                        children: [
                          const Text('Nothing planned this day',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: RCColors.textMuted)),
                          if (state.canManageClub) ...[
                            const SizedBox(height: 10),
                            PressableScale(
                              child: ElevatedButton(
                                onPressed: state.openAddEvent,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: RCColors.chipBg,
                                  foregroundColor: RCColors.blue,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('＋ Add event',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _EventCard(event: visible[i], state: state),
                    ],
                ],
              ),
            ),
          ],
        ),
        if (state.eventEditor != null) _EditorSheet(state: state),
        if (state.eventQR != null) _QRSheet(state: state),
      ],
    );
  }
}

class _CalTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _CalTab(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? RCColors.gold : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? RCColors.blue : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Month grid for whichever year/month is currently selected in [state].
class _MonthGrid extends StatelessWidget {
  final AppState state;
  const _MonthGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    final year = state.calendarYear;
    final month = state.calendarMonth;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1=Mon..7=Sun
    final leadBlanks = (firstWeekday - 1) % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MonthNavButton(icon: '‹', onTap: state.goPrevMonth),
              Text('${_monthNames[month - 1]} $year',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
              _MonthNavButton(icon: '›', onTap: state.goNextMonth),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final l in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Text(l,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: .6),
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (var i = 0; i < leadBlanks; i++) const SizedBox.shrink(),
              for (var day = 1; day <= daysInMonth; day++)
                _MonthCell(
                    date: DateTime(year, month, day),
                    dow: weekOrder[DateTime(year, month, day).weekday - 1],
                    state: state),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  const _MonthNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 26,
          height: 26,
          child: Center(
              child: Text(icon,
                  style: const TextStyle(color: Colors.white, fontSize: 14))),
        ),
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  final DateTime date;
  final String dow;
  final AppState state;
  const _MonthCell(
      {required this.date, required this.dow, required this.state});

  @override
  Widget build(BuildContext context) {
    final sel = state.selectedMonthDate;
    final selected = sel != null &&
        sel.year == date.year &&
        sel.month == date.month &&
        sel.day == date.day;
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final hasEvents = state.isNextEventOccurrence(date);
    return Material(
      color: selected
          ? RCColors.gold
          : (isToday
              ? RCColors.blue.withValues(alpha: .06)
              : Colors.transparent),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => state.pickMonthDate(date, dow),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${date.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? RCColors.blue : Colors.white,
                )),
            const SizedBox(height: 2),
            Opacity(
              opacity: hasEvents ? 1 : 0,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: selected ? RCColors.blue : RCColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDayBox extends StatelessWidget {
  final WeekDay day;
  final AppState state;
  const _WeekDayBox({required this.day, required this.state});

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedDay == day.dow;
    final hasEvents = state.dayHasEvents(day.dow);
    return Material(
      color: selected ? RCColors.gold : Colors.white.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => state.pickDay(day.dow),
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            // Today (WED) keeps a gold inset outline when not selected.
            border: day.isToday && !selected
                ? Border.all(color: RCColors.gold, width: 1.5)
                : null,
          ),
          child: Column(
            children: [
              Text(day.dow,
                  style: TextStyle(
                      fontSize: 10,
                      color: (selected ? RCColors.blue : Colors.white)
                          .withValues(alpha: .8),
                      height: 1)),
              const SizedBox(height: 3),
              Text(day.num,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: selected ? RCColors.blue : Colors.white)),
              const SizedBox(height: 3),
              Opacity(
                opacity: hasEvents ? 1 : 0,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: selected ? RCColors.blue : RCColors.gold,
                    shape: BoxShape.circle,
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

class _EventCard extends StatelessWidget {
  final EventItem event;
  final AppState state;
  const _EventCard({required this.event, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: RCColors.cardShadow, blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => state.openEditEvent(event),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (event.photo != null)
              Image.network(event.photo!, height: 110, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                        color: RCColors.chipBg,
                        borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        Text(event.dow,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: RCColors.blue,
                                height: 1.1)),
                        Text(event.num,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: RCColors.blue,
                                height: 1.1)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.name,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: RCColors.textDark)),
                        const SizedBox(height: 2),
                        Text(event.meta,
                            style: const TextStyle(
                                fontSize: 11.5, color: RCColors.textMuted)),
                      ],
                    ),
                  ),
                  // Hidden once today's occurrence is ending (15 min
                  // before its end time) — registration is closed, so
                  // there's nothing left to generate a QR for.
                  if (state.canGenerateEventQr && event.registrationOpen)
                    PressableScale(
                      child: OutlinedButton(
                        onPressed: () => state.openQR(event),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: RCColors.blue,
                          side: const BorderSide(
                              color: Color(0xFFD4DBE8), width: 1.5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('▦ Register',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 11)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorSheet extends StatelessWidget {
  final AppState state;
  const _EditorSheet({required this.state});

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 1920);
    if (file == null) return;
    state.setEditorPhoto(await file.readAsBytes());
  }

  @override
  Widget build(BuildContext context) {
    final ed = state.eventEditor!;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: state.closeEditor,
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: SingleChildScrollView(
                child: Column(
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
                        Text(state.canDeleteEvent ? 'Edit event' : 'New event',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: RCColors.textDark)),
                        Material(
                          color: RCColors.chipBg,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: state.closeEditor,
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
                    if (ed.pendingPhotoBytes == null && ed.photo == null)
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _pickPhoto,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F9FC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: const Color(0xFFB9C4D6), width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Text('＋',
                                  style: TextStyle(
                                      fontSize: 18,
                                      color: RCColors.blue,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('Add photo or poster',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: RCColors.blue)),
                              const SizedBox(height: 4),
                              const Text('Shown on the event card',
                                  style: TextStyle(
                                      fontSize: 11, color: Color(0xFF8B96A8))),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ed.pendingPhotoBytes != null
                            ? Image.memory(ed.pendingPhotoBytes!,
                                height: 130,
                                width: double.infinity,
                                fit: BoxFit.cover)
                            : Image.network(ed.photo!,
                                height: 130,
                                width: double.infinity,
                                fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: PressableScale(
                              child: OutlinedButton(
                                onPressed: _pickPhoto,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: RCColors.blue,
                                  side: const BorderSide(
                                      color: Color(0xFFD4DBE8), width: 1.5),
                                  padding: const EdgeInsets.all(9),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Change photo',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PressableScale(
                              child: ElevatedButton(
                                onPressed: state.removeEventPhoto,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFDECEA),
                                  foregroundColor: RCColors.red,
                                  padding: const EdgeInsets.all(9),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                child: const Text('Remove',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    const _FieldLabel('EVENT NAME'),
                    const SizedBox(height: 6),
                    _EditorInput(
                      hint: 'e.g. Charter Night planning',
                      value: ed.name,
                      onChanged: state.setEditorTitle,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _FieldLabel('FROM'),
                              const SizedBox(height: 6),
                              _EditorInput(
                                hint: 'e.g. 6:00 PM',
                                value: ed.time,
                                onChanged: state.setEditorTime,
                                readOnly: true,
                                icon: Icons.access_time,
                                onTap: () async {
                                  final picked = await pickRCTime(context,
                                      initialTime: tryParseTimeOfDay(ed.time) ??
                                          TimeOfDay.now());
                                  if (picked != null) {
                                    state.setEditorTime(
                                        formatTimeOfDay(picked));
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _FieldLabel('TO'),
                              const SizedBox(height: 6),
                              _EditorInput(
                                hint: 'e.g. 8:00 PM',
                                value: ed.endTime,
                                onChanged: state.setEditorEndTime,
                                readOnly: true,
                                icon: Icons.access_time,
                                onTap: () async {
                                  final picked = await pickRCTime(context,
                                      initialTime:
                                          tryParseTimeOfDay(ed.endTime) ??
                                              tryParseTimeOfDay(ed.time) ??
                                              TimeOfDay.now());
                                  if (picked != null) {
                                    state.setEditorEndTime(
                                        formatTimeOfDay(picked));
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _FieldLabel('VENUE'),
                    const SizedBox(height: 6),
                    _EditorInput(
                      hint: 'e.g. Mbalwa Gardens Hall',
                      value: ed.venue,
                      onChanged: state.setEditorVenue,
                    ),
                    const SizedBox(height: 14),
                    const _FieldLabel('DAY'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (var i = 0; i < weekOrder.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: _DayChip(
                              label: weekOrder[i],
                              active: ed.dow == weekOrder[i],
                              onTap: () => state.setEditorDay(weekOrder[i]),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (state.canDeleteEvent) ...[
                          PressableScale(
                            child: ElevatedButton(
                              onPressed: state.deleteEvent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFDECEA),
                                foregroundColor: RCColors.red,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('Delete',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: PressableScale(
                            child: ElevatedButton(
                              onPressed: state.saveEvent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RCColors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('Save event',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                            ),
                          ),
                        ),
                      ],
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
}

class _QRSheet extends StatelessWidget {
  final AppState state;
  const _QRSheet({required this.state});

  // Embeds the backend's own QR PNG (decoded from its data URL) rather
  // than rendering a second, separate QR locally — one source of truth
  // for the image, matching what's shown on screen. clubLogoUrl is either
  // an R2 https URL or (older deployments) a data: URL — either way it's
  // fetched into bytes here since pw.Image needs an in-memory image, not
  // a URL.
  Future<void> _exportPdf(EventItem event, String clubName,
      String? clubLogoUrl, String link, Uint8List qrPngBytes) async {
    final doc = pw.Document();
    final qrImage = pw.MemoryImage(qrPngBytes);
    pw.MemoryImage? logoImage;
    if (clubLogoUrl != null && clubLogoUrl.isNotEmpty) {
      try {
        if (clubLogoUrl.startsWith('data:')) {
          logoImage = pw.MemoryImage(base64Decode(clubLogoUrl.split(',').last));
        } else {
          final res = await http.get(Uri.parse(clubLogoUrl));
          if (res.statusCode == 200) logoImage = pw.MemoryImage(res.bodyBytes);
        }
      } catch (_) {
        // The flyer still works without a logo — just skip it.
      }
    }
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(height: 16),
            pw.Text('Scan the QR code and register for',
                textAlign: pw.TextAlign.center,
                style:
                    const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
            pw.SizedBox(height: 6),
            pw.Text(event.name,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF17458F))),
            pw.SizedBox(height: 4),
            pw.Text(event.meta,
                style:
                    const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
            pw.SizedBox(height: 22),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF7A81B),
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(18)),
              ),
              child: pw.Column(
                children: [
                  pw.Text('scan me',
                      style: const pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.white)),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    color: PdfColors.white,
                    child: pw.Image(qrImage, width: 170, height: 170),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('See you there!',
                style: const pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF17458F))),
            pw.SizedBox(height: 4),
            pw.Text(link,
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.Spacer(),
            pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration:
                  const pw.BoxDecoration(color: PdfColor.fromInt(0xFF17458F)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  if (logoImage != null) ...[
                    pw.ClipRRect(
                      horizontalRadius: 16,
                      verticalRadius: 16,
                      child: pw.Image(logoImage, width: 32, height: 32),
                    ),
                    pw.SizedBox(width: 10),
                  ],
                  pw.Text(clubName,
                      style: const pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    final event = state.eventQR!;
    final registration = state.eventRegistration;
    final link = registration?.link ?? '';
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: state.closeQR,
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4DBE8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Event registration',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: RCColors.textDark)),
                        Material(
                          color: RCColors.chipBg,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: state.closeQR,
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
                    Text(event.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: RCColors.textDark)),
                    const SizedBox(height: 2),
                    Text(event.meta,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, color: RCColors.textMuted)),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: registration != null
                            ? Image.memory(
                                base64Decode(
                                    registration.qrImage.split(',').last),
                                fit: BoxFit.contain)
                            : Container(
                                color: RCColors.chipBg,
                                alignment: Alignment.center,
                                child: state.eventRegistrationError != null
                                    ? const Text(
                                        'Could not load the QR code',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: RCColors.textMuted),
                                      )
                                    : const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5),
                                      ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        border: Border.all(
                            color: const Color(0xFFEAEEF5), width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(link,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF4A5670))),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: PressableScale(
                            child: OutlinedButton(
                              onPressed: registration == null
                                  ? null
                                  : () {
                                      Clipboard.setData(
                                          ClipboardData(text: link));
                                      state.copyQRLink();
                                    },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: RCColors.blue,
                                side: const BorderSide(
                                    color: Color(0xFFD4DBE8), width: 1.5),
                                padding: const EdgeInsets.all(12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                  state.qrCopied ? 'Copied ✓' : 'Copy link',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PressableScale(
                            child: ElevatedButton(
                              onPressed: state.closeQR,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RCColors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('Done',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    PressableScale(
                      child: OutlinedButton(
                        onPressed: registration == null
                            ? null
                            : () => _exportPdf(
                                event,
                                state.displayClubName,
                                state.clubLogo,
                                link,
                                base64Decode(
                                    registration.qrImage.split(',').last)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: RCColors.blue,
                          backgroundColor: const Color(0xFFF7F9FC),
                          side: const BorderSide(
                              color: Color(0xFFB9C4D6),
                              width: 1.5,
                              style: BorderStyle.solid),
                          padding: const EdgeInsets.all(12),
                          minimumSize: const Size.fromHeight(0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('⬇ Export as PDF for printing',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Share this link or QR so guests can RSVP online without an account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Color(0xFF9AA5B8)),
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
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: Color(0xFF8B96A8)),
    );
  }
}

class _EditorInput extends StatelessWidget {
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? icon;
  const _EditorInput(
      {required this.hint,
      required this.value,
      required this.onChanged,
      this.readOnly = false,
      this.onTap,
      this.icon});

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 1.5),
        );
    return SyncedTextField(
      value: value,
      builder: (context, controller) => TextField(
        controller: controller,
        onChanged: onChanged,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(color: RCColors.textDark, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF8B96A8)),
          suffixIcon: icon == null
              ? null
              : Icon(icon, size: 18, color: RCColors.blue),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: border(const Color(0xFFD4DBE8)),
          enabledBorder: border(const Color(0xFFD4DBE8)),
          focusedBorder: border(RCColors.blue),
        ),
    ),
           );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _DayChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? RCColors.blue : RCColors.chipBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : const Color(0xFF5A6A85),
            ),
          ),
        ),
      ),
    );
  }
}
