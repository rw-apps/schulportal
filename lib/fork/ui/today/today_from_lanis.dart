import 'package:liblanis/liblanis.dart';

import '../../l10n/l10n.dart';
import '../plan/plan_model.dart';
import 'today_model.dart';

/// Übersetzt Stundenplan, Vertretungsplan und Kalender eines Kontos in die
/// Datenform von „Heute“ ([ChildToday], [WeekItem]).
///
/// Grundlage ist der schon aufbereitete [KidPlan] samt Gruppenwahl – also
/// dieselben Stunden, die „Plan“ zeigt (gleiche Doppelstunden, gleiche
/// Gruppe, gleiche Lehrernamen). Der Vertretungsplan wird darübergelegt.

/// Abschnitte eines Wochentags (0 = Montag) als [DayLesson]s. Gruppen ohne
/// Wahl erscheinen mit dem Hinweis „Gruppe im Plan wählen“, statt still zu
/// fehlen – sonst sähe ein Tag mit Ästhetik kürzer aus, als er ist.
List<DayLesson> dayLessonsFor(
  KidPlan plan,
  int weekday,
  GroupChoice choice, {
  required ForkL10n t,
}) {
  if (weekday < 0 || weekday > 4 || weekday >= plan.days.length) {
    return const [];
  }
  return [
    for (final b in dayBlocks(plan, weekday, choice))
      ?_lessonOfBlock(t, plan, b),
  ];
}

DayLesson? _lessonOfBlock(ForkL10n t, KidPlan plan, DayBlock b) {
  final start = plan.slots[b.firstSlot].start;
  final end = plan.slots[b.lastSlot].end;
  final slot = blockLabel(plan, b);
  return switch (b.content) {
    ResolvedNone() => null,
    ResolvedLesson(:final lesson) => DayLesson(
      slot: slot,
      subject: lesson.subject,
      start: start,
      end: end,
      room: lesson.room,
      teacher: plan.teacherFull(lesson.teacher),
    ),
    final ResolvedOpen open => DayLesson(
      slot: slot,
      subject: groupShortLabel(plan, open.short),
      start: start,
      end: end,
      teacher: t.chooseGroupInPlan,
    ),
  };
}

/// „3 Blöcke heute“ / „6 Stunden heute“ – gezählt wie die Schule (Slots),
/// vor dem Zusammenfassen der Doppelstunden.
String? periodsLabelFor(
  KidPlan plan,
  int weekday,
  GroupChoice choice, {
  required ForkL10n t,
}) {
  if (weekday < 0 || weekday > 4 || weekday >= plan.days.length) return null;
  final n = dayBlocks(plan, weekday, choice)
      .where((b) => b.content is! ResolvedNone)
      .fold<int>(0, (sum, b) => sum + b.span);
  if (n == 0) return null;
  // „Block“ ist das Wort der Schule in der Zeilenbeschriftung (Portaldaten).
  final blocks = plan.slots.any((s) => s.label.contains('Block'));
  return blocks ? t.blocksToday(n) : t.periodsToday(n);
}

// ---- Vertretungsplan --------------------------------------------------------

/// HTML-Reste entfernen („<del>R101</del>“), leer = null.
String? _plain(String? s) {
  if (s == null) return null;
  final t = s
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .trim();
  return t.isEmpty || t == '---' || t == '-' ? null : t;
}

/// Führende Zahl einer Zeilenbeschriftung („2. Block“ → 2).
int? slotNumber(String label) =>
    int.tryParse(RegExp(r'^\s*(\d+)').firstMatch(label)?.group(1) ?? '');

/// „3“ → {3}; „3 - 4“ → {3, 4}.
Set<int> hoursOf(String stunde) {
  final nums = RegExp(r'\d+').allMatches(stunde).map((m) => int.parse(m[0]!));
  if (nums.isEmpty) return const {};
  final a = nums.first;
  final b = nums.last;
  return {for (var i = a; i <= (b < a ? a : b); i++) i};
}

