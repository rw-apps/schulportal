import 'package:flutter/material.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/font_step.dart';
import 'package:lanis/fork/ui/kit.dart';
import 'package:lanis/fork/ui/settings/settings_page.dart';
import 'package:liblanis/liblanis.dart';

void main() {
  for (final scale in [1.0, 1.4 * 1.3]) {
    testWidgets('Einstellungen ohne Überlauf ×$scale, ohne Lanis-Ballast', (
      t,
    ) async {
      t.view.physicalSize = const Size(1080, 2424);
      t.view.devicePixelRatio = 2.625;
      addTearDown(t.view.reset);
      final db = LanisDatabase.open();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            lanisDatabaseProvider.overrideWithValue(db),
            supportedAppletPhpUrlsProvider.overrideWithValue(const {
              'vertretungsplan.php',
              'nachrichten.php',
              'kalender.php',
            }),
            storageManagerProvider.overrideWithValue(null),
          ],
          child: MaterialApp(
            localizationsDelegates: ForkL10n.localizationsDelegates,
            supportedLocales: ForkL10n.supportedLocales,
            locale: const Locale('de'),

            builder: (c, w) => MediaQuery(
              data: MediaQuery.of(
                c,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: w!,
            ),
            home: const ForkSettingsPage(),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      // Seite schrittweise durchscrollen und alle Texte einsammeln.
      final seen = <String>{};
      for (var i = 0; i < 25; i++) {
        for (final e in find.byType(Text).evaluate()) {
          final d = (e.widget as Text).data;
          if (d != null) seen.add(d);
        }
        await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
      for (final s in [
        'Konto',
        'Benachrichtigungen',
        'Darstellung',
        'Daten',
        'Über die App',
        'Fehlersuche',
      ]) {
        expect(seen, contains(s));
      }
      final all = seen.join(' ');
      for (final gone in [
        'Moodle',
        'AMOLED',
        'Farbschema',
        'Stundenplan anpassen',
      ]) {
        expect(all, isNot(contains(gone)));
      }
      // Schriftgröße wirkt über den Provider (für alle Seiten). Auslösen
      // direkt über onTap: Die Trefferprüfung von tap() lag im Test neben
      // dem Eintrag (Rand der Liste), die Bedienung selbst ist dieselbe.
      await t.drag(find.byType(Scrollable).first, const Offset(0, 20000));
      await t.pumpAndSettle();
      final large = find.text('Groß');
      for (var i = 0; i < 40 && large.evaluate().isEmpty; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -150));
        await t.pumpAndSettle();
      }
      t
          .widget<InkWell>(
            find.ancestor(of: large, matching: find.byType(InkWell)).first,
          )
          .onTap!();
      await t.pumpAndSettle();
      final c = ProviderScope.containerOf(
        t.element(find.byType(ForkSettingsPage)),
      );
      expect(c.read(fontStepProvider), KitFontStep.large);
      expect(db.getSharedSetting(fontStepKey), contains('large'));
      expect(t.takeException(), isNull);
    });
  }
}
