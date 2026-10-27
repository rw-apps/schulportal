import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/demo/demo_meals.dart';
import 'package:lanis/fork/mensa_store.dart';
import 'package:lanis/fork/mensa_week.dart';
import 'package:lanis/fork/school_links.dart' show normalizeMensaUrl;
import 'package:lanis/fork/ui/today/live_today_page.dart' show mealUnorderedDay;

/// Demo-Caterer (demo_meals.dart): zeigt jede Essens-Funktion.
void main() {
  test('Dienstag 10:00: heute bestellt, morgen offen, ein Tag zu', () {
    final now = DateTime(2026, 10, 27, 10);
    final e = demoMealEntry(now);
    expect(e.weeks.length, 2);
    final today = e.dayOf(DateTime(2026, 10, 27))!;
    expect(today.state, MealState.ordered);
    expect(today.canCancel, isFalse, reason: 'nach 08:30');
    expect(e.dayOf(DateTime(2026, 10, 28))!.state, MealState.open);
    expect(e.dayOf(DateTime(2026, 10, 28))!.options.first.orderable, isTrue);
    expect(e.dayOf(DateTime(2026, 10, 29))!.canCancel, isTrue);
    expect(
      e.weeks.first.days.where((d) => d.state == MealState.closed),
      isEmpty,
      reason: 'Mittwoch ist morgen und damit offen',
    );
    expect(mealUnorderedDay(e, now), DateTime(2026, 10, 28));
    expect(lowMealBalance(e), '12,50');
    expect(normalizeMensaUrl(demoMensaUrl), demoMensaUrl);
  });

  test('Montag früh: Mittwoch geschlossen, heute noch abbestellbar', () {
    final e = demoMealEntry(DateTime(2026, 10, 26, 7));
    expect(e.dayOf(DateTime(2026, 10, 26))!.canCancel, isTrue);
    expect(e.dayOf(DateTime(2026, 10, 28))!.state, MealState.closed);
  });

  test('Speicher liefert im Demo-Modus den Demo-Stand, schreibt nichts', () {
    final c = MealCache.instance..reset();
    c.demo = (_) => demoMealEntry(DateTime(2026, 10, 27, 10));
    expect(c.of('egal')!.balance, '12,50');
    c.markUnreadable('egal');
    expect(c.notifier.value, isEmpty);
    c.demo = null;
    expect(c.of('egal'), isNull);
  });
}
