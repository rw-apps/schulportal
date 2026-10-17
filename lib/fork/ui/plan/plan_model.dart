import '../today/today_model.dart' show ChangeKind;
import '../../data/portal_rules.dart';

/// Datenform des Stundenplans je Kind.
///
/// Wie „Heute“ unabhängig von liblanis; später aus TimetableStudentParser
/// (Klassenplan) plus Vertretungsplan gefüllt. Entscheidend ist
/// [PlanCell.options]: Der Klassenplan Schule A (Export 16.10.26) liefert in
/// einer Stunde mehrere Parallelgruppen (Freitag 1. Block: vier Textil-
/// Gruppen bei vier Lehrkräften), obwohl das Kind nur in einer ist. Auch der
/// „Persönliche Plan“ des Portals enthielt sie fast alle. Darum wählt man je
/// Fach EINMAL die eigene Gruppe ([GroupChoice]), statt jede Kachel einzeln
/// auszublenden wie in Lanis.

/// Eine Stunde laut Zeitraster der Schule.
class PlanSlot {
  const PlanSlot({required this.label, required this.start, required this.end});

  /// „1.“ oder „1. Block“.
  final String label;
  final String start;
  final String end;
}

/// Ein Unterricht in einer Stunde.
class PlanLesson {
  const PlanLesson({
    required this.subject,
    required this.short,
    this.room,
    this.teacher,
    this.change,
    this.changeDetail,
  });

  /// Ausgeschrieben („Textil“).
  final String subject;

  /// Kürzel aus dem Plan („TXT“); bestimmt Fachfarbe und Gruppenwahl.
  final String short;
  final String? room;

  /// Kürzel der Lehrkraft; unterscheidet Parallelgruppen.
  final String? teacher;
  final ChangeKind? change;
  final String? changeDetail;

  /// Kennung der Gruppe innerhalb des Fachs.
  String get groupKey => teacher ?? room ?? subject;

  bool sameAs(PlanLesson o) =>
      short == o.short &&
      room == o.room &&
      teacher == o.teacher &&
      change == o.change;
}

/// Inhalt einer Stunde an einem Tag: keine, eine oder mehrere Gruppen.
class PlanCell {
  const PlanCell(this.options);
  final List<PlanLesson> options;

  bool get isEmpty => options.isEmpty;
  bool get isParallel => options.length > 1;
}

/// Wochenplan eines Kindes: [days] Mo–Fr, je Tag eine Zelle je [slots].
class KidPlan {
  const KidPlan({
    required this.firstName,
    required this.colorIndex,
    required this.slots,
    required this.days,
    this.teacherNames = const {},
  });

  final String firstName;
  final int colorIndex;
  final List<PlanSlot> slots;

  /// days[0] = Montag; days[d][s] gehört zu slots[s].
  final List<List<PlanCell>> days;

  /// Kürzel → „Vorname Nachname“. Quelle: „Mein Unterricht“
  /// (meinunterricht.php, Lehrer-Knöpfe mit title „Nachname, Vorname
  /// (KÜR)“, Export Schule A 16.10.26: 11 Lehrkräfte). Der Stundenplan selbst
  /// liefert nur Kürzel. Grenze: Lehrkräfte ohne eigenen Kurs des Kindes
  /// (Vertretungen, fremde Parallelgruppen) bleiben Kürzel.
  final Map<String, String> teacherNames;

  /// Gleicher Plan mit zusätzlichen bzw. überschriebenen Lehrernamen (von
  /// Hand eingetragen, siehe PlanPage „Name eintragen“). Leere Werte löschen
  /// den Eintrag, dann gilt wieder der Name aus dem Portal bzw. das Kürzel.
  KidPlan withTeacherNames(Map<String, String> overrides) {
    if (overrides.isEmpty) return this;
    final merged = {...teacherNames};
    overrides.forEach((k, v) {
      if (v.trim().isEmpty) {
        merged.remove(k);
      } else {
        merged[k] = v.trim();
      }
    });
    return KidPlan(
      firstName: firstName,
      colorIndex: colorIndex,
      slots: slots,
      days: days,
      teacherNames: merged,
    );
  }

  /// Einzelne Kürzel einer Lehrer-Angabe („ABC, DEF“ → [ABC, DEF]).
  static List<String> kuerzelOf(String? teacher) =>
      teacher == null ? const [] : _each(teacher).toList();

