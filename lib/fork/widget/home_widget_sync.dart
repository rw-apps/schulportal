/// Schreibt die Daten des Startbildschirm-Widgets (home_widget_data.dart)
/// und stößt das Neuzeichnen an – aus der offenen App ([HomeWidgetSync], alle
/// gezeigten Kinder) und aus dem Hintergrund-Lauf
/// ([updateHomeWidgetInBackground], nur das eigene Kind, notify_task.dart).
library;

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:liblanis/liblanis.dart';

import '../demo/demo_mode.dart' show demoActive;
import '../exams.dart';
import '../kid_colors.dart' show storedKidColor;
import '../l10n/l10n.dart';
import '../mensa_store.dart' show MealCache;
import '../ui/courses/homework_due.dart' show liveOpenHomeworkItems;
import '../ui/courses/live_courses_page.dart' show examCalendarOf;
import '../ui/live/family.dart';
import '../ui/live/live_data.dart';
import '../ui/plan/plan_from_lanis.dart' show subjectFullName;
import '../ui/plan/plan_model.dart';
import '../ui/today/today_from_lanis.dart' show freeDaysAhead, freeDaysFrom;
import 'home_widget_data.dart';

/// Widget-Klassen in Kotlin (android/app/src/main/kotlin/com/example/app/
/// widget/SchoolWidget.kt). Voll ausgeschrieben, weil das Paket der App
/// (io.github.rwapps.sph, .debug) vom Kotlin-Namensraum (com.example.app)
/// abweicht – home_widget sucht kurze Namen im App-Paket.
const _providers = [
  'com.example.app.widget.SchoolWidgetSmall',
  'com.example.app.widget.SchoolWidgetMedium',
  'com.example.app.widget.SchoolWidgetLarge',
];

/// Zuletzt geschriebene Daten ohne `generatedAt` – derselbe Stand wird nicht
/// erneut geschrieben. Ursache: [HomeWidgetSync] baut bei jeder Änderung der
/// Familie neu auf (FamilyData meldet immer), das Widget soll nicht bei
/// jedem Aufbau neu zeichnen. Grenze: gilt je Isolat; der Hintergrund-Lauf
/// schreibt daher jedes Mal.
String? _lastWritten;

/// Daten ablegen und alle Widget-Größen neu zeichnen lassen. Nur auf
/// Android (sonst kein Widget); Fehler des Plugins (z. B. in Tests ohne
/// Plattform) werden geschluckt – das Widget ist Beiwerk, kein Grund für
/// einen Absturz oder einen abgebrochenen Hintergrund-Lauf.
Future<void> writeHomeWidget(Map<String, Object?> payload) async {
  if (!Platform.isAndroid) return;
  final same = jsonEncode({...payload}..remove('generatedAt'));
  if (same == _lastWritten) return;
  try {
    await HomeWidget.saveWidgetData<String>(
      homeWidgetDataKey,
      jsonEncode(payload),
    );
    for (final p in _providers) {
      await HomeWidget.updateWidget(qualifiedAndroidName: p);
    }
    _lastWritten = same;
  } catch (_) {}
}

/// Zuletzt geschriebene Daten (null ohne Datei oder außerhalb von Android).
Future<Map<String, Object?>?> readHomeWidget() async {
  if (!Platform.isAndroid) return null;
  try {
    final raw = await HomeWidget.getWidgetData<String>(homeWidgetDataKey);
    if (raw == null) return null;
    final v = jsonDecode(raw);
    return v is Map<String, Object?> ? v : null;
  } catch (_) {
    return null;
  }
}

/// Gewählte Kinder ([widgetKidsSetting], sonst die alte Einzelwahl
/// [widgetAccountSetting]); null = alle.
Set<int>? widgetKidSelection(TypedSettings shared) => widgetKidSelectionFrom(
  kids: shared.getString(widgetKidsSetting),
  legacy: shared.getString(widgetAccountSetting),
);

/// Auswahl speichern; null = alle Kinder (Eintrag gelöscht, damit später
/// hinzugefügte Kinder von selbst erscheinen). Löscht immer auch die alte
/// Einzelwahl – sonst käme sie bei „alle“ als Übernahme zurück.
void storeWidgetKidSelection(TypedSettings shared, Set<int>? selection) {
  shared.setString(
    widgetKidsSetting,
    selection == null ? null : jsonEncode([...selection]..sort()),
  );
  shared.setString(widgetAccountSetting, null);
}

