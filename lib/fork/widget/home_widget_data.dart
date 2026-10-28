/// Daten des Startbildschirm-Widgets (Android, Entwurf 5, Abnahme 28.10.26).
///
/// Das Widget selbst ist native Android-Oberfläche (RemoteViews,
/// android/app/src/main/kotlin/com/example/app/widget/SchoolWidget.kt und
/// WidgetModel.kt): Ein Startbildschirm kann keine Flutter-Ansicht zeigen.
/// Darum rechnet Dart hier alles, was Wissen über Plan, Vertretungsplan und
/// Sprache braucht, zu fertigen Texten (ForkL10n) – Kotlin legt sie nur noch
/// in die Kacheln.
///
/// Ursache Entwurf 5 (Rückmeldung 28.10.26: „viel Fläche für wenig
/// Information“): Die Datei trägt seit Version 2 ALLE gezeigten Kinder
/// ([homeWidgetPayload], `kids`), nicht mehr nur eines. Kotlin wählt aus
/// der Zahl der Kinder die Stufe (1 Kind / 2 Kinder / ab 3 Kindern).
///
/// Was Kotlin selbst entscheidet: „heute“/„morgen“/Wochentag aus dem Datum
/// eines Eintrags und dem aktuellen Tag, vergangene Tage und heute schon
/// beendete Stunden fallen weg, dann die Reihenfolge der Kacheln
/// (WidgetModel.tilesFor). Ursache: Ohne neuen Abruf (nachts kein
/// Hintergrundlauf, notify_window.dart) bliebe sonst nach Mitternacht
/// „morgen“ an einem Eintrag von heute stehen. Grenze: Kommt länger keine
/// neue Datei, zeigt das Widget nach dem letzten abgedeckten Tag (nächster
/// Schultag nach `stand`) statt „Nach Plan“ grau „Stand Fr 18:05“
/// (WidgetModel.quietTile, Prüfung 28.10.26).
library;

import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:liblanis/liblanis.dart' show SubstitutionDay;

import '../exams.dart';
import '../l10n/l10n.dart';
import '../ui/plan/plan_model.dart';
import '../ui/today/kid_hints.dart' show nextSchoolDay;
import '../ui/today/today_from_lanis.dart'
    show applySubstitutions, dayLessonsFor, planWithSubstitutions;
import '../ui/today/today_model.dart';

/// Schlüssel der Widget-Daten in den SharedPreferences „HomeWidgetPreferences“
/// (Paket home_widget); Kotlin liest denselben Namen (WidgetModel.kt,
/// PAYLOAD_KEY).
const homeWidgetDataKey = 'fork_widget_payload';

/// Version der Datei. 2 = Entwurf 5 (`kids`); Kotlin liest 1 weiter
/// (WidgetModel.parse), bis die App die Datei neu schreibt.
const homeWidgetVersion = 2;

/// Alte Einstellung (Entwurf 4): EIN Konto als Text. Nur noch gelesen
/// – wird nicht mehr ausgewertet (alle Kinder als Standard, Abnahme
/// 28.10.26) und mit der ersten Wahl im neuen Blatt gelöscht.
const widgetAccountSetting = 'fork-widget/account';

/// Gezeigte Kinder (localIds als JSON-Liste, geteilte Einstellungen).
/// Fehlt der Eintrag, zeigt das Widget alle Kinder der Familie (Abnahme
/// 28.10.26, Entwurf 5) – auch später hinzugefügte.
const widgetKidsSetting = 'fork-widget/kids';

/// Höchstzahl der Einträge je Kind in der Datei. Ursache: Das große Widget
/// zeigt höchstens sechs Kacheln; mehr als ein Dutzend Abweichungen an zwei
/// Tagen kommen praktisch nicht vor. Grenze: Was darüber liegt, fehlt auch,
/// wenn frühere Stunden schon vorbei sind.
const widgetMaxItems = 12;

