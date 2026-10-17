import 'package:flutter/widgets.dart' show IconData;
import 'package:liblanis/liblanis.dart';

import '../../data/course_rules.dart';
import '../plan/plan_model.dart';
import '../today/today_model.dart' show WeekItem, WeekKind;

/// Auswertung der Kursseite (meinunterricht.php?a=sus_view) für die neue
/// Ansicht (Entwurf 3, abgenommen 17.10.26). Reine Funktionen, damit sie
/// ohne Portal testbar sind (test/fork/course_detail_test.dart).

/// Thema eines Eintrags: Teil vor dem ersten Trenner („Unit 2: Tickets“ →
/// „Unit 2“), sonst der ganze Titel. Leer → null.
String? topicKey(String? title) {
  final t = title?.trim() ?? '';
  if (t.isEmpty) return null;
  for (final sep in CourseRules.topicSeparators) {
    final i = t.indexOf(sep);
    if (i > 0) return t.substring(0, i).trim();
  }
  return t;
}

/// Rest des Titels nach dem Thema („Unit 2: Tickets“ → „Tickets“); ohne
/// Trenner null (dann trägt der Eintrag keinen eigenen Titel).
String? topicRest(String? title) {
  final t = title?.trim() ?? '';
  for (final sep in CourseRules.topicSeparators) {
    final i = t.indexOf(sep);
    if (i > 0) {
      final r = t.substring(i + sep.length).trim();
      return r.isEmpty ? null : r;
    }
  }
  return null;
}

/// Mehrere Stunden zu einem Thema.
class TopicGroup {
  const TopicGroup(this.title, this.entries);

  final String title;

  /// Neueste zuerst, wie im Portal.
  final List<CurrentEntry> entries;

  DateTime? get from => entries
      .map((e) => e.topicDate)
      .nonNulls
      .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
  DateTime? get to => entries
      .map((e) => e.topicDate)
      .nonNulls
      .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
  int get openHomework => entries
      .where((e) => e.homework != null && !e.homework!.homeWorkDone)
      .length;
}

/// Verlauf nach Themen: aufeinanderfolgende Einträge mit gleichem
/// [topicKey] bilden eine Gruppe.
///
/// Ursache „aufeinanderfolgend“ statt „gleich irgendwo“: Kehrt ein Thema
/// nach Wochen wieder („Wiederholung“), soll es an seiner Stelle in der
/// Zeitleiste stehen und nicht die Reihenfolge sprengen. Grenze: Trägt eine
/// Lehrkraft nur Stichworte ein („KL“, „Logo, Lernbegleiter“), wird fast
/// jede Stunde ein eigenes Thema – gezeigt wird, was eingetragen ist.
List<TopicGroup> groupHistory(List<CurrentEntry> history, {String? noTopic}) {
  final out = <TopicGroup>[];
  for (final e in history) {
    final key = topicKey(e.topicTitle) ?? noTopic ?? '';
    if (out.isNotEmpty && out.last.title == key) {
      out.last.entries.add(e);
    } else {
      out.add(TopicGroup(key, [e]));
    }
  }
  return out;
}

/// Zählung der Anwesenheit aus der Tabelle des Portals.
typedef AttendanceCounts = ({int present, int excused, int missing});

/// Zahlen je Spalte nach [CourseRules]; nicht zuordenbare Spalten zählen
/// nicht. null, wenn nichts Zählbares da ist.
AttendanceCounts? attendanceCounts(Map<String, String> a) {
  var p = 0, e = 0, m = 0;
  var any = false;
  for (final x in a.entries) {
    final n = int.tryParse(x.value.trim());
    if (n == null) continue;
    final k = x.key.toLowerCase();
    if (CourseRules.missing.any(k.contains)) {
      m += n;
    } else if (CourseRules.excused.any(k.contains)) {
      e += n;
    } else if (CourseRules.present.any(k.contains)) {
      p += n;
    } else {
      continue;
    }
    any = true;
  }
  return any ? (present: p, excused: e, missing: m) : null;
}

/// Einträge mit Abwesenheit („fehlend“, „entschuldigt“ …), neueste zuerst.
List<CurrentEntry> absentEntries(List<CurrentEntry> history) => [
  for (final e in history)
    if (!CourseRules.presenceNeutral.contains(
      (e.presence ?? '').trim().toLowerCase(),
    ))
      e,
];

/// Alle Dateien des Halbjahrs mit dem Tag ihrer Stunde.
List<(FileInfo, DateTime?)> allFiles(List<CurrentEntry> history) => [
  for (final e in history)
    for (final f in e.files) (f, e.topicDate),
];