  /// Ausgeschrieben („Maria Becker“), sonst das Kürzel. Doppelbesetzung
  /// („ABC, DEF“) wird je Kürzel übersetzt: „Maria Becker, Jan Wolf“.
  String? teacherFull(String? kuerzel) => kuerzel == null
      ? null
      : _each(kuerzel).map((k) => teacherNames[k] ?? k).join(', ');

  /// Nachname für enge Stellen (Wochenraster), sonst das Kürzel; bei
  /// Doppelbesetzung „Becker/Wolf“.
  String? teacherLast(String? kuerzel) => kuerzel == null
      ? null
      : _each(kuerzel)
            .map((k) {
              final full = teacherNames[k];
              return full == null ? k : full.trim().split(RegExp(r'\s+')).last;
            })
            .join('/');

  /// Für das Wochenraster: ein Nachname, bei Doppelbesetzung „Becker +1“.
  /// Ursache: „Becker/Wolf“ wurde in ~60 dp Zellbreite unlesbar klein
  /// (echter Plan von Schule A, 16.10.26).
  String? teacherCell(String? kuerzel) {
    if (kuerzel == null) return null;
    final all = _each(kuerzel).toList();
    if (all.isEmpty) return null;
    final first = teacherLast(all.first);
    return all.length == 1 ? first : '$first +${all.length - 1}';
  }

  static Iterable<String> _each(String s) =>
      s.split(RegExp(r'\s*,\s*')).where((x) => x.isNotEmpty);
}

/// „Nachname, Vorname“ (Portal) → „Vorname Nachname“.
String portalNameToDisplay(String portal) {
  final parts = portal.split(',');
  if (parts.length < 2) return portal.trim();
  return '${parts.sublist(1).join(',').trim()} ${parts.first.trim()}';
}

/// Gewählte Gruppe je Fachkürzel („TXT“ → „ABE“). Gilt für alle Stunden
/// dieses Fachs, weil ein Kind die ganze Woche in derselben Gruppe ist.
/// Grenze: Wechselt die Gruppe je Halbjahr, muss neu gewählt werden.
typedef GroupChoice = Map<String, String>;

/// Was in einer Zelle tatsächlich angezeigt wird.
sealed class Resolved {
  const Resolved();
}

class ResolvedNone extends Resolved {
  const ResolvedNone();
}

class ResolvedLesson extends Resolved {
  const ResolvedLesson(this.lesson);
  final PlanLesson lesson;
}

/// Parallelgruppen ohne Wahl: zeigen „n Gruppen – wählen“.
class ResolvedOpen extends Resolved {
  const ResolvedOpen(this.options);
  final List<PlanLesson> options;
  String get short => options.first.short;
  String get subject => options.first.subject;
}

Resolved resolveCell(PlanCell cell, GroupChoice choice) {
  if (cell.isEmpty) return const ResolvedNone();
  if (!cell.isParallel) return ResolvedLesson(cell.options.single);
  // Verschiedene Fächer parallel (z. B. Religion/Ethik): gewählte Gruppe
  // eines davon gewinnt; die übrigen gelten als „nicht meine“.
  for (final o in cell.options) {
    final chosen = choice[o.short];
    if (chosen != null && chosen == o.groupKey) return ResolvedLesson(o);
  }
  for (final short in {for (final o in cell.options) o.short}) {
    final team = _teamIn(cell.options, short, choice[short]);
    if (team != null) return ResolvedLesson(team);
  }
  final chosenShorts = cell.options
      .where((o) => choice.containsKey(o.short))
      .map((o) => o.short)
      .toSet();
  final open = cell.options.where((o) => !chosenShorts.contains(o.short));
  if (open.isEmpty) return const ResolvedNone();
  final list = open.toList();
  return list.length == 1 ? ResolvedLesson(list.single) : ResolvedOpen(list);
}

/// Ein Abschnitt der Tagesansicht: gleiche aufeinanderfolgende Stunden
/// zusammengefasst (Doppelstunde = ein Abschnitt).
class DayBlock {
  const DayBlock({
    required this.firstSlot,
    required this.lastSlot,
    required this.content,
  });

  final int firstSlot;
  final int lastSlot;
  final Resolved content;

  int get span => lastSlot - firstSlot + 1;
}

