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
    expect(items[0].line(de, now), startsWith('Jonas · Heute: 5. Sport – '));
    expect(items[0].kind, SummaryKind.cancelled);
    expect(items[1].line(de, now), contains('Morgen: 3. Musik'));
    // Nach Mitternacht heißt derselbe Eintrag „Heute“.
    expect(
      items[1].line(de, DateTime(2026, 10, 28, 6)),
      contains('Heute: 3. Musik'),
    );
    // Schlüssel ohne Fachnamen (Kürzel im Hintergrund, Name in der App).
    final again = changeSummaryItems(
      scope: '1',
      name: '',
      now: now,
      next: next,
      t: de,
      changes: [
        ChangeItem(
          day: next,
          slot: '3.',
          subject: 'MU',
          kind: ChangeKind.substitution,
        ),
      ],
    );
    expect(again.single.key, items[1].key);
  });

  test('Quellen: ersetzen, sortieren, vergangene Tage, Konten/Themen', () {
    final s = mem();
    putSummaryItems(
      s,
      '1/meals',
      mealSummaryItems(name: 'Mika', owner: '1:', days: [next], t: de),
    );
    putSummaryItems(
      s,
      '1/messages',
      messageSummaryItems(
        scope: '1',
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
    putSummaryItems(
      s,
      '2/messages',
      messageSummaryItems(
        scope: '2',
        name: 'Jonas',
        unread: [(id: 'a', from: 'Frau Sommer', subject: 'Ausflug')],
        t: de,
      ),
    );
    var all = allSummaryItems(s, now);
    expect(
      [for (final i in all) i.kind],
      [
        SummaryKind.cancelled,
        SummaryKind.message,
        SummaryKind.message,
        SummaryKind.meal,
      ],
      reason: 'gleiche Rundnachricht an zwei Konten = zwei Zeilen',
    );
    expect(all[1].line(de, now), 'Lena: Nachricht von Frau Sommer: Ausflug');
    expect(all[3].line(de, now), 'Mika · Morgen: Essen noch nicht bestellt');
    // Am Tag danach sind Plan und Essen vergangen.
    expect(allSummaryItems(s, DateTime(2026, 10, 29, 7)).length, 2);
    // Konto 2 ohne Nachrichten-Benachrichtigung, Konto 1 ganz erlaubt.
    pruneSummarySources(s, {
      '1': {'plan', 'messages', 'meals'},
      '2': {'plan', 'meals'},
    });
    all = allSummaryItems(s, now);
    expect(all.where((i) => i.kind == SummaryKind.message).length, 1);
    // Konto 2 gelöscht.
    pruneSummarySources(s, {
      '1': {'plan', 'messages', 'meals'},
    });
    expect(allSummaryItems(s, now).length, 2);
  });

  test('Erlaubt-Liste lesen und schreiben', () {
    final s = mem();
    writeSummaryAllowed(s, {
      '3': {'plan', 'meals'},
    });
    expect(readSummaryAllowed(s), {
      '3': {'plan', 'meals'},
    });
  });
}
