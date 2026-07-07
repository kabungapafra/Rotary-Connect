/// Static seed data for the Rotary Mbalwa app, taken as-is from the design.
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

  String get initials => name.split(' ').map((w) => w[0]).join();

  /// "phone · email", omitting whichever is empty — shown under the role.
  String get contact => [phone, email].where((s) => s.isNotEmpty).join(' · ');
}

const List<Member> members = [
  Member('Sarah Namuli', 'President', true,
      email: 'sarah.namuli@mbalwarotary.org',
      phone: '0772 401 118',
      dob: '14 Mar 1979'),
  Member('David Ssemakula', 'Vice President', true,
      email: 'david.ssemakula@mbalwarotary.org',
      phone: '0701 552 209',
      dob: '2 Jul 1975'),
  Member('Grace Nakato', 'Secretary', true,
      email: 'grace.nakato@mbalwarotary.org',
      phone: '0782 334 471',
      dob: '19 Nov 1988'),
  Member('Peter Okello', 'Treasurer', true,
      email: 'peter.okello@mbalwarotary.org',
      phone: '0752 990 812',
      dob: '5 Jan 1982'),
  Member('Agnes Kembabazi', 'Sergeant-at-Arms', true,
      email: 'agnes.kembabazi@mbalwarotary.org',
      phone: '0778 214 663',
      dob: '30 Aug 1990'),
  Member('Ronald Mugisha', 'Community Service Director', true,
      email: 'ronald.mugisha@mbalwarotary.org',
      phone: '0704 118 205',
      dob: '11 Apr 1984'),
  Member('Esther Achan', 'Youth Service Director', true,
      email: 'esther.achan@mbalwarotary.org',
      phone: '0789 662 331',
      dob: '23 Jun 1991'),
  Member('Brian Kato', 'Membership Chair', true,
      email: 'brian.kato@mbalwarotary.org',
      phone: '0712 887 540',
      dob: '8 Oct 1986'),
  Member('Joan Atim', 'Rotary Foundation Chair', true,
      email: 'joan.atim@mbalwarotary.org',
      phone: '0700 445 918',
      dob: '27 Feb 1980'),
  Member('Samuel Wasswa', 'Member', false,
      email: 'samuel.wasswa@gmail.com',
      phone: '0782 003 447',
      dob: '16 May 1993'),
  Member('Rebecca Nabirye', 'Member', false,
      email: 'rebecca.nabirye@gmail.com',
      phone: '0703 219 685',
      dob: '9 Sep 1995'),
  Member('Isaac Tumwine', 'Member', false,
      email: 'isaac.tumwine@gmail.com',
      phone: '0778 561 023',
      dob: '21 Dec 1989'),
  Member('Doreen Apio', 'Member', false,
      email: 'doreen.apio@gmail.com', phone: '0755 340 176', dob: '3 Mar 1992'),
  Member('Moses Lubega', 'Member', false,
      email: 'moses.lubega@gmail.com',
      phone: '0713 908 254',
      dob: '17 Jul 1987'),
];

class HistoryEntry {
  final String name;
  final String date;
  final String status; // Present | Made up | Absent
  const HistoryEntry(this.name, this.date, this.status);
}

const List<HistoryEntry> history = [
  HistoryEntry('Weekly Fellowship Meeting', 'Wed 1 Jul 2026', 'Present'),
  HistoryEntry('District Fellowship Day', 'Sat 27 Jun 2026', 'Present'),
  HistoryEntry('Weekly Fellowship Meeting', 'Wed 24 Jun 2026', 'Present'),
  HistoryEntry('Weekly Fellowship Meeting', 'Wed 17 Jun 2026', 'Made up'),
  HistoryEntry('Weekly Fellowship Meeting', 'Wed 10 Jun 2026', 'Present'),
  HistoryEntry('Weekly Fellowship Meeting', 'Wed 3 Jun 2026', 'Absent'),
  HistoryEntry('Health Camp Volunteer Day', 'Sat 30 May 2026', 'Present'),
];

class Cert {
  final String title;
  final String sub;
  final String body;
  const Cert(this.title, this.sub, this.body);
}

const List<Cert> certs = [
  Cert(
    '100% Attendance',
    'June 2026 · meeting attendance',
    'For achieving 100% attendance at all weekly fellowship meetings in June 2026.',
  ),
  Cert(
    'Fellowship Participation',
    'District Fellowship Day · 27 Jun 2026',
    'In recognition of active participation at the District Fellowship Day, Kampala.',
  ),
];

/// Editable project — the design keeps these in mutable component state so
/// they can be added, edited and deleted from the Projects editor sheet.
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

