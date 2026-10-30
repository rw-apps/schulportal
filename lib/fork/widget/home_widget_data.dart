/// Daten des Startbildschirm-Widgets (Android, Entwurf 10, Abnahme 30.10.26;
/// davor Entwurf 5 vom 28.10.26).
///
/// Entwurf 10 (Rückmeldung 30.10.26: „Relevante Informationen stehen dort
/// nicht, alles sieht einheitlich aus“): je Kind nur noch der tatsächliche
/// Zeitraum des Tages (Ausfall vorn/hinten rot) und feste Symbole – Arbeit,
/// Hausaufgaben, Essen, beim Schülerkonto Vertretung und Raum. Keine Fächer.
/// Datei Version 3 ([widgetDays], [widgetKidEntry]); Darstellung und Tagwahl
/// in Kotlin (WidgetModel.kt).
///
/// Das Widget selbst ist native Android-Oberfläche (RemoteViews,
/// android/app/src/main/kotlin/com/example/app/widget/SchoolWidget.kt und
/// WidgetModel.kt): Ein Startbildschirm kann keine Flutter-Ansicht zeigen.
/// Darum rechnet Dart hier alles, was Wissen über Plan, Vertretungsplan und
/// Sprache braucht, zu fertigen Texten (ForkL10n) – Kotlin legt sie nur noch
/// in die Kacheln.
///
/// Was Kotlin selbst entscheidet (WidgetModel.kt): welcher Tag gezeigt wird
/// (heute bis Schulschluss, dann der nächste Schultag; nach Mitternacht der
/// neue Tag), „bis 13:10“ während des Unterrichts, welche Hausaufgaben bis
/// dahin fällig sind. Ursache: Ohne neuen Abruf (nachts kein Hintergrundlauf,
/// notify_window.dart) stimmte das Widget sonst nicht mehr. Grenze: Deckt
/// die Datei den Tag nicht mehr ab, zeigt das Widget grau „Stand Fr 18:05“.
library;

import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:liblanis/liblanis.dart' show SubstitutionDay;

import '../l10n/l10n.dart';
import '../ui/plan/plan_model.dart';
import '../ui/today/today_from_lanis.dart'
    show dayLessonsFor, planWithSubstitutions;
import '../ui/today/today_model.dart';

/// Schlüssel der Widget-Daten in den SharedPreferences „HomeWidgetPreferences“
/// (Paket home_widget); Kotlin liest denselben Namen (WidgetModel.kt,
/// PAYLOAD_KEY).
const homeWidgetDataKey = 'fork_widget_payload';

/// Version der Datei. 3 = Entwurf 10 (`days` je Kind); ältere Dateien zeigt
/// Kotlin als „keine Daten“, bis die App neu schreibt (beim nächsten Start).
const homeWidgetVersion = 3;

/// Alte Einstellung (Entwurf 4): EIN Konto als Text. Nur noch gelesen
/// – wird nicht mehr ausgewertet (alle Kinder als Standard, Abnahme
/// 28.10.26) und mit der ersten Wahl im neuen Blatt gelöscht.
const widgetAccountSetting = 'fork-widget/account';

/// Gezeigte Kinder (localIds als JSON-Liste, geteilte Einstellungen).
/// Fehlt der Eintrag, zeigt das Widget alle Kinder der Familie (Abnahme
/// 28.10.26, Entwurf 5) – auch später hinzugefügte.
const widgetKidsSetting = 'fork-widget/kids';

/// Tage, die die Datei je Kind abdeckt: heute bis heute + [widgetDaysAhead].
/// Ursache: Kotlin wählt den gezeigten Tag selbst (nach Schulschluss der
/// nächste Schultag, nach Mitternacht der neue Tag) – auch ohne neuen Abruf
/// über ein Wochenende oder kurze Ferien hinweg. Grenze: Danach zeigt das
/// Widget „Stand …“ (veraltet, WidgetModel.kt).
const widgetDaysAhead = 7;

