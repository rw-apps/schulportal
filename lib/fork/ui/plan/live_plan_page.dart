import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../live/live_data.dart';
import '../today/today_from_lanis.dart'
    show planWithSubstitutions, weekItemsFromCalendar;
import '../today/today_page.dart' show schoolWeek;
import 'plan_page.dart';

/// Bereich „Kalender“ mit echten Daten: Stunden des Kindes (Gruppenwahl und
/// eigene Lehrernamen je Konto gespeichert, siehe LiveDataScope) und die
/// Termine der Schule für die nächsten vier Monate.
///
/// Grenze: Bei mehreren Kindern an EINER Schule zeigt das Portal unter
/// stundenplan.php nur ein Kind; das zweite folgt mit der Familienansicht.
class LiveCalendarPage extends StatelessWidget {
  const LiveCalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LiveGate(
      builder: (context, s) {
        final (:plan, :auto) = livePlanOf(
          s,
          fallbackName: context.t.yourChild,
        )!;
        final now = DateTime.now();
        final withSubs = planWithSubstitutions(
          plan: plan,
          days: s.substitutions.content?.days ?? const [],
          week: schoolWeek(now),
          t: context.t,
        );
        final events = s.offers('kalender.php')
            ? weekItemsFromCalendar(
                s.calendar.content ?? const [],
                now,
                childIndex: 0,
                className: liveClassName(s),
                days: 120,
                includeMeals: true,
              )
            : null;
        return PlanPage(
          key: ValueKey('plan-${s.session.account.localId}'),
          plans: [withSubs],
          now: now,
          initialChoices: {0: s.userChoice},
          onChoicesChanged: (c) => s.setUserChoice(c[0] ?? const {}),
          autoChoices: {0: auto},
          initialNames: {0: s.ownNames},
          onNamesChanged: (n) => s.setOwnNames(n[0] ?? const {}),
          events: events,
          onRefresh: s.refresh,
        );
      },
    );
  }
}
