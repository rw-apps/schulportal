/// Hinweise an der Kinderkarte: alles, was vom regulären Plan abweicht, als
/// eigener Abschnitt über dem Stundenplan (Abnahme 21.10.26).
///
/// Ursache (Rückmeldung 21.10.26): Ausfall und Vertretung standen als
/// kleine Zeile unter der Tagesleiste, obwohl sie wichtiger sind als der
/// reguläre Plan. Der Kasten für morgen oben auf der Seite (bis 9389
/// `ImportantBox`) ist hier aufgegangen, damit alles zu einem Kind in seiner
/// Karte steht.
library;

import '../../data/portal_rules.dart';
import '../../l10n/l10n.dart';
import '../../widget/home_widget_data.dart' show widgetSlotShort;
import 'today_model.dart';
import 'today_page.dart' show dayDiff, relativeDay;

enum HintKind {
  cancelled,
  substitution,
  roomChange,
  unclear,
  meal,
  exam,
  balance,
}

class KidHint {
  const KidHint({
    required this.kind,
    required this.title,
    required this.subject,
    required this.what,
    this.detail,
    this.when,
    this.slot,
    this.day,
    this.toMeal = false,
  });

  final HintKind kind;

  // ---- Zeile der Karte (Abnahme 30.10.26, Entwurf B „Zeilen nach Tag“) ----
  //
  // Ursache: Sieben Hinweise als je eigene zweizeilige Fläche schoben den
  // Stundenplan unter den ersten Bildschirm. Die Karte zeigt jetzt EINE
  // Zeile aus [subject], [what] und [slot] und gruppiert nach [day]
  // ([groupHints]). Grenze: Lehrkraft, „Schluss 11:20“ und „Beginn erst …“
  // stehen nur noch in [detail] – die Zeile nennt sie nicht, sie bleiben für
  // den Bildschirmleser (Semantics in _HintLine) und im Kalender, den das
  // Antippen öffnet.

  /// Fett vorn: „Mathematik“, „Essen“, „Guthaben 12,50 €“.
  final String subject;

  /// Art in der Signalfarbe: „Vertretung“, „fällt aus“, „Raum R020“,
  /// „nicht bestellt“, „Test“, „bitte aufladen“; leer = nur [subject].
  final String what;

  /// Kleine Marke rechts: nur die Stunde als Zahl („3.–4.“, „6.“) oder die
  /// Uhrzeit einer Arbeit („09:50“); null = keine Marke.
  final String? slot;

  /// Tag des Hinweises (ohne Uhrzeit); null = an keinen Tag gebunden
  /// (Guthaben) – [groupHints] stellt ihn zum Tag, den die Karte zeigt.
  final DateTime? day;

  /// Antippen öffnet die Essensbestellung statt des Tages im Kalender
  /// (Guthaben, nichts bestellt) – dort lässt sich etwas tun.
  final bool toMeal;

  /// „Ev. Religion fällt aus“, „Deutsch: Vertretung“, „Heute: kein Essen“.
  final String title;

  /// „1.–2. Stunde · Beginn erst 09:45“; null = nur der Titel.
  final String? detail;

  /// „Morgen“ bzw. „Mo 26.10.“ bei Hinweisen für den nächsten Schultag;
  /// null = heute.
  final String? when;

  bool get cancelled => kind == HintKind.cancelled;
}

HintKind _kind(ChangeKind k) => switch (k) {
  ChangeKind.cancelled => HintKind.cancelled,
  ChangeKind.substitution => HintKind.substitution,
  ChangeKind.roomChange => HintKind.roomChange,
  ChangeKind.unclear => HintKind.unclear,
};

/// Art-Wort der Zeile, dieselben Wörter wie die Widget-Kacheln
/// (widgetItems in home_widget_data.dart): Raumwechsel nennt den neuen Raum
/// („Raum R020“), ohne Raumangabe das Wort. „Bitte prüfen“ klein, weil es
/// hinter dem Fach steht.
String _what(ForkL10n t, ChangeKind k, String? room) => switch (k) {
  ChangeKind.cancelled => t.lessonCancelled,
  ChangeKind.substitution => t.changeSubstitution,
  ChangeKind.roomChange => room == null ? t.changeRoom : t.widgetRoom(room),
  ChangeKind.unclear => lowerFor(t, t.changeUnclear),
};

