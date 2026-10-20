import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/device_transfer.dart';
import 'package:liblanis/liblanis.dart' show AccountType;

void main() {
  const account = TransferAccount(
    schoolId: 1234,
    schoolName: 'Muster-Gymnasium',
    username: 'vorname.nachname',
    password: 'geheim-123',
  );

  test('zwei Schritte: nur das neue Gerät kann lesen', () async {
    final receiver = await newTransferKey();
    final offer = await offerCode(receiver);
    final pub = parseOffer(offer)!;
    final codes = await sealPayload(
      buildDevicePayload(
        [account],
        {
          '1234:vorname.nachname': {'fork/class': '"x"'},
        },
      ),
      pub,
    );
    // Der Daten-Code enthält das Passwort nicht lesbar.
    expect(codes.join(), isNot(contains('geheim')));
    final c = ChunkCollector();
    for (final code in codes.reversed) {
      c.add(code);
    }
    expect(c.complete, isTrue);
    final p = parseDevicePayload((await openPayload(c.blob, receiver))!)!;
    expect(p.accounts.single.password, 'geheim-123');
    expect(p.settings['1234:vorname.nachname']!['fork/class'], '"x"');

    // Ein anderes Gerät (fremder Schlüssel) kann nichts damit anfangen.
    final other = await newTransferKey();
    expect(await openPayload(c.blob, other), isNull);
  });

  test('viele Daten: mehrere Codes, doppelte und fremde ignoriert', () async {
    final receiver = await newTransferKey();
    final pub = parseOffer(await offerCode(receiver))!;
    final r = Random(1);
    final big = {
      for (var i = 0; i < 40; i++)
        'k$i': {
          'v': String.fromCharCodes([
            for (var j = 0; j < 60; j++) 65 + r.nextInt(26),
          ]),
        },
    };
    final codes = await sealPayload(buildDevicePayload([account], big), pub);
    expect(codes.length, greaterThan(1));
    final c = ChunkCollector();
    expect(c.add('kein code'), isFalse);
    expect(c.add(codes.first), isTrue);
    expect(c.add(codes.first), isFalse);
    expect(c.complete, isFalse);
    for (final code in codes.skip(1)) {
      c.add(code);
    }
    expect(await openPayload(c.blob, receiver), isNotNull);
  });

  test('Prüfcode gleich für gleichen Schlüssel, Angebot geprüft', () async {
    final k = await newTransferKey();
    final pub = (await k.extractPublicKey()).bytes;
    expect(await checkCode(pub), await checkCode(pub));
    expect(await checkCode(pub), matches(RegExp(r'^\d{3} \d{3}$')));
    expect(parseOffer('SPT1K:kurz'), isNull);
    expect(parseOffer('https://example.org'), isNull);
  });

  test('Kontoart reist mit, leeres Passwort wird verworfen', () {
    const parent = TransferAccount(
      schoolId: 1234,
      schoolName: 'Muster-Gymnasium',
      username: 'eltern.muster',
      password: 'geheim',
      accountType: AccountType.parent,
    );
    final back = parseDevicePayload(buildDevicePayload([parent, account], {}))!;
    expect(back.accounts.first.accountType, AccountType.parent);
    // Ohne Angabe (älterer Sender): unbekannt, nicht „Schüler“.
    expect(back.accounts.last.accountType, isNull);
    expect(
      TransferAccount.fromJson({'i': 1, 'n': '', 'u': 'x', 'p': ''}),
      isNull,
    );
  });

  test(
    'nach misslungenem Öffnen lassen sich dieselben Codes neu lesen',
    () async {
      final receiver = await newTransferKey();
      final codes = await sealPayload(
        buildDevicePayload([account], {}),
        parseOffer(await offerCode(receiver))!,
      );
      final c = ChunkCollector();
      for (final code in codes) {
        c.add(code);
      }
      expect(c.add(codes.first), isFalse); // schon gelesen
      c.reset();
      expect(c.complete, isFalse);
      expect(c.add(codes.first), isTrue);
    },
  );

  test('zu viele Daten: Fehler statt still gekürzt', () async {
    final receiver = await newTransferKey();
    final rnd = Random(1);
    final big = String.fromCharCodes([
      for (var i = 0; i < 120000; i++) 33 + rnd.nextInt(90),
    ]);
    final pub = parseOffer(await offerCode(receiver))!;
    await expectLater(
      sealPayload(
        buildDevicePayload(
          [account],
          {
            'x': {'y': big},
          },
        ),
        pub,
      ),
      throwsStateError,
    );
  });
}
