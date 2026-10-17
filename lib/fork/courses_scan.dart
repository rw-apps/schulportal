import 'package:liblanis/liblanis.dart';

import 'ui/courses/course_detail_model.dart'
    show attendanceCounts, examSections;
import 'ui/courses/courses_model.dart';

/// Gespeicherte Auswertung aller Kursseiten eines Kontos (je Konto,
/// TypedSettings, roher Schlüssel wie fork-notify/sent).
const courseScanSetting = 'fork-courses/scan';

/// Eine anstehende Leistungskontrolle („26.11.2026 Arbeit, 3., 4. Std.“).
class ScanExam {
  const ScanExam({
    required this.course,
    required this.subject,
    required this.day,
    required this.text,
  });

  /// Kurs-ID (CourseItem.id).
  final String course;

  /// Fach wie in der Fächerliste („Mathematik“).
  final String subject;
  final DateTime day;

  /// Art und Stunden ohne Datum („Arbeit, 3., 4. Std. (90 Min.)“).
  final String text;

  String get key => '$course|${_ymd(day)}';

  /// „Arbeit, 3., 4. Std. (90 Min.)“ → „Arbeit“.
  String get kind {
    final i = text.indexOf(',');
    return (i < 0 ? text : text.substring(0, i)).trim();
  }

  /// „Arbeit, 3., 4. Std. (90 Min.)“ → „3., 4. Std. (90 Min.)“; null ohne
  /// Angabe.
  String? get hours {
    final i = text.indexOf(',');
    if (i < 0) return null;
    final rest = text.substring(i + 1).trim();
    return rest.isEmpty ? null : rest;
  }

  Map<String, dynamic> toJson() => {
    'c': course,
    's': subject,
    'd': _ymd(day),
    'x': text,
  };

  static ScanExam? fromJson(Object? j) {
    if (j is! Map) return null;
    final day = DateTime.tryParse('${j['d']}');
    if (day == null) return null;
    return ScanExam(
      course: '${j['c'] ?? ''}',
      subject: '${j['s'] ?? ''}',
      day: day,
      text: '${j['x'] ?? ''}',
    );
  }
}

/// Auswertung der Kursseiten des laufenden Halbjahrs.
///
/// Was gespeichert wird (Entscheidung 17.10.26): je Kurs nur die ANZAHL der
/// Noten und die anstehenden Leistungskontrollen mit Datum und Art. Ursache:
/// Für „Neue Note in Mathematik“ reicht die Anzahl; die Noten selbst
/// bleiben im Arbeitsspeicher (GradesCache) – sie sind das Sensibelste der
/// App. Grenze: Ändert eine Lehrkraft eine Note, ohne dass die Anzahl
/// steigt, gibt es keinen Hinweis.
class CourseScan {
  const CourseScan({
    required this.day,
    required this.marks,
    required this.exams,
  });

  /// Tag der Auswertung (Hintergrund: höchstens einmal täglich).
  final DateTime day;

  /// Anzahl Noten je Kurs-ID. Fehlt ein Kurs, wurde er nie geladen.
  final Map<String, int> marks;

  /// Leistungskontrollen ab dem Tag der Auswertung, nach Datum.
  final List<ScanExam> exams;

  Map<String, dynamic> toJson() => {
    'day': _ymd(day),
    'marks': marks,
    'exams': [for (final e in exams) e.toJson()],
  };

