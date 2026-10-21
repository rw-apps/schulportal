/// Hinweise an der Kinderkarte: alles, was vom regulären Plan abweicht, als
/// eigener Abschnitt über dem Stundenplan (Abnahme 21.10.26).
///
/// Ursache (Rückmeldung 21.10.26): Ausfall und Vertretung standen als
/// kleine Zeile unter der Tagesleiste, obwohl sie wichtiger sind als der
/// reguläre Plan. Der Kasten für morgen oben auf der Seite (bis 9389
/// `ImportantBox`) ist hier aufgegangen, damit alles zu einem Kind in seiner
/// Karte steht.
library;

import '../../l10n/l10n.dart';
import 'today_model.dart';
import 'today_page.dart' show dayDiff, relativeDay;

enum HintKind { cancelled, substitution, roomChange, unclear, meal }

class KidHint {
  const KidHint({
    required this.kind,
    required this.title,
    this.detail,
    this.when,
  });

  final HintKind kind;

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
List<KidHint> kidHints(ChildToday kid, DateTime now, ForkL10n t) {
  final l = kid.lessons;
  final held = [
    for (var i = 0; i < l.length; i++)
      if (!l[i].cancelled) i,
  ];
  String? effect(int i) {
    if (!l[i].cancelled || held.isEmpty) return null;
    final first = l[held.first];
    final last = l[held.last];
    if (held.first > i && hasTime(first)) return t.hintLaterStart(first.start);
    if (held.last < i && hasTime(last)) return t.hintEarlyEnd(last.end);
    return null;
  }

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
    out.add(KidHint(kind: HintKind.meal, title: meal));
  }
  final next = nextSchoolDay(now);
  for (final c in kid.changes) {
    if (dayDiff(next, c.day) != 0) continue;
    out.add(fromItem(c, when: relativeDay(t, c.day, now)));
  }
  return out;
}
