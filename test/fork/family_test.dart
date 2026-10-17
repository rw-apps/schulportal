import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/live/family.dart';
import 'package:lanis/fork/ui/live/live_data.dart';
import 'package:lanis/fork/ui/nav.dart';
import 'package:liblanis/liblanis.dart';

final _checkers = <ConnectionChecker>[];

ConnectionChecker _checker() {
  final c = ConnectionChecker();
  _checkers.add(c);
  return c;
}

/// Erfundenes Konto ohne Portal (nur Name und Schule).
LiveSnapshot _snap(int id, String first, String school) {
  final session = LanisSession(
    account: ClearTextAccount(
      localId: id,
      schoolID: 1000 + id,
      username: 'u$id',
      password: '',
      schoolName: school,
      accountType: AccountType.student,
    ),
    config: const LanisConfig(),
    connectionChecker: _checker(),
  )..userData = {'vorname': first};
  return LiveSnapshot(
    session: session,
    supported: const {},
    timetable: const Feed(),
    lessons: const Feed(),
    substitutions: const Feed(),
    calendar: const Feed(),
    conversations: const Feed(),
    userChoice: const {},
    ownNames: const {},
    setUserChoice: (_) {},
    setOwnNames: (_) {},
    refresh: () async {},
    refreshMessages: () async {},
    setMensaUrl: (_, _) {},
  );
}

void _disposeCheckers() {
  for (final c in _checkers) {
    c.dispose();
  }
  _checkers.clear();
}

void main() {
  testWidgets('Auswahl je Kind: Bereich zeigt das gewählte Konto', (t) async {
    final a = _snap(1, 'Anna', 'Schule A');
    final b = _snap(2, 'Ben', 'Schule B');
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: LiveData(
            snapshot: a,
            child: FamilyData(
              members: [
                FamilyMember(accountId: 1, snapshot: a, colorIndex: 0),
                FamilyMember(accountId: 2, snapshot: b, colorIndex: 1),
              ],
              child: FamilySwitch(
                child: Builder(
                  builder: (c) => Text(
                    'Seite von ${LiveData.of(c)!.firstName}'
                    ' ${FamilyMember.around(c)?.accountId}',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Seite von Anna 1'), findsOneWidget);
    expect(find.text('Ben'), findsOneWidget);
    await t.tap(find.text('Ben'));
    await t.pump();
    expect(find.text('Seite von Ben 2'), findsOneWidget);
    expect(t.takeException(), isNull);
    _disposeCheckers();
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('Ein Konto: keine Auswahl', (t) async {
    final a = _snap(1, 'Anna', 'Schule A');
    await t.pumpWidget(
      MaterialApp(
        home: FamilyData(
          members: [FamilyMember(accountId: 1, snapshot: a, colorIndex: 0)],
          child: const FamilySwitch(child: Text('Seite')),
        ),
      ),
    );
    expect(find.text('Seite'), findsOneWidget);
    expect(find.text('Anna'), findsNothing);
    _disposeCheckers();
    await t.pump(const Duration(seconds: 1));
  });

  test('Name: Vorname, sonst Schule', () {
    expect(kidLabel(_snap(1, 'Anna', 'Schule A')), 'Anna');
    expect(kidLabel(_snap(2, '', 'Schule B')), 'Schule B');
    _disposeCheckers();
  });

  testWidgets('geöffnete Seite wird nur einmal gebaut', (t) async {
    var builds = 0;
    late BuildContext ctx;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    pushInTab<void>(ctx, (_) {
      builds++;
      return const Text('Seite');
    });
    await t.pumpAndSettle();
    // Neuaufbau der Route (z. B. Theme-/Daten-Wechsel) baut nicht neu.
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Builder(builder: (c) => const SizedBox()),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Seite'), findsOneWidget);
    expect(builds, 1);
  });
}
