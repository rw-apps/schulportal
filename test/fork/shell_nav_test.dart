import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/courses/course_detail_page.dart';
import 'package:lanis/fork/ui/preview/preview_shell.dart';

Widget _app() => MaterialApp(
  localizationsDelegates: ForkL10n.localizationsDelegates,
  supportedLocales: ForkL10n.supportedLocales,
  locale: const Locale('de'),
  home: const PreviewShell(),
);

Finder _nav(String label) => find.descendant(
  of: find.byType(FloatingNavBar),
  matching: find.text(label),
);

void main() {
  testWidgets('Leiste bleibt auf der Kursseite, Reiter merken ihren Verlauf', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2424);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app());
    await t.tap(_nav('Unterricht'));
    await t.pumpAndSettle();
    await t.tap(find.text('Mathematik').first);
    await t.pumpAndSettle();
    expect(find.byType(CourseDetailPage), findsOneWidget);
    expect(find.byType(FloatingNavBar), findsOneWidget);

    // Anderer Reiter und zurück: Kursseite ist noch offen.
    await t.tap(_nav('Heute'));
    await t.pumpAndSettle();
    expect(find.byType(CourseDetailPage), findsNothing);
    await t.tap(_nav('Unterricht'));
    await t.pumpAndSettle();
    expect(find.byType(CourseDetailPage), findsOneWidget);

    // Erneut antippen: an den Anfang des Reiters.
    await t.tap(_nav('Unterricht'));
    await t.pumpAndSettle();
    expect(find.byType(CourseDetailPage), findsNothing);

    // Android-Zurück: erst im Reiter, dann nach „Heute“.
    await t.tap(find.text('Mathematik').first);
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(CourseDetailPage), findsNothing);
    expect(find.text('Mathematik'), findsWidgets);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(FloatingNavBar), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