List<Project> initialProjects() => [
      Project(
          id: 1,
          name: 'Clean Water Borehole',
          icon: 'W',
          area: 'Water & sanitation · Mbalwa Village',
          pct: 75,
          desc:
              'Drilling and commissioning a community borehole serving 400 households in Mbalwa Village.',
          deadline: 'Sep 2026'),
      Project(
          id: 2,
          name: 'Desks for St. Kizito Primary',
          icon: 'E',
          area: 'Basic education · Namugongo',
          pct: 40,
          desc:
              '120 twin desks for St. Kizito Primary School, replacing floor seating for P1–P3 classes.',
          deadline: 'Nov 2026'),
      Project(
          id: 3,
          name: 'Community Health Camp',
          icon: 'H',
          area: 'Disease prevention · Kira Division',
          pct: 100,
          desc:
              'Free screening for 600 residents: malaria, blood pressure, diabetes, and eye checks.',
          deadline: 'Completed May 2026'),
      Project(
          id: 4,
          name: 'Green Mbalwa Tree Drive',
          icon: 'T',
          area: 'Environment · Mbalwa–Kireka road',
          pct: 20,
          desc:
              '2,000 indigenous trees planted along the Mbalwa–Kireka road reserve with local schools.',
          deadline: 'Dec 2026'),
    ];

class WeekDay {
  final String dow;
  final String num;
  const WeekDay(this.dow, this.num);
  bool get isToday => dow == 'WED';
}

const List<WeekDay> weekDays = [
  WeekDay('MON', '6'),
  WeekDay('TUE', '7'),
  WeekDay('WED', '8'),
  WeekDay('THU', '9'),
  WeekDay('FRI', '10'),
  WeekDay('SAT', '11'),
  WeekDay('SUN', '12'),
];

const List<String> weekOrder = [
  'MON',
  'TUE',
  'WED',
  'THU',
  'FRI',
  'SAT',
  'SUN'
];

const Map<String, String> dayNums = {
  'MON': '6',
  'TUE': '7',
  'WED': '8',
  'THU': '9',
  'FRI': '10',
  'SAT': '11',
  'SUN': '12',
};

const Map<String, String> dayNames = {
  'MON': 'Monday',
  'TUE': 'Tuesday',
  'WED': 'Wednesday',
  'THU': 'Thursday',
  'FRI': 'Friday',
  'SAT': 'Saturday',
  'SUN': 'Sunday',
};

/// Editable event — the design keeps these in mutable component state so
/// they can be added, edited and deleted from the Events editor sheet.
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

List<EventItem> initialEvents() => [
      EventItem(
          id: 1,
          dow: 'WED',
          name: 'Weekly Fellowship Meeting',
          meta:
              '6:00 PM · Mbalwa Gardens Hall · Guest speaker: District Governor'),
      EventItem(
          id: 2,
          dow: 'FRI',
          name: 'Board Meeting',
          meta: '5:30 PM · Online (Zoom)'),
      EventItem(
          id: 3,
          dow: 'SAT',
          name: 'Borehole Site Visit',
          meta: '9:00 AM · Mbalwa Village · Community service'),
      EventItem(
          id: 4,
          dow: 'SUN',
          name: 'Interact Club Mentorship',
          meta: '2:00 PM · St. Kizito Primary'),
    ];

class RegisterMeeting {
  final String short;
  final String name;
  final String date;
  final int members;
  final int guests;
  final int clubs;
  const RegisterMeeting(
      this.short, this.name, this.date, this.members, this.guests, this.clubs);
}

const List<RegisterMeeting> registerMeetings = [
  RegisterMeeting(
      'Weekly Fellowship', 'Weekly Fellowship Meeting', 'Wed 1 Jul', 18, 4, 2),
  RegisterMeeting(
      'District Fellowship', 'District Fellowship Day', 'Sat 27 Jun', 15, 9, 3),
  RegisterMeeting(
      'Weekly Fellowship', 'Weekly Fellowship Meeting', 'Wed 24 Jun', 20, 2, 1),
  RegisterMeeting(
      'Health Camp', 'Health Camp Volunteer Day', 'Sat 30 May', 12, 6, 3),
];

class Poster {
  final String title;
  final String date;
  const Poster(this.title, this.date);
  String get placeholder => 'poster image';
}

const List<Poster> posters = [
  Poster('Charter Night 2026', 'Sat 25 Jul · Speke Resort'),
  Poster('Rotary Cancer Run', 'Sun 30 Aug · Kololo'),
  Poster('Family Fun Day', 'Sat 15 Aug · Mbalwa Gardens'),
  Poster('District Conference', 'Sep 24–26 · Munyonyo'),
];

class TodayMember {
  final String name;
  final String role;
  final String time;
  const TodayMember(this.name, this.role, this.time);
  String get initials => name.split(' ').map((w) => w[0]).join();
}

const List<TodayMember> todayMembers = [
  TodayMember('Sarah Namuli', 'President', '5:48 PM'),
  TodayMember('Grace Nakato', 'Secretary', '5:52 PM'),
  TodayMember('Peter Okello', 'Treasurer', '5:55 PM'),
  TodayMember('Ronald Mugisha', 'Community Service Director', '5:58 PM'),
  TodayMember('Samuel Wasswa', 'Member', '6:01 PM'),
  TodayMember('Rebecca Nabirye', 'Member', '6:02 PM'),
  TodayMember('Isaac Tumwine', 'Member', '6:04 PM'),
  TodayMember('Doreen Apio', 'Member', '6:07 PM'),
];

