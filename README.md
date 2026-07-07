# Rotary Connect

A member app for the **Rotary Club of Mbalwa** — meeting check-in, events, projects, member directory, gallery, treasury and attendance, all in one place. Built with Flutter for Android.

## Features

- **Member login & guest access** — sign in with a member number and PIN, or continue as a visiting guest.
- **QR check-in** — a full-screen live camera scanner reads the club's meeting QR code to record attendance for members and guests.
- **Today at fellowship** — see who's checked in, visiting guests, and clubs represented at the current meeting.
- **Events** — weekly and monthly calendar views, add/edit/delete events with a photo, and generate a QR/link registration sheet per event (with PDF export for printing).
- **Projects** — track club projects with progress, deadlines, photos, and a "done" status; add and edit your own.
- **Members** — searchable directory with board/officer grouping, member profiles (email, phone, date of birth), and the ability to add new members.
- **Gallery** — browse photo albums from past fellowships and projects, and upload new photos.
- **Treasury** — dues collection status, outstanding balances, and recent transactions.
- **Attendance** — personal attendance history, certificates, and a club-wide register with downloadable reports.

## Getting started

```bash
flutter pub get
flutter run
```

Requires a physical device or emulator with a camera for the QR check-in feature.

## Project structure

```
lib/
  app_state.dart      # Single shared app state (navigation, data, UI state)
  data.dart            # Static seed data (members, events, projects, etc.)
  theme.dart            # Colors and Poppins text theme
  main.dart              # App entry point and screen routing
  screens/               # One file per top-level screen
  widgets/               # Shared reusable widgets (cards, avatars, overlays)
assets/
  images/                 # Logo and Rotary wheel artwork
  fonts/                    # Bundled Poppins font weights
```

## Tech notes

- State management is a single `AppState` (a `ChangeNotifier`) rather than a routing/navigation package — screens are swapped by a `tab` string, matching a simple single-page app model.
- No backend — all data is seeded in memory and resets when the app restarts.
- Camera QR scanning uses [`mobile_scanner`](https://pub.dev/packages/mobile_scanner); event registration PDFs are generated on-device with [`pdf`](https://pub.dev/packages/pdf) and [`printing`](https://pub.dev/packages/printing).
