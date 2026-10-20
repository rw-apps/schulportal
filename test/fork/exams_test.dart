import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/courses_scan.dart';
import 'package:lanis/fork/exams.dart';
import 'package:lanis/fork/ui/today/today_from_lanis.dart' show withCourseExams;
import 'package:lanis/fork/ui/today/today_model.dart';

/// Gemeinsame Regel für Arbeiten (exams.dart) – synthetische Daten.
void main() {
  final now = DateTime(2026, 10, 20, 9);
  ScanExam scan(String subject, DateTime day, String text) =>
      ScanExam(course: subject, subject: subject, day: day, text: text);
  WeekItem cal(String title, DateTime day, {String? time}) =>
      WeekItem(day: day, title: title, kind: WeekKind.exam, time: time);

  test('Kursmappe gewinnt, Kalender ergänzt bereinigt', () {
    final exams = upcomingExamsOf(
      scan: [
        scan(
          'Englisch',
          DateTime(2026, 10, 27),
          'Arbeit, 5./6. Std. (60 Min.)',
        ),
        scan('Mathematik', DateTime(2026, 11, 3), 'Arbeit, 3. Std.'),
      ],
      calendar: [
        // Dieselbe Arbeit im Kalender: entfällt.
        cal('Englisch 09C Arbeit', DateTime(2026, 10, 27), time: '11:40'),
        // Kurzform des Fachs: ebenfalls dieselbe.
        cal('Mathe 9C Test', DateTime(2026, 11, 3)),
        // Nur im Kalender: kommt dazu, ohne Klassenangabe.
        cal(
          'Naturwissenschaften 06 xy Lernkontrolle',
          DateTime(2026, 11, 2),
          time: '08:00',
        ),
        // Kein Art-Wort: Titel bleibt Fach.
        cal('Vokabeltest-Woche', DateTime(2026, 11, 4)),
        WeekItem(
          day: DateTime(2026, 11, 5),
          title: 'Elternabend',
          kind: WeekKind.event,
        ),
      ],
      now: now,
      until: halfYearEnd(now),
    );
    expect(
      [for (final e in exams) e.title],
      [
        'Englisch: Arbeit',
        'Naturwissenschaften: Lernkontrolle',
        'Mathematik: Arbeit',
        'Vokabeltest-Woche',
      ],
    );
    expect(exams.first.detail, '5./6. Std. (60 Min.)');
    expect(exams[1].detail, '08:00');
    expect(exams[1].fromCalendar, isTrue);
  });

  test('Zeitraum: ab heute bis Halbjahresende', () {
    expect(halfYearEnd(now), DateTime(2027, 1, 31));
    expect(halfYearEnd(DateTime(2027, 1, 10)), DateTime(2027, 1, 31));
    expect(halfYearEnd(DateTime(2027, 3, 1)), DateTime(2027, 7, 31));
    final exams = upcomingExamsOf(
      scan: [
        scan('Deutsch', DateTime(2026, 10, 19), 'Arbeit'),
        scan('Deutsch', DateTime(2026, 10, 20), 'Arbeit'),
        scan('Deutsch', DateTime(2027, 1, 31), 'Arbeit'),
        scan('Deutsch', DateTime(2027, 2, 1), 'Arbeit'),
      ],
      calendar: const [],
      now: now,
      until: halfYearEnd(now),
    );
    expect(
      [for (final e in exams) e.day],
      [DateTime(2026, 10, 20), DateTime(2027, 1, 31)],
    );
  });

  test('Heute: übrige Termine bleiben, Arbeiten nach gemeinsamer Regel', () {
    final week = withCourseExams(
      [
        WeekItem(
          day: DateTime(2026, 10, 22),
          title: 'Elternabend',
          kind: WeekKind.event,
        ),
        cal('Englisch 09C Arbeit', DateTime(2026, 10, 27), time: '11:40'),
      ],
      CourseScan(
        day: DateTime(2026, 10, 20),
        marks: const {},
        exams: [
          scan('Englisch', DateTime(2026, 10, 27), 'Arbeit, 5./6. Std.'),
          // Außerhalb der 14 Tage von Heute.
          scan('Physik', DateTime(2026, 12, 3), 'Arbeit'),
        ],
      ),
      now,
      childIndex: 1,
    );
    expect(
      [for (final w in week) w.title],
      ['Elternabend', 'Englisch: Arbeit'],
    );
    expect(week.last.time, '5./6. Std.');
    expect(week.last.childIndex, 1);
  });
}
