import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/today/today_model.dart';
import 'package:lanis/fork/ui/today/today_page.dart';

/// Schule ohne Uhrzeiten (Abnahme 30.10.26): ab 17 Uhr nächster Schultag,
/// Link „Stundenzeiten eintragen“ – synthetisch.
void main() {
  DayLesson l(String slot, String s) =>
      DayLesson(slot: slot, subject: s, start: '', end: '');
  ChildToday kid(List<DayLesson> ls) => ChildToday(
    firstName: 'Lena',
    school: 'Beispielschule',
    className: '9X',
    colorIndex: 0,
    lessons: ls,
  );
  final today = [l('1.–2.', 'Mathematik'), l('3.', 'Sport')];
  final monday = [l('1.–2.', 'Geschichte')];

  test('ohne Zeiten: bis 17 Uhr offen, danach vorbei', () {
    expect(
      dayStatus(today, DateTime(2026, 10, 30, 16, 59)).phase,
      DayPhase.untimed,
    );
    expect(dayStatus(today, DateTime(2026, 10, 30, 17)).phase, DayPhase.over);
  });

  Future<List<ChildToday>> pump(WidgetTester t, DateTime now) async {
    final asked = <ChildToday>[];
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: KidCard(
              kid: kid(today),
              now: now,
              nextDay: kid(monday),
              nextDate: DateTime(2026, 11, 2),
              onEnterTimes: asked.add,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    return asked;
  }

  testWidgets('15 Uhr: heute, Link öffnet Stundenzeiten', (t) async {
    final asked = await pump(t, DateTime(2026, 10, 30, 15));
    expect(find.text('HEUTE · AB 1.–2.'), findsOneWidget);
    await t.tap(find.text('Stundenzeiten eintragen'));
    expect(asked.single.firstName, 'Lena');
  });

  testWidgets('17:30: nächster Schultag ohne „seit“', (t) async {
    await pump(t, DateTime(2026, 10, 30, 17, 30));
    expect(find.text('Unterricht vorbei'), findsOneWidget);
    expect(find.text('Montag, 2. November'), findsOneWidget);
    expect(find.text('ERSTE STUNDE · 1.–2.'), findsOneWidget);
  });
}
