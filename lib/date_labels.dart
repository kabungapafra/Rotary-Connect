/// Shared month/weekday name tables — used by AppState (today's date line,
/// check-in timestamps) and EventsController (calendar, next-meeting
/// badge) alike, so neither has to duplicate or depend on the other for
/// plain date formatting.
const List<String> monthNames = [
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

const List<String> weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