/// Vorschau für Arbeiten (Abnahme 28.10.26: „nächste Arbeit innerhalb von
/// 7 Tagen“): heute bis heute + 6; Kotlin prüft dieselbe Grenze am Tag der
/// Anzeige (WidgetModel.EXAM_DAYS, nameable).
///
/// Ursache für „weniger als 7“ (Prüfung 28.10.26): Die Kachel nennt nur den
/// Wochentag; eine Arbeit genau 7 Tage voraus hieß wie heute („Mittwoch“).
/// Grenze: Eine Arbeit in genau einer Woche erscheint erst am Tag darauf.
const widgetExamDays = 7;

/// Art einer Kachel – bestimmt Farbe und Lagebild in Kotlin: [cancel] rot
/// mit durchgestrichenem Termin, [change] gelb mit anderer Lehrkraft
/// (Vertretung, „bitte prüfen“), [room] gelb mit Fußgänger.
enum WidgetKind { cancel, change, room }

/// Eine Abweichung als Kachel: Fach / was / wann (Entwurf 5, drei Zeilen).
class WidgetItem {
  const WidgetItem({
    required this.date,
    required this.kind,
    required this.title,
    required this.what,
    required this.word,
    required this.slot,
    this.end,
  });

  /// Tag der Stunde (ohne Uhrzeit).
  final DateTime date;
  final WidgetKind kind;

  /// Fach („Englisch“).
  final String title;

  /// Zweite Zeile der Kachel: „fällt aus“, „Vertretung“, „Raum R310“.
  final String what;

  /// Art im Klartext für die kompakte Zelle ab drei Kindern: „fällt aus“,
  /// „Vertretung“, „Raumwechsel“. Ursache (Rückmeldung 28.10.26): Dort
  /// steht die Art IMMER als Wort, beim Raumwechsel nicht der Raum.
  final String word;

  /// Stunde, wie die Schule sie nennt: „3.“, „1.–2.“, „2. Block“ – Kotlin
  /// setzt den Tag davor („heute 3.“).
  final String slot;

  /// Ende der Stunde „HH:mm“ – Kotlin nimmt heutige Einträge danach heraus;
  /// null ohne Uhrzeiten der Schule (dann bleiben sie bis Mitternacht).
  final String? end;

  Map<String, Object?> toJson() => {
    'date': isoDate(date),
    'kind': kind.name,
    'title': title,
    'what': what,
    'word': word,
    'slot': slot,
    if (end != null) 'end': end,
  };
}

