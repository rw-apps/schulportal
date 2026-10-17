import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../live/family.dart';
import '../live/live_data.dart';
import '../today/today_from_lanis.dart'
    show planWithSubstitutions, weekItemsFromCalendar;
import '../today/today_page.dart' show schoolWeek;
import 'lesson_times_dialog.dart';
import 'plan_page.dart';

/// Bereich „Kalender“ mit echten Daten: Stunden je Kind (Gruppenwahl und
/// eigene Lehrernamen je Konto gespeichert, siehe LiveDataScope) und die
/// Termine der Schulen für die nächsten vier Monate.
///
/// Mehrere Konten ([FamilyData]): ein Plan je Konto, Auswahl oben wie im
/// Entwurf (KidChips in PlanPage); Termine aller Schulen zusammen, je Kind
/// gefärbt. Grenze: Bei mehreren Kindern an EINER Schule zeigt das Portal
/// unter stundenplan.php nur ein Kind.
class LiveCalendarPage extends StatelessWidget {
  const LiveCalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LiveGate(
      builder: (context, active) {
        final now = DateTime.now();
        final family = FamilyData.of(context);
        final members = family.isEmpty
            ? [FamilyMember(accountId: -1, snapshot: active, colorIndex: 0)]
            : family;
        final shown = [
          for (final m in members)
            if (m.snapshot.offers('stundenplan.php'))
              if (livePlanOf(
                    m.snapshot,
                    fallbackName: context.t.yourChild,
                    colorIndex: m.colorIndex,
                  )
                  case final live?)
                (m, live),
        ];
        final plans = [
          for (final (m, live) in shown)
            planWithSubstitutions(
              plan: live.plan,
              days: m.snapshot.substitutions.content?.days ?? const [],
              week: schoolWeek(now),
              t: context.t,
            ),
        ];
        final anyEvents = shown.any(
          (x) => x.$1.snapshot.offers('kalender.php'),
        );
        final merged =
            [
              for (final (i, (m, _)) in shown.indexed)
                if (m.snapshot.offers('kalender.php'))
                  ...weekItemsFromCalendar(
                    m.snapshot.calendar.content ?? const [],
                    now,
                    childIndex: i,
                    className: liveClassName(m.snapshot),
                    days: 120,
                    includeMeals: true,
                  ),
            ].indexed.toList()..sort((a, b) {
              final d = a.$2.day.compareTo(b.$2.day);
              return d != 0 ? d : a.$1.compareTo(b.$1);
            });
        return PlanPage(
          key: ValueKey(
            'plan-${[for (final (m, _) in shown) m.snapshot.session.account.localId].join('-')}',
          ),
          plans: plans,
          // Andere Wochen: derselbe Plan mit den Vertretungen jener Tage.
          plansForWeek: (w) => [
            for (final (m, live) in shown)
              planWithSubstitutions(
                plan: live.plan,
                days: m.snapshot.substitutions.content?.days ?? const [],
                week: w,
                t: context.t,
              ),
          ],
          now: now,
          // Gemeinsame Kindwahl aller Reiter (FamilyData.selectedAccount).
          selectedKid: () {
            final id = FamilyData.scopeOf(context)?.selectedAccount;
            final i = shown.indexWhere((x) => x.$1.accountId == id);
            return i < 0 ? null : i;
          }(),
          onSelectKid: (i) => FamilyData.scopeOf(
            context,
          )?.onSelect?.call(shown[i].$1.accountId),
          onEditTimes: (i) async {
            final m = shown[i].$1.snapshot;
            final save = m.setLessonTimes;
            if (save == null) return;
            final r = await askLessonTimes(context, m.lessonTimes);
            if (r != null) save(r.times);
          },
          initialChoices: {
            for (final (i, (m, _)) in shown.indexed) i: m.snapshot.userChoice,
          },
          onChoicesChanged: (c) {
            for (final (i, (m, _)) in shown.indexed) {
              if (c[i] case final v?) m.snapshot.setUserChoice(v);
            }
          },
          autoChoices: {
            for (final (i, (_, live)) in shown.indexed) i: live.auto,
          },
          initialNames: {
            for (final (i, (m, _)) in shown.indexed) i: m.snapshot.ownNames,
          },
          onNamesChanged: (n) {
            for (final (i, (m, _)) in shown.indexed) {
              if (n[i] case final v?) m.snapshot.setOwnNames(v);
            }
          },
          events: anyEvents ? [for (final x in merged) x.$2] : null,
          onRefresh: () async {
            await Future.wait([for (final m in members) m.snapshot.refresh()]);
          },
        );
      },
    );
  }
}
