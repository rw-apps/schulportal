import 'package:liblanis/liblanis.dart';

import '../courses/courses_model.dart' show courseTitle;
import '../plan/plan_model.dart' show portalNameToDisplay;

/// Eine Lehrkraft aus dem Unterricht des Kindes als mögliche Empfängerin.
class RecipientCandidate {
  const RecipientCandidate({
    required this.kuerzel,
    required this.display,
    required this.lastName,
    required this.subjects,
    this.firstName,
  });

  final String kuerzel;

  /// „Anna Alt“
  final String display;
  final String lastName;
  final String? firstName;

  /// „Mathematik, Training“ – woher das Kind sie kennt.
  final List<String> subjects;
}

/// Lehrkräfte aus „Mein Unterricht“, je Kürzel einmal, mit ihren Fächern.
///
/// Ursache (Konzept 17.10.26): Statt das Lehrerverzeichnis der ganzen Schule
/// zu durchsuchen, wählt man aus dem Unterricht des eigenen Kindes
/// („Mathematik – Herr …“). Grenze: Wer keinen Kurs in „Mein Unterricht“
/// hat (Schule A: Ästhetik), fehlt hier – dafür bleibt die freie Suche.
List<RecipientCandidate> candidatesFrom(Lessons lessons) {
  final byK = <String, RecipientCandidate>{};
  final order = <String>[];
  // Kleinste Teamgröße je Kürzel: Wer nur in großen Teams vorkommt (Schule A:
  // Ganztagsangebot mit sechs Lehrkräften, Export 16.10.26), kommt ans Ende –
  // die Fachlehrkräfte sollen oben stehen.
  final team = <String, int>{};
  for (final l in lessons) {
    for (final t in l.teachers) {
      final k = t.teacherKuerzel?.trim() ?? '';
      final n = l.teachers.length;
      if ((team[k] ?? 1 << 30) > n) team[k] = n;
    }
  }
  for (final l in lessons) {
    final subject = courseTitle(l.name);
    for (final t in l.teachers) {
      final k = t.teacherKuerzel?.trim();
      final raw = t.teacher?.trim();
      if (k == null || k.isEmpty || raw == null || raw.isEmpty) continue;
      final had = byK[k];
      if (had != null) {
        if (!had.subjects.contains(subject)) had.subjects.add(subject);
        continue;
      }
      final parts = raw.split(',');
      byK[k] = RecipientCandidate(
        kuerzel: k,
        display: portalNameToDisplay(raw),
        lastName: parts.first.trim(),
        firstName: parts.length > 1 ? parts.sublist(1).join(',').trim() : null,
        subjects: [subject],
      );
      order.add(k);
    }
  }
  final big = <String>[
    for (final k in order)
      if ((team[k] ?? 0) > 3) k,
  ];
  return [
    for (final k in order)
      if (!big.contains(k)) byK[k]!,
    for (final k in big) byK[k]!,
  ];
}

/// Passende Einträge der Portal-Suche (nachrichten.php?a=searchRecipt) zu
/// einer Lehrkraft.
///
/// Gesucht wird mit dem Nachnamen; die Treffer kommen als Text, dessen Form
/// das Portal vorgibt (nicht dokumentiert). Deshalb tolerant: Lehrkraft
/// (`isTeacher`), Nachname enthalten, und – wenn vorhanden – Vorname oder
/// Kürzel. Grenze: Gibt es danach mehrere, wählt der Nutzer; nie raten.
List<ReceiverEntry> matchReceivers(
  List<ReceiverEntry> results,
  RecipientCandidate c,
) {
  String n(String s) => s.toLowerCase();
  final teachers = [
    for (final r in results)
      if (r.isTeacher && n(r.name).contains(n(c.lastName))) r,
  ];
  if (teachers.length <= 1) return teachers;
  final first = c.firstName?.split(' ').first;
  final narrowed = [
    for (final r in teachers)
      if ((first != null && n(r.name).contains(n(first))) ||
          n(r.name).contains(n(c.kuerzel)))
        r,
  ];
  return narrowed.isEmpty ? teachers : narrowed;
}