/// Art einer Vertretungszeile mit kurzer Angabe für die Anzeige.
///
/// Ursache der Wortlisten: Das Portal liefert die Spalte „Art“ als Freitext
/// der Schule („Entfall“, „Raumvertretung“, „Vertretung“ …). Grenze: Ein
/// unbekannter Ausdruck gilt als Vertretung, nie als Ausfall – lieber eine
/// gelbe Zeile zu viel als ein Kind, das zu Hause bleibt.
({ChangeKind kind, String? detail}) classifySubstitution(
  Substitution s, {
  required ForkL10n t,
  String? lessonRoom,
  List<String> lessonTeachers = const [],
  String Function(String kuerzel)? nameOf,
}) {
  String name(String k) => nameOf?.call(k) ?? k;
  final art = (_plain(s.art) ?? '').toLowerCase();
  final hint = _plain(s.hinweis);
  final room = _plain(s.raum);
  final roomBefore = _plain(s.raum_alt) ?? lessonRoom;
  final absent = _plain(s.Lehrerkuerzel);
  final sub = _plain(s.Vertreterkuerzel);
  final subText = _plain(s.vertreter);

  final cancelWords = RegExp(r'entfall|ausfall|fällt aus|entfällt|frei');
  final cancelled =
      cancelWords.hasMatch(art) ||
      (hint != null &&
          RegExp(r'entfällt|fällt aus').hasMatch(hint.toLowerCase()));
  if (cancelled) {
    // Doppelbesetzung: Fehlt nur eine von zwei Lehrkräften, findet die
    // Stunde statt (Schule A: D, M, E zu zweit). Ohne diese Grenze zeigte „Heute“
    // einen Ausfall, obwohl die zweite Lehrkraft unterrichtet.
    final others = lessonTeachers.where((t) => t != absent).toList();
    if (absent != null &&
        lessonTeachers.contains(absent) &&
        others.isNotEmpty) {
      return (
        kind: ChangeKind.substitution,
        detail: t.teacherAbsent(name(absent)),
      );
    }
    return (kind: ChangeKind.cancelled, detail: hint);
  }

  final sameTeacher = (sub == null && subText == null) || sub == absent;
  final roomMoved = room != null && room != roomBefore;
  if (art.contains('raum') || (sameTeacher && roomMoved)) {
    return (
      kind: ChangeKind.roomChange,
      detail: room == null
          ? hint
          : (roomBefore != null && roomBefore != room
                ? t.roomInsteadOf(room, roomBefore)
                : room),
    );
  }

  final who = sub != null ? name(sub) : subText;
  final parts = [?who, if (roomMoved) room];
  return (
    kind: ChangeKind.substitution,
    detail: parts.isEmpty ? (hint ?? _plain(s.art)) : parts.join(', '),
  );
}

/// Betrifft die Zeile die Stunde des Kindes? Bei Parallelgruppen stehen
/// auch die Vertretungen der ANDEREN Gruppen im Klassenplan (Lehrkraft der
/// anderen Gruppe fehlt). Grenze: Ohne Lehrerkürzel in der Zeile wird sie
/// angenommen – sonst ginge ein echter Ausfall verloren.
bool _concerns(Substitution s, PlanLesson? lesson) {
  final absent = _plain(s.Lehrerkuerzel);
  if (lesson == null || absent == null || lesson.teacher == null) return true;
  return KidPlan.kuerzelOf(lesson.teacher).contains(absent);
}