/// Eintrag eines Kindes aus dem geladenen Stand seines Kontos; null, solange
/// Stundenplan oder Vertretungsplan fehlen. Ursache: Ohne Vertretungsplan
/// zeigte das Widget „Nach Plan“, obwohl nichts bekannt ist – dann bleibt
/// der Eintrag der vorigen Datei stehen ([HomeWidgetSync]).
Map<String, Object?>? liveKidEntry(FamilyMember m, ForkL10n t, DateTime now) {
  final s = m.snapshot;
  if (!s.offers('stundenplan.php') || s.substitutions.content == null) {
    return null;
  }
  final live = livePlanOf(
    s,
    fallbackName: t.yourChild,
    colorIndex: m.colorIndex,
  );
  if (live == null) return null;
  final className = liveClassName(s);
  final events = s.calendar.content ?? const <CalendarEvent>[];
  final courses = s.courseNames;
  final items = widgetItems(
    plan: live.plan,
    choice: effectiveChoice(live.auto, s.userChoice),
    days: s.substitutionDaysFromToday(now),
    now: now,
    t: t,
    subjectName: (c) => subjectFullName(c, courses),
    free: s.offers('kalender.php')
        ? freeDaysFrom(events, now, className: className, days: freeDaysAhead)
        : const {},
    className: className,
  );
  final exams = upcomingExamsOf(
    scan: s.courseScan?.upcoming(now) ?? const [],
    calendar: examCalendarOf(s, now),
    now: now,
    until: DateTime(now.year, now.month, now.day + widgetExamDays),
  );
  final homework = liveOpenHomeworkItems(s);
  final today = DateTime(now.year, now.month, now.day);
  // Früheste vermutete Frist ab heute („für morgen“); ohne Stundenplan
  // keine Frist, dann bleibt die dritte Zeile der Kachel leer.
  DateTime? due;
  for (final h in homework) {
    final d = h.due;
    if (d == null) continue;
    final day = DateTime(d.year, d.month, d.day);
    if (day.isBefore(today)) continue;
    if (due == null || day.isBefore(due)) due = day;
  }
  // Essen: dieselbe Quelle wie die Kinderkarte (live_today_page.dart,
  // lunch) – nur, was für heute bestellt ist.
  final meal = s.mensaUrl == null
      ? null
      : MealCache.instance.of(s.mensaOwner(s.mensaKid))?.dayOf(now);
  final name = s.firstName.trim();
  return widgetKidEntry(
    account: m.accountId,
    name: name.isEmpty ? t.yourChild : name,
    color: m.colorIndex,
    items: items,
    stand: s.substitutions.fetchedAt,
    homework: homework.length,
    homeworkDue: due,
    exam: nextExamWithin(exams, now),
    meal: meal?.ordered?.name,
    mealDay: meal?.day,
  );
}

/// Hält das Widget beim Stand der offenen App: liegt unter FamilyScope
/// (preview_shell.dart) und schreibt nach jedem Aufbau der Familie die
/// Einträge ALLER gezeigten Kinder (Entwurf 5: Vorgabe alle,
/// [widgetKidSelection]) in Familienreihenfolge (nach Anlage des Kontos,
/// wie FamilyScope).
///
/// Kinder, deren Stand noch lädt, behalten ihren Eintrag aus der vorigen
/// Datei. Ursache: Sonst wechselte das Widget beim Start kurz die Stufe
/// (erst ein Kind, dann zwei). Grenze: Ein Kind, das nie geladen war, fehlt,
/// bis sein Stand da ist.
///
/// Ursache des Wegs überhaupt: Die App lädt Stundenplan und Vertretungsplan
/// ohnehin; ohne ihn käme neuer Stand nur mit dem Hintergrund-Lauf (15–60
/// Min., nur bei eingeschalteten Benachrichtigungen). Grenze: Im Demo-Modus
/// (demo_mode.dart) wird nichts geschrieben – sonst stünden nach der
/// Vorführung die erfundenen Kinder auf dem Startbildschirm.
class HomeWidgetSync extends ConsumerWidget {
  const HomeWidgetSync({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = FamilyData.of(context);
    if (demoActive || members.isEmpty) return child;
    final shared = ref.watch(sharedOverAccountSettingsProvider);
    final accounts = ref.watch(accountsProvider).value;
    final ordered = [
      for (final a in accounts ?? const <AccountSummary>[]) a.localId,
    ]..sort();
    final ids = widgetAccounts(
      ordered.isEmpty ? [for (final m in members) m.accountId] : ordered,
      widgetKidSelection(shared),
    );
    final t = context.t;
    // Neu gelesene Essenswochen (MealCache) erneuern das Widget wie Heute.
    return ValueListenableBuilder(
      valueListenable: MealCache.instance.notifier,
      child: child,
      builder: (context, _, child) {
        final now = DateTime.now();
        final fresh = <int, Map<String, Object?>>{
          for (final m in members)
            if (ids.contains(m.accountId))
              m.accountId: ?_cachedEntry(m, t, now),
        };
        if (fresh.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _writeKids(ids, fresh, t, now),
          );
        }
        return child!;
      },
    );
  }
}