/// Arbeiten, die die Datei kennt: wie [widgetDaysAhead]. Das Symbol leuchtet
/// nur am gezeigten Tag selbst (Vorschlag 2, 30.10.26: sonst leuchtete es
/// tagelang vorher).
const widgetExamDays = widgetDaysAhead + 1;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// „2026-10-27“ – das Format, das Kotlin mit LocalDate.parse liest.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Erste bzw. letzte Stunde einer Beschriftung: „1.–2.“ → „1.“ / „2.“,
/// „3. Block“ → „3.“. Für „ab 3. Std.“ bei Schulen ohne Uhrzeiten.
String _firstSlot(String slot) {
  final first = widgetSlotShort(slot).split(RegExp('[–-]')).first;
  return first.endsWith('.') ? first : '$first.';
}

String _lastSlot(String slot) {
  final last = widgetSlotShort(slot).split(RegExp('[–-]')).last;
  return last.endsWith('.') ? last : '$last.';
}

/// Ein Tag eines Kindes in der Datei (Entwurf 10): tatsächlicher Zeitraum
/// (ohne ausfallende Rand-Stunden) und der laut Plan, Ausfälle mitten am
/// Tag, Vertretungen und Raumwechsel (nur Schülerkonto), oder ein freier Tag.
///
/// Ursache (Rückmeldung 30.10.26: „wie erkenne ich, ab wann ich Unterricht
/// habe, wenn die ersten Stunden ausfallen“): Für Eltern zählt, wann das Kind
/// wirklich in der Schule ist, nicht welches Fach ausfällt.
Map<String, Object?> _dayJson(
  DateTime d,
  List<DayLesson> lessons, {
  String? free,
}) {
  if (free != null) return {'date': isoDate(d), 'free': free};
  final held = [
    for (final (i, l) in lessons.indexed)
      if (!l.cancelled) i,
  ];
  final timed = lessons.every(hasTime);
  Map<String, Object?> at(
    DayLesson l, [
    Map<String, Object?> more = const {},
  ]) => {
    'slot': widgetSlotShort(l.slot),
    if (hasTime(l)) 'end': l.end,
    ...more,
  };
  final first = held.isEmpty ? null : held.first;
  final last = held.isEmpty ? null : held.last;
  return {
    'date': isoDate(d),
    'timed': timed,
    if (timed) 'planStart': lessons.first.start,
    if (timed) 'planEnd': lessons.last.end,
    'planStartSlot': _firstSlot(lessons.first.slot),
    'planEndSlot': _lastSlot(lessons.last.slot),
    if (first != null && last != null) ...{
      if (timed) 'start': lessons[first].start,
      if (timed) 'end': lessons[last].end,
      'startSlot': _firstSlot(lessons[first].slot),
      'endSlot': _lastSlot(lessons[last].slot),
    },
    'allOff': held.isEmpty,
    'mid': [
      if (first != null && last != null)
        for (var i = first + 1; i < last; i++)
          if (lessons[i].cancelled) at(lessons[i]),
    ],
    'subs': [
      for (final l in lessons)
        if (l.change == ChangeKind.substitution ||
            l.change == ChangeKind.unclear)
          at(l),
    ],
    'rooms': [
      for (final l in lessons)
        if (l.change == ChangeKind.roomChange)
          at(l, {if (l.room != null) 'room': l.room}),
    ],
  };
}

/// Tage eines Kindes für die Datei: heute bis heute + [widgetDaysAhead], je
/// Schultag mit Unterricht der überlagerte Plan ([planWithSubstitutions] +
/// [dayLessonsFor], dieselbe Zuordnung wie „Heute“ und Kalender); freie Tage
/// ([free], z. B. Ferien) mit „Herbstferien bis Fr 6.11.“.
///
/// Grenze: Tage ohne Stunden im Plan (und nicht frei) fehlen – Kotlin nimmt
/// den nächsten vorhandenen. Wochenenden fehlen immer.
List<Map<String, Object?>> widgetDays({
  required KidPlan plan,
  required GroupChoice choice,
  required List<SubstitutionDay> days,
  required DateTime now,
  required ForkL10n t,
  Map<DateTime, String> free = const {},
  String className = '',
}) {
  final today = _day(now);
  final out = <Map<String, Object?>>[];
  final date = DateFormat(t.widgetFreeDate, t.localeName);
  for (var i = 0; i <= widgetDaysAhead; i++) {
    final d = DateTime(today.year, today.month, today.day + i);
    final wd = d.weekday - 1;
    if (wd > 4) continue;
    final label = free[d];
    if (label != null) {
      // Letzter freier Tag am Stück (Wochenenden zählen mit).
      var end = d;
      while (true) {
        var n = DateTime(end.year, end.month, end.day + 1);
        while (n.weekday > 5) {
          n = DateTime(n.year, n.month, n.day + 1);
        }
        if (!free.containsKey(n)) break;
        end = n;
      }
      out.add(
        _dayJson(d, const [], free: t.widgetFreeUntil(label, date.format(end))),
      );
      continue;
    }
    final rows = [
      for (final x in days)
        if (_day(x.dateTime) == d) x,
    ];
    final over = planWithSubstitutions(
      plan: plan,
      days: rows,
      week: [
        for (var j = 0; j < 5; j++) DateTime(d.year, d.month, d.day - wd + j),
      ],
      t: t,
      className: className,
    );
    final lessons = dayLessonsFor(over, wd, choice, t: t);
    if (lessons.isEmpty) continue;
    out.add(_dayJson(d, lessons));
  }
  return out;
}

