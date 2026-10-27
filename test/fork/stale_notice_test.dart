import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/live/live_data.dart';
import 'package:lanis/fork/ui/live/stale_notice.dart';
import 'package:lanis/fork/ui/today/hint_card.dart';

/// Hinweis „Portal nicht erreichbar“ (stale_notice.dart) – synthetisch.
void main() {
  final now = DateTime(2026, 10, 21, 7, 30);

  Future<Widget?> build(WidgetTester t, List<Feed<Object?>> feeds) async {
    Widget? out;
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Builder(
          builder: (c) {
            out = staleNotice(c, feeds: feeds, now: now, onRetry: () {});
            return Scaffold(body: out ?? const SizedBox());
          },
        ),
      ),
    );
    return out;
  }

  testWidgets('kein Hinweis bei frischem Stand oder ohne Inhalt', (t) async {
    expect(
      await build(t, [Feed(content: 1, fetchedAt: DateTime(2026, 10, 21, 7))]),
      isNull,
    );
    expect(await build(t, [const Feed<int>(error: 'x')]), isNull);
  });

  testWidgets('ältester betroffener Stand mit Tag', (t) async {
    final w = await build(t, [
      Feed(
        content: 1,
        offline: true,
        fetchedAt: DateTime(2026, 10, 20, 21, 40),
      ),
      Feed(content: 2, error: 'x', fetchedAt: DateTime(2026, 10, 21, 6, 50)),
      Feed(content: 3, fetchedAt: DateTime(2026, 10, 19, 8)),
    ]);
    expect(w, isA<HintCard>());
    expect(find.text('Portal nicht erreichbar'), findsOneWidget);
    expect(find.text('Gespeicherter Stand von gestern 21:40'), findsOneWidget);
  });

  testWidgets('Vertretungsplan nie geladen: eigener Hinweis', (t) async {
    Widget? out;
    Future<void> pump(List<Feed<Object?>> f) => t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Builder(
          builder: (c) {
            out = substitutionsMissingNotice(
              c,
              substitutions: f,
              onRetry: () {},
            );
            return Scaffold(body: out ?? const SizedBox());
          },
        ),
      ),
    );
    await pump([const Feed<int>(error: 'x')]);
    expect(out, isA<HintCard>());
    expect(
      find.text('Der Vertretungsplan ließ sich nicht laden'),
      findsOneWidget,
    );
    // Gespeicherter Stand oder noch am Laden: kein solcher Hinweis.
    await pump([Feed(content: 1, error: 'x', fetchedAt: now)]);
    expect(out, isNull);
    await pump([const Feed<int>(error: 'x', loading: true)]);
    expect(out, isNull);
  });
}
