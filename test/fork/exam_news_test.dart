import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/courses_scan.dart';
import 'package:lanis/fork/exams.dart';
import 'package:lanis/fork/notify/notify_task.dart';
import 'package:lanis/fork/ui/live/live_data.dart' show shortFirstName;

/// Hinweise auf neue Arbeiten (notify_task.dart, examNews) – synthetisch.
void main() {
  final now = DateTime(2026, 10, 20, 16);
  final physik = UpcomingExam(
    day: DateTime(2026, 11, 2),
    subject: 'Physik',
    kind: 'Lernkontrolle',
    fromCalendar: true,
  );

  test('erster Lauf: Kalender-Arbeiten nur merken', () {
    final r = examNews(
      scanNews: const [],
      calendarOnly: [physik],
      known: null,
      now: now,
    );
    expect(r.calendar, isEmpty);
    expect(r.remember, ['2026-11-02|Physik']);
  });

  test('neue Kalender-Arbeit einmal, danach nicht mehr', () {
    final first = examNews(
      scanNews: const [],
      calendarOnly: [physik],
      known: const [],
      now: now,
    );
    expect(first.calendar, [physik]);
    final again = examNews(
      scanNews: const [],
      calendarOnly: [physik],
      known: first.remember,
      now: now,
    );
    expect(again.calendar, isEmpty);
  });

  test('schon als Kalender-Arbeit gemeldet: Kursmappe meldet nicht erneut', () {
    final r = examNews(
      scanNews: [
        ScanExam(
          course: 'p',
          subject: 'Physik',
          day: DateTime(2026, 11, 2),
          text: 'Lernkontrolle, 3. Std.',
        ),
        ScanExam(
          course: 'm',
          subject: 'Mathematik',
          day: DateTime(2026, 11, 3),
          text: 'Arbeit',
        ),
      ],
      calendarOnly: const [],
      known: const ['2026-11-02|Physik', '2026-10-01|Alt'],
      now: now,
    );
    expect([for (final e in r.scan) e.subject], ['Mathematik']);
    // Vergangene Tage fallen aus dem Merkzettel.
    expect(r.remember, ['2026-11-02|Physik']);
  });

  test('Vorname wie in der App', () {
    expect(shortFirstName(' Lena Marie '), 'Lena');
    expect(shortFirstName('Anna-Lena'), 'Anna-Lena');
    expect(shortFirstName(''), '');
  });
}
