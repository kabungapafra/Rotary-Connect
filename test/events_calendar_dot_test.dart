// The Month calendar's dot used to mark every date sharing a recurring
// event's weekday (a Wednesday event lit up every Wednesday in the whole
// month) instead of just the next time it actually happens. Locks in the
// fix: only the single nearest upcoming occurrence gets a dot.

import 'package:flutter_test/flutter_test.dart';
import 'package:rotary_connect/api_client.dart';
import 'package:rotary_connect/data.dart';
import 'package:rotary_connect/events_controller.dart';

void main() {
  group('nextOccurrenceOfDow', () {
    test('returns today itself when today already matches', () {
      final wed = DateTime(2026, 7, 8); // a Wednesday
      expect(nextOccurrenceOfDow('WED', wed), DateTime(2026, 7, 8));
    });

    test('returns the following week when today is past that weekday', () {
      final wed = DateTime(2026, 7, 8);
      // Monday already passed this week (7/6) — next one is 7/13.
      expect(nextOccurrenceOfDow('MON', wed), DateTime(2026, 7, 13));
    });

    test('returns later this week when the weekday is still ahead', () {
      final wed = DateTime(2026, 7, 8);
      expect(nextOccurrenceOfDow('FRI', wed), DateTime(2026, 7, 10));
    });
  });

  group('EventsController.isNextOccurrence', () {
    EventsController makeController() =>
        EventsController(ApiClient(), () => null);

    test('marks only the single nearest date for one recurring event', () {
      final controller = makeController();
      controller.events.add(
        EventItem(id: 1, dow: 'WED', name: 'Fellowship', meta: '6:00 PM'),
      );

      final today = DateTime.now();
      final wednesdaysThisMonth = List.generate(35, (i) {
        final d = DateTime(today.year, today.month, 1).add(Duration(days: i));
        return d.month == today.month && d.weekday == DateTime.wednesday
            ? d
            : null;
      }).whereType<DateTime>().toList();

      final dotted =
          wednesdaysThisMonth.where(controller.isNextOccurrence).toList();
      expect(dotted.length, lessThanOrEqualTo(1),
          reason: 'exactly one Wednesday (the nearest) should be dotted, '
              'not every Wednesday in the month');
    });

    test('two different weekly events each get their own single dot', () {
      final controller = makeController();
      controller.events.addAll([
        EventItem(id: 1, dow: 'MON', name: 'Board Meeting', meta: '5:00 PM'),
        EventItem(id: 2, dow: 'WED', name: 'Fellowship', meta: '6:00 PM'),
      ]);

      final todayOnly = DateTime.now();
      final today = DateTime(todayOnly.year, todayOnly.month, todayOnly.day);
      final nextMonday = nextOccurrenceOfDow('MON', today);
      final nextWednesday = nextOccurrenceOfDow('WED', today);

      expect(controller.isNextOccurrence(nextMonday), isTrue);
      expect(controller.isNextOccurrence(nextWednesday), isTrue);
      // A day that isn't either event's nearest occurrence must not be dotted.
      final unrelatedDay = today.add(const Duration(days: 400));
      expect(controller.isNextOccurrence(unrelatedDay), isFalse);
    });

    test('no events means nothing is ever dotted', () {
      final controller = makeController();
      expect(controller.isNextOccurrence(DateTime.now()), isFalse);
    });
  });
}