/// Der Plan mit den Vertretungen der angezeigten Woche ([week], Mo–Fr) –
/// für Tag und Woche im Kalender.
///
/// Ursache: Mit dem Wegfall der bisherigen Ansicht (Entscheidung 17.10.26)
/// gab es den Vertretungsplan sonst nur noch auszugsweise in „Heute“. Die
/// Zuordnung ist dieselbe wie dort (Stundennummer, Lehrkraft der Gruppe,
/// classifySubstitution). Grenze: Bei offener Gruppenwahl („2 Gruppen –
/// wählen“) wird die Zeile jeder passenden Gruppe angehängt; Tage außerhalb
/// von [week] bleiben unberührt.
KidPlan planWithSubstitutions({
  required KidPlan plan,
  required List<SubstitutionDay> days,
  required List<DateTime> week,
  required ForkL10n t,
}) {
  if (days.isEmpty) return plan;
  final out = [
    for (final d in plan.days) [for (final c in d) List.of(c.options)],
  ];
  String nameOf(String k) => plan.teacherFull(k) ?? k;
  var changed = false;
  for (final d in days) {
    final date = DateTime(d.dateTime.year, d.dateTime.month, d.dateTime.day);
    final wd = week.indexWhere(
      (w) => w.year == date.year && w.month == date.month && w.day == date.day,
    );
    if (wd < 0 || wd >= out.length) continue;
    for (final s in d.substitutions) {
      final hours = hoursOf(s.stunde);
      final code = (_plain(s.fach) ?? _plain(s.fach_alt))?.toUpperCase();
      for (var i = 0; i < plan.slots.length && i < out[wd].length; i++) {
        if (!hours.contains(slotNumber(plan.slots[i].label))) continue;
        final opts = out[wd][i];
        for (var j = 0; j < opts.length; j++) {
          final o = opts[j];
          if (code != null && o.short.toUpperCase() != code) continue;
          if (!_concerns(s, o)) continue;
          final c = classifySubstitution(
            s,
            t: t,
            lessonRoom: o.room,
            lessonTeachers: KidPlan.kuerzelOf(o.teacher),
            nameOf: nameOf,
          );
          // Ausfall schlägt alles; sonst bleibt die erste Angabe.
          if (o.change != null && c.kind != ChangeKind.cancelled) continue;
          opts[j] = PlanLesson(
            subject: o.subject,
            short: o.short,
            room: c.kind == ChangeKind.roomChange
                ? (_plain(s.raum) ?? o.room)
                : o.room,
            teacher: o.teacher,
            change: c.kind,
            changeDetail: c.detail,
          );
          changed = true;
        }
      }
    }
  }
  if (!changed) return plan;
  return KidPlan(
    firstName: plan.firstName,
    colorIndex: plan.colorIndex,
    slots: plan.slots,
    days: [
      for (final d in out) [for (final o in d) PlanCell(o)],
    ],
    teacherNames: plan.teacherNames,
  );
}