/// Eintrag je Stand (LiveSnapshot) einmal je Tag, Sprache, Farbe und
/// Essensstand. Ursache: Seit Entwurf 5 rechnet [HomeWidgetSync] bei jedem
/// Aufbau der Familie für ALLE Kinder Plan, Vertretungen, Arbeiten und
/// Aufgaben – ohne Ablage liefe das bei jeder Meldung von FamilyData neu.
/// Grenze: Ein neuer Stand (neue LiveSnapshot-Instanz) rechnet neu; innerhalb
/// eines Tages gilt der Eintrag weiter, vergangene Stunden nimmt ohnehin
/// Kotlin heraus.
final _entryCache = Expando<(String, Map<String, Object?>?)>();

Map<String, Object?>? _cachedEntry(FamilyMember m, ForkL10n t, DateTime now) {
  final key =
      '${isoDate(now)}|${t.localeName}|${m.accountId}|${m.colorIndex}|'
      '${identityHashCode(MealCache.instance.notifier.value)}';
  final hit = _entryCache[m.snapshot];
  if (hit != null && hit.$1 == key) return hit.$2;
  final e = liveKidEntry(m, t, now);
  _entryCache[m.snapshot] = (key, e);
  return e;
}

/// Zuletzt übergebene Einträge der App – spart das Lesen der Datei, wenn
/// sich nichts geändert hat (FamilyData meldet bei jedem Aufbau).
String? _lastFresh;

Future<void> _writeKids(
  List<int> ids,
  Map<int, Map<String, Object?>> fresh,
  ForkL10n t,
  DateTime now,
) async {
  final key = jsonEncode([ids, fresh.map((k, v) => MapEntry('$k', v))]);
  if (key == _lastFresh) return;
  _lastFresh = key;
  final old = {
    for (final k in widgetKidsOf(await readHomeWidget()))
      if (k['account'] case final int a) a: k,
  };
  final kids = [for (final id in ids) ?(fresh[id] ?? old[id])];
  await writeHomeWidget(homeWidgetPayload(kids: kids, now: now, t: t));
}

/// Hintergrund-Lauf (notify_task.dart, je Konto): Widget mit dem eben
/// geladenen Vertretungsplan erneuern – nur den Eintrag DIESES Kontos,
/// die übrigen Kinder bleiben ([mergeWidgetKid]).
///
/// Ohne Datei der App (Version 2) oder wenn das Konto nicht im Widget steht,
/// schreibt der Hintergrund nichts. Grenze: Aufgaben, Arbeit und Essen sind
/// so alt wie der letzte App-Start; abgelaufene Arbeiten und Essen anderer
/// Tage nimmt Kotlin trotzdem heraus (Datum).
Future<void> updateHomeWidgetInBackground({
  required TypedSettings account,
  required int accountId,
  required ForkL10n t,
  required List<WidgetItem> items,
  required DateTime now,
}) async {
  final kids = mergeWidgetKid(
    await readHomeWidget(),
    account: accountId,
    items: items,
    stand: now,
    color: storedKidColor(account),
  );
  if (kids == null) return;
  await writeHomeWidget(homeWidgetPayload(kids: kids, now: now, t: t));
}
