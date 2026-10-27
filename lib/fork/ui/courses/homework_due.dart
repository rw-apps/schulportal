import 'package:liblanis/liblanis.dart';

import '../../homework_ledger.dart';
import '../live/live_data.dart';
import '../plan/plan_model.dart' show effectiveChoice;
import '../today/today_from_lanis.dart' show freeDaysFrom;
import 'course_detail_model.dart' show nextLessonOf;
import 'courses_model.dart';

/// Vermutete Frist einer Hausaufgabe je Kurs: die nächste Stunde des Kurses
/// nach dem Tag des Aufgebens – aus dem Stundenplan (nextLessonOf, dieselbe
/// Zuordnung Kurs ↔ Plan wie „Nächste Stunde“ auf der Kursseite), schulfreie
/// Tage aus dem Kalender übersprungen (freeDaysFrom).
///
/// Ursache (Frage 27.10.26: „Wann sind Hausaufgaben nicht mehr
/// relevant?“): Das Portal nennt nur den Tag des Aufgebens, keine Frist;
/// meist gilt die nächste Stunde. Grenzen: Ausfall und Vertretung zählen
/// nicht (die Frist kann später liegen), gesucht wird höchstens 22 Tage
/// weit; ohne Stundenplan null (dann nur die Halbjahresgrenze,
/// homeworkExpiry).
DateTime? Function(String course, DateTime? given)? liveHomeworkDue(
  LiveSnapshot s,
) {
  final live = s.offers('stundenplan.php') && s.timetable.content != null
      ? livePlanOf(s)
      : null;
  if (live == null) return null;
  final items = courseItemsFrom(
    s.lessons.content ?? const [],
    ownNames: s.ownNames,
    plan: live.plan,
  );
  final byId = {for (final i in items) i.id: i};
  final choice = effectiveChoice(live.auto, s.userChoice);
  final cal = s.offers('kalender.php')
      ? (s.calendar.content ?? const <CalendarEvent>[])
      : const <CalendarEvent>[];
  final className = liveClassName(s);
  final cache = <String, DateTime?>{};
  return (course, given) {
    if (given == null) return null;
    final i = byId[course];
    if (i == null) return null;
    return cache.putIfAbsent('$course|${given.toIso8601String()}', () {
      // Spät am Tag des Aufgebens: Stunden dieses Tages zählen nicht mehr.
      final from = DateTime(given.year, given.month, given.day, 23, 59);
      final codes = {...i.teacherCodes}..remove('');
      return nextLessonOf(
        live.plan,
        choice,
        i.title,
        codes,
        from,
        free: cal.isEmpty
            ? const {}
            : freeDaysFrom(cal, from, className: className, days: 22),
      )?.day;
    });
  };
}

/// Offene Hausaufgaben für Heute: wie die Liste unter „Unterricht“
/// (homeworkLists mit Frist), abgelaufene zählen nicht mit.
int liveOpenHomework(LiveSnapshot s) => homeworkLists(
  s.lessons.content ?? const <Lesson>[],
  s.homework,
  subjectOf: (l) => l.name,
  dueOf: liveHomeworkDue(s),
).open.length;