/// Offene Abgaben (Status „open“ laut liblanis LessonUpload).
List<LessonUpload> openUploads(List<CurrentEntry> history) => [
  for (final e in history)
    for (final u in e.uploads)
      if (u.status == 'open') u,
];

/// Gehört eine Planstunde zu diesem Kurs? Gleicher Fachname oder eine
/// gemeinsame Lehrkraft bei gleichem Fach-Anfang.
///
/// Ursache: Die Planstunde kennt nur Fachkürzel und Lehrerkürzel, der Kurs
/// nur Namen und Kürzel seiner Lehrkräfte. Grenze: Unterrichtet dieselbe
/// Lehrkraft zwei Fächer mit gleichem Namensanfang, kann die falsche Stunde
/// erscheinen – dann hilft nur der Fachname.
bool lessonBelongsTo(PlanLesson l, String courseTitle, Set<String> teachers) {
  final title = courseTitle.toLowerCase();
  if (l.subject.toLowerCase() == title) return true;
  final shared = KidPlan.kuerzelOf(l.teacher).any(teachers.contains);
  if (!shared) return false;
  final a = l.subject.toLowerCase();
  return a.length >= 3 && title.startsWith(a.substring(0, 3));
}

/// Fachkürzel des Kurses im Plan (für Fachfarbe und nächste Stunde), sonst
/// null – dann ist er ein weiteres Angebot ohne Platz im Stundenplan.
String? courseShortIn(KidPlan plan, String courseTitle, Set<String> teachers) {
  for (final d in plan.days) {
    for (final c in d) {
      for (final o in c.options) {
        if (lessonBelongsTo(o, courseTitle, teachers)) return o.short;
      }
    }
  }
  return null;
}

/// Kurs ohne Noten bzw. ohne Stunde im Plan (Ganztag, Training) – steht in
/// der Liste eingeklappt unter „Weitere Angebote“.
bool isExtraOffer(String fullName, {required bool inPlan}) =>
    !inPlan ||
    CourseRules.extraOfferMarkers.any(fullName.toLowerCase().contains);

/// Nächste Stunde des Kurses ab [now] (heute später oder an den folgenden
/// sieben Tagen) laut Wochenplan mit Gruppenwahl.
///
/// Grenze: Vertretungen und Ausfälle bleiben hier unberücksichtigt; die
/// stehen in „Heute“ und im Kalender.
({DateTime day, String slot, String start, String end, String? room})?
nextLessonOf(
  KidPlan plan,
  GroupChoice choice,
  String courseTitle,
  Set<String> teachers,
  DateTime now,
) {
  final nowMin = now.hour * 60 + now.minute;
  for (var add = 0; add < 8; add++) {
    final day = DateTime(now.year, now.month, now.day + add);
    final wd = day.weekday - 1;
    if (wd > 4 || wd >= plan.days.length) continue;
    for (final b in dayBlocks(plan, wd, choice)) {
      final content = b.content;
      if (content is! ResolvedLesson) continue;
      final l = content.lesson;
      if (!lessonBelongsTo(l, courseTitle, teachers)) continue;
      final start = plan.slots[b.firstSlot].start;
      if (add == 0 && _minutes(start) <= nowMin) continue;
      return (
        day: day,
        slot: blockLabel(plan, b),
        start: start,
        end: plan.slots[b.lastSlot].end,
        room: l.room,
      );
    }
  }
  return null;
}

int _minutes(String hm) {
  final p = hm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// Anstehende Arbeit des Fachs aus dem Schulkalender: Termin der Art
/// „Arbeit“, dessen Titel den Fachnamen nennt, in den nächsten [days] Tagen.
///
/// Grenze: Nennt die Schule das Fach nicht im Titel („Klassenarbeit 7b“),
/// gibt es keinen Treffer – lieber keine Zeile als eine falsche.
WeekItem? upcomingExamOf(
  List<WeekItem> items,
  String courseTitle,
  DateTime now, {
  int days = 30,
}) {
  final title = courseTitle.toLowerCase();
  if (title.length < 3) return null;
  final until = DateTime(now.year, now.month, now.day + days);
  for (final w in items) {
    if (w.kind != WeekKind.exam || w.day.isAfter(until)) continue;
    if (w.title.toLowerCase().contains(title)) return w;
  }
  return null;
}

/// Fachsymbol nach [CourseRules.subjectIcons].
IconData subjectIconFor(String title) {
  final t = title.toLowerCase();
  for (final (k, icon) in CourseRules.subjectIcons) {
    if (t.contains(k)) return icon;
  }
  return CourseRules.fallbackIcon;
}