const int todayMemberCount = 8;
const int todayGuestCount = 4;

class TodayGuest {
  final String name;
  final String sub;
  final String type; // Visiting Rotarian | Prospective | Friend & family
  const TodayGuest(this.name, this.sub, this.type);
  String get initials =>
      name.replaceFirst('Rtn. ', '').split(' ').map((w) => w[0]).join();
}

const List<TodayGuest> todayGuests = [
  TodayGuest('Rtn. James Odongo', 'Rotary Club of Naalya', 'Visiting Rotarian'),
  TodayGuest(
      'Rtn. Lydia Nansubuga', 'Rotary Club of Naalya', 'Visiting Rotarian'),
  TodayGuest('Martin Ssebunya', 'Guest of Rtn. Sarah Namuli', 'Prospective'),
  TodayGuest('Christine Auma', 'Guest of Rtn. Peter Okello', 'Friend & family'),
];

class TodayClub {
  final String abbr;
  final String name;
  final String sub;
  final bool isClubOfDay;
  const TodayClub(this.abbr, this.name, this.sub, this.isClubOfDay);
}

const List<TodayClub> todayClubs = [
  TodayClub('RCN', 'Rotary Club of Naalya', '2 visiting Rotarians', true),
  TodayClub('RCK', 'Rotary Club of Kira', '1 visiting Rotarian', false),
  TodayClub(
      'RCB', 'Rotaract Club of Bweyogerere', '1 visiting Rotaractor', false),
];

/// Home screen gallery preview tiles — a distinct, smaller data set from
/// [galleryAlbums] in the original design (not derived from it).
const List<String> galleryPreview = [
  'Health Camp',
  'Charter Night',
  'Tree Drive'
];

class GalleryAlbum {
  final String activity;
  final String date;
  final String caption;
  const GalleryAlbum(this.activity, this.date, this.caption);
  List<String> get photoLabels => const ['photo 1', 'photo 2', 'photo 3'];
}

const List<GalleryAlbum> galleryAlbums = [
  GalleryAlbum('Community Health Camp', 'Sat 27 Jun 2026',
      'Free screening day at Kira Division — 600 residents served by 22 volunteers.'),
  GalleryAlbum('Weekly Fellowship Meeting', 'Wed 24 Jun 2026',
      'Guest speaker evening with DG visit and new member induction.'),
  GalleryAlbum('Green Mbalwa Tree Drive', 'Sat 13 Jun 2026',
      'Planting along the Mbalwa–Kireka road reserve with St. Kizito pupils.'),
  GalleryAlbum('Charter Night 2025', 'Sat 26 Jul 2025',
      'Celebrating 8 years of service — awards, dinner and fellowship.'),
];

class DuesEntry {
  final String name;
  final String detail;
  final bool paidInitially;
  const DuesEntry(this.name, this.detail, this.paidInitially);
  String get initials => name.split(' ').map((w) => w[0]).join();
}

const List<DuesEntry> duesList = [
  DuesEntry('Sarah Namuli', 'President · UGX 150,000 / quarter', true),
  DuesEntry('David Ssemakula', 'Vice President · UGX 150,000 / quarter', true),
  DuesEntry('Grace Nakato', 'Secretary · UGX 150,000 / quarter', true),
  DuesEntry('Samuel Wasswa', 'Member · UGX 150,000 / quarter', false),
  DuesEntry('Rebecca Nabirye', 'Member · UGX 150,000 / quarter', false),
  DuesEntry('Isaac Tumwine', 'Member · UGX 150,000 / quarter', false),
  DuesEntry('Doreen Apio', 'Member · UGX 150,000 / quarter', true),
  DuesEntry('Moses Lubega', 'Member · UGX 150,000 / quarter', false),
];

class TransactionEntry {
  final String label;
  final String date;
  final String amount;
  final bool isIn;
  const TransactionEntry(this.label, this.date, this.amount, this.isIn);
  String get sign => isIn ? '↓' : '↑';
}

const List<TransactionEntry> transactions = [
  TransactionEntry(
      'Dues — Rtn. Doreen Apio', 'Fri 3 Jul 2026', '+ UGX 150,000', true),
  TransactionEntry('Fine — late arrival (2 members)', 'Wed 1 Jul 2026',
      '+ UGX 20,000', true),
  TransactionEntry('Venue hire — Mbalwa Gardens Hall', 'Wed 1 Jul 2026',
      '− UGX 200,000', false),
  TransactionEntry('Donation — Cancer Run pledges', 'Sun 28 Jun 2026',
      '+ UGX 850,000', true),
  TransactionEntry('Borehole project disbursement', 'Fri 26 Jun 2026',
      '− UGX 1,200,000', false),
];

const List<String> guestTypes = [
  'Prospective member',
  'Visiting Rotarian',
  'Friend & family'
];
