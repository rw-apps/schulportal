import 'package:liblanis/liblanis.dart';

import '../plan/plan_model.dart' show portalNameToDisplay;

/// Ein Kurs aus „Mein Unterricht“, aufbereitet für den Bereich „Unterricht“.
class CourseItem {
  const CourseItem({
    required this.id,
    required this.title,
    required this.fullName,
    this.teachers = const [],
    this.topic,
    this.date,
    this.homework,
    this.homeworkDone = false,
    this.attendance,
    this.files = 0,
  });

  /// Kurs-ID wie im Portal (bei Eltern mit „&p=Kind-ID“, siehe
  /// parseParentLessons) – für die Kursseite.
  final String id;

  /// „Naturwissenschaften“ statt „Naturwissenschaften 06 xy (061NAWI05-IGS)“.
  final String title;
  final String fullName;

  /// Ausgeschrieben („Anna Alt“), sonst das Kürzel.
  final List<String> teachers;

  /// Neuester Eintrag der Kursmappe.
  final String? topic;
  final DateTime? date;
  final String? homework;
  final bool homeworkDone;

  /// „Fehlstunden 2 · entschuldigt 2“; null, wenn nichts eingetragen ist.
  final String? attendance;
  final int files;

  bool get hasOpenHomework => homework != null && !homeworkDone;
}

/// Wörter bis zum ersten mit Ziffer oder Klammer („Projekt Text 6 …“ →
/// „Projekt Text“). Ursache: Die Kursnamen tragen Klasse und Kurscode; als
/// Überschrift reicht das Fach.
String courseTitle(String name) {
  final words = <String>[];
  for (final w in name.split(RegExp(r'\s+'))) {
    if (w.isEmpty) continue;
    if (RegExp(r'[\d(]').hasMatch(w)) break;
    words.add(w);
  }
  return words.isEmpty ? name.trim() : words.join(' ');
}

/// Anwesenheit als kurze Zeile: nur Fehlzeiten ungleich 0, Spaltennamen wie
/// im Portal („Fehlend“, „Entschuldigt“ …). „Anwesend“ entfällt – an Schule A
/// stand dort bei jedem Kurs eine Zahl (Export 16.10.26), ohne Aussage.
String? attendanceLine(Map<String, String>? a) {
  if (a == null) return null;
  final parts = [
    for (final e in a.entries)
      if (e.value.trim().isNotEmpty &&
          e.value.trim() != '0' &&
          !e.key.toLowerCase().startsWith('anwesend'))
        '${e.key.isEmpty ? '' : e.key[0].toUpperCase()}${e.key.length > 1 ? e.key.substring(1) : ''} ${e.value.trim()}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Kurse für den Bereich „Unterricht“, neueste Einträge zuerst.
///
/// Gleiche Überschriften mit verschiedenen Kursnamen bekommen den vollen
/// Namen, sonst wären sie nicht zu unterscheiden.
List<CourseItem> courseItemsFrom(
  Lessons lessons, {
  Map<String, String> ownNames = const {},
}) {
  // Überschriften, die mehrere Kurse mit VERSCHIEDENEN vollen Namen teilen.
  // Sind auch die vollen Namen gleich (Schule A: zweimal „Ganztagsangebot 06 …“),
  // hilft der volle Name nicht – dann bleibt die kurze Überschrift.
  final fullByTitle = <String, Set<String>>{};
  for (final l in lessons) {
    (fullByTitle[courseTitle(l.name)] ??= {}).add(l.name.trim());
  }
  final items = [
    for (final l in lessons)
      CourseItem(
        id: l.courseID,
        title: (fullByTitle[courseTitle(l.name)]?.length ?? 0) > 1
            ? l.name.trim()
            : courseTitle(l.name),
        fullName: l.name.trim(),
        teachers: [
          for (final t in l.teachers)
            ownNames[t.teacherKuerzel ?? ''] ??
                (t.teacher != null && t.teacher!.isNotEmpty
                    ? portalNameToDisplay(t.teacher!)
                    : (t.teacherKuerzel ?? '')),
        ].where((s) => s.isNotEmpty).toList(),
        topic: _blank(l.currentEntry?.topicTitle),
        date: l.currentEntry?.topicDate,
        homework:
            _blank(l.currentEntry?.homework?.description) ??
            (l.currentEntry?.homework != null
                ? 'Hausaufgabe eingetragen'
                : null),
        homeworkDone: l.currentEntry?.homework?.homeWorkDone ?? false,
        attendance: attendanceLine(l.attendances),
        files: l.currentEntry?.files.length ?? 0,
      ),
  ];
  items.sort((a, b) {
    final da = a.date;
    final db = b.date;
    if (da == null && db == null) return a.title.compareTo(b.title);
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  });
  return items;
}

String? _blank(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}
