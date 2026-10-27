# Schulportal

*[Auf Deutsch lesen](README.md)*

An Android app for the **Schulportal Hessen** (the school portal of the German state of Hesse) – made for parents and students who want the school day at a glance: what's on today, what's cancelled, which homework is open. Private and non-commercial, shared with family and friends.

The app is a fork of [Lanis-Mobile](https://github.com/lanis-mobile/lanis) and, like the original, licensed under the **GPL-3.0**. It is not affiliated with the State of Hesse, the Schulportal Hessen or the Lanis-Mobile developers.

## Features

- **Today** – one card per child: cancellations, substitutions and room changes first, then the day's timetable with the current lesson; open homework, new messages, upcoming events.
- **Calendar** – day, week and events; substitutions stay visible for past days; group choice for parallel courses (e.g. religion/ethics).
- **Lessons** – course folders, open and completed homework, upcoming tests, grades and absences.
- **Messages** – read, reply, write new ones.
- **Family** – several accounts side by side, also at different schools (parent and student accounts).
- **Meals** – the week's ordered meals, ordering and cancelling in the app, hints for missing orders and low balance (for known caterer pages; otherwise the caterer's page opens).
- **Offline** – shows the last saved state and when it is from.
- **Notifications** – for cancellations, substitutions and new messages.
- **Demo** – “Try the demo” on the start page shows the app with a made-up school, no login needed.

## Installation

The app is available for **Android** only.

1. Download and install the APK from the [releases](https://github.com/rw-apps/schulportal/releases/latest). Android asks once whether installs from this source are allowed.
2. For automatic updates: install [Obtainium](https://github.com/ImranR98/Obtainium) and add `https://github.com/rw-apps/schulportal`.

The app has its own app ID (`io.github.rwapps.sph`) and runs alongside Lanis-Mobile.

## Privacy

The app signs in **directly with the school portal**; credentials stay on the device. No ads, no tracking, no usage statistics. Error reports are only sent with consent and contain no names, grades or messages. Details (German): [PRIVACY.md](PRIVACY.md).

## Reporting problems

In the app under **Settings → About → Troubleshooting**: share the detected problems or – with consent – report them automatically. If the app can't read a portal page (e.g. at another school or with a teacher account), the **anonymous export** helps: it shows the structure of the pages without names, grades or texts.

Questions and hints are welcome as an [issue](https://github.com/rw-apps/schulportal/issues).

## For developers

- Flutter (stable, see `pubspec.yaml`), Riverpod, [liblanis](https://pub.dev/packages/liblanis) for portal access.
- Fork code lives in `lib/fork/`, the UI in `lib/fork/ui/` with the central design kit `lib/fork/ui/kit.dart`.
- Strings: `lib/fork/l10n/fork_*.arb` (German, English, Turkish), then `flutter gen-l10n`.
- Checks: `dart format lib test/fork`, `flutter analyze`, `flutter test`.
- Test data is made up – real school or personal data does not belong in the repository.
- A release is created by a version bump in `pubspec.yaml` on `main` (`.github/workflows/release-fork.yml`).

Changes compared to the original (German): [CHANGELOG-FORK.md](CHANGELOG-FORK.md).

## Origin and license

Based on [Lanis-Mobile](https://github.com/lanis-mobile/lanis) – many thanks to everyone who contributed to it. License: [GPL-3.0](LICENSE). The Manrope font is licensed under the SIL Open Font License 1.1.