/// Vertretungen eines Kindes: als [ChangeItem]s (Kasten, Wochenleiste) und
/// für [today] eingearbeitet in die Abschnitte des Tages.
///
/// Zuordnung über die Stundennummer: „Stunde 2“ im Vertretungsplan = Zeile
/// „2. Block“ im Stundenplan. Grenze: Zählt eine Schule im Vertretungsplan
/// Einzelstunden, im Stundenplan aber Blöcke, verschiebt sich das – noch
/// ungeprüft, an Schule A standen am 16.10.26 keine Vertretungen im Plan.
({List<ChangeItem> changes, List<DayLesson> today}) applySubstitutions({
  required KidPlan plan,
  required GroupChoice choice,
  required List<SubstitutionDay> days,
  required DateTime now,
  required ForkL10n t,
  String Function(String code)? subjectName,
}) {
  final todayWd = now.weekday - 1;
  final todayDate = DateTime(now.year, now.month, now.day);
  final todayBlocks = todayWd <= 4
      ? dayBlocks(plan, todayWd, choice)
      : <DayBlock>[];
  final today = dayLessonsFor(plan, todayWd, choice, t: t);
  // Abschnitt der Tagesliste je Block (ResolvedNone hat keinen Eintrag).
  final todayIndex = <int, int>{};
  var li = 0;
  for (var b = 0; b < todayBlocks.length; b++) {
    if (todayBlocks[b].content is ResolvedNone) continue;
    todayIndex[b] = li++;
  }

  final subjects = <String, String>{
    for (final d in plan.days)
      for (final c in d)
        for (final o in c.options) o.short.toUpperCase(): o.subject,
  };
  String nameOf(String k) => plan.teacherFull(k) ?? k;

  final changes = <ChangeItem>[];
  final seen = <String>{};
  for (final d in days) {
    final date = DateTime(d.dateTime.year, d.dateTime.month, d.dateTime.day);
    final wd = date.weekday - 1;
    final blocks = wd <= 4 ? dayBlocks(plan, wd, choice) : <DayBlock>[];
    for (final s in d.substitutions) {
      final hours = hoursOf(s.stunde);
      final slotIdx = [
        for (var i = 0; i < plan.slots.length; i++)
          if (hours.contains(slotNumber(plan.slots[i].label))) i,
      ];
      final bIdx = slotIdx.isEmpty
          ? -1
          : blocks.indexWhere(
              (b) =>
                  b.firstSlot <= slotIdx.first && slotIdx.first <= b.lastSlot,
            );
      final block = bIdx < 0 ? null : blocks[bIdx];
      final lesson = switch (block?.content) {
        ResolvedLesson(:final lesson) => lesson,
        _ => null,
      };
      if (!_concerns(s, lesson)) continue;
      final c = classifySubstitution(
        s,
        t: t,
        lessonRoom: lesson?.room,
        lessonTeachers: KidPlan.kuerzelOf(lesson?.teacher),
        nameOf: nameOf,
      );
      final code = _plain(s.fach) ?? _plain(s.fach_alt) ?? '';
      final subject =
          lesson?.subject ??
          subjects[code.toUpperCase()] ??
          (code.isEmpty ? t.lessonFallback : (subjectName?.call(code) ?? code));
      final slot = block != null
          ? blockLabel(plan, block)
          : (slotIdx.isNotEmpty
                ? plan.slots[slotIdx.first].label
                : '${s.stunde.trim()}.');
      final key = '$date|$slot|${c.kind}|${c.detail}';
      if (!seen.add(key)) continue;
      changes.add(
        ChangeItem(
          day: date,
          slot: slot,
          subject: subject,
          kind: c.kind,
          detail: c.detail,
        ),
      );

      if (date == todayDate && bIdx >= 0 && todayIndex[bIdx] != null) {
        final i = todayIndex[bIdx]!;
        final x = today[i];
        // Ausfall schlägt alles; sonst gewinnt die erste Angabe.
        if (x.change != null && c.kind != ChangeKind.cancelled) continue;
        today[i] = DayLesson(
          slot: x.slot,
          subject: x.subject,
          start: x.start,
          end: x.end,
          room: c.kind == ChangeKind.roomChange
              ? (_plain(s.raum) ?? x.room)
              : x.room,
          teacher: x.teacher,
          change: c.kind,
          changeDetail: c.detail,
        );
      }
    }
  }
  changes.sort((a, b) => a.day.compareTo(b.day));
  return (changes: changes, today: today);
}

/// Ein Kind für „Heute“.
ChildToday childTodayFromLanis({
  required KidPlan plan,
  required GroupChoice choice,
  required List<SubstitutionDay> substitutions,
  required DateTime now,
  required String school,
  required ForkL10n t,
  String className = '',
  bool canReportAbsence = false,
  String Function(String code)? subjectName,
  String? mealHint,
  String? mensaUrl,
  int openHomework = 0,
  int unreadMessages = 0,
}) {
  final r = applySubstitutions(
    plan: plan,
    choice: choice,
    days: substitutions,
    now: now,
    t: t,
    subjectName: subjectName,
  );
  return ChildToday(
    firstName: plan.firstName,
    school: school,
    className: className,
    colorIndex: plan.colorIndex,
    lessons: r.today,
    periodsLabel: periodsLabelFor(plan, now.weekday - 1, choice, t: t),
    changes: r.changes,
    canReportAbsence: canReportAbsence,
    mealHint: mealHint,
    mensaUrl: mensaUrl,
    openHomework: openHomework,
    unreadMessages: unreadMessages,
  );
}

