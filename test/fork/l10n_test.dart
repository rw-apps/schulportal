import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/today/today_page.dart';

/// Sprachdateien der neuen Oberfläche (lib/fork/l10n/fork_*.arb).
Map<String, dynamic> _arb(String l) =>
    jsonDecode(File('lib/fork/l10n/fork_$l.arb').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _placeholders(String s) => RegExp(
  r'(?<![\w=])\{(\w+)(?=[},])',
).allMatches(s).map((m) => m[1]!).toSet();

void main() {
  test('alle Sprachen haben dieselben Schlüssel und Platzhalter', () {
    final de = _arb('de');
    final keys = de.keys.where((k) => !k.startsWith('@')).toSet();
    for (final l in ['en', 'tr']) {
      final x = _arb(l);
      expect(
        x.keys.where((k) => !k.startsWith('@')).toSet(),
        keys,
        reason: 'Schlüssel in fork_$l.arb',
      );
      for (final k in keys) {
        expect(
          _placeholders(x[k] as String),
          _placeholders(de[k] as String),
          reason: '$k in fork_$l.arb',
        );
      }
    }
  });

  test('Sprachwahl: Einstellung vor Handy, sonst Englisch', () {
    expect(resolveLanguage('tr', 'de'), 'tr');
    expect(resolveLanguage('system', 'de'), 'de');
    expect(resolveLanguage(null, 'tr'), 'tr');
    expect(resolveLanguage('system', 'fr'), 'en');
  });

  test('Datum und Großschreibung je Sprache', () {
    final now = DateTime(2026, 10, 20, 10, 50);
    expect(dateCaps(forkL10nFor('de'), now), 'DIENSTAG, 20. OKTOBER');
    expect(dateCaps(forkL10nFor('en'), now), 'TUESDAY, OCTOBER 20');
    // Türkisch: i → İ („EKİM“), nicht „EKIM“.
    expect(dateCaps(forkL10nFor('tr'), now), '20 EKİM SALI');
    final tr = forkL10nFor('tr');
    expect(relativeDay(tr, DateTime(2026, 10, 21), now), 'Yarın');
    expect(greetingFor(forkL10nFor('en'), now), 'Good morning');
    expect(tr.homeworkCount(3), '3 ödev');
    expect(forkL10nFor('de').homeworkCount(1), '1 Hausaufgabe');
    expect(forkL10nFor('en').unreadCount(2), '2 messages');
  });
}