/// Eintrag EINES Kindes in der Datei (`kids[]`, Version 3).
///
/// [account]: Konto (localId) – Schlüssel beim Zusammenführen
/// ([mergeWidgetKid]), für Klick-Ziele und die Auswahl je Widget;
/// [color]: Farbplatz (KitPalette.kids); [stand]: Ladezeit des
/// Vertretungsplans; [own]: Schülerkonto (Kotlin zeigt dann Vertretung und
/// Raum); [shown]: Vorgabe „Kinder im Widget“ der App (Widgets ohne eigene
/// Auswahl zeigen nur diese).
///
/// [homeworkDue]: vermutete Fristen der offenen Aufgaben (je Aufgabe eine);
/// Kotlin zählt nur die bis zum gezeigten Tag fälligen, nicht die
/// überfälligen. Ursache (Vorschlag 1, 30.10.26): Eine Zahl aller offenen
/// Aufgaben bleibt bei Nicht-Abhakern dauerhaft stehen und sagt nichts mehr.
/// [exams]: Tage mit Arbeit; [mealOpen]: Tage, für die Essen bestellt werden
/// muss (mealReminderDays); [lowBalance]: Guthaben unter der Grenze.
Map<String, Object?> widgetKidEntry({
  required int account,
  required String name,
  required int color,
  required List<Map<String, Object?>> days,
  DateTime? stand,
  bool own = false,
  bool shown = true,
  List<DateTime> homeworkDue = const [],
  List<DateTime> exams = const [],
  List<DateTime> mealOpen = const [],
  bool lowBalance = false,
}) => {
  'account': account,
  'name': name.trim(),
  'color': color,
  if (stand != null) 'stand': stand.toIso8601String(),
  'own': own,
  'shown': shown,
  'days': days,
  'hwDue': [for (final d in homeworkDue) isoDate(d)]..sort(),
  'exams': {for (final d in exams) isoDate(d)}.toList()..sort(),
  'mealOpen': {for (final d in mealOpen) isoDate(d)}.toList()..sort(),
  'lowBalance': lowBalance,
};

/// Kinder einer vorhandenen Datei (nur Version 3, sonst leer).
List<Map<String, Object?>> widgetKidsOf(Map<String, Object?>? payload) {
  if (payload == null || payload['v'] != homeWidgetVersion) return const [];
  return [
    for (final k in (payload['kids'] as List?) ?? const [])
      if (k is Map) k.cast<String, Object?>(),
  ];
}

/// Hintergrund-Lauf (notify_task.dart, je Konto): ersetzt in [old] nur die
/// Tage und den Stand von [account] (neuer Vertretungsplan), ggf. die Farbe,
/// und lässt die übrigen Kinder unverändert (Zusammenführen nach Konto).
///
/// Ursache: Der Lauf kennt nur sein eigenes Konto; schriebe er die Datei
/// neu, verschwänden die Geschwister vom Widget. Name, Aufgaben, Arbeiten
/// und Essen bleiben aus [old] – der Lauf lädt weder die Liste der erledigten
/// Hausaufgaben noch die Kursmappen. Grenze: null (nichts schreiben), wenn
/// [old] fehlt, eine ältere Version ist oder das Konto nicht darin steht –
/// die Auswahl trifft allein die App.
List<Map<String, Object?>>? mergeWidgetKid(
  Map<String, Object?>? old, {
  required int account,
  required List<Map<String, Object?>> days,
  required DateTime stand,
  int? color,
}) {
  final kids = widgetKidsOf(old);
  final i = kids.indexWhere((k) => k['account'] == account);
  if (i < 0) return null;
  return [
    for (final (j, k) in kids.indexed)
      if (j != i)
        k
      else
        {...k, 'days': days, 'stand': stand.toIso8601String(), 'color': ?color},
  ];
}