/// „2026-10-27“ – das Format, das Kotlin mit LocalDate.parse liest.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Abweichungen von heute und dem nächsten Schultag ([nextSchoolDay]) für das
/// Widget, in der Reihenfolge von [applySubstitutions] (Tag, dann Stunde).
///
/// Dieselbe Zuordnung wie „Heute“, Kalender und Sammelmeldung
/// (applySubstitutions, Gruppenwahl, Klassenfilter, freie Tage). Das Ende
/// einer Stunde kommt aus dem überlagerten Plan des jeweiligen Tages
/// ([planWithSubstitutions] + [dayLessonsFor]).
///
/// Grenze: Heute schon vorbei Stunden bleiben in der Liste (mit [end]);
/// herausgenommen werden sie erst in Kotlin, damit es auch ohne neuen Abruf
/// stimmt. Die Folge eines Ausfalls („Start erst 09:55“) zeigt Entwurf 5
/// nicht mehr – drei kurze Zeilen je Kachel (Abnahme 28.10.26).
List<WidgetItem> widgetItems({
  required KidPlan plan,
  required GroupChoice choice,
  required List<SubstitutionDay> days,
  required DateTime now,
  required ForkL10n t,
  String Function(String code)? subjectName,
  Map<DateTime, String> free = const {},
  String className = '',
}) {
  final today = _day(now);
  final next = nextSchoolDay(now);
  final r = applySubstitutions(
    plan: plan,
    choice: choice,
    days: days,
    now: now,
    t: t,
    subjectName: subjectName,
    free: free,
    className: className,
  );
  final lessonsByDay = <DateTime, List<DayLesson>>{};
  List<DayLesson> lessonsOf(DateTime d) => lessonsByDay.putIfAbsent(d, () {
    final wd = d.weekday - 1;
    if (wd > 4 || free.containsKey(d)) return const [];
    final rows = [
      for (final x in days)
        if (_day(x.dateTime) == d) x,
    ];
    final over = planWithSubstitutions(
      plan: plan,
      days: rows,
      week: [
        for (var i = 0; i < 5; i++) DateTime(d.year, d.month, d.day - wd + i),
      ],
      t: t,
      className: className,
    );
    return dayLessonsFor(over, wd, choice, t: t);
  });

  final out = <WidgetItem>[];
  for (final c in r.changes) {
    final d = _day(c.day);
    if (d != today && d != next) continue;
    final lesson = lessonsOf(d).where(
      (l) => l.slot == c.slot && l.subject == c.subject && l.change == c.kind,
    );
    // Ende: aus dem Abschnitt, sonst (Zusatzstunde ohne Abschnitt) aus dem
    // Zeitraster der Schule, wenn die Beschriftung genau eine Stunde ist.
    final slotEnd = plan.timed
        ? plan.slots.where((s) => s.label == c.slot).firstOrNull?.end
        : null;
    final end = lesson.isNotEmpty
        ? (hasTime(lesson.first) ? lesson.first.end : null)
        : slotEnd;
    final room = c.room;
    final (kind, what, word) = switch (c.kind) {
      ChangeKind.cancelled => (
        WidgetKind.cancel,
        t.lessonCancelled,
        t.lessonCancelled,
      ),
      ChangeKind.substitution => (
        WidgetKind.change,
        t.changeSubstitution,
        t.changeSubstitution,
      ),
      // Kachel: der neue Raum („Raum R310“, Entwurf 5); ohne Raumangabe
      // das Wort.
      ChangeKind.roomChange => (
        WidgetKind.room,
        room == null ? t.changeRoom : t.widgetRoom(room),
        t.changeRoom,
      ),
      // Unsicher: gelb wie in der App, nie als sicherer Ausfall.
      ChangeKind.unclear => (
        WidgetKind.change,
        t.changeUnclear,
        t.changeUnclear,
      ),
    };
    out.add(
      WidgetItem(
        date: d,
        kind: kind,
        title: c.subject,
        what: what,
        word: word,
        slot: widgetSlotShort(c.slot),
        end: end == null || end.isEmpty ? null : end,
      ),
    );
    if (out.length >= widgetMaxItems) break;
  }
  return out;
}

/// Erste Arbeit ab heute, weniger als [widgetExamDays] Tage voraus; [exams]
/// wie von upcomingExamsOf (nach Tag sortiert).
UpcomingExam? nextExamWithin(List<UpcomingExam> exams, DateTime now) {
  final today = _day(now);
  final end = DateTime(now.year, now.month, now.day + widgetExamDays);
  for (final e in exams) {
    final d = _day(e.day);
    if (!d.isBefore(today) && d.isBefore(end)) return e;
  }
  return null;
}

/// Eintrag EINES Kindes in der Datei (`kids[]`), ohne übersetzte Zusätze –
/// die ergänzt [homeWidgetPayload] beim Schreiben (Sprache des Moments).
///
/// [account]: Konto (localId), Schlüssel beim Zusammenführen
/// ([mergeWidgetKid]); [color]: Farbplatz (KitPalette.kids, in Kotlin
/// widget_kidN_*); [stand]: Ladezeitpunkt des Vertretungsplans;
/// [homework]/[homeworkDue]: offene Aufgaben und die früheste vermutete
/// Frist ab heute („für morgen“); [exam]: nächste Arbeit
/// ([nextExamWithin]); [meal]: heute bestelltes Essen (MealCache) – Kotlin
/// zeigt es nur beim großen Widget mit einem Kind (Abnahme 28.10.26).
Map<String, Object?> widgetKidEntry({
  required int account,
  required String name,
  required int color,
  required List<WidgetItem> items,
  DateTime? stand,
  int homework = 0,
  DateTime? homeworkDue,
  UpcomingExam? exam,
  String? meal,
  DateTime? mealDay,
}) => {
  'account': account,
  'name': name.trim(),
  'color': color,
  if (stand != null) 'stand': stand.toIso8601String(),
  'items': [for (final i in items) i.toJson()],
  if (homework > 0) 'hw': homework,
  if (homework > 0 && homeworkDue != null) 'hwDue': isoDate(homeworkDue),
  if (exam != null)
    'exam': {
      'date': isoDate(exam.day),
      'subject': exam.subject,
      // Leer = Art unbekannt; Kotlin nimmt dann labels.exam („Arbeit“).
      'kind': exam.kind,
    },
  if (meal != null && meal.trim().isNotEmpty && mealDay != null)
    'meal': {'date': isoDate(mealDay), 'name': meal.trim()},
};

