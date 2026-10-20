import 'package:flutter/widgets.dart' show IconData;
import 'package:liblanis/liblanis.dart';

import '../../data/course_rules.dart';
import '../plan/plan_model.dart';

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
  // Kurs heißt wie das Kürzel („MU 09/1 (091MU03-GYM)“ → Titel „MU“) oder
  // gleiche Wörter in anderer Form („Ev. Religion“ ↔ „Religion -
  // evangelisch“, Export Schule B 17.10.26). Grenze: Jedes Wort des Fachs
  // muss Anfang eines Wortes im Kurstitel sein – „Kath. Religion“ trifft
  // „Religion - evangelisch“ daher nicht.
  if (l.short.toLowerCase() == title) return true;
  if (_wordsMatch(l.subject.toLowerCase(), title)) return true;
  final shared = KidPlan.kuerzelOf(l.teacher).any(teachers.contains);
  if (!shared) return false;
  final a = l.subject.toLowerCase();
  return a.length >= 3 && title.startsWith(a.substring(0, 3));
}

bool _wordsMatch(String subject, String title) {
  List<String> words(String x) => [
    for (final w in x.split(RegExp(r'[^a-zäöüß]+')))
      if (w.length >= 2) w,
  ];
  final a = words(subject);
  final b = words(title);
  if (a.length < 2 || b.isEmpty) return false;
  return a.every((w) => b.any((v) => v.startsWith(w)));
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
/// Tagen) laut Wochenplan mit Gruppenwahl; schulfreie Tage ([free],
/// freeDaysFrom) zählen nicht. Gesucht wird drei Wochen voraus, damit nach
/// zwei Wochen Ferien die erste Stunde danach erscheint.
///
/// Grenze: Vertretungen und Ausfälle bleiben hier unberücksichtigt; die
/// stehen in „Heute“ und im Kalender.
({DateTime day, String slot, String start, String end, String? room})?
nextLessonOf(
  KidPlan plan,
  GroupChoice choice,
  String courseTitle,
  Set<String> teachers,
  DateTime now, {
  Map<DateTime, String> free = const {},
}) {
  final nowMin = now.hour * 60 + now.minute;
  for (var add = 0; add < 22; add++) {
    final day = DateTime(now.year, now.month, now.day + add);
    final wd = day.weekday - 1;
    if (wd > 4 || wd >= plan.days.length || free.containsKey(day)) continue;
    for (final b in dayBlocks(plan, wd, choice)) {
      final content = b.content;
      if (content is! ResolvedLesson) continue;
      final l = content.lesson;
      if (!lessonBelongsTo(l, courseTitle, teachers)) continue;
      final start = plan.slots[b.firstSlot].start;
      // Ohne Uhrzeiten (KidPlan.timed) ist unklar, ob die Stunde heute
      // schon war: heute nur bis 12 Uhr zählen, Zeiten bleiben leer.
      if (add == 0 &&
          (plan.timed ? _minutes(start) <= nowMin : now.hour >= 12)) {
        continue;
      }
      return (
        day: day,
        slot: blockLabel(plan, b),
        start: plan.timed ? start : '',
        end: plan.timed ? plan.slots[b.lastSlot].end : '',
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

/// Fachsymbol nach [CourseRules.subjectIcons].
IconData subjectIconFor(String title) {
  final t = title.toLowerCase();
  for (final (k, icon) in CourseRules.subjectIcons) {
    if (t.contains(k)) return icon;
  }
  return CourseRules.fallbackIcon;
}

/// Ein Eintrag der Leistungskontrollen („02.11.2026 Lernkontrolle, 1. Std.“).
typedef ExamLine = ({DateTime? date, String text});

/// Leistungskontrollen als Überschrift + Zeilen, ohne Doppelungen.
///
/// Ursache (Bildschirmfoto Pixel 17.10.26): liblanis liefert je Abschnitt
/// den Titel („Kommende Leistungskontrollen“) als Name und ALLE Einträge als
/// einen mehrzeiligen Wert; jeder Eintrag kam zweimal (einmal mit Stunde und
/// Dauer, einmal nur „Lernkontrolle“). Die Seite setzte den Wert rechts
/// neben den Namen – der Name brach Buchstabe für Buchstabe um. Jetzt: Zeilen
/// einzeln, das Datum vorn erkannt, je Datum nur die ausführlichste Zeile.
/// Grenze: Zeilen ohne Datum bleiben, wie sie sind.
List<({String title, List<ExamLine> lines})> examSections(
  List<LessonExam> exams,
) {
  final out = <({String title, List<ExamLine> lines})>[];
  final dateRe = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})\s*');
  for (final e in exams) {
    final lines = <ExamLine>[];
    for (final raw in (e.value ?? '').split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line == 'Keine Daten!') continue;
      final m = dateRe.firstMatch(line);
      final date = m == null
          ? null
          : DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
      final text = m == null ? line : line.substring(m.end).trim();
      final same = lines.indexWhere(
        (x) =>
            x.date == date &&
            (x.text.startsWith(text) || text.startsWith(x.text)),
      );
      if (same >= 0) {
        if (text.length > lines[same].text.length) {
          lines[same] = (date: date, text: text);
        }
        continue;
      }
      lines.add((date: date, text: text));
    }
    if (lines.isEmpty) continue;
    out.add((title: e.name.trim(), lines: lines));
  }
  return out;
}