/// Datei ohne das Konto [account] (Kind abgemeldet,
/// account_removal.dart): die übrigen Einträge; leer, wenn keines bleibt
/// (dann wird die Datei gelöscht); null, wenn das Konto nicht darin steht
/// (nichts zu tun).
///
/// Ursache (Prüfung 28.10.26): Nichts löschte die Datei – ein abgemeldetes
/// Kind blieb mit seinem letzten Stand auf dem Startbildschirm. Ältere
/// Versionen werden ganz gelöscht, wenn das Konto darin vorkommt. Grenze: Der
/// Hintergrund-Lauf eines anderen Kontos, der in denselben Millisekunden die
/// alte Datei liest, kann den Eintrag zurückschreiben; der nächste Aufbau der
/// App ([widgetAccounts] kennt das Konto nicht mehr) nimmt ihn wieder heraus.
List<Map<String, Object?>>? widgetKidsWithout(
  Map<String, Object?>? payload,
  int account,
) {
  if (payload == null) return null;
  if (payload['v'] != homeWidgetVersion) {
    final old = [
      payload['account'],
      for (final k in (payload['kids'] as List?) ?? const [])
        if (k is Map) k['account'],
    ];
    return old.contains(account) ? const [] : null;
  }
  final kids = widgetKidsOf(payload);
  if (!kids.any((k) => k['account'] == account)) return null;
  return [
    for (final k in kids)
      if (k['account'] != account) k,
  ];
}

/// Eintrag eines Kindes beim Schreiben aus der App: [app] (eben gerechnet)
/// gegen [old] (aus der Datei). Ist der Eintrag der Datei neuer – der
/// Hintergrund-Lauf hat nach dem letzten Laden der App abgerufen
/// (mergeWidgetKid) –, bleiben dessen `days` und `stand`; alles andere kommt
/// aus [app] (das kennt der Hintergrund nicht).
///
/// Ursache (Prüfung 28.10.26): Die offene App schrieb sonst den älteren Plan
/// über einen neueren aus dem Hintergrund. Grenze: Ohne `stand` (oder nicht
/// lesbar) gilt [app].
Map<String, Object?>? newerWidgetKid(
  Map<String, Object?>? app,
  Map<String, Object?>? old,
) {
  if (app == null || old == null) return app ?? old;
  final a = DateTime.tryParse('${app['stand'] ?? ''}');
  final o = DateTime.tryParse('${old['stand'] ?? ''}');
  if (a == null || o == null || !o.isAfter(a)) return app;
  return {...app, 'days': old['days'], 'stand': old['stand']};
}

