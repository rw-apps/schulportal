import 'package:liblanis/liblanis.dart';

import '../../error_log.dart';
import 'lesson_times.dart';
import 'plan_model.dart';
import '../../data/portal_rules.dart';

/// Übersetzt den Lanis-Stundenplan (TimetableStudentParser) in [KidPlan].
///
/// Quelle: `TimeTable.hours` (Zeitraster, nur Zeilen vom Typ `lesson`) und
/// `planForOwn` (Portal: „Persönlicher Plan“), ersatzweise `planForAll`.
/// Mehrere Einträge in derselben Stunde werden Parallelgruppen
/// ([PlanCell.options]) – genau das Bild aus dem Export von Schule A vom 16.10.26
/// (Freitag 1. Block: vier TXT-Einträge bei vier Lehrkräften).
///
/// Zuordnung Eintrag → Stunden über die Uhrzeit: Ein Eintrag belegt jede
/// Stunde, die ganz in seiner Zeit liegt (Doppelstunde = zwei Stunden).
/// Grenze: Blendet die Schule die Uhrzeiten aus (liblanis setzt dann 0:00),
/// fällt der Eintrag auf `stunde` (Zeilenindex) zurück.
KidPlan kidPlanFromTimetable(
  TimeTable tt, {
  required String firstName,
  required int colorIndex,
  Map<String, String> teacherNames = const {},
  List<String> courseNames = const [],
  List<CourseRef> courses = const [],
  LessonTimes? lessonTimes,
}) {
  final rows = [
    for (final r in tt.hours ?? const <TimeTableRow>[])
      if (r.type == TimeTableRowType.lesson) r,
  ];
  final source = (tt.planForOwn?.any((d) => d.isNotEmpty) ?? false)
      ? tt.planForOwn!
      : (tt.planForAll ?? const <TimetableDay>[]);
  // Ohne Uhrzeiten im Plan liefert liblanis kein Zeitraster (hours leer,
  // .VonBis fehlt; Export Schule B 17.10.26: 13 Zeilen „0.–12. Stunde“, alle
  // Einträge 00:00). Dann Stunden aus den Nummern der Einträge bilden.
  final untimed = rows.isEmpty ? untimedLessonNumbers(source) : const <int>[];
  final slots = rows.isNotEmpty
      ? [
          for (final r in rows)
            PlanSlot(
              label: _slotLabel(r.label),
              start: _hm(r.startTime),
              end: _hm(r.endTime),
            ),
        ]
      : [
          for (final n in untimed)
            lessonTimes == null
                ? placeholderSlot(n)
                : PlanSlot(
                    label: '$n. Stunde',
                    start: LessonTimes.hm(lessonTimes.of(n).start),
                    end: LessonTimes.hm(lessonTimes.of(n).end),
                  ),
        ];

  final days = <List<PlanCell>>[];
  for (var d = 0; d < 5; d++) {
    final cells = List.generate(slots.length, (_) => <PlanLesson>[]);
    final day = d < source.length ? source[d] : const <TimetableSubject>[];
    for (final subj in day) {
      final code = (subj.name ?? '').trim();
      if (code.isEmpty) continue;
      final lesson = PlanLesson(
        subject: subjectFullName(code, courseNames),
        short: code,
        room: _blankToNull(subj.raum),
        teacher: _blankToNull(subj.lehrer),
      );
      for (final s
          in rows.isEmpty
              ? _untimedSlotsOf(subj, untimed)
              : _slotsOf(subj, rows)) {
        if (!cells[s].any((o) => o.sameAs(lesson))) cells[s].add(lesson);
      }
    }
    days.add([for (final c in cells) PlanCell(mergeCoTeaching(c))]);
  }

  // Kürzel ohne Namen (Ergebnis = Kürzel) über die Lehrkräfte einem Kurs
  // zuordnen, siehe subjectsByCourseTeachers.
  final codeTeachers = <String, Set<String>>{};
  for (final d in days) {
    for (final c in d) {
      for (final o in c.options) {
        if (o.subject != o.short) continue;
        (codeTeachers[o.short] ??= {}).addAll(KidPlan.kuerzelOf(o.teacher));
      }
    }
  }
  final claimed = <String>{
    for (final d in days)
      for (final c in d)
        for (final o in c.options)
          if (o.subject != o.short) o.subject,
  };
  final named = subjectsByCourseTeachers(codeTeachers, [
    for (final c in courses)
      if (!claimed.contains(_courseBaseName(c.name) ?? c.name.trim())) c,
  ]);
  final finalDays = named.isEmpty
      ? days
      : [
          for (final d in days)
            [
              for (final c in d)
                PlanCell([
                  for (final o in c.options)
                    named[o.short] != null && o.subject == o.short
                        ? PlanLesson(
                            subject: named[o.short]!,
                            short: o.short,
                            room: o.room,
                            teacher: o.teacher,
                            change: o.change,
                            changeDetail: o.changeDetail,
                          )
                        : o,
                ]),
            ],
        ];

  // Diagnose: Einträge im Portal, aber keiner fand eine Stunde (Zuordnung
  // über Uhrzeit bzw. Nummer gescheitert) – mit Zählwerten ins Protokoll.
  final srcCount = source.fold<int>(0, (a, d) => a + d.length);
  final placed = finalDays.fold<int>(
    0,
    (a, d) => a + d.where((c) => !c.isEmpty).length,
  );
  if (srcCount > 0 && placed == 0) {
    ErrorLog.instance.notice('plan', 'EmptyPlan', {
      'entries': srcCount,
      'rows': rows.length,
      'slots': slots.length,
      'untimed': untimed.length,
      'times': lessonTimes == null ? 0 : 1,
    });
  }

  // Kurse der ganzen Klasse je Stunde, wenn oben der persönliche Plan
  // genommen wurde (KidPlan.classCodes) – für die Zuordnung von
  // Vertretungen zum Parallelkurs.
  final all = tt.planForAll ?? const <TimetableDay>[];
  final classCodes = identical(source, all) || all.isEmpty
      ? const <List<Set<String>>>[]
      : [
          for (var d = 0; d < 5; d++)
            () {
              final cells = List.generate(slots.length, (_) => <String>{});
              final day = d < all.length ? all[d] : const <TimetableSubject>[];
              for (final subj in day) {
                final code = (subj.name ?? '').trim().toUpperCase();
                if (code.isEmpty) continue;
                for (final s
                    in rows.isEmpty
                        ? _untimedSlotsOf(subj, untimed)
                        : _slotsOf(subj, rows)) {
                  cells[s].add(code);
                }
              }
              return cells;
            }(),
        ];

  return KidPlan(
    firstName: firstName,
    colorIndex: colorIndex,
    slots: slots,
    days: finalDays,
    teacherNames: teacherNames,
    // Eigene Zeiten nur, wo das Portal keine liefert (Portal geht vor).
    timed: rows.isNotEmpty || lessonTimes != null,
    customTimes: rows.isEmpty && lessonTimes != null,
    classCodes: classCodes,
  );
}