/// Kinder einer vorhandenen Datei (nur Version 2, sonst leer).
List<Map<String, Object?>> widgetKidsOf(Map<String, Object?>? payload) {
  if (payload == null || payload['v'] != homeWidgetVersion) return const [];
  return [
    for (final k in (payload['kids'] as List?) ?? const [])
      if (k is Map) k.cast<String, Object?>(),
  ];
}

/// Hintergrund-Lauf (notify_task.dart, je Konto): ersetzt in [old] nur den
/// Eintrag von [account] – neue Abweichungen, neuer Stand, ggf. Farbe –
/// und lässt die übrigen Kinder unverändert (Zusammenführen nach Konto).
///
/// Ursache: Der Lauf kennt nur sein eigenes Konto; schriebe er die Datei
/// neu, verschwänden die Geschwister vom Widget. Name, Aufgaben, Arbeit und
/// Essen bleiben aus [old] – der Lauf lädt weder die Liste der erledigten
/// Hausaufgaben noch die Kursmappen (erst ab 15 Uhr, _courseNews). Grenze:
/// null (nichts schreiben), wenn [old] fehlt, noch Version 1 ist oder das
/// Konto nicht darin steht (vom Widget abgewählt, oder die App lief seit dem
/// Update nicht) – die Auswahl trifft allein die App.
List<Map<String, Object?>>? mergeWidgetKid(
  Map<String, Object?>? old, {
  required int account,
  required List<WidgetItem> items,
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
        {
          ...k,
          'items': [for (final x in items) x.toJson()],
          'stand': stand.toIso8601String(),
          'color': ?color,
        },
  ];
}

/// Datei ohne das Konto [account] (Kind abgemeldet,
/// account_removal.dart): die übrigen Einträge; leer, wenn keines bleibt
/// (dann wird die Datei gelöscht); null, wenn das Konto nicht darin steht
/// (nichts zu tun).
///
/// Ursache (Prüfung 28.10.26): Nichts löschte die Datei – ein abgemeldetes
/// Kind blieb mit seinem letzten Stand auf dem Startbildschirm, beim letzten
/// Konto sogar das ganze Widget. Version 1 (ein Kind oben in der Datei) wird
/// ganz gelöscht, wenn es dieses Konto ist. Grenze: Der Hintergrund-Lauf
/// eines anderen Kontos, der in denselben Millisekunden die alte Datei liest,
/// kann den Eintrag zurückschreiben; der nächste Aufbau der App
/// ([widgetAccounts] kennt das Konto nicht mehr) nimmt ihn wieder heraus.
List<Map<String, Object?>>? widgetKidsWithout(
  Map<String, Object?>? payload,
  int account,
) {
  if (payload == null) return null;
  if (payload['v'] != homeWidgetVersion) {
    return payload['account'] == account ? const [] : null;
  }
  final kids = widgetKidsOf(payload);
  if (!kids.any((k) => k['account'] == account)) return null;
  return [
    for (final k in kids)
      if (k['account'] != account) k,
  ];
}

/// Eintrag eines Kindes beim Schreiben aus der App: [app] (eben gerechnet)
/// gegen [old] (aus der Datei). Gewinnt der neuere Vertretungsplan
/// (`stand`): Ist der Eintrag der Datei neuer – der Hintergrund-Lauf hat
/// nach dem letzten Laden der App abgerufen (mergeWidgetKid) –, bleiben
/// dessen `items` und `stand`; Name, Farbe, Aufgaben, Arbeit und Essen
/// kommen aus [app] (die kennt der Hintergrund nicht).
///
/// Ursache (Prüfung 28.10.26): _writeKids (home_widget_sync.dart) nahm immer
/// den Eintrag der App; die offene App schrieb so den älteren Plan über
/// einen neueren aus dem Hintergrund. Grenze: Ohne `stand` (oder nicht
/// lesbar) gilt [app].
Map<String, Object?>? newerWidgetKid(
  Map<String, Object?>? app,
  Map<String, Object?>? old,
) {
  if (app == null || old == null) return app ?? old;
  final a = DateTime.tryParse('${app['stand'] ?? ''}');
  final o = DateTime.tryParse('${old['stand'] ?? ''}');
  if (a == null || o == null || !o.isAfter(a)) return app;
  return {...app, 'items': old['items'], 'stand': old['stand']};
}

