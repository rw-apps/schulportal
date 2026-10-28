/// Schreibt die Daten des Startbildschirm-Widgets (home_widget_data.dart)
/// und stößt das Neuzeichnen an – aus der offenen App ([HomeWidgetSync]) und
/// aus dem Hintergrund-Lauf ([updateHomeWidgetInBackground],
/// notify_task.dart).
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
import '../ui/courses/homework_due.dart' show liveOpenHomework;
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
  'com.example.app.widget.SchoolWidgetMedium',
  'com.example.app.widget.SchoolWidgetSmall',
];

/// Zuletzt geschriebene Daten ohne `generatedAt` – derselbe Stand wird nicht
/// erneut geschrieben. Ursache: [HomeWidgetSync] baut bei jeder Änderung der
/// Familie neu auf (FamilyData meldet immer), das Widget soll nicht bei
/// jedem Aufbau neu zeichnen. Grenze: gilt je Isolat; der Hintergrund-Lauf
/// schreibt daher jedes Mal.
String? _lastWritten;

/// Daten ablegen und beide Widget-Größen neu zeichnen lassen. Nur auf
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

/// Gewähltes Konto aus [widgetAccountSetting]; null = nicht gewählt.
int? storedWidgetAccount(TypedSettings shared) =>
    int.tryParse(shared.getString(widgetAccountSetting) ?? '');

/// Konto des Widgets unter [members]: das gewählte, sonst das aktive, sonst
/// das erste. null, wenn das gewählte Konto zwar besteht ([known]), aber
/// noch nicht geladen ist – dann wird gewartet, statt kurz das Kind eines
/// anderen Kontos zu zeigen. Ein gelöschtes Konto zählt nicht mehr.
FamilyMember? widgetMember(
  List<FamilyMember> members, {
  required int? chosen,
  required int? active,
  required Set<int> known,
}) {
  if (members.isEmpty) return null;
  if (chosen != null && known.contains(chosen)) {
    return members.where((m) => m.accountId == chosen).firstOrNull;
  }
  return members.where((m) => m.accountId == active).firstOrNull ??
      members.first;
}

/// Widget-Daten aus dem geladenen Stand eines Kontos; null, solange
/// Stundenplan oder Vertretungsplan fehlen. Ursache: Ohne Vertretungsplan
/// zeigte das Widget „Alles nach Plan“, obwohl nichts bekannt ist – dann
/// bleibt die vorige Datei stehen (wie die Sammelmeldung,
/// live_today_page.dart).
Map<String, Object?>? livePayloadOf(FamilyMember m, ForkL10n t, DateTime now) {
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
  return homeWidgetPayload(
    account: m.accountId,
    kid: m.colorIndex,
    items: items,
    now: now,
    t: t,
    stand: s.substitutions.fetchedAt,
    homework: liveOpenHomework(s),
    exam: nextExamWithin(exams, now),
  );
}

/// Hält das Widget beim Stand der offenen App: liegt unter FamilyScope
/// (preview_shell.dart) und schreibt nach jedem Aufbau der Familie die
/// Daten des gewählten Kindes ([widgetMember]).
///
/// Ursache: Die App lädt Stundenplan und Vertretungsplan ohnehin; ohne
/// diesen Weg käme neuer Stand nur mit dem Hintergrund-Lauf (15–60 Min.,
/// nur bei eingeschalteten Benachrichtigungen). Grenze: Im Demo-Modus
/// (demo_mode.dart) wird nichts geschrieben – sonst stünde nach der
/// Vorführung das erfundene Kind auf dem Startbildschirm.
class HomeWidgetSync extends ConsumerWidget {
  const HomeWidgetSync({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = FamilyData.of(context);
    if (demoActive || members.isEmpty) return child;
    final shared = ref.watch(sharedOverAccountSettingsProvider);
    final active = ref.watch(activeAccountProvider)?.localId;
    final accounts = ref.watch(accountsProvider).value;
    final m = widgetMember(
      members,
      chosen: storedWidgetAccount(shared),
      active: active,
      known: {for (final a in accounts ?? const <AccountSummary>[]) a.localId},
    );
    if (m == null) return child;
    final payload = livePayloadOf(m, context.t, DateTime.now());
    if (payload != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => writeHomeWidget(payload),
      );
    }
    return child;
  }
}

/// Hintergrund-Lauf (notify_task.dart, je Konto): Widget mit dem eben
/// geladenen Vertretungsplan erneuern – nur für das Konto des Widgets.
///
/// Welches Konto: [widgetAccountSetting], sonst das der vorhandenen Datei
/// (die App schreibt dort das aktive Konto hinein). Ohne beides – die App
/// lief seit der Installation des Widgets nie – schreibt der Hintergrund
/// nichts. Hausaufgaben und Arbeit bleiben aus der vorigen Datei. Ursache:
/// Der Lauf lädt weder die Liste der erledigten Hausaufgaben noch die
/// Kursmappen (erst ab 15 Uhr, _courseNews). Grenze: Die Fußzeile ist so
/// alt wie der letzte App-Start; abgelaufene Arbeiten nimmt Kotlin trotzdem
/// heraus (Datum).
Future<void> updateHomeWidgetInBackground({
  required TypedSettings shared,
  required TypedSettings account,
  required int accountId,
  required ForkL10n t,
  required List<WidgetItem> items,
  required DateTime now,
}) async {
  final old = await readHomeWidget();
  final target = storedWidgetAccount(shared) ?? (old?['account'] as int?);
  if (target == null || target != accountId) return;
  final exam = old?['exam'];
  final payload = homeWidgetPayload(
    account: accountId,
    kid: storedKidColorOrOld(account, old),
    items: items,
    now: now,
    t: t,
    stand: now,
  );
  if (old?['homework'] case final String hw) payload['homework'] = hw;
  if (exam is Map) payload['exam'] = exam;
  await writeHomeWidget(payload);
}

/// Farbplatz des Kindes: gespeichert (kid_colors.dart), sonst aus der
/// vorigen Datei, sonst 0.
int storedKidColorOrOld(TypedSettings account, Map<String, Object?>? old) =>
    storedKidColor(account) ?? (old?['kid'] as int?) ?? 0;