/// Tag als Abschnitte; leere Stunden vor der ersten und nach der letzten
/// entfallen, Lücken dazwischen bleiben als [ResolvedNone]-Abschnitt.
List<DayBlock> dayBlocks(KidPlan plan, int day, GroupChoice choice) {
  final cells = plan.days[day];
  final res = [for (final c in cells) resolveCell(c, choice)];
  bool same(Resolved a, Resolved b) => switch ((a, b)) {
    (ResolvedLesson x, ResolvedLesson y) => x.lesson.sameAs(y.lesson),
    (ResolvedOpen x, ResolvedOpen y) => x.short == y.short,
    (ResolvedNone _, ResolvedNone _) => true,
    _ => false,
  };
  final blocks = <DayBlock>[];
  for (var s = 0; s < res.length; s++) {
    if (blocks.isNotEmpty && same(blocks.last.content, res[s])) {
      final b = blocks.removeLast();
      blocks.add(
        DayBlock(firstSlot: b.firstSlot, lastSlot: s, content: b.content),
      );
    } else {
      blocks.add(DayBlock(firstSlot: s, lastSlot: s, content: res[s]));
    }
  }
  while (blocks.isNotEmpty && blocks.first.content is ResolvedNone) {
    blocks.removeAt(0);
  }
  while (blocks.isNotEmpty && blocks.last.content is ResolvedNone) {
    blocks.removeLast();
  }
  return blocks;
}

/// Stunden, die in der ganzen Woche leer sind (z. B. 0. Block), fallen im
/// Wochenraster weg.
List<int> usedSlots(KidPlan plan) => [
  for (var s = 0; s < plan.slots.length; s++)
    if (plan.days.any((d) => d.length > s && !d[s].isEmpty)) s,
];

/// Fächer mit Parallelgruppen, für die noch keine Wahl getroffen ist.
Set<String> openGroupSubjects(KidPlan plan, GroupChoice choice) => {
  for (final d in plan.days)
    for (final c in d)
      if (resolveCell(c, choice) case ResolvedOpen o) o.short,
};

/// „1.–2.“ bzw. „1. Block“ für einen Abschnitt.
String blockLabel(KidPlan plan, DayBlock b) {
  final a = plan.slots[b.firstSlot].label;
  if (b.span == 1) return a;
  final z = plan.slots[b.lastSlot].label;
  // „1.“ + „2.“ → „1.–2.“; „1. Block“ + „2. Block“ → „1.–2. Block“
  final suffix = a.contains(' ') ? a.substring(a.indexOf(' ')) : '';
  final an = a.split(' ').first;
  final zn = z.split(' ').first;
  return '${an.replaceAll('.', '')}.–${zn.replaceAll('.', '')}.$suffix';
}

/// Alle Wahlmöglichkeiten der Parallel-Stunden, in denen [short] vorkommt –
/// bei gleichem Fach die Gruppen (Textil bei vier Lehrkräften), bei
/// verschiedenen Fächern die Fächer (Ev. Religion / Kath. Religion / Ethik).
/// Je Gruppe einmal, in Reihenfolge des ersten Auftretens.
List<PlanLesson> groupOptions(KidPlan plan, String short) {
  final out = <String, PlanLesson>{};
  for (final d in plan.days) {
    for (final c in d) {
      if (!c.isParallel || !c.options.any((o) => o.short == short)) continue;
      for (final o in c.options) {
        // Stammraum zeigen: eine Fundstelle ohne Änderung ersetzt eine mit
        // Raumwechsel (sonst stand in der Wahl der Ausweichraum vom Do).
        final key = '${o.short}|${o.groupKey}';
        final had = out[key];
        if (had == null || (had.change != null && o.change == null)) {
          out[key] = o;
        }
      }
    }
  }
  return out.values.toList();
}

/// Überschrift einer Wahl: Fachname, bei verschiedenen Fächern alle.
String groupLabel(KidPlan plan, String short) {
  final subjects = {for (final o in groupOptions(plan, short)) o.subject};
  return subjects.join(' / ');
}

/// Neue Wahl setzen: alle Kürzel dieser Parallel-Stunden zurücksetzen, dann
/// [lesson] wählen (null = wieder alle zeigen). Ursache für das Zurücksetzen:
/// Wer von Ev. Religion zu Ethik wechselt, darf nicht beide gewählt haben.
GroupChoice applyGroupChoice(
  KidPlan plan,
  GroupChoice choice,
  String short,
  PlanLesson? lesson,
) {
  final next = {...choice};
  for (final o in groupOptions(plan, short)) {
    next.remove(o.short);
  }
  if (lesson != null) next[lesson.short] = lesson.groupKey;
  return next;
}

