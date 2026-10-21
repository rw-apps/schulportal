import 'dart:typed_data';

import 'package:liblanis/liblanis.dart';

import '../../courses_scan.dart';
import '../../exams.dart';
import '../../l10n/l10n.dart';
import '../plan/plan_model.dart';
import 'today_model.dart';
import '../../data/portal_rules.dart';

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
  // Ohne Uhrzeiten der Schule (KidPlan.timed) leer statt Ersatzzeit.
  final start = plan.timed ? plan.slots[b.firstSlot].start : '';
  final end = plan.timed ? plan.slots[b.lastSlot].end : '';
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
      change: lesson.change,
      changeDetail: lesson.changeDetail,
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

  final cancelled =
      PortalRules.cancelKind.hasMatch(art) ||
      (hint != null && PortalRules.cancelHint.hasMatch(hint.toLowerCase()));
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

  // Auch die Spalte „Vertreter“ über das Namensverzeichnis: Der Plan als
  // HTML-Tabelle (liblanis substitutions/parser.dart, Zweig ohne AJAX) füllt
  // nur „Vertreter“/„Lehrer“, keine Kürzel-Spalten – bei Schule A steht dort
  // das Kürzel selbst (Bildschirmfoto 21.10.26: Vertretung mit Kürzel,
  // obwohl der Name aus „Mein Unterricht“ bekannt war). Grenze: Steht dort
  // schon ein Name, bleibt er unverändert (KidPlan.teacherFull übersetzt nur
  // bekannte Kürzel); unbekannte Kürzel bleiben Kürzel.
  final who = sub != null
      ? name(sub)
      : (subText == null ? null : name(subText));
  final parts = [?who, if (roomMoved) room];
  return (
    kind: ChangeKind.substitution,
    detail: parts.isEmpty ? (hint ?? _plain(s.art)) : parts.join(', '),
  );
}

/// Nennt die Zeile einen anderen Kurs, den die Klasse in dieser Stunde hat
/// ([classCodes], KidPlan.classCodes)? Dann betrifft sie sicher den
/// Parallelkurs, nicht die Stunde [o]. Ursache (Rückmeldung 21.10.26):
/// Schule B kürzt Ethik „ETHI“ ab – kein Eintrag in SubjectNames.known,
/// [_otherSubject] allein hätte den Ausfall weiter Religion zugeordnet.
bool _otherCourse(Set<String> codes, PlanLesson o, Set<String> classCodes) {
  final own = o.short.toUpperCase();
  if (codes.isEmpty || codes.contains(own)) return false;
  return codes.any((c) => c != own && classCodes.contains(c));
}