/// Stundennummern von der ersten bis zur letzten belegten Stunde (Lücken
/// bleiben als leere Stunde, damit das Raster stimmt).
List<int> untimedLessonNumbers(List<TimetableDay> days) {
  int? lo, hi;
  for (final d in days) {
    for (final s in d) {
      final y = s.stunde;
      if (y == null || (s.name ?? '').trim().isEmpty) continue;
      final end = y + (s.duration < 1 ? 1 : s.duration) - 1;
      lo = lo == null || y < lo ? y : lo;
      hi = hi == null || end > hi ? end : hi;
    }
  }
  if (lo == null || hi == null) return const [];
  return [for (var n = lo; n <= hi; n++) n];
}

/// Stunde ohne Uhrzeit. Ersatzzeit: lückenlos 45 Minuten ab 7:00 – nur für
/// Reihenfolge und Rasterhöhe, angezeigt wird sie nie (KidPlan.timed).
/// Bezeichnung wie im Portal („3. Stunde“).
PlanSlot placeholderSlot(int n) {
  String hm(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  final start = 7 * 60 + n * 45;
  return PlanSlot(label: '$n. Stunde', start: hm(start), end: hm(start + 45));
}

Iterable<int> _untimedSlotsOf(TimetableSubject s, List<int> numbers) sync* {
  final y = s.stunde;
  if (y == null) return;
  for (var k = 0; k < (s.duration < 1 ? 1 : s.duration); k++) {
    final i = numbers.indexOf(y + k);
    if (i >= 0) yield i;
  }
}

/// Fachnamen für Kürzel ohne bekannten Namen über die Lehrkräfte: Der Kurs
/// aus „Mein Unterricht“, mit dem die Lehrkräfte des Kürzels am meisten
/// gemeinsam haben, liefert den Namen („TXT“ → „Projekt Text“).
///
/// Ursache: Vorher stand die Zuordnung TXT → „Projekt Text“ fest im Code,
/// gebunden an eine Schulnummer – das verriet im öffentlichen Repository
/// die Schule (Entscheidung 17.10.26: Schulnamen neutralisieren). Grenze:
/// Erst ab zwei gemeinsamen Lehrkräften und nur bei eindeutigem Sieger;
/// eine einzelne gemeinsame Lehrkraft (die oft mehrere Kurse gibt) reicht
/// nicht – dann bleibt das Kürzel.
Map<String, String> subjectsByCourseTeachers(
  Map<String, Set<String>> codeTeachers,
  List<CourseRef> courses,
) {
  final out = <String, String>{};
  for (final e in codeTeachers.entries) {
    // Anteil der Kurs-Lehrkräfte, die das Kürzel unterrichten. Ursache:
    // Große Teams (Ganztagsangebot mit sechs Lehrkräften, Export von Schule
    // A 16.10.26) teilen zufällig mehrere Lehrkräfte mit vielen Kürzeln; ein
    // kleiner Kurs, dessen Lehrkräfte ALLE dazugehören, ist der Treffer.
    var best = 0.0;
    var tie = false;
    CourseRef? pick;
    for (final c in courses) {
      if (c.teachers.isEmpty) continue;
      final n = c.teachers.intersection(e.value).length;
      if (n == 0) continue;
      final score = n / c.teachers.length;
      if (score > best) {
        best = score;
        pick = c;
        tie = false;
      } else if (score == best &&
          (_courseBaseName(c.name) ?? c.name) !=
              (_courseBaseName(pick!.name) ?? pick.name)) {
        tie = true;
      }
    }
    if (pick == null || tie) continue;
    out[e.key] = _courseBaseName(pick.name) ?? pick.name.trim();
  }
  return out;
}

Iterable<int> _slotsOf(TimetableSubject s, List<TimeTableRow> rows) sync* {
  final a = s.startTime.hour * 60 + s.startTime.minute;
  final b = s.endTime.hour * 60 + s.endTime.minute;
  if (b > a) {
    for (var i = 0; i < rows.length; i++) {
      final rs = rows[i].startTime.hour * 60 + rows[i].startTime.minute;
      final re = rows[i].endTime.hour * 60 + rows[i].endTime.minute;
      if (rs >= a && re <= b) yield i;
    }
    return;
  }
  // Ohne Uhrzeiten: Zeilenindex der Lanis-Tabelle auf Stunde abbilden.
  final y = s.stunde;
  if (y == null) return;
  for (var k = 0; k < s.duration; k++) {
    final i = rows.indexWhere((r) => r.lessonIndex == y + k);
    if (i >= 0) yield i;
  }
}

String _hm(SphTimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// „1.Block“ → „1. Block“; „1“ → „1.“
String _slotLabel(String raw) {
  final s = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  final m = RegExp(r'^(\d+)\.?\s*(.*)$').firstMatch(s);
  if (m == null) return s;
  final rest = m.group(2)!.trim();
  return rest.isEmpty ? '${m.group(1)}.' : '${m.group(1)}. $rest';
}

String? _blankToNull(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// Ausgeschriebener Fachname zu einem Kürzel aus dem Stundenplan.
///
/// Reihenfolge: (1) eindeutige, landesweit übliche Kürzel; (2) Kurscode in
/// Klammern eines Kurses aus „Mein Unterricht“ („Naturwissenschaften 06 xy
/// (061NAWI05-IGS)“); (3) ein Wort eines Kursnamens beginnt mit dem Kürzel
/// (TRAIN → „Training Klasse 6“, erst ab 3 Buchstaben). Sonst bleibt das
/// Kürzel – lieber „TXT“ als ein geratener Name; kidPlanFromTimetable
/// versucht danach noch die Lehrkräfte (subjectsByCourseTeachers). Beleg für die Vorsicht: Im
/// Export von Schule A hieß der passende Kurs „Projekt Text“, nicht „Textil“, wie die
/// Beispieldaten angenommen hatten.
String subjectFullName(String code, List<String> courseNames) {
  final up = code.toUpperCase().trim();
  final base = up.replaceAll(RegExp(r'\d+$'), ''); // SP5 → SP
  final known = SubjectNames.known[up] ?? SubjectNames.known[base];
  if (known != null) return known;

  for (final c in courseNames) {
    final paren = RegExp(r'\(([^)]*)\)').firstMatch(c)?.group(1)?.toUpperCase();
    if (paren != null && base.length >= 2 && paren.contains(base)) {
      final name = _courseBaseName(c);
      if (name != null) return name;
    }
  }
  if (base.length >= 3) {
    for (final c in courseNames) {
      for (final w in c.split(RegExp(r'\s+'))) {
        if (w.length >= base.length &&
            w.toUpperCase().startsWith(base) &&
            !RegExp(r'\d').hasMatch(w)) {
          return w;
        }
      }
    }
  }
  return code;
}

/// „Naturwissenschaften 06 xy (061NAWI05-IGS)“ → „Naturwissenschaften“:
/// Wörter bis zum ersten mit Ziffer oder Klammer.
String? _courseBaseName(String course) {
  final words = <String>[];
  for (final w in course.split(RegExp(r'\s+'))) {
    if (w.isEmpty) continue;
    if (RegExp(r'[\d(]').hasMatch(w)) break;
    words.add(w);
  }
  return words.isEmpty ? null : words.join(' ');
}

/// Doppelbesetzung zu EINER Stunde zusammenfassen.
///
/// Gleiches Fach im selben Raum = zwei Lehrkräfte für die ganze Klasse, keine
/// Parallelgruppe (Export von Schule A 16.10.26: D, M und E jeweils zweimal im selben Raum).
/// Ohne Raumangabe nur, wenn ALLE Einträge des Fachs keinen Raum haben
/// (Training: zweimal ohne Raum). Grenze: Gemischt (TXT: R106 und zweimal
/// ohne Raum) bleiben es Gruppen – lieber einmal zu viel „Gruppe wählen“ als
/// eine fremde Gruppe als eigene Stunde zeigen.
List<PlanLesson> mergeCoTeaching(List<PlanLesson> options) {
  if (options.length < 2) return options;
  final out = <PlanLesson>[];
  final bySubject = <String, List<PlanLesson>>{};
  for (final o in options) {
    bySubject.putIfAbsent(o.short, () => []).add(o);
  }
  for (final group in bySubject.values) {
    final allNoRoom = group.every((o) => o.room == null);
    final byRoom = <String?, List<PlanLesson>>{};
    for (final o in group) {
      final key =
          o.room ?? (allNoRoom ? '' : '\u0000${out.length}${o.teacher}');
      byRoom.putIfAbsent(key, () => []).add(o);
    }
    for (final same in byRoom.values) {
      if (same.length == 1) {
        out.add(same.single);
        continue;
      }
      final teachers = <String>{for (final o in same) ?o.teacher}.join(', ');
      final f = same.first;
      out.add(
        PlanLesson(
          subject: f.subject,
          short: f.short,
          room: f.room,
          teacher: teachers.isEmpty ? null : teachers,
          change: f.change,
          changeDetail: f.changeDetail,
        ),
      );
    }
  }
  return out;
}

/// Ein Kurs aus „Mein Unterricht“: Name und Lehrerkürzel.
typedef CourseRef = ({String name, Set<String> teachers});

/// Parallelgruppen automatisch wählen, wo der Unterricht des Kindes es
/// verrät: Ein Kurs, dessen Name den Fachnamen enthält („Projekt Text 6 …“
/// ⊃ „Projekt Text“), hat Lehrkräfte. Ist GENAU EINE Gruppe des Fachs bei
/// einer davon, ist das die Gruppe des Kindes. Passen mehrere Gruppen und
/// steht in JEDER Stunde des Fachs mindestens eine davon, gilt das Team der
/// Kurs-Lehrkräfte (Team-Wahl, siehe `chosenOption`) – Beleg Schule A 16.10.26:
/// zwei Kurs-Lehrkräfte, beide in jeder TXT-Stunde.
///
/// Grenze: Ohne passenden Kurs (Ästhetik hat an Schule A keine Kursmappe)
/// bleibt die Wahl offen – dann entscheidet der Nutzer. Fächer ohne
/// ausgeschriebenen Namen (Kürzel = Name) werden nicht geraten.
GroupChoice autoGroupChoice(KidPlan plan, List<CourseRef> courses) {
  final out = <String, String>{};
  for (final short in openGroupSubjects(plan, const {})) {
    final options = groupOptions(plan, short);
    if (options.isEmpty) continue;
    final subject = options.first.subject;
    if (subject == short) continue;
    final teachers = <String>{
      for (final c in courses)
        if (c.name.toLowerCase().contains(subject.toLowerCase())) ...c.teachers,
    };
    if (teachers.isEmpty) continue;
    final hits = [
      for (final o in options)
        if (KidPlan.kuerzelOf(o.teacher).any(teachers.contains)) o,
    ];
    if (hits.length == 1) {
      out[hits.single.short] = hits.single.groupKey;
      continue;
    }
    if (hits.length < 2) continue;
    final team = [
      for (final t in teachers)
        if (hits.any((o) => KidPlan.kuerzelOf(o.teacher).contains(t))) t,
    ];
    final key = team.join(', ');
    final everyLesson = plan.days.every(
      (d) => d.every(
        (c) =>
            !c.isParallel ||
            !c.options.any((o) => o.short == short) ||
            resolveCell(c, {short: key}) is ResolvedLesson,
      ),
    );
    if (everyLesson) out[short] = key;
  }
  return out;
}