/// „Musterschule (Frankfurt)“ → „Musterschule“.
String shortSchoolName(String name) =>
    name.replaceAll(RegExp(r'\s*\(.*\)\s*$'), '').trim();

/// Klasse aus den Kursnamen von „Mein Unterricht“ („Naturwissenschaften
/// 06 xy (061NAWI05-IGS)“ → „06 XY“), häufigster Treffer gewinnt.
///
/// Ursache: Elternkonten liefern die Klasse nicht in den Benutzerdaten, und
/// Stundenplan/Vertretungsplan nennen sie nur im Seitentitel, den liblanis
/// nicht weitergibt. Grenze: Ohne Kurs mit Klassenangabe bleibt sie leer.
String classFromCourses(List<String> courseNames) {
  final count = <String, int>{};
  for (final c in courseNames) {
    final m = RegExp(r'\b(\d{2})\s+([a-zA-Z]{1,3})\b').firstMatch(c);
    if (m == null) continue;
    final k = '${m[1]} ${m[2]!.toUpperCase()}';
    count[k] = (count[k] ?? 0) + 1;
  }
  if (count.isEmpty) return '';
  return (count.entries.toList()..sort((a, b) => b.value - a.value)).first.key;
}

// ---- Kalender ---------------------------------------------------------------

/// Hinweis zum Mittagessen („Kein Essen für alle Jg.!“)? Solche Einträge
/// stehen an Schule A fast jede Woche im Kalender (Kategorie „Erinnerung“,
/// Export 16.10.26: 6 von 23 Terminen). Als Kachel unter „Demnächst“
/// verdrängten sie die echten Termine; sie erscheinen stattdessen als
/// Hinweis am Tag neben „Essen bestellen“ ([mealHintFor]). Grenze: Nur das
/// Wort „Essen“/„Mittagessen“/„Mensa“ als ganzes Wort („Interessen“ nicht).
bool isMealNote(String title) => RegExp(
  r'\b(mittag)?essen\b|\bmensa\b',
  caseSensitive: false,
).hasMatch(title);

