import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/device_transfer.dart';

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
}
