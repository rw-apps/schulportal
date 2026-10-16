import '../today/today_model.dart';

/// Beispieldaten für den Entwurf. Alle Namen, Lehrkräfte und Räume sind
/// erfunden (öffentliches Repository). Schulnamen und Zählweise (Stunden an
/// der Schule B, Blöcke an Schule A mit den Zeiten aus dem Export vom
/// 16.10.26) sind echt, damit der Entwurf realistisch aussieht.
///
/// Fester Zeitpunkt Di 20.10.26, 10:50 (laufende Stunde, Pause, Änderungen
/// heute und morgen sichtbar), unabhängig von der echten Uhrzeit.
FamilyToday demoFamily() {
  final now = DateTime(2026, 10, 20, 10, 50);
  DateTime d(int day) => DateTime(2026, 10, day);
  return FamilyToday(
    now: now,
    isDemo: true,
    kids: [
      ChildToday(
        firstName: 'Lena',
        school: 'Schule B',
        className: '8b',
        colorIndex: 0,
        now: const LessonRef(
          subject: 'Mathematik',
          start: '09:50',
          end: '11:20',
          room: 'R 204',
          teacher: 'Fr. Becker',
        ),
        next: const LessonRef(
          subject: 'Englisch',
          start: '11:40',
          end: '12:25',
          room: 'R 117',
        ),
        changes: [
          ChangeItem(
            day: d(20),
            slot: '5./6. Std.',
            subject: 'Deutsch',
            kind: ChangeKind.substitution,
            detail: 'Hr. Sommer, Raum 112',
          ),
          ChangeItem(
            day: d(21),
            slot: '1. Std.',
            subject: 'Sport',
            kind: ChangeKind.cancelled,
          ),
        ],
        openHomework: 2,
        unreadMessages: 1,
      ),
      ChildToday(
        firstName: 'Jonas',
        school: 'Schule A',
        className: '6 NI',
        colorIndex: 1,
        now: const LessonRef(
          subject: 'Englisch',
          start: '10:30',
          end: '11:45',
          room: 'R106',
          teacher: 'Hr. Wolf',
        ),
        next: const LessonRef(
          subject: 'Mathematik',
          start: '12:30',
          end: '13:45',
          room: 'R106',
        ),
        changes: [
          ChangeItem(
            day: d(22),
            slot: '1. Block',
            subject: 'Textil',
            kind: ChangeKind.roomChange,
            detail: 'R101 statt R106',
          ),
        ],
        openHomework: 1,
        canReportAbsence: true,
      ),
    ],
    week: [
      WeekItem(
        day: d(21),
        title: 'Klassenarbeit Englisch',
        kind: WeekKind.exam,
        childIndex: 0,
      ),
      WeekItem(
        day: d(22),
        title: 'Wandertag Taunus',
        kind: WeekKind.event,
        childIndex: 1,
        time: '08:00',
      ),
      WeekItem(
        day: d(22),
        title: 'Elternabend 6 NI',
        kind: WeekKind.event,
        childIndex: 1,
        time: '19:30',
      ),
      WeekItem(
        day: d(23),
        title: 'Abgabe Referat Biologie',
        kind: WeekKind.deadline,
        childIndex: 0,
      ),
      WeekItem(
        day: d(26),
        title: 'Pädagogischer Tag – unterrichtsfrei',
        kind: WeekKind.free,
      ),
    ],
  );
}
