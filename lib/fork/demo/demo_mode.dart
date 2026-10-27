import 'dart:io';

import 'package:liblanis/liblanis.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod/misc.dart' show Override;

import 'package:lanis/bridge/lanis_bootstrap.dart' show bootstrapOverrides;
import 'package:lanis/utils/privacy_policy.dart';

import '../error_log.dart';
import '../mensa_store.dart';
import '../ui/live/live_data.dart' show mensaUrlSetting;
import 'demo_meals.dart';
import '../parent_support.dart';
import 'demo_portal.dart';
import 'demo_school.dart';

/// Demo-Modus: die ganze App mit einer erfundenen Schule (demo_portal.dart).
///
/// Ursache (Entscheidung 26.10.26): Wer die App weitergibt oder Änderungen
/// prüft, soll sie ohne echtes Konto zeigen können – auch einer Lehrkraft,
/// bevor sie Zugangsdaten eingibt.
///
/// Abgrenzung zu den echten Konten (bewusst streng):
/// - eigene Datenbank im Zwischenspeicher, bei jedem Start neu; die echte
///   Datenbank wird nicht geöffnet, Konten mischen sich nie;
/// - Passwörter nur im Speicher (MemorySecretStore);
/// - der Netzadapter ist [DemoPortal] – keine Anfrage verlässt das Gerät;
/// - das Fehlerprotokoll schweigt ([ErrorLog.muted]), damit erfundene
///   Fehler nicht gemeldet werden.
///
/// Grenze: Der Hintergrunddienst (Benachrichtigungen) läuft weiter für die
/// echten Konten – er liest deren Datenbank, nicht die der Demo. Die Demo
/// gilt bis zum Beenden oder bis die App geschlossen wird; danach startet
/// sie wieder normal.
enum DemoChoice { parent, student }

/// Läuft gerade die Demo? Gesetzt von [bootstrapDemoClient].
bool demoActive = false;

/// Startet die App neu – mit Demo oder wieder normal (main.dart setzt es).
Future<void> Function({DemoChoice? demo})? restartApp;

/// Konten der Demo: Eltern = Elternkonto (Jonas) + Schülerkonto (Lena),
/// wie eine Familie mit einem älteren Kind mit eigenem Zugang; Schüler =
/// nur Lena.
List<DemoUser> demoUsersFor(DemoChoice c) => switch (c) {
  DemoChoice.parent => const [demoParent, demoStudent],
  DemoChoice.student => const [demoStudent],
};

/// Wie bootstrapLanisClient, aber mit Demo-Portal und eigener Datenbank.
///
/// [baseDir] nur für Tests (sonst der Zwischenspeicher der App).
Future<List<Override>> bootstrapDemoClient(
  DemoChoice choice, {
  Directory? baseDir,
  DateTime Function()? now,
}) async {
  final temp = baseDir ?? await getTemporaryDirectory();
  final dir = Directory(p.join(temp.path, 'demo'));
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  final path = p.join(dir.path, 'demo.sqlite');
  final store = MemorySecretStore();

  final db = LanisDatabase.open(path: path, secretStore: store);
  try {
    await prepareDemoDatabase(db, choice);
  } finally {
    db.dispose();
  }

  demoActive = true;
  MealCache.instance.demo = (_) => demoMealEntry(DateTime.now());
  ErrorLog.instance.muted = true;
  final overrides = LanisClient.configure(
    databasePath: path,
    secretStore: store,
    documentCacheDirectory: p.join(dir.path, 'documents'),
    httpAdapter: DemoPortal(now: now),
    userAgent: 'schulportal-demo',
  );
  final all = [...overrides, ...forkProviderOverrides()];
  // Die Familienansicht baut je Konto einen Container damit (family.dart).
  bootstrapOverrides = all;
  return all;
}

/// Konten anlegen und den Datenschutzhinweis als gelesen markieren (die
/// Demo sendet nichts).
Future<void> prepareDemoDatabase(LanisDatabase db, DemoChoice choice) async {
  final shared = TypedSettings.shared(db);
  acceptPrivacyPolicy(shared);
  for (final u in demoUsersFor(choice)) {
    final id = await db.addAccount(
      schoolId: demoSchoolId,
      schoolName: demoSchoolName,
      username: u.username,
      password: 'demo',
      accountType: u.role == DemoRole.parent
          ? AccountType.parent
          : AccountType.student,
    );
    // Erfundener Caterer (demo_meals.dart): Adresse, damit „Essen“ und die
    // Zeilen auf Heute erscheinen.
    TypedSettings.account(
      db,
      id,
    ).setString('fork/$mensaUrlSetting', demoMensaUrl);
  }
}

/// Demo verlassen: Merker zurück, Protokoll wieder an.
void leaveDemo() {
  demoActive = false;
  MealCache.instance.demo = null;
  ErrorLog.instance.muted = false;
}