/// Marke einer Arbeit aus ihrer Angabe (UpcomingExam.detail): Uhrzeit
/// („11:40“) bzw. die Stunden als Zahlen („3., 4. Std. (90 Min.)“ →
/// „3.–4.“). Grenze: null, wenn die Angabe mit keinem von beiden beginnt
/// (freier Text der Schule) – dann keine Marke.
String? examSlot(String? detail) {
  final d = detail?.trim();
  if (d == null || d.isEmpty) return null;
  final time = RegExp(r'^\d{1,2}:\d{2}').firstMatch(d);
  if (time != null) return time[0]!.padLeft(5, '0');
  final head = d.split('(').first;
  if (!RegExp(r'^\d').hasMatch(head)) return null;
  final n = [for (final m in RegExp(r'(\d+)\.').allMatches(head)) m[1]!];
  if (n.isEmpty) return null;
  return n.length == 1 ? '${n.first}.' : '${n.first}.–${n.last}.';
}

/// Fach und Art einer Arbeit aus ihrem Titel: „Mathematik: Arbeit“
/// (UpcomingExam.title, withCourseExams) wird geteilt; sonst das Art-Wort
/// aus dem Titel gelöst („Klassenarbeit Englisch“, PortalRules.examKind).
/// Grenze: Ohne erkennbares Art-Wort steht „Arbeit“ (kindExam) dahinter.
(String, String) examParts(ForkL10n t, String title) {
  final i = title.indexOf(': ');
  if (i > 0) return (title.substring(0, i), title.substring(i + 2).trim());
  final m = PortalRules.examKind.firstMatch(title);
  if (m == null) return (title, t.kindExam);
  final w = m[0]!;
  final rest = title
      .replaceRange(m.start, m.end, ' ')
      .replaceAll(RegExp(r'^[\s:–-]+|[\s:–-]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
  final word = w[0].toUpperCase() + w.substring(1).toLowerCase();
  return rest.isEmpty ? (word, '') : (rest, word);
}

/// Text des Essenshinweises ohne „Heute: “ bzw. „Morgen: “
/// (mealToday/mealTomorrow, mealHintFor): Die Gruppe nennt den Tag schon.
/// Über die Vorlagen der Sprache gelöst, damit es auch gilt, wo der
/// Platzhalter nicht am Ende steht. Grenze: passt keine Vorlage, bleibt der
/// Text ganz.
String _mealNotes(ForkL10n t, String meal) {
  const mark = '\u0000';
  for (final f in [t.mealToday, t.mealTomorrow]) {
    final parts = f(mark).split(mark);
    if (parts.length != 2) continue;
    final (pre, post) = (parts[0], parts[1]);
    if (meal.length > pre.length + post.length &&
        meal.startsWith(pre) &&
        meal.endsWith(post)) {
      return meal.substring(pre.length, meal.length - post.length);
    }
  }
  return meal;
}

String _title(ForkL10n t, ChangeKind k, String subject) => switch (k) {
  ChangeKind.cancelled => t.hintCancelled(subject),
  ChangeKind.substitution => t.hintSubstitution(subject),
  ChangeKind.roomChange => t.hintRoom(subject),
  ChangeKind.unclear => t.hintUnclear(subject),
};

/// Geschützte Leerzeichen innerhalb einer Angabe: umbrochen wird nur
/// zwischen Stunde, Uhrzeit und Lehrkraft. Ursache (Mockup 21.10.26):
/// „Tim / Sommer“ stand auf zwei Zeilen.
String _keep(String v) => v.replaceAll(' ', ' ');

/// Nächster Schultag nach [now]: morgen, ab Freitag der Montag.
/// Grenze: Feiertage und Ferien kennt die Rechnung nicht; für solche Tage
/// gibt es aber keinen Vertretungsplan und damit keine Hinweise.
DateTime nextSchoolDay(DateTime now) {
  var d = DateTime(now.year, now.month, now.day + 1);
  while (d.weekday >= DateTime.saturday) {
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return d;
}

/// Folge des Ausfalls von Abschnitt [i] in [lessons] (Tag, zeitlich
/// sortiert): [start] = Beginn der ersten stattfindenden Stunde, wenn vor
/// [i] nichts mehr stattfindet („Beginn erst 09:45“); sonst [end] = Ende der
/// letzten stattfindenden Stunde, wenn nach [i] nichts mehr kommt („Schluss
/// schon 13:00“).
///
/// Als eigene Funktion aus [kidHints] gelöst, solange das
/// Startbildschirm-Widget (Entwurf 4) dieselbe Folge nannte; seit Entwurf 5
/// (Abnahme 28.10.26, drei kurze Zeilen je Kachel) nutzt sie nur noch die
/// Kinderkarte. Grenze: beides null, wenn
/// [i] stattfindet, der ganze Tag ausfällt, der Ausfall mitten im Tag liegt
/// oder die Schule keine Uhrzeiten zeigt (hasTime).
({String? start, String? end}) cancelEffect(List<DayLesson> lessons, int i) {
  const none = (start: null, end: null);
  if (i < 0 || i >= lessons.length || !lessons[i].cancelled) return none;
  final held = [
    for (var j = 0; j < lessons.length; j++)
      if (!lessons[j].cancelled) j,
  ];
  if (held.isEmpty) return none;
  final first = lessons[held.first];
  final last = lessons[held.last];
  if (held.first > i && hasTime(first)) return (start: first.start, end: null);
  if (held.last < i && hasTime(last)) return (start: null, end: last.end);
  return none;
}

/// Hinweise in dieser Reihenfolge:
/// 1. heutige Änderungen an Stunden, die noch kommen oder laufen
///    (vorbei = weg); ein Ausfall am Anfang bzw. Ende nennt die Folge
///    („Beginn erst 09:45“, „Schluss schon 13:00“);
/// 2. heutige Änderungen ohne Stunde im Plan (Zusatzstunde in einer
///    Freistunde, applySubstitutions in today_from_lanis.dart);
/// 3. Essenshinweis aus dem Schulkalender ([ChildToday.mealHint]);
/// 4. Änderungen am nächsten Schultag ([nextSchoolDay]), mit „Morgen“.
///
/// Eine heutige Änderung aus [ChildToday.changes] gilt als schon gezeigt,
/// wenn eine Stunde mit gleichem Fach und gleicher Art geändert ist. Nicht
/// über die Stunde verglichen, weil die Bezeichnung abweichen kann
/// („5.“ an der Stunde, „5. Std.“ im Beispiel demo_family.dart).
List<KidHint> kidHints(
  ChildToday kid,
  DateTime now,
  ForkL10n t, {
  List<WeekItem> exams = const [],
}) {
  final l = kid.lessons;
  String? effect(int i) => switch (cancelEffect(l, i)) {
    (start: final s?, end: _) => t.hintLaterStart(s),
    (start: _, end: final e?) => t.hintEarlyEnd(e),
    _ => null,
  };

  final today = DateTime(now.year, now.month, now.day);
  final out = <KidHint>[];
  final shown = <String>{};
  for (var i = 0; i < l.length; i++) {
    final x = l[i];
    final c = x.change;
    if (c == null) continue;
    shown.add('${x.subject}|$c');
    if (lessonDone(x, now)) continue;
    final e = effect(i);
    out.add(
      KidHint(
        kind: _kind(c),
        title: _title(t, c, x.subject),
        subject: x.subject,
        what: _what(t, c, x.room),
        slot: widgetSlotShort(x.slot),
        day: today,
        detail: [
          _keep(x.slot),
          if (e != null)
            _keep(e)
          else if (hasTime(x))
            _keep('${x.start}–${x.end}'),
          if (!x.cancelled && x.changeDetail != null) _keep(x.changeDetail!),
        ].join(' · '),
      ),
    );
  }

  KidHint fromItem(ChangeItem c, {String? when}) => KidHint(
    kind: _kind(c.kind),
    title: _title(t, c.kind, c.subject),
    subject: c.subject,
    what: _what(t, c.kind, c.room),
    slot: widgetSlotShort(c.slot),
    day: DateTime(c.day.year, c.day.month, c.day.day),
    detail: [
      _keep(c.slot),
      if (c.kind != ChangeKind.cancelled && c.detail != null) _keep(c.detail!),
    ].join(' · '),
    when: when,
  );

  for (final c in kid.changes) {
    if (dayDiff(now, c.day) != 0) continue;
    if (shown.contains('${c.subject}|${c.kind}')) continue;
    out.add(fromItem(c));
  }
  if (kid.mealHint case final meal?) {
    out.add(
      KidHint(
        kind: HintKind.meal,
        title: meal,
        subject: t.kindMeal,
        what: _mealNotes(t, meal),
        day: mealHintDay(now),
      ),
    );
  }
  final unordered = kid.mealUnordered;
  if (unordered != null && dayDiff(now, unordered) == 0) {
    out.add(
      KidHint(
        kind: HintKind.meal,
        title: t.mealUnordered,
        subject: t.kindMeal,
        what: t.hintMealUnordered,
        toMeal: true,
        day: today,
        detail: t.mealStillOpen,
      ),
    );
  }
  if (kid.lowBalance case final b?) {
    out.add(
      KidHint(
        kind: HintKind.balance,
        title: t.mealBalance(b),
        subject: t.mealBalance(b),
        what: t.mealTransferShort,
        toMeal: true,
        detail: t.mealTransfer,
      ),
    );
  }
  final next = nextSchoolDay(now);
  for (final c in kid.changes) {
    if (dayDiff(next, c.day) != 0) continue;
    out.add(fromItem(c, when: relativeDay(t, c.day, now)));
  }
  // Nichts bestellt für den nächsten Schultag (mensa_store.dart).
  if (unordered != null && dayDiff(next, unordered) == 0) {
    out.add(
      KidHint(
        kind: HintKind.meal,
        title: t.mealUnordered,
        subject: t.kindMeal,
        what: t.hintMealUnordered,
        toMeal: true,
        day: DateTime(unordered.year, unordered.month, unordered.day),
        detail: t.mealStillOpen,
        when: relativeDay(t, unordered, now),
      ),
    );
  }
  // Arbeiten heute und am nächsten Schultag, nach den Planänderungen
  // (Vorschlag 5, Entwurf 26.10.26). Ursache: Sie standen nur unter
  // „Demnächst“ zwischen Elternabend und Ferien; am Vorabend gehören sie
  // zu den Hinweisen.
  for (final e in exams) {
    if (!examIsHint(e, now)) continue;
    final isToday = dayDiff(now, e.day) == 0;
    final (subject, what) = examParts(t, e.title);
    out.add(
      KidHint(
        kind: HintKind.exam,
        title: e.title,
        subject: subject,
        what: what,
        slot: examSlot(e.time),
        day: DateTime(e.day.year, e.day.month, e.day.day),
        detail: e.time == null ? null : _keep(e.time!),
        when: isToday ? null : relativeDay(t, e.day, now),
      ),
    );
  }
  return out;
}

/// Hinweise eines Tages auf der Karte ([groupHints]).
class HintGroup {
  const HintGroup(this.day, this.hints);

  /// Tag ohne Uhrzeit.
  final DateTime day;
  final List<KidHint> hints;
}

/// Hinweise je Tag, Tage aufsteigend, innerhalb eines Tages in der
/// Reihenfolge von [kidHints]. Hinweise ohne Tag (Guthaben) stehen beim Tag
/// [home] – dem, den die Karte zeigt (heute bzw. nach Schulschluss der
/// nächste Schultag, KidCard).
///
/// Ursache (Abnahme 30.10.26): Statt „Morgen ·“ an jedem Hinweis ein Kopf
/// je Tag; nach Schulschluss bleibt so eine einzige Gruppe mit dem Tag aus
/// dem Kopf der Karte (_NextDayHead), kein „HEUTE“ darüber.
List<HintGroup> groupHints(List<KidHint> hints, DateTime home) {
  DateTime key(DateTime d) => DateTime(d.year, d.month, d.day);
  final byDay = <DateTime, List<KidHint>>{};
  for (final h in hints) {
    byDay.putIfAbsent(key(h.day ?? home), () => []).add(h);
  }
  final days = byDay.keys.toList()..sort();
  return [for (final d in days) HintGroup(d, byDay[d]!)];
}

/// Kopf einer Gruppe: „HEUTE“, sonst „MONTAG, 2. NOV.“ (hintsDayCaption der
/// Sprache).
String hintDayCaption(ForkL10n t, DateTime day, DateTime now) => upperFor(
  t,
  dayDiff(now, day) == 0 ? t.dayToday : formatDate(t, t.hintsDayCaption, day),
);

/// Arbeit, die als Hinweis auf der Kinderkarte steht (heute oder am
/// nächsten Schultag) – UpcomingList lässt sie dann weg (Abnahme 26.10.26:
/// nicht doppelt). Grenze: Ohne Kindzuordnung (childIndex null) nur bei
/// einem einzigen Kind, sonst wüsste die Karte nicht, wem sie gehört.
bool examIsHint(WeekItem w, DateTime now) =>
    w.kind == WeekKind.exam &&
    (dayDiff(now, w.day) == 0 || dayDiff(nextSchoolDay(now), w.day) == 0);

/// Arbeiten der Karte [index] aus [week] (Familie mit [kidCount] Kindern).
List<WeekItem> examsFor(List<WeekItem> week, int index, int kidCount) => [
  for (final w in week)
    if (w.kind == WeekKind.exam &&
        (w.childIndex == index || (w.childIndex == null && kidCount == 1)))
      w,
];

/// Termine für „Demnächst“ ohne die Arbeiten, die schon als Hinweis auf
/// einer Karte stehen.
List<WeekItem> upcomingWithoutHints(
  List<WeekItem> week,
  DateTime now,
  int kidCount,
) => [
  for (final w in week)
    if (!examIsHint(w, now) ||
        (w.childIndex == null && kidCount != 1) ||
        (w.childIndex != null && w.childIndex! >= kidCount))
      w,
];
