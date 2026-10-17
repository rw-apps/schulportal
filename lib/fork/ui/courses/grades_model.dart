import 'package:liblanis/liblanis.dart';

import 'courses_model.dart';

/// Notenübersicht über alle Kurse eines Kontos – nur Daten und Rechnung.
///
/// Quelle: die Kursseiten aus „Mein Unterricht“ (DetailedLesson.marks, Tabelle
/// „Leistungen“, liblanis getDetailedCourseView). Das Portal hat keine Seite
/// mit allen Noten; die Übersicht muss jede Kursseite einzeln abrufen.
///
/// Bewusst KEIN Durchschnitt (Entscheidung 17.10.26): Wie mündliche und
/// schriftliche Noten gewichtet werden, legt jede Lehrkraft fest – ein
/// errechneter Schnitt wäre oft schlicht falsch.

/// Ein Kurs mit seinen Noten.
class SubjectMarks {
  const SubjectMarks(this.course, this.marks);

  final CourseItem course;
  final List<LessonMark> marks;
}

/// Ergebnis für die Anzeige.
class GradesOverview {
  const GradesOverview({
    required this.withMarks,
    required this.without,
    required this.failed,
    required this.hasFirstHalf,
  });

  /// Kurse mit mindestens einer Note, Reihenfolge wie die Fächerliste.
  final List<SubjectMarks> withMarks;

  /// Fächer ohne Note (weitere Angebote wie Ganztag nicht – die führen fast
  /// nie Noten und machten die Liste nur länger).
  final List<CourseItem> without;

  /// Kurse, deren Seite nicht geladen werden konnte.
  final List<CourseItem> failed;

  /// Das Portal bietet ein 1. Halbjahr an (semester1URL einer Kursseite) –
  /// dann läuft das 2. und der Umschalter erscheint.
  final bool hasFirstHalf;

  int get markCount => withMarks.fold(0, (a, s) => a + s.marks.length);
}

/// Reihenfolge wie im Bereich „Unterricht“: Platz im Wochenplan (= Fachfarbe),
/// ohne Platz ans Ende, dann nach Name; weitere Angebote zuletzt.
int compareCourses(CourseItem a, CourseItem b) {
  if (a.extra != b.extra) return a.extra ? 1 : -1;
  final c = (a.colorSlot ?? 999).compareTo(b.colorSlot ?? 999);
  return c != 0 ? c : a.title.compareTo(b.title);
}

/// Fasst geladene Kursseiten zusammen. [loaded] und [failed] nach Kurs-ID.
GradesOverview gradesOverview(
  List<CourseItem> courses,
  Map<String, DetailedLesson> loaded,
  Set<String> failed,
) {
  final sorted = [...courses]..sort(compareCourses);
  final withMarks = <SubjectMarks>[];
  final without = <CourseItem>[];
  final bad = <CourseItem>[];
  var first = false;
  for (final c in sorted) {
    final d = loaded[c.id];
    if (d == null) {
      if (failed.contains(c.id)) bad.add(c);
      continue;
    }
    if (d.semester1URL != null) first = true;
    final marks = d.marks.where((m) => m.mark.trim().isNotEmpty).toList();
    if (marks.isNotEmpty) {
      withMarks.add(SubjectMarks(c, marks));
    } else if (!c.extra) {
      without.add(c);
    }
  }
  return GradesOverview(
    withMarks: withMarks,
    without: without,
    failed: bad,
    hasFirstHalf: first,
  );
}

/// Halbjahr, das ohne Umschalter gilt: Februar bis Juli das 2., sonst das 1.
///
/// Ursache: Ohne Link zum 1. Halbjahr nennt das Portal das laufende nicht.
/// Grenze: Der Wechsel liegt in Hessen um den 1. Februar; schaltet eine
/// Schule ein paar Tage früher oder später um, stimmt nur die Überschrift
/// kurz nicht – die Noten selbst kommen immer aus dem laufenden Halbjahr.
bool currentIsFirstHalf(DateTime now) => !(now.month >= 2 && now.month <= 7);

/// Geladene Kursseiten je Konto und Halbjahr, nur im Arbeitsspeicher.
///
/// Ursache: Ein Wechsel zwischen „Kurse“ und „Noten“ oder zwischen Kindern
/// soll nicht jedes Mal 10–15 Seiten neu laden. Bewusst nicht auf dem Gerät
/// gespeichert: Noten sind die sensibelsten Daten der App, und ein Neustart
/// lädt ohnehin frisch. Grenze: Neue Noten erscheinen erst nach Ziehen zum
/// Aktualisieren oder Neustart.
class GradesCache {
  GradesCache._();

  static final instance = GradesCache._();

  final _pages = <String, Map<String, DetailedLesson>>{};

  static String key(String account, {required bool firstHalf}) =>
      '$account|${firstHalf ? 1 : 0}';

  Map<String, DetailedLesson> pagesFor(String key) =>
      _pages.putIfAbsent(key, () => {});

  void drop(String key) => _pages.remove(key);

  void clear() => _pages.clear();
}
