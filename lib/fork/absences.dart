import 'dart:convert';

import 'package:liblanis/liblanis.dart';

import 'data/course_rules.dart';
import 'ui/courses/courses_model.dart';

/// Eine Stunde, in der das Kind laut Kursmappe nicht anwesend war.
class AbsenceItem {
  const AbsenceItem({
    required this.course,
    required this.entry,
    required this.subject,
    required this.status,
    required this.excused,
    this.day,
    this.hours,
    this.teacherCodes = const [],
  });

  /// Kurs-ID (CourseItem.id) und Eintrag der Stunde (CurrentEntry.entryID).
  final String course;
  final String entry;
  final String subject;

  /// Wortlaut des Portals („fehlend“, „entschuldigt“ …).
  final String status;

  /// Entschuldigt laut Portal.
  final bool excused;
  final DateTime? day;

  /// „3.“ bzw. „3. - 4.“ (CurrentEntry.schoolHours).
  final String? hours;
  final List<String> teacherCodes;

  String get key => '$course|$entry';
}

/// Entschuldigt? Erst „unentschuldigt“/„fehl…“ prüfen – „unentschuldigt“
/// enthält „entschuldigt“ (CourseRules.missing vor excused, wie
/// attendanceCounts).
bool isExcused(String presence) {
  final p = presence.toLowerCase();
  if (CourseRules.missing.any(p.contains)) return false;
  return CourseRules.excused.any(p.contains);
}

/// Alle Abwesenheiten aus den geladenen Kursseiten, neueste zuerst.
///
/// Quelle: Spalte „Anwesenheit“ im Verlauf jeder Kursmappe (CurrentEntry.
/// presence); „anwesend“ und „nicht erfasst“ zählen nicht
/// (CourseRules.presenceNeutral). Grenze: nur das geladene Halbjahr, und nur
/// Stunden, die die Lehrkraft in die Kursmappe eingetragen hat.
List<AbsenceItem> absencesFrom(
  List<CourseItem> courses,
  Map<String, DetailedLesson> pages,
) {
  final out = <AbsenceItem>[];
  for (final c in courses) {
    final d = pages[c.id];
    if (d == null) continue;
    for (final e in d.history) {
      final p = (e.presence ?? '').trim();
      if (CourseRules.presenceNeutral.contains(p.toLowerCase())) continue;
      out.add(
        AbsenceItem(
          course: c.id,
          entry: e.entryID,
          subject: c.title,
          status: p,
          excused: isExcused(p),
          day: e.topicDate,
          hours: e.schoolHours?.trim(),
          teacherCodes: c.teacherCodes,
        ),
      );
    }
  }
  out.sort(
    (a, b) => (b.day ?? DateTime(2000)).compareTo(a.day ?? DateTime(2000)),
  );
  return out;
}

/// Gesendete Entschuldigungen je Konto: Abwesenheit → Tag des Sendens.
/// Ursache: Bis die Lehrkraft im Portal „entschuldigt“ einträgt, vergehen
/// oft Tage; ohne Vermerk schriebe man doppelt. Grenze: Wurde außerhalb der
/// App entschuldigt, fehlt der Vermerk.
const absenceSentSetting = 'fork-absence/sent';

Map<String, DateTime> decodeSent(String? s) {
  if (s == null || s.isEmpty) return const {};
  try {
    final v = jsonDecode(s);
    if (v is! Map) return const {};
    return {
      for (final e in v.entries)
        if (DateTime.tryParse('${e.value}') case final d?) '${e.key}': d,
    };
  } catch (_) {
    return const {};
  }
}

String encodeSent(Map<String, DateTime> m) =>
    jsonEncode({for (final e in m.entries) e.key: e.value.toIso8601String()});
