import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/utils/applet_settings.dart';

import '../../class_choice.dart' show storedClass;
import '../../l10n/l10n.dart';
import '../kit.dart';
import '../live/live_data.dart';
import '../plan/plan_model.dart';
import '../plan/plan_page.dart';
import '../today/today_from_lanis.dart';
import '../today/today_model.dart';
import '../today/today_page.dart';

/// Zuletzt gespeicherter Stand eines Kontos (applet_offline_data).
///
/// Ursache (Entscheidung 17.10.26): Lanis öffnete beim Start ohne Netz die
/// alten Ansichten von Vertretungs- und Stundenplan; die sind entfernt. Jetzt
/// zeigt die neue Oberfläche denselben gespeicherten Stand. Grenze: liblanis
/// speichert offline nur Stundenplan und Vertretungsplan (allowOffline);
/// Lehrernamen aus „Mein Unterricht“ fehlen daher – es erscheinen Kürzel
/// bzw. die selbst eingetragenen Namen.
class OfflineSnapshot {
  const OfflineSnapshot({
    required this.account,
    required this.timetable,
    required this.fetchedAt,
    this.substitutions,
  });

  final AccountSummary account;
  final TimeTable timetable;
  final SubstitutionPlan? substitutions;
  final DateTime fetchedAt;
}

/// Konten mit gespeichertem Stundenplan, neuester Stand zuerst.
Future<List<OfflineSnapshot>> loadOfflineSnapshots(LanisDatabase db) async {
  final out = <OfflineSnapshot>[];
  for (final a in await db.listAccounts()) {
    try {
      final tt = db.getAppletOfflineData(
        accountId: a.localId,
        appletId: 'stundenplan.php',
      );
      if (tt == null) continue;
      final subs = db.getAppletOfflineData(
        accountId: a.localId,
        appletId: 'vertretungsplan.php',
      );
      out.add(
        OfflineSnapshot(
          account: a,
          timetable: TimeTable.fromJson(jsonDecode(tt.json)),
          substitutions: subs == null
              ? null
              : SubstitutionPlan.fromJson(jsonDecode(subs.json)),
          fetchedAt: subs != null && subs.timestamp.isAfter(tt.timestamp)
              ? subs.timestamp
              : tt.timestamp,
        ),
      );
    } catch (_) {
      // Unlesbarer Stand (ältere Datenform) – Konto auslassen.
    }
  }
  out.sort((a, b) => b.fetchedAt.compareTo(a.fetchedAt));
  return out;
}

/// „Heute“ und „Kalender“ aus dem gespeicherten Stand, mit Hinweis „Offline“.
class OfflinePage extends ConsumerStatefulWidget {
  const OfflinePage({super.key, required this.snapshot});

  final OfflineSnapshot snapshot;

  @override
  ConsumerState<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends ConsumerState<OfflinePage> {
  bool _week = false;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final s = widget.snapshot;
    final db = ref.read(lanisDatabaseProvider);
    final settings = TypedSettings.account(db, s.account.localId);
    final userChoice = settingStrings(
      resolveStoredAppletSetting(
        settings,
        'stundenplan.php/$groupChoiceSetting',
        const <String, dynamic>{},
      ),
    );
    final ownNames = settingStrings(
      resolveStoredAppletSetting(
        settings,
        'stundenplan.php/$teacherNamesSetting',
        const <String, dynamic>{},
      ),
    );
    final (:plan, :auto) = livePlan(
      tt: s.timetable,
      lessons: const [],
      // Vorname des Kindes ist offline nicht gespeichert – Schulname statt
      // leerer Karte.
      firstName: shortSchoolName(s.account.schoolName),
      lessonTimes: storedLessonTimes(settings),
    );
    final named = plan.withTeacherNames(ownNames);
    final choice = effectiveChoice(auto, userChoice);
    final now = DateTime.now();
    final days = s.substitutions?.days ?? const <SubstitutionDay>[];
    final when =
        '${formatDate(t, t.dateShort, s.fetchedAt)} '
        '${s.fetchedAt.hour.toString().padLeft(2, '0')}:'
        '${s.fetchedAt.minute.toString().padLeft(2, '0')}';

    final Widget body;
    if (_week) {
      body = PlanPage(
        plans: [
          planWithSubstitutions(
            plan: named,
            days: days,
            week: schoolWeek(now),
            t: t,
            // Offline nur die eigene Eingabe (class_choice.dart); ohne sie
            // bleiben alle Zeilen (substitutionForClass).
            className: storedClass(settings)?.name ?? '',
          ),
        ],
        now: now,
        initialChoices: {0: userChoice},
        autoChoices: {0: auto},
      );
    } else {
      final kid = childTodayFromLanis(
        plan: named,
        choice: choice,
        substitutions: days,
        now: now,
        school: '',
        t: t,
        className: storedClass(settings)?.name ?? '',
      );
      body = TodayPage(
        data: FamilyToday(now: now, kids: [kid], week: const []),
      );
    }

    return Scaffold(
      backgroundColor: k.p.bg,
      body: Column(
        children: [
          Material(
            color: k.p.change.bg,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Sp.s, Sp.xs, Sp.l, Sp.s),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.arrow_back, color: k.p.change.ink),
                      tooltip: t.back,
                    ),
                    Icon(Icons.wifi_off, size: Sz.icon, color: k.p.change.ink),
                    const SizedBox(width: Sp.s),
                    Expanded(
                      child: Text(
                        t.offlineBanner(when),
                        style: k.boxStrong(k.p.change),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: body,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Sp.m),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(t.navToday)),
              ButtonSegment(value: true, label: Text(t.navCalendar)),
            ],
            selected: {_week},
            onSelectionChanged: (v) => setState(() => _week = v.first),
          ),
        ),
      ),
    );
  }
}

/// Einstieg im Startbildschirm ohne Verbindung: je Konto mit gespeichertem
/// Stand ein Knopf.
class OfflineEntry extends ConsumerStatefulWidget {
  const OfflineEntry({super.key});

  @override
  ConsumerState<OfflineEntry> createState() => _OfflineEntryState();
}

class _OfflineEntryState extends ConsumerState<OfflineEntry> {
  List<OfflineSnapshot>? _items;

  @override
  void initState() {
    super.initState();
    loadOfflineSnapshots(ref.read(lanisDatabaseProvider)).then((v) {
      if (mounted) setState(() => _items = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final t = context.t;
    final k = Kit.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.offlineHint, style: k.meta, textAlign: TextAlign.center),
          const SizedBox(height: Sp.s),
          for (final s in items)
            Padding(
              padding: const EdgeInsets.only(top: Sp.s),
              child: FilledButton.tonal(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OfflinePage(snapshot: s),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Sp.s),
                  child: Column(
                    children: [
                      Text(t.offlineEntry),
                      Text(
                        t.offlineEntryDetail(
                          shortSchoolName(s.account.schoolName),
                          formatDate(t, t.dateShort, s.fetchedAt),
                        ),
                        style: k.planMeta(k.p.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
