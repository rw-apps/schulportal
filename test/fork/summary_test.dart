import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/notify/summary.dart';
import 'package:lanis/fork/ui/today/today_model.dart';
import 'package:liblanis/liblanis.dart' show TypedSettings;

/// Sammel-Benachrichtigung „Das Wichtigste“ (summary.dart) – Daten.
final de = forkL10nFor('de');

TypedSettings mem() {
  final m = <String, String?>{};
  return TypedSettings(
    read: (k) => m[k],
    write: (k, v) => m[k] = v,
    delete: m.remove,
  );
}

void main() {
  final now = DateTime(2026, 10, 27, 10);
  final next = DateTime(2026, 10, 28);

  test('Änderungen: heute nur Offenes, morgen alles, kein Raumwechsel', () {
    final items = changeSummaryItems(
      scope: '1',
      name: 'Jonas',
      now: now,
      next: next,
      t: de,
      endOf: {'1.': 8 * 60 + 45, '5.': 12 * 60 + 30},
      changes: [
        ChangeItem(
          day: DateTime(2026, 10, 27),
          slot: '1.',
          subject: 'Deutsch',
          kind: ChangeKind.cancelled,
        ),
        ChangeItem(
          day: DateTime(2026, 10, 27),
          slot: '5.',
          subject: 'Sport',
          kind: ChangeKind.cancelled,
        ),
        ChangeItem(
          day: next,
          slot: '3.',
          subject: 'Musik',
          kind: ChangeKind.substitution,
          detail: 'Herr X',
        ),
        ChangeItem(
          day: next,
          slot: '4.',
          subject: 'Ethik',
          kind: ChangeKind.roomChange,
          detail: 'R2',
        ),
        ChangeItem(
          day: DateTime(2026, 10, 29),
          slot: '1.',
          subject: 'Mathe',
          kind: ChangeKind.cancelled,
        ),
      ],
    );
    expect(items.length, 2);
    expect(items[0].line, startsWith('Jonas: Heute 5. Sport – '));
    expect(items[0].kind, SummaryKind.cancelled);
    expect(items[1].line, contains('Morgen 3. Musik'));
    expect(items[1].kind, SummaryKind.substitution);
  });

  test('Quellen: ersetzen, sortieren, doppelt einmal, Konten bereinigen', () {
    final s = mem();
    putSummaryItems(
      s,
      '1/meals',
      mealSummaryItems(
        name: 'Mika',
        owner: '1:',
        days: [next],
        now: now,
        t: de,
      ),
    );
    putSummaryItems(
      s,
      '1/messages',
      messageSummaryItems(
        name: 'Lena',
        unread: [(id: 'a', from: 'Frau Sommer', subject: 'Ausflug')],
        t: de,
      ),
    );
    putSummaryItems(
      s,
      '2/plan',
      changeSummaryItems(
        scope: '2',
        name: 'Jonas',
        now: now,
        next: next,
        t: de,
        changes: [
          ChangeItem(
            day: next,
            slot: '1.',
            subject: 'Deutsch',
            kind: ChangeKind.cancelled,
          ),
        ],
      ),
    );
    var all = allSummaryItems(s);
    expect(
      [for (final i in all) i.kind],
      [SummaryKind.cancelled, SummaryKind.message, SummaryKind.meal],
    );
    expect(all[1].line, 'Lena: Nachricht von Frau Sommer: Ausflug');
    expect(all[2].line, 'Mika: Morgen: Essen noch nicht bestellt');
    // Gelesen: Quelle leer → Zeile weg.
    putSummaryItems(s, '1/messages', const []);
    expect(allSummaryItems(s).length, 2);
    // Konto 2 gelöscht.
    pruneSummarySources(s, {'1'});
    expect(allSummaryItems(s).single.kind, SummaryKind.meal);
  });
}