/// Termine ab jetzt für die nächsten [days] Tage.
///
/// [includeMeals] = false für „Heute“ (dort steht der Essenshinweis an der
/// Kinderkarte), true für die vollständige Liste im Kalender.
///
/// Art nach Kategorie der Schule (Schule A: „Arbeiten“, „Ferien/Schulfreie
/// Tage“, „Erinnerung“ …) und Stichworten im Titel. Ausgelassen:
/// „Pausenaufsicht“ und „Schulwochen“ (Lehrerdienst bzw. A/B-Wochen, für
/// Eltern nur Rauschen) sowie Termine für andere Jahrgänge, wenn der Titel
/// sie nennt („8-10 Klassen …“, „nur für 5, 6 und 7 Jg.“) und die Klasse
/// bekannt ist.
List<WeekItem> weekItemsFromCalendar(
  List<CalendarEvent> events,
  DateTime now, {
  int? childIndex,
  String className = '',
  int days = 14,
  bool includeMeals = false,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final horizon = DateTime(now.year, now.month, now.day + days);
  final grade = int.tryParse(RegExp(r'^\d+').stringMatch(className) ?? '');
  final out = <(DateTime, WeekItem)>[];
  for (final e in events) {
    if (e.endTime.isBefore(now) || !e.startTime.isBefore(horizon)) continue;
    final cat = (e.category?.name ?? '').toLowerCase();
    if (cat.contains('pausenaufsicht') || cat.contains('schulwoche')) continue;
    final title = e.title.trim();
    if (title.isEmpty) continue;
    if (grade != null && !forGrade(title, grade)) continue;
    final meal = isMealNote(title);
    if (meal && !includeMeals) continue;
    final lower = title.toLowerCase();
    final kind = meal
        ? WeekKind.meal
        : cat.contains('arbeit') ||
              RegExp(
                r'lernkontrolle|klassenarbeit|klausur|\btest\b',
              ).hasMatch(lower)
        ? WeekKind.exam
        : (cat.contains('ferien') ||
                  cat.contains('frei') ||
                  RegExp(r'ferien|unterrichtsfrei').hasMatch(lower)
              ? WeekKind.free
              : (lower.contains('abgabe')
                    ? WeekKind.deadline
                    : WeekKind.event));
    final start = e.startTime;
    final day = start.isBefore(today)
        ? today
        : DateTime(start.year, start.month, start.day);
    final end = e.endTime;
    final endDay = DateTime(end.year, end.month, end.day);
    final timed = !e.allDay && !(start.hour == 0 && start.minute == 0);
    out.add((
      start,
      WeekItem(
        day: day,
        title: title,
        kind: kind,
        childIndex: childIndex,
        time: timed ? _hhmm(start) : null,
        until: endDay.isAfter(day) ? endDay : null,
        place: _blank(e.place),
      ),
    ));
  }
  out.sort((a, b) {
    final d = a.$2.day.compareTo(b.$2.day);
    return d != 0 ? d : a.$1.compareTo(b.$1);
  });
  return [for (final x in out) x.$2];
}

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String? _blank(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// Essenshinweis für die Kinderkarte: die von heute, ab 14 Uhr die von
/// morgen (dann ist das heutige Essen vorbei, das morgige noch planbar).
String? mealHintFor(
  List<CalendarEvent> events,
  DateTime now, {
  required ForkL10n t,
  String className = '',
}) {
  final afternoon = now.hour >= 14;
  final target = DateTime(now.year, now.month, now.day + (afternoon ? 1 : 0));
  final grade = int.tryParse(RegExp(r'^\d+').stringMatch(className) ?? '');
  final notes = <String>{};
  for (final e in events) {
    final title = e.title.trim();
    if (!isMealNote(title)) continue;
    if (grade != null && !forGrade(title, grade)) continue;
    final a = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
    final b = DateTime(e.endTime.year, e.endTime.month, e.endTime.day);
    if (target.isBefore(a) || target.isAfter(b)) continue;
    notes.add(title);
  }
  if (notes.isEmpty) return null;
  final text = notes.join(' · ');
  return afternoon ? t.mealTomorrow(text) : t.mealToday(text);
}

/// Gilt der Titel für [grade]? Erkennt Bereiche („5-7 Klassen“, „Jg. 8–10“)
/// und Aufzählungen („nur für 5, 6 und 7 Jg.“). Ohne Angabe: für alle.
bool forGrade(String title, int grade) {
  final range =
      RegExp(
        r'(\d{1,2})\s*[-–]\s*(\d{1,2})\s*\.?\s*(?:klass|jg|jahrg)',
        caseSensitive: false,
      ).firstMatch(title) ??
      RegExp(
        r'(?:klassen?|jg\.?|jahrgang|jahrgänge)\s*(\d{1,2})\s*[-–]\s*(\d{1,2})',
        caseSensitive: false,
      ).firstMatch(title);
  if (range != null) {
    final a = int.parse(range[1]!);
    final b = int.parse(range[2]!);
    return grade >= a && grade <= b;
  }
  final list = RegExp(
    r'((?:\d{1,2}\s*(?:,|und|u\.|/)\s*)+\d{1,2})\.?\s*(?:klass|jg|jahrg)',
    caseSensitive: false,
  ).firstMatch(title);
  if (list != null) {
    final grades = RegExp(
      r'\d{1,2}',
    ).allMatches(list[1]!).map((m) => int.parse(m[0]!)).toSet();
    return grades.contains(grade);
  }
  return true;
}
