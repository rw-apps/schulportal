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

  testWidgets('im Rahmen geöffnete Seite sieht den neuen Stand', (t) async {
    // Ursache (Rückmeldung 20.10.26): Archiv blieb nach „Wieder offen“
    // beim Stand vom Öffnen.
    final a = _snap(1, 'Anna', 'Schule A');
    final b1 = _snap(2, 'Ben', 'Schule B');
    final b2 = _snap(2, 'Bernd', 'Schule B');
    late BuildContext ctx;
    Widget app(LiveSnapshot b) => MaterialApp(
      home: LiveData(
        snapshot: a,
        child: FamilyData(
          members: [
            FamilyMember(accountId: 1, snapshot: a, colorIndex: 0),
            FamilyMember(accountId: 2, snapshot: b, colorIndex: 1),
          ],
          // Wie in der App: Navigator des Reiters unter FamilyData
          // (preview_shell.dart, FamilyScope über _TabNavigator).
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await t.pumpWidget(app(b1));
    final member = FamilyData.of(ctx).last;
    Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (_) => member.scope(
          Builder(builder: (c) => Text('Stand ${LiveData.of(c)!.firstName}')),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Stand Ben'), findsOneWidget);
    await t.pumpWidget(app(b2));
    await t.pumpAndSettle();
    expect(find.text('Stand Bernd'), findsOneWidget);
  });

  testWidgets('Kindwahl samt „Alle“ gilt für alle Bereiche', (t) async {
    // Ursache (Rückmeldung 20.10.26): „Alle“ merkte sich jeder Reiter
    // selbst; beim Wechsel sprang die Wahl.
    final a = _snap(1, 'Anna', 'Schule A');
    final b = _snap(2, 'Ben', 'Schule B');
    int? selected;
    var all = true;
    late StateSetter set;
    Widget area(String name) => FamilySwitch(
      all: (_, _) => Text('$name: alle'),
      child: Builder(
        builder: (c) => Text('$name: ${LiveData.of(c)!.firstName}'),
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: StatefulBuilder(
          builder: (c, s) {
            set = s;
            return Scaffold(
              body: LiveData(
                snapshot: a,
                child: FamilyData(
                  members: [
                    FamilyMember(accountId: 1, snapshot: a, colorIndex: 0),
                    FamilyMember(accountId: 2, snapshot: b, colorIndex: 1),
                  ],
                  selectedAccount: selected,
                  onSelect: (id) => set(() {
                    selected = id;
                    all = false;
                  }),
                  showAll: all,
                  onSelectAll: () => set(() => all = true),
                  // Zwei Bereiche nebeneinander wie zwei Reiter.
                  child: Row(
                    children: [
                      Expanded(child: area('Heute')),
                      Expanded(child: area('Unterricht')),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    expect(find.text('Heute: alle'), findsOneWidget);
    expect(find.text('Unterricht: alle'), findsOneWidget);
    await t.tap(find.text('Ben').first);
    await t.pumpAndSettle();
    expect(find.text('Heute: Ben'), findsOneWidget);
    expect(find.text('Unterricht: Ben'), findsOneWidget);
    await t.tap(find.text('Alle').last);
    await t.pumpAndSettle();
    expect(find.text('Heute: alle'), findsOneWidget);
    expect(find.text('Unterricht: alle'), findsOneWidget);
  });
}
