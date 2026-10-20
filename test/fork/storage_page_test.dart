import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/data_storage.dart';
import 'package:lanis/fork/ui/storage/storage_page.dart';
import 'package:liblanis/liblanis.dart';

import '../helpers/test_app.dart';

void main() {
  tearDown(LanisClient.reset);

  testWidgets('neue Dateien und Ordner, Antippen ruft zurück', (t) async {
    StorageFile? opened;
    StorageFolder? folder;
    await pumpTestApp(
      t,
      locale: const Locale('de'),
      child: StoragePage(
        title: 'Dateien',
        load: () async => const StorageView(
          newFiles: [StorageFile(id: 1, name: 'Brief.pdf')],
          folders: [StorageFolder(id: 6, name: 'Formulare', files: 2)],
        ),
        onOpenFile: (f) => opened = f,
        onOpenFolder: (f) => folder = f,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Brief.pdf'), findsOneWidget);
    expect(find.text('2 Dateien'), findsOneWidget);
    await t.tap(find.text('Brief.pdf'));
    await t.tap(find.text('Formulare'));
    expect(opened?.id, 1);
    expect(folder?.id, 6);
  });

  testWidgets('Fehler: Hinweis und erneut versuchen', (t) async {
    var calls = 0;
    await pumpTestApp(
      t,
      locale: const Locale('de'),
      child: StoragePage(
        title: 'Dateien',
        load: () async {
          calls++;
          if (calls == 1) throw NoConnectionException();
          return const StorageView();
        },
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Die Dateien ließen sich nicht laden.'), findsOneWidget);
    await t.tap(find.text('Erneut versuchen'));
    await t.pumpAndSettle();
    expect(find.text('Hier liegen gerade keine Dateien.'), findsOneWidget);
  });
}
