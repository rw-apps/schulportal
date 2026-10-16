import '../today/today_model.dart';

/// Beispieldaten für die Vorschau. Alle Namen, Lehrkräfte und Räume sind
/// erfunden (öffentliches Repository). Schulnamen und Zählweise sind echt:
/// Schule A in Blöcken mit den Zeiten aus dem Export vom 16.10.26; die Stunden-
/// zeiten der Schule B sind GESCHÄTZT (noch kein Export).
///
/// Lena hat absichtlich einen langen Tag (8 Stunden, 6 Fächer), damit die
/// Vorschau zeigt, dass Karte und Tagesleiste dabei lesbar bleiben.
///
/// Fester Zeitpunkt Di 20.10.26, 10:50, unabhängig von der echten Uhrzeit.
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
        periodsLabel: '8 Stunden heute',
        lessons: const [
          DayLesson(
            slot: '1.–2.',
            subject: 'Biologie',
            start: '08:00',
            end: '09:30',
            room: 'R 310',
          ),
          DayLesson(
            slot: '3.–4.',
            subject: 'Mathematik',
            start: '09:50',
            end: '11:20',
            room: 'R 204',
            teacher: 'Maria Becker',
          ),
          DayLesson(
            slot: '5.',
            subject: 'Deutsch',
            start: '11:40',
            end: '12:25',
            room: 'R 112',
            change: ChangeKind.substitution,
            changeDetail: 'Tim Sommer, R 112',
          ),
          DayLesson(
            slot: '6.',
            subject: 'Englisch',
            start: '12:30',
            end: '13:15',
            room: 'R 117',
          ),
          DayLesson(
            slot: '7.',
            subject: 'Erdkunde',
            start: '14:00',
            end: '14:45',
            room: 'R 021',
          ),
          DayLesson(
            slot: '8.',
            subject: 'Musik',
            start: '14:45',
            end: '15:30',
            room: 'Musiksaal',
          ),
        ],
        changes: [
          ChangeItem(
            day: d(20),
            slot: '5. Std.',
            subject: 'Deutsch',
            kind: ChangeKind.substitution,
            detail: 'Tim Sommer, R 112',
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
        lessons: const [
          DayLesson(
            slot: '1. Block',
            subject: 'Gesellschaftslehre',
            start: '09:00',
            end: '10:15',
            room: 'R106',
          ),
          DayLesson(
            slot: '2. Block',
            subject: 'Englisch',
            start: '10:30',
            end: '11:45',
            room: 'R106',
            teacher: 'Jan Wolf',
          ),
          DayLesson(
            slot: '3. Block',
            subject: 'Mathematik',
            start: '12:30',
            end: '13:45',
            room: 'R106',
          ),
        ],
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
