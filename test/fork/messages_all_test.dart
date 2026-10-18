import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/live/family.dart';
import 'package:lanis/fork/ui/live/live_data.dart';
import 'package:lanis/fork/ui/messages/live_messages_page.dart';
import 'package:liblanis/liblanis.dart';

// Erfundene Konten und Nachrichten.
final _checkers = <ConnectionChecker>[];

OverviewEntry _m(String id, String title, String date, {bool unread = false}) =>
    OverviewEntry(
      id: id,
      title: title,
      shortName: 'AB',
      fullName: 'Alt, Anna',
      date: date,
      unread: unread,
      hidden: false,
    );

LiveSnapshot _snap(int id, String first, List<OverviewEntry> msgs) {
  final c = ConnectionChecker();
  _checkers.add(c);
  final session = LanisSession(
    account: ClearTextAccount(
      localId: id,
      schoolID: 1000 + id,
      username: 'u$id',
      password: '',
      schoolName: 'Schule $id',
      accountType: AccountType.parent,
    ),
    config: const LanisConfig(),
    connectionChecker: c,
  )..userData = {'vorname': first};
  return LiveSnapshot(
    session: session,
    supported: const {'nachrichten.php'},
    timetable: const Feed(),
    lessons: const Feed(),
    substitutions: const Feed(),
    calendar: const Feed(),
    conversations: Feed(content: msgs),
    userChoice: const {},
    ownNames: const {},
    setUserChoice: (_) {},
    setOwnNames: (_) {},
    refresh: () async {},
    refreshMessages: () async {},
    setMensaUrl: (_, _) {},
  );
}

void main() {
  tearDown(() {
    for (final c in _checkers) {
      c.dispose();
    }
    _checkers.clear();
  });

  test('Datum des Portals → Reihenfolge', () {
    final now = DateTime(2026, 10, 18, 10);
    expect(
      messageTimeOf('14.10.2026 13:27', now),
      DateTime(2026, 10, 14, 13, 27),
    );
    expect(messageTimeOf('heute 08:12', now), DateTime(2026, 10, 18, 8, 12));
    expect(messageTimeOf('gestern 17:40', now), DateTime(2026, 10, 17, 17, 40));
    expect(messageTimeOf('???', now), DateTime(1970));
  });

  testWidgets('Alle Kinder: eine Liste, neueste zuerst, mit Namen', (t) async {
    t.view.physicalSize = const Size(1080, 2424);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    final a = _snap(1, 'Anna', [
      _m('1', 'Elternabend', '08.10.2026 11:48'),
      _m('2', 'Ausflug', '15.09.2026 12:51'),
    ]);
    final b = _snap(2, 'Ben', [
      _m('3', 'Noten Mathearbeit', '14.10.2026 13:27', unread: true),
    ]);
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
                all: (_, members) => LiveAllMessagesPage(members: members),
                child: const Text('Seite eines Kindes'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Alle'), findsOneWidget);
    final titles = ['Noten Mathearbeit', 'Elternabend', 'Ausflug'];
    final ys = [for (final x in titles) t.getTopLeft(find.text(x)).dy];
    expect(ys[0] < ys[1] && ys[1] < ys[2], isTrue);
    // Name je Nachricht (ohne Vornamen im Test: die Schule) plus Pille oben.
    expect(find.text('Schule 1'), findsNWidgets(3));
    expect(find.text('Schule 2'), findsNWidgets(2));
    expect(find.text('1 ungelesen'), findsOneWidget);
    // Ein Kind gewählt: dessen Seite.
    await t.tap(find.text('Schule 2').first);
    await t.pumpAndSettle();
    expect(find.text('Seite eines Kindes'), findsOneWidget);
    await t.tap(find.text('Alle'));
    await t.pumpAndSettle();
    expect(find.text('Ausflug'), findsOneWidget);
  });
}