/// Die aktuell gewählte Möglichkeit dieser Parallel-Stunden, falls eine.
PlanLesson? chosenOption(KidPlan plan, GroupChoice choice, String short) {
  final options = groupOptions(plan, short);
  for (final o in options) {
    if (choice[o.short] == o.groupKey) return o;
  }
  for (final s in {for (final o in options) o.short}) {
    final team = _teamIn(options, s, choice[s]);
    if (team != null) return team;
  }
  return null;
}

/// Team-Wahl: [key] nennt mehrere Kürzel („ABC, DEF“), und die Stunde des
/// Kindes ist jede Gruppe des Fachs, deren Lehrkräfte alle dazugehören –
/// zusammengefasst zu EINER Stunde mit den anwesenden Lehrkräften.
///
/// Ursache: An von Schule A (Export 16.10.26) hat der Kurs „Projekt Text …“ in
/// „Mein Unterricht“ ZWEI Lehrkräfte, und der Stundenplan führt beide in
/// jeder TXT-Stunde als eigene Einträge (einmal mit Raum, einmal ohne). Eine
/// einzelne Gruppe hätte die halbe Stunde unterschlagen. Raum: der erste
/// angegebene. Grenze: Teilen sich die beiden die Klasse tatsächlich auf,
/// zeigt die App trotzdem beide – der Nutzer kann dann eine Gruppe wählen.
PlanLesson? _teamIn(List<PlanLesson> options, String short, String? key) {
  final team = KidPlan.kuerzelOf(key).toSet();
  if (team.length < 2) return null;
  final hits = [
    for (final o in options)
      if (o.short == short &&
          KidPlan.kuerzelOf(o.teacher).isNotEmpty &&
          KidPlan.kuerzelOf(o.teacher).every(team.contains))
        o,
  ];
  if (hits.isEmpty) return null;
  final present = {for (final o in hits) ...KidPlan.kuerzelOf(o.teacher)};
  final f = hits.first;
  final changed = hits.where((o) => o.change != null).firstOrNull;
  return PlanLesson(
    subject: f.subject,
    short: short,
    room: hits.map((o) => o.room).nonNulls.firstOrNull,
    teacher: [
      for (final t in team)
        if (present.contains(t)) t,
    ].join(', '),
    change: changed?.change,
    changeDetail: changed?.changeDetail,
  );
}

/// Kurzname einer Wahl für Knöpfe und Rasterzellen: bei gleichem Fach der
/// Fachname, bei verschiedenen Fächern die Kürzel („ER / KR / Eth“).
String groupShortLabel(KidPlan plan, String short) {
  final opts = groupOptions(plan, short);
  final subjects = {for (final o in opts) o.subject};
  if (subjects.length == 1) return subjects.single;
  return {for (final o in opts) o.short}.join(' / ');
}

/// Gleiches Fach in allen Möglichkeiten (Gruppen) statt verschiedener Fächer.
bool isSameSubjectChoice(List<PlanLesson> options) =>
    options.map((o) => o.subject).toSet().length == 1;

/// Name im Wochenraster: gängige Kurzform, wenn es eine gibt („Bio“), sonst
/// der Fachname bis 8 Zeichen („Englisch“), sonst das Kürzel.
/// Ursache: Reine Kürzel („M“, „Ek“) waren im ersten Raster schwer lesbar.
String gridName(PlanLesson l) {
  return SubjectNames.gridShort[l.subject] ??
      (l.subject.length <= 8 ? l.subject : l.short);
}

/// Farbplatz je Fach eines Kindes: in der Reihenfolge des ersten Auftretens
/// (Mo 1. Stunde zuerst), Kürzel ohne Farbe bekommen den nächsten freien.
/// Ursache: Aus dem Kürzel errechnete Plätze kollidierten (Englisch, Mathe,
/// NaWi und Sport waren alle grau). Grenze: Bei mehr Fächern als Farben
/// (KitPalette.subjects, 8) wiederholen sich Farben – dann aber erst ab dem
/// neunten Fach.
Map<String, int> subjectColorSlots(KidPlan plan) {
  final out = <String, int>{};
  for (final d in plan.days) {
    for (final c in d) {
      for (final o in c.options) {
        out.putIfAbsent(o.short, () => out.length);
      }
    }
  }
  return out;
}

/// Wirksame Gruppenwahl: automatisch erkannte, darüber die eigene. Ein
/// leerer Wert in [user] heißt „bewusst alle zeigen“ und hebt die
/// automatische Wahl dieses Fachs auf.
GroupChoice effectiveChoice(GroupChoice auto, GroupChoice user) =>
    {...auto, ...user}..removeWhere((_, v) => v.isEmpty);