/// Die ganze Datei für Kotlin (JSON-fähige Map), Version 2.
///
/// [kids]: Einträge ([widgetKidEntry]) in der Reihenfolge der Familie
/// (nach Anlage des Kontos, family.dart). Ergänzt je Kind `hwText`
/// („2 Aufgaben“) und für alle `hwTotal` (Fußzeile ab drei Kindern) –
/// Mehrzahl kann Kotlin nicht in allen Sprachen bilden.
///
/// [dates]: Kopfzeile („Mi, 28. Okt.“) für heute und die nächsten 7 Tage,
/// damit Kotlin nach Mitternacht ohne neue Datei das richtige Datum zeigt;
/// [labels.weekdays]/[labels.weekdaysLong]: Mo–So kurz (Fußzeile „Mo
/// Jonas“, kompakte Zelle) und lang (Kachel „Donnerstag“).
Map<String, Object?> homeWidgetPayload({
  required List<Map<String, Object?>> kids,
  required DateTime now,
  required ForkL10n t,
}) {
  final monday = DateTime(2024, 1, 1); // ein Montag
  final short = DateFormat('ccc', t.localeName);
  final long = DateFormat('cccc', t.localeName);
  final head = DateFormat(t.widgetDate, t.localeName);
  var total = 0;
  final out = <Map<String, Object?>>[];
  for (final k in kids) {
    final hw = (k['hw'] as num?)?.toInt() ?? 0;
    total += hw;
    // Neu übersetzt bei jedem Schreiben (auch nach einem Sprachwechsel).
    final e = {...k}..remove('hwText');
    if (hw > 0) e['hwText'] = t.homeworkShort(hw);
    out.add(e);
  }
  return {
    'v': homeWidgetVersion,
    'generatedAt': now.toIso8601String(),
    'kids': out,
    if (total > 0) 'hwTotal': t.homeworkShort(total),
    'dates': {
      for (var i = 0; i <= 7; i++)
        isoDate(DateTime(now.year, now.month, now.day + i)): head.format(
          DateTime(now.year, now.month, now.day + i),
        ),
    },
    'labels': {
      'today': t.widgetToday,
      'tomorrow': t.widgetTomorrow,
      'weekdays': [
        for (var i = 0; i < 7; i++)
          short.format(DateTime(monday.year, monday.month, monday.day + i)),
      ],
      'weekdaysLong': [
        for (var i = 0; i < 7; i++)
          long.format(DateTime(monday.year, monday.month, monday.day + i)),
      ],
      // Ruhige Kachel: „Nach Plan / heute / und morgen“, kompakt „nach Plan“.
      // „calmAnd“: Kotlin setzt den nächsten Schultag ein („und Montag“ am
      // Freitag, Prüfung 28.10.26); „calmText“ nur für Kotlin-Stände, die
      // „calmAnd“ nicht kennen – Grenze: dort am Freitag „und morgen“.
      'calmTitle': t.widgetCalmTitle,
      'calmText': t.widgetCalmText,
      'calmAnd': t.widgetCalmAnd('%s'),
      'calmShort': t.widgetCalmShort,
      // Veraltet (Plan deckt heute nicht ab, WidgetModel.quietTile):
      // „Stand %s“ – Kotlin setzt „Fr 18:05“ ein – und „App öffnen“.
      'stale': t.asOf('%s'),
      'staleText': t.widgetStaleText,
      'homeworkOpen': t.widgetHomeworkOpen,
      // „für %s“ – Kotlin setzt „morgen“/„Donnerstag“ ein (Wortstellung je
      // Sprache, tr: „%s için“).
      'dueFor': t.widgetDueFor('%s'),
      'exam': t.widgetExam,
      'meal': t.widgetMeal,
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