/// Die ganze Datei für Kotlin (JSON-fähige Map), Version 3.
///
/// [kids]: Einträge ([widgetKidEntry]) in der Reihenfolge der Familie.
/// `labels`: alle Texte, die Kotlin braucht, fertig übersetzt (Kotlin kennt
/// die Sprache der App nicht); Platzhalter %s/%d für Kotlins String.format.
Map<String, Object?> homeWidgetPayload({
  required List<Map<String, Object?>> kids,
  required DateTime now,
  required ForkL10n t,
}) {
  final monday = DateTime(2024, 1, 1); // ein Montag
  final short = DateFormat('ccc', t.localeName);
  final long = DateFormat('cccc', t.localeName);
  String up(String s) => s.toUpperCase();
  // Mehrzahl kann Kotlin nicht in allen Sprachen bilden: „1 Aufgabe“ und
  // die Form für 2+ mit %d (Grenze: Sprachen mit mehr als zwei Formen –
  // de/en/tr haben zwei).
  final many = t.homeworkShort(7).replaceFirst('7', '%d');
  return {
    'v': homeWidgetVersion,
    'generatedAt': now.toIso8601String(),
    'kids': kids,
    'labels': {
      'today': up(t.widgetToday),
      'weekdays': [
        for (var i = 0; i < 7; i++)
          short.format(DateTime(monday.year, monday.month, monday.day + i)),
      ],
      'weekdaysLong': [
        for (var i = 0; i < 7; i++)
          up(long.format(DateTime(monday.year, monday.month, monday.day + i))),
      ],
      'from': t.widgetFrom('%s'),
      'until': t.widgetUntil('%s'),
      'range': '%1\$s–%2\$s',
      'slot': t.widgetSlotLabel('%s'),
      'off': t.widgetOff,
      'stale': t.asOf('%s'),
      'staleText': t.widgetStaleText,
      'exam': t.widgetExam,
      'homework': t.widgetHomework,
      'homeworkN': [t.homeworkShort(1), many],
      'meal': t.widgetMeal,
      'mealOrder': t.widgetMealOrder,
      'balance': t.widgetBalance,
      'sub': t.changeSubstitution,
      'subAt': t.widgetSubAt('%s'),
      'room': t.widgetRoomShort,
      'roomAt': t.widgetRoomAt('%s'),
      'more': t.widgetMoreCalm('%d'),
      'cdCancel': t.widgetCdCancel,
      'cdExam': t.widgetExam,
      'cdHomework': t.widgetCdHomework,
      'cdMeal': t.widgetMeal,
      'cdSub': t.changeSubstitution,
      'cdRoom': t.changeRoom,
      'configTitle': t.widgetConfigTitle,
      'configAll': t.widgetAllKids,
      'configOk': t.widgetConfigOk,
      'configEmpty': t.widgetConfigEmpty,
    },
  };
}

/// Gezeigte Kinder aus den Einstellungen: [kids] = Wert von
/// [widgetKidsSetting], [legacy] = Wert von [widgetAccountSetting].
/// null = alle Kinder (Vorgabe, Entwurf 5).
///
/// [legacy] (Entwurf 4, ein Kind) wird nicht mehr übernommen: Standard
/// sind alle Kinder (Abnahme 28.10.26). Grenze: Eine leere oder kaputte Liste gilt als „alle“ – ein Widget ohne
/// Kind wäre nutzlos.
Set<int>? widgetKidSelectionFrom({String? kids, String? legacy}) {
  if (kids != null) {
    try {
      final v = jsonDecode(kids);
      if (v is List) {
        final ids = {
          for (final x in v)
            if (x is int) x else ?int.tryParse('$x'),
        };
        return ids.isEmpty ? null : ids;
      }
    } on FormatException {
      return null;
    }
    return null;
  }
  // Fork: die Wahl aus 9437/9438 (ein Kind) gilt nicht weiter. Ursache
  // (Abnahme 28.10.26): Standard sind alle Kinder; die alte Einstellung
  // wurde auch ohne bewusste Wahl mit dem aktiven Konto belegt.
  return null;
}

/// Kinder des Widgets in Familienreihenfolge: [ordered] = alle Konten
/// (localId, nach Anlage sortiert), [selection] wie
/// [widgetKidSelectionFrom]. Gewählte, aber gelöschte Konten zählen nicht;
/// bleibt keines übrig, gelten wieder alle.
List<int> widgetAccounts(List<int> ordered, Set<int>? selection) {
  if (selection == null) return ordered;
  final shown = [
    for (final a in ordered)
      if (selection.contains(a)) a,
  ];
  return shown.isEmpty ? ordered : shown;
}

/// Stunde ohne Zusatz („1.–2. Std.“ → „1.–2.“, „3. Block“ → „3.“).
/// Ursache (Bildschirmfoto Pixel 28.10.26): „morgen 1.–2. S…“ wurde in der
/// Kachel abgeschnitten; der Entwurf zeigt nur die Zahlen. Grenze: Ohne
/// Zahl am Anfang bleibt die Beschriftung wie im Plan.
String widgetSlotShort(String slot) {
  final t = slot.trim();
  final m = RegExp(r'^\d+\.?(\s*[–-]\s*\d+\.?)?').firstMatch(t);
  if (m == null) return t;
  final n = m.group(0)!.replaceAll(RegExp(r'\s+'), '');
  return n.endsWith('.') ? n : '$n.';
}
