import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/fork/anon/anon_export.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/settings/anon_export_page.dart';

import '../helpers/test_app.dart';

void main() {
  tearDown(LanisClient.reset);

  testWidgets('vor dem Export: Erklärung und Knopf', (tester) async {
    await pumpTestApp(tester, child: const AnonExportPage());
    final t = tester.element(find.byType(AnonExportPage)).t;
    expect(find.text(t.anonExportIntro), findsOneWidget);
    expect(find.text(t.anonExportRun), findsOneWidget);
    expect(find.text(t.shareReport), findsNothing);
  });

  testWidgets('nach dem Export: stehen gebliebene Wörter, Vorschau, Teilen', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      child: const AnonExportPage(
        initialResult: AnonExport(
          text: 'Kopf\n=== timetable ===\n<td>Xqzt</td>',
          kept: ['stunde', 'vertreter'],
        ),
      ),
    );
    final t = tester.element(find.byType(AnonExportPage)).t;
    expect(find.text('stunde, vertreter'), findsOneWidget);
    expect(find.text(t.anonExportKeptHint), findsOneWidget);
    expect(find.text(t.shareReport), findsOneWidget);
    expect(find.text(t.anonExportRun), findsNothing);
  });
}
