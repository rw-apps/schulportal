import 'dart:async';

import 'package:flutter/material.dart';

import 'package:lanis/fork/absence/absence_view.dart';

import '../../l10n/l10n.dart';
import '../live/family.dart';
import '../live/live_data.dart';
import '../mensa/mensa_page.dart';
import '../plan/plan_from_lanis.dart' show subjectFullName;
import '../plan/plan_model.dart';
import 'today_from_lanis.dart';
import 'today_model.dart';
import 'login_failure_card.dart';
import 'today_page.dart';
import '../nav.dart';

/// Bestellseite des Kindes in der App öffnen (MensaPage). Ohne Adresse
/// geschieht nichts – die Oberfläche bietet dann „eintragen“ an.
Future<void> openMensa(
  BuildContext context,
  LiveSnapshot s,
  String kid, {
  String? name,
}) async {
  final url = s.mensa.of(kid);
  if (url == null) return;
  await pushFullScreen<void>(
    context,
    (_) => MensaPage(url: url, owner: s.mensaOwner(kid), childName: name),
  );
}

/// Krankmeldung über der neuen Oberfläche öffnen.
Future<void> openAbsence(BuildContext context) =>
    pushFullScreen<void>(context, (_) => const AbsencePage());

/// „Heute“ mit echten Daten des angemeldeten Kontos (LiveDataScope).
///
/// Fehlt Vertretungsplan oder Kalender (nicht freigeschaltet, offline,
/// Fehler), zeigt die Seite den Rest – der Stundenplan allein ist schon
/// nützlich. Mehrere Konten (zweite Schule): eine Karte je Konto
/// ([FamilyData]). Grenze: Im Elternkonto erscheint wie bisher nur das Kind,
/// dessen Stundenplan das Portal liefert.
class LiveTodayPage extends StatefulWidget {
  const LiveTodayPage({
    super.key,
    this.onOpenCalendar,
    this.onOpenHomework,
    this.onOpenMessages,
    this.onOpenDay,
  });

  /// Kalender in der Ansicht „Tag“ (Tagesleiste angetippt); das Kind ist
  /// dann schon gewählt (FamilyData.onSelect).
  final VoidCallback? onOpenDay;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenHomework;
  final VoidCallback? onOpenMessages;

  @override
  State<LiveTodayPage> createState() => _LiveTodayPageState();
}

class _LiveTodayPageState extends State<LiveTodayPage> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // „Jetzt“ und Restminuten werden aus der Uhrzeit berechnet
    // (today_model.dayStatus); ohne Takt stünde „noch 30 Min.“ still.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Karte eines Kontos; null, solange dessen Stundenplan fehlt.
  ChildToday? _kidOf(FamilyMember m, DateTime now) {
    final s = m.snapshot;
    if (!s.offers('stundenplan.php')) return null;
    final live = livePlanOf(
      s,
      fallbackName: context.t.yourChild,
      colorIndex: m.colorIndex,
    );
    if (live == null) return null;
    final className = liveClassName(s);
    final courses = s.courseNames;
    final events = s.calendar.content ?? const [];
    return childTodayFromLanis(
      plan: live.plan,
      choice: effectiveChoice(live.auto, s.userChoice),
      substitutions: s.substitutions.content?.days ?? const [],
      now: now,
      school: shortSchoolName(s.schoolName),
      t: context.t,
      className: className,
      canReportAbsence: s.offers('abwesenheitsmeldung.php'),
      subjectName: (code) => subjectFullName(code, courses),
      mealHint: mealHintFor(events, now, t: context.t, className: className),
      mensaUrl: s.mensaUrl,
      openHomework: liveOpenHomework(s),
      unreadMessages: liveUnreadMessages(s),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiveGate(
      builder: (context, active) {
        final now = DateTime.now();
        // Familienansicht (family.dart): eine Karte je Konto mit Plan. Ohne
        // FamilyScope (Tests) nur das aktive Konto.
        final family = FamilyData.of(context);
        final members = family.isEmpty
            ? [FamilyMember(accountId: -1, snapshot: active, colorIndex: 0)]
            : family;
        final shown = <(FamilyMember, ChildToday)>[
          for (final m in members)
            if (_kidOf(m, now) case final kid?) (m, kid),
        ];
        final kids = [for (final x in shown) x.$2];
        FamilyMember memberOf(ChildToday c) =>
            shown[kids.indexOf(c).clamp(0, shown.length - 1)].$1;
        // Nach Tag zusammenführen; innerhalb eines Tages bleibt die
        // Reihenfolge je Konto (Uhrzeit) erhalten – Dart sortiert nicht
        // stabil, daher die Position als zweiter Schlüssel.
        final merged =
            [
              for (final (i, (m, _)) in shown.indexed)
                ...withCourseExams(
                  weekItemsFromCalendar(
                    m.snapshot.calendar.content ?? const [],
                    now,
                    childIndex: i,
                    className: liveClassName(m.snapshot),
                    skipHolidays: true,
                  ),
                  m.snapshot.courseScan,
                  now,
                  childIndex: i,
                ),
            ].indexed.toList()..sort((a, b) {
              final d = a.$2.day.compareTo(b.$2.day);
              return d != 0 ? d : a.$1.compareTo(b.$1);
            });
        final week = [for (final x in merged) x.$2];
        // Ältester Stand der angezeigten Pläne – ehrlicher als der neueste.
        DateTime? updated;
        for (final (m, _) in shown) {
          for (final at in [
            m.snapshot.timetable.fetchedAt,
            m.snapshot.substitutions.fetchedAt,
          ]) {
            if (at != null && (updated == null || at.isBefore(updated))) {
              updated = at;
            }
          }
        }
        // Vor dem Wechsel in einen anderen Reiter das Kind der Karte wählen
        // (gemeinsame Kindwahl), damit dort gleich das richtige Kind steht.
        void select(ChildToday c) =>
            FamilyData.scopeOf(context)?.onSelect?.call(memberOf(c).accountId);
        final scope = FamilyData.scopeOf(context);
        return TodayPage(
          notices: [
            for (final f in scope?.failures ?? const <FamilyFailure>[])
              LoginFailureCard(
                failure: f,
                onRetry: scope?.onRetry == null
                    ? null
                    : () => scope!.onRetry!(f.account.localId),
              ),
          ],
          data: FamilyToday(
            now: now,
            kids: kids,
            week: week,
            updatedAt: updated,
          ),
          onOpenDay: widget.onOpenDay == null
              ? null
              : (c) {
                  select(c);
                  widget.onOpenDay!();
                },
          onReportAbsence: kids.any((k) => k.canReportAbsence)
              ? (c) {
                  final m = memberOf(c);
                  pushFullScreen<void>(
                    context,
                    (_) => m.scope(const AbsencePage()),
                  );
                }
              : null,
          onOrderMeal: kids.any((k) => k.mensaUrl != null)
              ? (c) {
                  final s = memberOf(c).snapshot;
                  openMensa(
                    context,
                    s,
                    s.mensaKid,
                    name: kids.length > 1 || s.kids.length > 1
                        ? c.firstName
                        : null,
                  );
                }
              : null,
          onOpenCalendar: widget.onOpenCalendar,
          onOpenHomework: widget.onOpenHomework == null
              ? null
              : (c) {
                  select(c);
                  widget.onOpenHomework!();
                },
          onOpenMessages: widget.onOpenMessages == null
              ? null
              : (c) {
                  select(c);
                  widget.onOpenMessages!();
                },
          onRefresh: () async {
            await Future.wait([for (final m in members) m.snapshot.refresh()]);
          },
        );
      },
    );
  }
}
