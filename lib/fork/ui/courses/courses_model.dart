import 'package:liblanis/liblanis.dart';

import '../plan/plan_model.dart';
import 'course_detail_model.dart';

/// Ein Kurs aus „Mein Unterricht“, aufbereitet für den Bereich „Unterricht“.
class CourseItem {
  const CourseItem({
    required this.id,
    required this.title,
    required this.fullName,
    this.teachers = const [],
    this.teacherCodes = const [],
    this.topic,
    this.date,
    this.homework,
    this.homeworkDone = false,
    this.attendance,
    this.missing = 0,
    this.files = 0,
    this.colorSlot,
    this.extra = false,
  });

  /// Kurs-ID wie im Portal (bei Eltern mit „&p=Kind-ID“, siehe
  /// parseParentLessons) – für die Kursseite.
  final String id;

  /// „Naturwissenschaften“ statt „Naturwissenschaften 06 xy (061NAWI05-IGS)“.
  final String title;
  final String fullName;

  /// Ausgeschrieben („Anna Alt“), sonst das Kürzel.
  final List<String> teachers;

  /// Kürzel in derselben Reihenfolge wie [teachers] (leer, wo das Portal
  /// keins nennt) – für „Schreiben“ und die Zuordnung zum Stundenplan.
  final List<String> teacherCodes;

  /// Neuester Eintrag der Kursmappe.
  final String? topic;
  final DateTime? date;
  final String? homework;
  final bool homeworkDone;

  /// „Fehlstunden 2 · entschuldigt 2“; null, wenn nichts eingetragen ist.
  final String? attendance;

  /// Fehlstunden laut Anwesenheit (attendanceCounts.missing).
  final int missing;
  final int files;

  /// Fachfarbe wie im Wochenraster; null, wenn der Kurs nicht im Plan steht.
  final int? colorSlot;

  /// Weiteres Angebot (Ganztag, Training …), siehe isExtraOffer.
  final bool extra;

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
/// Namen, sonst wären sie nicht zu unterscheiden. Mit [plan] bekommt jeder
/// Kurs seine Fachfarbe; Kurse ohne Platz im Plan gelten als weiteres
/// Angebot. Eine Hausaufgabe ohne Text hat [CourseItem.homework] = '' (die
/// Oberfläche schreibt dann „Hausaufgabe eingetragen“ in der Sprache).
List<CourseItem> courseItemsFrom(
  Lessons lessons, {
  Map<String, String> ownNames = const {},
  KidPlan? plan,
}) {
  final slots = plan == null ? const <String, int>{} : subjectColorSlots(plan);
  // Überschriften, die mehrere Kurse mit VERSCHIEDENEN vollen Namen teilen.
  // Sind auch die vollen Namen gleich (Schule A: zweimal „Ganztagsangebot 06 …“),
  // hilft der volle Name nicht – dann bleibt die kurze Überschrift.
  final fullByTitle = <String, Set<String>>{};
  for (final l in lessons) {
    (fullByTitle[courseTitle(l.name)] ??= {}).add(l.name.trim());
  }
  CourseItem item(Lesson l) {
    // Name und Kürzel als PAAR filtern. Ursache (Prüfbefund 17.10.26): Die
    // Namen wurden einzeln um leere Einträge gekürzt, die Kürzel nicht – die
    // Kursseite ordnete dann „Schreiben“ der falschen Lehrkraft zu. Ein leer
    // gespeicherter eigener Name gilt als „nicht gesetzt“ (wie
    // KidPlan.withTeacherNames).
    final pairs = <(String, String)>[];
    for (final t in l.teachers) {
      final kz = t.teacherKuerzel ?? '';
      final own = ownNames[kz]?.trim() ?? '';
      final name = own.isNotEmpty
          ? own
          : (t.teacher != null && t.teacher!.trim().isNotEmpty
                ? portalNameToDisplay(t.teacher!)
                : kz);
      if (name.isNotEmpty) pairs.add((kz, name));
    }
    final codes = [for (final p in pairs) p.$1];
    final short = plan == null
        ? null
        : courseShortIn(plan, courseTitle(l.name), codes.toSet()..remove(''));
    return CourseItem(
      id: l.courseID,
      title: (fullByTitle[courseTitle(l.name)]?.length ?? 0) > 1
          ? l.name.trim()
          : courseTitle(l.name),
      teacherCodes: codes,
      colorSlot: short == null ? null : slots[short],
      extra: plan != null && isExtraOffer(l.name, inPlan: short != null),
      missing: attendanceCounts(l.attendances ?? const {})?.missing ?? 0,
      fullName: l.name.trim(),
      teachers: [for (final p in pairs) p.$2],
      topic: _blank(l.currentEntry?.topicTitle),
      date: l.currentEntry?.topicDate,
      homework: l.currentEntry?.homework == null
          ? null
          : (_blank(l.currentEntry?.homework?.description) ?? ''),
      homeworkDone: l.currentEntry?.homework?.homeWorkDone ?? false,
      attendance: attendanceLine(l.attendances),
      files: l.currentEntry?.files.length ?? 0,
    );
  }

  final items = [for (final l in lessons) item(l)];
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
