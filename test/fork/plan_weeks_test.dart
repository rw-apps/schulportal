import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/plan/plan_model.dart';
import 'package:lanis/fork/ui/plan/plan_page.dart';
import 'package:lanis/fork/ui/preview/demo_plan.dart';

void main() {
  testWidgets('Wochen blättern und zurück zu „Diese Woche“', (t) async {
    t.view.physicalSize = const Size(1080, 2424);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    final asked = <DateTime>[];
    final plans = demoPlans();
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: PlanPage(
            plans: plans,
            now: DateTime(2026, 10, 14, 9),
            plansForWeek: (w) {
              asked.add(w.first);
              return <KidPlan>[...plans];
            },
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('12.10.–16.10. · KW 42'), findsOneWidget);
    expect(find.text('Diese Woche'), findsNothing);
    await t.tap(find.byTooltip('Nächste Woche'));
    await t.pumpAndSettle();
    expect(find.text('19.10.–23.10. · KW 43'), findsOneWidget);
    expect(asked.last, DateTime(2026, 10, 19));
    await t.tap(find.text('Woche'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Vorherige Woche'));
    await t.tap(find.byTooltip('Vorherige Woche'));
    await t.pumpAndSettle();
    expect(find.text('5.10.–9.10. · KW 41'), findsOneWidget);
    await t.tap(find.text('Diese Woche'));
    await t.pumpAndSettle();
    expect(find.text('12.10.–16.10. · KW 42'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