/// Nennt die Zeile (Fächer [codes], Fach und altes Fach) sicher ein anderes
/// Fach als die Stunde [o]? Ja nur, wenn KEIN Kürzel zur Stunde passt und
/// JEDES Kürzel einem Fachnamen zugeordnet ist (Plan des Kindes, sonst
/// SubjectNames.known), der vom Fach der Stunde abweicht – z. B. „ETH“
/// (Ethik) neben „Ev. Religion“. Unbekannte Kürzel ergeben nein.
bool _otherSubject(
  Set<String> codes,
  PlanLesson o,
  Map<String, String> planNames,
) {
  if (codes.isEmpty) return false;
  String norm(String s) => s.trim().toLowerCase();
  for (final c in codes) {
    if (c == o.short.toUpperCase()) return false;
    final base = c.replaceAll(RegExp(r'\d+$'), '');
    final name =
        planNames[c] ?? SubjectNames.known[c] ?? SubjectNames.known[base];
    if (name == null || norm(name) == norm(o.subject)) return false;
  }
  return true;
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
/// für Tag und Woche im Kalender, und (über [applySubstitutions]) für
/// Heute, den Kasten „Morgen“, das „!“ am Reiter und die Hinweise.
///
/// Ursache: Mit dem Wegfall der bisherigen Ansicht (Entscheidung 17.10.26)
/// gab es den Vertretungsplan sonst nur noch auszugsweise in „Heute“.
/// Zuordnung je Stunde über die Stundennummer und die Lehrkraft der Gruppe
/// (_concerns), Art über classifySubstitution. Grenze: Bei offener
/// Gruppenwahl („2 Gruppen – wählen“) wird die Zeile jeder passenden Gruppe
/// angehängt; Tage außerhalb von [week] bleiben unberührt.
///
/// [free]: schulfreie Tage (freeDaysFrom) – an ihnen bleibt der Tag leer.
KidPlan planWithSubstitutions({
  required KidPlan plan,
  required List<SubstitutionDay> days,
  required List<DateTime> week,
  required ForkL10n t,
  Map<DateTime, String> free = const {},
}) => _overlay(plan: plan, days: days, week: week, t: t, free: free).plan;

/// [planWithSubstitutions] samt den Zeilen, die keine Stunde des Plans
/// trafen (für [applySubstitutions]).
///
/// Fach der Zeile: Bei parallelen Gruppen verschiedener Fächer
/// (Religion/Ethik) muss Fach ODER altes Fach (Fachwechsel: „Fach“ ist das
/// neue) dem Kürzel der Gruppe gleichen. Ursache (Prüfung 20.10.26):
/// Bisher verlangte der Kalender, dass „Fach“ dem Kürzel im Plan gleicht –
/// ein Fachwechsel fiel so durch, Heute zeigte ihn.
///
/// Eine einzelne Stunde wird verworfen, wenn die Zeile sicher ein ANDERES
/// Fach nennt ([_otherSubject]). Ursache (Rückmeldung 21.10.26): Im
/// eigenen Stundenplan eines Schülerkontos steht nur der eigene Kurs
/// (Ev. Religion), nicht die Parallelkurse; der Vertretungsplan von
/// Schule B hat keine Spalte Lehrerkürzel, also prüft [_concerns] nichts –
/// der Ausfall des Ethikkurses erschien als Ausfall von Religion. Grenze:
/// Ein unbekanntes Kürzel verwirft nichts (lieber ein Hinweis zu viel als
/// ein verpasster Ausfall).
({KidPlan plan, List<(DateTime, Substitution)> unmatched}) _overlay({
  required KidPlan plan,
  required List<SubstitutionDay> days,
  required List<DateTime> week,
  required ForkL10n t,
  Map<DateTime, String> free = const {},
}) {
  final unmatched = <(DateTime, Substitution)>[];
  final freeIdx = [
    for (var i = 0; i < week.length && i < plan.days.length; i++)
      if (free.containsKey(DateTime(week[i].year, week[i].month, week[i].day)))
        i,
  ];
  if (days.isEmpty && freeIdx.isEmpty) {
    return (plan: plan, unmatched: unmatched);
  }
  final out = [
    for (final d in plan.days) [for (final c in d) List.of(c.options)],
  ];
  String nameOf(String k) => plan.teacherFull(k) ?? k;
  // Kürzel → Fach aus dem Plan des Kindes (für _otherSubject).
  final planNames = {
    for (final d in plan.days)
      for (final c in d)
        for (final o in c.options) o.short.toUpperCase(): o.subject,
  };
  var changed = false;
  for (final i in freeIdx) {
    for (final c in out[i]) {
      c.clear();
    }
    changed = true;
  }
  for (final d in days) {
    final date = DateTime(d.dateTime.year, d.dateTime.month, d.dateTime.day);
    final wd = week.indexWhere(
      (w) => w.year == date.year && w.month == date.month && w.day == date.day,
    );
    if (wd < 0 || wd >= out.length || freeIdx.contains(wd)) continue;
    for (final s in d.substitutions) {
      final hours = hoursOf(s.stunde);
      final codes = {
        for (final c in [_plain(s.fach), _plain(s.fach_alt)])
          if (c != null) c.toUpperCase(),
      };
      var hit = false;
      for (var i = 0; i < plan.slots.length && i < out[wd].length; i++) {
        if (!hours.contains(slotNumber(plan.slots[i].label))) continue;
        final opts = out[wd][i];
        for (var j = 0; j < opts.length; j++) {
          final o = opts[j];
          if (opts.length > 1 &&
              codes.isNotEmpty &&
              !codes.contains(o.short.toUpperCase())) {
            continue;
          }
          if (opts.length == 1 &&
              (_otherCourse(codes, o, plan.classCodesAt(wd, i)) ||
                  _otherSubject(codes, o, planNames))) {
            continue;
          }
          if (!_concerns(s, o)) continue;
          hit = true;
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
      if (!hit) unmatched.add((date, s));
    }
  }
  if (!changed) return (plan: plan, unmatched: unmatched);
  return (
    plan: KidPlan(
      firstName: plan.firstName,
      colorIndex: plan.colorIndex,
      slots: plan.slots,
      days: [
        for (final d in out) [for (final o in d) PlanCell(o)],
      ],
      teacherNames: plan.teacherNames,
      timed: plan.timed,
      customTimes: plan.customTimes,
      classCodes: plan.classCodes,
    ),
    unmatched: unmatched,
  );
}

/// Vertretungen eines Kindes: als [ChangeItem]s (Kasten, Wochenleiste,
/// „!“, Hinweise) und für [today] eingearbeitet in die Abschnitte des Tages
/// – beides aus dem überlagerten Plan wie im Kalender ([_overlay]).
///
/// Ursache (Prüfung 20.10.26): Bisher ordnete Heute eine Zeile dem ganzen
/// Abschnitt zu, in dem ihre erste Stunde liegt. Fiel nur die 6. Stunde
/// einer Doppelstunde 5–6 aus, galt auf Heute die ganze Doppelstunde als
/// ausgefallen und das Schulende lag eine Stunde zu früh; der Kalender
/// zeigte richtig nur die 6. Jetzt teilt dayBlocks die Doppelstunde
/// (PlanLesson.sameAs vergleicht die Änderung mit).
///
/// Zeilen ohne passende Stunde des Kindes: Trifft die Stundennummer keine
/// Zeile des Plans (Zählweise unbekannt), bleiben sie im Kasten – sonst
/// ginge ein echter Ausfall verloren. Ist die Stunde im Klassenplan leer
/// (Zusatz- oder verlegte Stunde), bleiben sie ohne Ausfall. Hat die
/// Klasse dort Unterricht, aber nicht in der Gruppe des Kindes, betreffen
/// sie ein anderes Kind und entfallen – bisher erschienen sie als Ausfall
/// im Kasten, im „!“ und als Hinweis.
///
/// Grenze: Zählt eine Schule im Vertretungsplan Einzelstunden, im
/// Stundenplan aber Blöcke, verschiebt sich die Zuordnung – noch
/// ungeprüft, an Schule A standen bisher keine Vertretungen im Plan.
({List<ChangeItem> changes, List<DayLesson> today}) applySubstitutions({
  required KidPlan plan,
  required GroupChoice choice,
  required List<SubstitutionDay> days,
  required DateTime now,
  required ForkL10n t,
  String Function(String code)? subjectName,
  Map<DateTime, String> free = const {},
}) {
  final todayWd = now.weekday - 1;
  final todayDate = DateTime(now.year, now.month, now.day);
  // Schulfrei (freeDaysFrom): kein Unterricht, keine Vertretungen.
  var today = free.containsKey(todayDate)
      ? const <DayLesson>[]
      : dayLessonsFor(plan, todayWd, choice, t: t);

  final subjects = <String, String>{
    for (final d in plan.days)
      for (final c in d)
        for (final o in c.options) o.short.toUpperCase(): o.subject,
  };

  final changes = <(DateTime, int, ChangeItem)>[];
  final seen = <String>{};
  void add(int order, ChangeItem c) {
    if (!seen.add('${c.day}|${c.slot}|${c.kind}|${c.detail}')) return;
    changes.add((c.day, order, c));
  }

  for (final d in days) {
    final date = DateTime(d.dateTime.year, d.dateTime.month, d.dateTime.day);
    final wd = date.weekday - 1;
    if (wd > 4 || wd >= plan.days.length || free.containsKey(date)) continue;
    final week = [
      for (var i = 0; i < 5; i++)
        DateTime(date.year, date.month, date.day - wd + i),
    ];
    final o = _overlay(plan: plan, days: [d], week: week, t: t);
    for (final b in dayBlocks(o.plan, wd, choice)) {
      final changed = switch (b.content) {
        ResolvedLesson(:final lesson) => [lesson],
        ResolvedOpen(:final options) => options,
        ResolvedNone() => const <PlanLesson>[],
      }.where((l) => l.change != null);
      for (final l in changed) {
        add(
          b.firstSlot,
          ChangeItem(
            day: date,
            slot: blockLabel(o.plan, b),
            subject: l.subject,
            kind: l.change!,
            detail: l.changeDetail,
          ),
        );
      }
    }
    if (date == todayDate) today = dayLessonsFor(o.plan, wd, choice, t: t);

    for (final (_, s) in o.unmatched) {
      final hours = hoursOf(s.stunde);
      final slotIdx = [
        for (var i = 0; i < plan.slots.length; i++)
          if (hours.contains(slotNumber(plan.slots[i].label))) i,
      ];
      final c = classifySubstitution(
        s,
        t: t,
        nameOf: (k) => plan.teacherFull(k) ?? k,
      );
      if (slotIdx.isNotEmpty) {
        final classHasLesson = slotIdx.any(
          (i) => i < plan.days[wd].length && !plan.days[wd][i].isEmpty,
        );
        if (classHasLesson || c.kind == ChangeKind.cancelled) continue;
      }
      final code = _plain(s.fach) ?? _plain(s.fach_alt) ?? '';
      add(
        slotIdx.isEmpty ? 99 : slotIdx.first,
        ChangeItem(
          day: date,
          slot: slotIdx.isNotEmpty
              ? plan.slots[slotIdx.first].label
              : '${s.stunde.trim()}.',
          subject:
              subjects[code.toUpperCase()] ??
              (code.isEmpty
                  ? t.lessonFallback
                  : (subjectName?.call(code) ?? code)),
          kind: c.kind,
          detail: c.detail,
        ),
      );
    }
  }
  changes.sort((a, b) {
    final d = a.$1.compareTo(b.$1);
    return d != 0 ? d : a.$2.compareTo(b.$2);
  });
  return (changes: [for (final c in changes) c.$3], today: today);
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
  Uint8List? photo,
  Map<DateTime, String> free = const {},
}) {
  final r = applySubstitutions(
    plan: plan,
    choice: choice,
    days: substitutions,
    now: now,
    t: t,
    subjectName: subjectName,
    free: free,
  );
  final freeLabel = free[DateTime(now.year, now.month, now.day)];
  return ChildToday(
    firstName: plan.firstName,
    school: school,
    className: className,
    colorIndex: plan.colorIndex,
    lessons: r.today,
    periodsLabel: freeLabel != null
        ? null
        : periodsLabelFor(plan, now.weekday - 1, choice, t: t),
    changes: r.changes,
    canReportAbsence: canReportAbsence,
    mealHint: freeLabel != null ? null : mealHint,
    mensaUrl: mensaUrl,
    openHomework: openHomework,
    unreadMessages: unreadMessages,
    photo: photo,
    freeLabel: freeLabel,
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
bool isMealNote(String title) => PortalRules.meal.hasMatch(title);

/// Allgemeiner Feiertag ohne Bezug zur Schule („Reformationstag“), siehe
/// PortalRules.plainHoliday; Satzzeichen am Ende zählen nicht.
bool isPlainHoliday(String title) => PortalRules.plainHoliday.hasMatch(
  title.toLowerCase().trim().replaceAll(RegExp(r'[\s!.:]+$'), ''),
);

/// Schulfreie Schultage (Mo–Fr) ab heute laut Schulkalender: Tag → Titel
/// des Eintrags („Herbstferien“). Heute, Kalender und Kursseite leeren an
/// diesen Tagen den Stundenplan (planWithSubstitutions, applySubstitutions,
/// nextLessonOf).
///
/// Ursache (Prüfung 20.10.26): Freie Tage wirkten nirgends auf den Plan –
/// in den Ferien zeigte Heute „Jetzt Mathe“, während „Demnächst“ schon
/// „Schulfrei“ sagte.
///
/// Was zählt: Kategorie der Schule für Ferien/freie Tage
/// (PortalRules.freeCategories) oder ein Titel, der nur den freien Tag
/// nennt (PortalRules.freeDayTitle – „Ferienbetreuung“ zählt nicht);
/// ganztägig oder über mehrere Tage; nicht nur für einen Teil des Tages
/// (PortalRules.partialDay); für die eigene Klasse ([forClass]). Grenzen:
/// Allgemeine Feiertage in der Ferien-Kategorie („Reformationstag“, an
/// Schule B so eingetragen) zählen nicht – manche sind Schultage. Ein
/// Ferieneintrag mit Uhrzeit über mehrere Tage (Schule A: 05.10. 11:00 bis
/// 16.10. 12:00) gilt an allen seinen Tagen ganz.
Map<DateTime, String> freeDaysFrom(
  List<CalendarEvent> events,
  DateTime now, {
  String className = '',
  int days = 400,
}) {
  DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
  final today = dayOf(now);
  final last = DateTime(today.year, today.month, today.day + days);
  final out = <DateTime, String>{};
  for (final e in events) {
    final title = e.title.trim();
    if (title.isEmpty) continue;
    final cat = (e.category?.name ?? '').toLowerCase();
    final named = PortalRules.freeDayTitle.hasMatch(title);
    if (!named && !PortalRules.freeCategories.any(cat.contains)) continue;
    if (!named && isPlainHoliday(title)) continue;
    if (PortalRules.partialDay.hasMatch(title)) continue;
    if (!forClass(title, className)) continue;
    final a = dayOf(e.startTime);
    var b = dayOf(e.endTime);
    final endsAtMidnight = e.endTime.hour == 0 && e.endTime.minute == 0;
    // Ganztägige Einträge enden oft um 0 Uhr des Folgetags (exklusiv).
    if (endsAtMidnight && b.isAfter(a)) {
      b = DateTime(b.year, b.month, b.day - 1);
    }
    final startsAtMidnight = e.startTime.hour == 0 && e.startTime.minute == 0;
    final whole =
        e.allDay ||
        b.isAfter(a) ||
        (startsAtMidnight && (endsAtMidnight || e.endTime.hour >= 23));
    if (!whole) continue;
    for (
      var d = a.isBefore(today) ? today : a;
      !d.isAfter(b) && !d.isAfter(last);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      if (d.weekday <= DateTime.friday) out.putIfAbsent(d, () => title);
    }
  }
  return out;
}

/// Termine ab jetzt für die nächsten [days] Tage.
///
/// [includeMeals] = false für „Heute“ (dort steht der Essenshinweis an der
/// Kinderkarte), true für die vollständige Liste im Kalender.
///
/// Art nach Kategorie der Schule (Schule A: „Arbeiten“, „Ferien/Schulfreie
/// Tage“, „Erinnerung“ …) und Stichworten im Titel. Ausgelassen:
/// „Pausenaufsicht“ und „Schulwochen“ (Lehrerdienst bzw. A/B-Wochen, für
/// Eltern nur Rauschen) sowie Termine, die sicher nur andere Klassen oder
/// Jahrgänge betreffen ([forClass]), wenn die Klasse bekannt ist.
///
/// [skipHolidays]: allgemeine Feiertage weglassen (PortalRules.plainHoliday)
/// – für „Demnächst“; der Kalender zeigt alles.
List<WeekItem> weekItemsFromCalendar(
  List<CalendarEvent> events,
  DateTime now, {
  int? childIndex,
  String className = '',
  int days = 14,
  bool includeMeals = false,
  bool skipHolidays = false,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final horizon = DateTime(now.year, now.month, now.day + days);
  final out = <(DateTime, WeekItem)>[];
  for (final e in events) {
    if (e.endTime.isBefore(now) || !e.startTime.isBefore(horizon)) continue;
    final cat = (e.category?.name ?? '').toLowerCase();
    if (PortalRules.skipCategories.any(cat.contains)) continue;
    final title = e.title.trim();
    if (title.isEmpty) continue;
    if (!forClass(title, className)) continue;
    final meal = isMealNote(title);
    if (meal && !includeMeals) continue;
    final lower = title.toLowerCase();
    if (skipHolidays && isPlainHoliday(lower)) continue;
    final kind = meal
        ? WeekKind.meal
        : PortalRules.examCategories.any(cat.contains) ||
              PortalRules.examTitle.hasMatch(lower)
        ? WeekKind.exam
        : (PortalRules.freeCategories.any(cat.contains) ||
                  PortalRules.freeTitle.hasMatch(lower)
              ? WeekKind.free
              : (lower.contains(PortalRules.deadlineWord)
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
  final notes = <String>{};
  for (final e in events) {
    final title = e.title.trim();
    if (!isMealNote(title)) continue;
    if (!forClass(title, className)) continue;
    final a = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
    final b = DateTime(e.endTime.year, e.endTime.month, e.endTime.day);
    if (target.isBefore(a) || target.isAfter(b)) continue;
    notes.add(title);
  }
  if (notes.isEmpty) return null;
  final text = notes.join(' · ');
  return afternoon ? t.mealTomorrow(text) : t.mealToday(text);
}

/// Gilt der Termin [title] für die Klasse [className] („09C“, „06 XY“)?
/// false nur, wenn der Titel sicher und ausschließlich andere nennt.
///
/// Ursache (Wunsch 20.10.26, Schülerin einer 9. Klasse): „Demnächst“ zeigte
/// Termine wie „Elternabend 9D“ oder „Französisch 09A Arbeit“ (Kalender
/// Schule B, Export 17.10.26: 4 von 21 Terminen für andere Klassen).
///
/// false, wenn der Titel
/// - einen Jahrgangsbereich/-liste ohne den eigenen nennt ([forGrade]),
/// - Klassen nennt (PortalRules.classToken), aber nicht die eigene –
///   gleicher Jahrgang mit anderem Buchstaben zählt als andere Klasse,
/// - nur die Oberstufe nennt (Q1–Q4, E-Phase) und das Kind höchstens in
///   Jahrgang 9 ist.
///
/// Klassennamen statt Buchstaben („6 Ahorn“, im Kalender „06 ah“): Kürzel
/// und Name gelten als gleich, wenn eines mit dem anderen beginnt.
///
/// Grenzen: Eine bloße Zahl („Betriebspraktikum 9“) bleibt sichtbar, ebenso
/// alles ohne Klassenangabe und ausgeschriebene fremde Namen („6 Birke“). Ohne bekannte Klasse wird nichts ausgeblendet.
/// Kennt die App nur den Jahrgang, zählt jede Klasse dieses Jahrgangs.
bool forClass(String title, String className) {
  final own = RegExp(
    r'^\s*0?(\d{1,2})\s*([a-zA-ZäöüÄÖÜß]+)?',
  ).firstMatch(className);
  if (own == null) return true;
  final grade = int.parse(own[1]!);
  final letters = own[2]?.toLowerCase();
  if (!forGrade(title, grade)) return false;
  // Eigener Klassenname ausgeschrieben im Titel („6 Ahorn“, „06 Ahorn“):
  // sicher eigene Klasse, auch wenn daneben andere stehen.
  if (letters != null &&
      letters.length > 3 &&
      RegExp(
        '(?<!\\d)0?$grade\\s*${RegExp.escape(letters)}\\b',
        caseSensitive: false,
      ).hasMatch(title)) {
    return true;
  }
  var mentioned = false;
  for (final m in PortalRules.classToken.allMatches(title)) {
    final g = int.parse(m[1] ?? m[3]!);
    final l = (m[2] ?? m[4]!).toLowerCase();
    if (g < 5 || g > 13 || PortalRules.notClassWords.contains(l)) continue;
    if (PortalRules.placeBefore.hasMatch(title.substring(0, m.start))) {
      continue;
    }
    mentioned = true;
    // Kürzel und Name gelten als dieselbe Klasse („ah“ ↔ „Ahorn“), Ursache:
    // Schule A kürzt die Klassennamen im Kalender und in den Kursen ab.
    if (g == grade &&
        (letters == null || letters.startsWith(l) || l.startsWith(letters))) {
      return true;
    }
  }
  if (mentioned) return false;
  if (grade <= 9 && PortalRules.upperSchool.hasMatch(title)) return false;
  return true;
}

/// Gilt der Titel für [grade]? Erkennt Bereiche („5-7 Klassen“, „Jg. 8–10“)
/// und Aufzählungen („nur für 5, 6 und 7 Jg.“). Ohne Angabe: für alle.
bool forGrade(String title, int grade) {
  final range =
      PortalRules.gradeRangeBefore.firstMatch(title) ??
      PortalRules.gradeRangeAfter.firstMatch(title);
  if (range != null) {
    final a = int.parse(range[1]!);
    final b = int.parse(range[2]!);
    return grade >= a && grade <= b;
  }
  final list = PortalRules.gradeList.firstMatch(title);
  if (list != null) {
    final grades = RegExp(
      r'\d{1,2}',
    ).allMatches(list[1]!).map((m) => int.parse(m[0]!)).toSet();
    return grades.contains(grade);
  }
  return true;
}

/// [calendar] mit den Arbeiten nach der gemeinsamen Regel (exams.dart,
/// upcomingExamsOf): Kursmappe zuerst, dazu Kalender-Arbeiten, die in
/// keiner Kursmappe stehen, mit bereinigtem Titel. Alle übrigen Termine
/// bleiben, wie sie sind.
///
/// Ursache (Wunsch 17.10.26): Viele Schulen tragen Arbeiten nur in der
/// Kursmappe ein, nicht im Schulkalender – „Demnächst“ kannte sie nicht.
/// Seit 20.10.26 gewinnt bei doppelter Nennung die Kursmappe (genauer), wie
/// in Unterricht. Grenze: Die Kursmappen-Arbeiten sind so aktuell wie die
/// letzte Auswertung (Noten geöffnet oder täglicher Abruf im Hintergrund).
List<WeekItem> withCourseExams(
  List<WeekItem> calendar,
  CourseScan? scan,
  DateTime now, {
  int? childIndex,
  int days = 14,
}) {
  final exams = upcomingExamsOf(
    scan: scan?.upcoming(now) ?? const [],
    calendar: calendar,
    now: now,
    until: DateTime(now.year, now.month, now.day + days - 1),
  );
  return [
    for (final w in calendar)
      if (w.kind != WeekKind.exam) w,
    for (final e in exams)
      WeekItem(
        day: e.day,
        title: e.title,
        kind: WeekKind.exam,
        childIndex: childIndex,
        time: e.detail,
      ),
  ];
}
