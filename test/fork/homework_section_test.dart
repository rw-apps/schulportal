import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/homework_ledger.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/courses/homework_section.dart';

/// Abhaken und Zurückholen mit Übergang (homework_section.dart) –
/// synthetisch; die Aufgaben wandern wie bei echten Daten zwischen den
/// Listen.
void main() {
  HomeworkItem hw(String entry, String text) => HomeworkItem(
    course: 'm',
    entry: entry,
    subject: 'Mathematik',
    text: text,
    given: DateTime(2026, 10, 20),
  );

  testWidgets('abhaken → unter Erledigt, Haken dort → wieder offen', (t) async {
    final open = [hw('1', 'Buch S. 42'), hw('2', 'Arbeitsblatt')];
    final done = <HomeworkItem>[];
    late StateSetter set;
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (c, s) {
              set = s;
              HwEntry e(HomeworkItem i) => HwEntry(
                item: i,
                onDone: () => set(() {
                  open.remove(i);
                  done.insert(0, i);
                }),
                onReopen: () => set(() {
                  done.remove(i);
                  open.insert(0, i);
                }),
              );
              return SingleChildScrollView(
                child: HomeworkSection(
                  open: [for (final i in open) e(i)],
                  done: [for (final i in done) e(i)],
                  emptyText: 'leer',
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(find.text('Erledigt (1)'), findsNothing);
    await t.tap(find.byTooltip('Als erledigt abhaken').first);
    await t.pumpAndSettle();
    expect(open.map((i) => i.text), ['Arbeitsblatt']);
    expect(find.text('Buch S. 42'), findsNothing, reason: 'zugeklappt');
    expect(find.text('Erledigt (1)'), findsOneWidget);

    await t.tap(find.text('Erledigt (1)'));
    await t.pumpAndSettle();
    expect(find.text('Buch S. 42'), findsOneWidget);
    await t.tap(find.byTooltip('Wieder offen'));
    await t.pumpAndSettle();
    expect(done, isEmpty);
    expect(open.first.text, 'Buch S. 42');
    // Wieder oben, genau einmal (nicht zusätzlich unter „Erledigt“).
    expect(find.text('Buch S. 42'), findsOneWidget);
    expect(find.text('Erledigt (1)'), findsNothing);
  });

  testWidgets('mehr als zehn erledigte: Verweis auf alle', (t) async {
    var all = 0;
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeworkSection(
              open: const [],
              done: [
                for (var i = 0; i < 12; i++)
                  HwEntry(
                    item: hw('$i', 'Aufgabe $i'),
                    onDone: () {},
                    onReopen: () {},
                  ),
              ],
              emptyText: 'leer',
              onShowAll: () => all++,
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Erledigt (12)'));
    await t.pumpAndSettle();
    expect(find.text('Aufgabe 9'), findsOneWidget);
    expect(find.text('Aufgabe 10'), findsNothing);
    await t.ensureVisible(find.text('Alle 12 erledigten anzeigen'));
    await t.pumpAndSettle();
    await t.tap(find.text('Alle 12 erledigten anzeigen'));
    expect(all, 1);
  });
}