  static CourseScan? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final day = DateTime.tryParse('${j['day']}');
    if (day == null) return null;
    final m = j['marks'];
    return CourseScan(
      day: day,
      marks: {
        if (m is Map)
          for (final e in m.entries)
            if (e.value is int) '${e.key}': e.value as int,
      },
      exams: [
        for (final x in (j['exams'] is List ? j['exams'] as List : const []))
          ?ScanExam.fromJson(x),
      ],
    );
  }

  /// Anstehende Arbeiten ab [now] (heute eingeschlossen).
  List<ScanExam> upcoming(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (final e in exams)
        if (!e.day.isBefore(today)) e,
    ];
  }
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Anstehende Leistungskontrollen aller [courses] aus den geladenen
/// Kursseiten, nach Datum (bei gleichem Tag nach Fach).
///
/// Je Kurs und Tag nur ein Eintrag, der ausführlichste. Ursache: Das Portal
/// nennt jede Arbeit zweimal – unter „Kommende“ mit Stunden und unter
/// „Alle“ nur mit Art (examSections fasst nur innerhalb eines Abschnitts
/// zusammen).
List<ScanExam> upcomingExams(
  List<CourseItem> courses,
  Map<String, DetailedLesson> pages,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final byKey = <String, ScanExam>{};
  for (final c in courses) {
    final d = pages[c.id];
    if (d == null) continue;
    for (final s in examSections(d.exams)) {
      for (final l in s.lines) {
        final day = l.date;
        if (day == null || day.isBefore(today)) continue;
        final e = ScanExam(
          course: c.id,
          subject: c.title,
          day: day,
          text: l.text,
        );
        final old = byKey[e.key];
        if (old == null || e.text.length > old.text.length) byKey[e.key] = e;
      }
    }
  }
  return byKey.values.toList()..sort((a, b) {
    final d = a.day.compareTo(b.day);
    return d != 0 ? d : a.subject.compareTo(b.subject);
  });
}

/// Fehlzeiten aller geladenen Kursseiten zusammen; null, wenn keine Seite
/// eine Anwesenheit nennt.
({int excused, int missing})? absenceTotals(Iterable<DetailedLesson> pages) {
  var e = 0, m = 0;
  var any = false;
  for (final d in pages) {
    final c = attendanceCounts(d.attendances);
    if (c == null) continue;
    any = true;
    e += c.excused;
    m += c.missing;
  }
  return any ? (excused: e, missing: m) : null;
}

/// Neue Auswertung aus den geladenen Seiten; Kurse, die diesmal fehlten
/// (Ladefehler), behalten ihren alten Stand aus [old] – sonst gälte ihre
/// nächste Note nach einem Fehlschlag nicht als neu.
CourseScan scanFrom(
  List<CourseItem> courses,
  Map<String, DetailedLesson> pages,
  DateTime now, {
  CourseScan? old,
}) {
  final loaded = {
    for (final c in courses)
      if (pages.containsKey(c.id)) c.id,
  };
  return CourseScan(
    day: DateTime(now.year, now.month, now.day),
    marks: {
      if (old != null)
        for (final e in old.marks.entries)
          if (!loaded.contains(e.key)) e.key: e.value,
      for (final id in loaded)
        id: pages[id]!.marks.where((m) => m.mark.trim().isNotEmpty).length,
    },
    exams: [
      if (old != null)
        for (final e in old.upcoming(now))
          if (!loaded.contains(e.course)) e,
      ...upcomingExams(courses, pages, now),
    ]..sort((a, b) => a.day.compareTo(b.day)),
  );
}

/// Was seit [old] neu ist: Fächer mit mehr Noten, neue Arbeitstermine.
///
/// Nur für Kurse, die [old] schon kannte. Ursache: Bei der ersten
/// Auswertung oder einem neuen Halbjahr (neue Kurs-IDs) wäre sonst jede
/// vorhandene Note und jeder Termin „neu“ – eine Flut von Hinweisen ohne
/// Neuigkeit.
({List<String> marks, List<ScanExam> exams}) newsSince(
  CourseScan? old,
  CourseScan fresh,
  Map<String, String> subjects,
) {
  if (old == null) return (marks: const [], exams: const []);
  final known = old.exams.map((e) => e.key).toSet();
  return (
    marks: [
      for (final e in fresh.marks.entries)
        if (old.marks[e.key] case final before?)
          if (e.value > before) subjects[e.key] ?? '',
    ].where((s) => s.isNotEmpty).toSet().toList(),
    exams: [
      for (final e in fresh.exams)
        if (old.marks.containsKey(e.course) && !known.contains(e.key)) e,
    ],
  );
}

/// Gespeicherte Auswertung, null = noch keine.
CourseScan? storedCourseScan(TypedSettings s) {
  try {
    return CourseScan.fromJson(s.getJsonMap(courseScanSetting));
  } catch (_) {
    return null;
  }
}

void storeCourseScan(TypedSettings s, CourseScan scan) =>
    s.setJsonMap(courseScanSetting, scan.toJson());
