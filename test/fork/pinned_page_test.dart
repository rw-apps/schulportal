import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/kit.dart';
import 'package:lanis/fork/ui/pinned_page.dart';

/// Feststehender Kopf (pinned_page.dart): Überschrift bleibt beim Scrollen
/// stehen, die Trennlinie erscheint erst, wenn Inhalt darunter liegt.
void main() {
  Widget page({List<Widget>? slivers}) => MaterialApp(
    home: Scaffold(
      body: PinnedPage(
        header: const [Text('Überschrift')],
        slivers: slivers,
        children: [
          for (var i = 0; i < 60; i++)
            SizedBox(height: 40, child: Text('Zeile $i')),
        ],
      ),
    ),
  );

  Color? line(WidgetTester t) => t
      .widget<ColoredBox>(
        find
            .ancestor(
              of: find.byWidgetPredicate((w) => w is SizedBox && w.height == 1),
              matching: find.byType(ColoredBox),
            )
            .first,
      )
      .color;

  testWidgets('Liste: Kopf steht, Linie erst nach dem Scrollen', (t) async {
    await t.pumpWidget(page());
    final head = t.getRect(find.text('Überschrift'));
    expect(line(t), Colors.transparent);
    await t.drag(find.byType(ListView), const Offset(0, -500));
    await t.pumpAndSettle();
    expect(t.getRect(find.text('Überschrift')), head);
    expect(find.text('Zeile 0'), findsNothing);
    expect(line(t), KitPalette.light.line);
  });

  testWidgets('Slivers: Kopf steht', (t) async {
    await t.pumpWidget(
      page(
        slivers: [
          SliverList.builder(
            itemCount: 60,
            itemBuilder: (_, i) => SizedBox(height: 40, child: Text('S $i')),
          ),
        ],
      ),
    );
    final head = t.getRect(find.text('Überschrift'));
    await t.drag(find.byType(CustomScrollView), const Offset(0, -800));
    await t.pumpAndSettle();
    expect(t.getRect(find.text('Überschrift')), head);
    expect(find.text('S 0'), findsNothing);
  });
}
