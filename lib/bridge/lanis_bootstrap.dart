import 'dart:async';
import 'dart:io';

import 'package:liblanis/liblanis.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod/misc.dart' show Override;

import '../core/native_adapter_instance.dart';
import '../fork/db_wal.dart';
import '../fork/error_log.dart';
import '../fork/parent_support.dart';
import '../utils/glitchtip.dart';
import 'flutter_secret_store.dart';
import 'package:lanis/fork_identity.dart';

/// Configures [LanisClient] for the Flutter host and returns Riverpod overrides.
///
/// Fork: [forApp] false für den Hintergrunddienst (background_service.dart).
/// Dann bleiben [bootstrapOverrides] und die statische Einstellung von
/// [LanisClient] so, wie die App sie gesetzt hat. Ursache (Prüfung 27.10.26):
/// Der Hintergrundlauf läuft bei geöffneter App im selben Prozess
/// (BackgroundFetch.configure, auch 10 s nach dem Start). Er überschrieb
/// beides mit der echten Einstellung; ein danach gebauter Familien-
/// Container (family.dart, _start) hätte in der Demo das echte Portal
/// gefragt. Grenze: Der Lauf selbst nutzt die echte Einstellung (eigene
/// Overrides) – nur sein onUnexpectedError ist während der Demo der der
/// Demo (keiner), weil liblanis ihn statisch liest (AppletParser).
Future<List<Override>> bootstrapLanisClient({
  FlutterSecretStore? secretStore,
  bool forApp = true,
}) async {
  final previous = forApp ? null : LanisClient.config;
  final persistentDir = await getApplicationSupportDirectory();
  final tempDir = await getTemporaryDirectory();
  final packageInfo = await PackageInfo.fromPlatform();
  final store = secretStore ?? FlutterSecretStore();
  // Fork: ohne migrateLanisDatabaseFromCache (database_storage_migration.dart
  // gelöscht). Ursache (Prüfung 27.10.26): Die Lanis-Migration (4de76d9a,
  // 25.08.26) holte lanis.db aus dem Cache-Ordner alter Lanis-Versionen. Der
  // Fork hat seit seinem ersten Stand (71259413, 14.10.26) die eigene
  // applicationId io.github.rwapps.sph – und damit eigene, leere Ordner –
  // und lag da schon auf dem Speicherort im Support-Ordner; keine Version
  // des Forks schrieb lanis.db in den Cache. Grenze: gilt für Fork-Builds;
  // ein Upstream-Build mit alter ID bräuchte die Migration wieder.
  final databasePath = p.join(persistentDir.path, 'lanis.db');
  // Fork: WAL-Modus, bevor liblanis die Datei öffnet (fork/db_wal.dart).
  enableWalJournal(databasePath);

  // Fork: lokales Fehlerprotokoll ohne Inhalte (fork/error_log.dart) und
  // Bereinigung des Dateispeichers (ersetzt den Knopf „Zwischenspeicher
  // leeren“, Entscheidung 17.10.26).
  ErrorLog.instance
    ..version = appVersionLabel(packageInfo.version, packageInfo.buildNumber)
    ..attach(File(p.join(persistentDir.path, 'fork_errors.json')));
  final documents = p.join(tempDir.path, 'lanis_documents');
  unawaited(Future(() => pruneOldFiles(Directory(documents))));

  final overrides = LanisClient.configure(
    databasePath: databasePath,
    secretStore: store,
    documentCacheDirectory: documents,
    httpAdapter: getNativeAdapterInstance(),
    userAgent: forkUserAgent(packageInfo.version, packageInfo.buildNumber),
    onUnexpectedError: (error, stackTrace, {required appletPhpUrl}) {
      unawaited(
        captureUnexpectedAppletError(
          error,
          stackTrace,
          appletPhpUrl: appletPhpUrl,
        ),
      );
    },
  );
  // Fork: Eltern-Freischaltungen (fork/parent_support.dart).
  final all = [...overrides, ...forkProviderOverrides(keepAlive: forApp)];
  if (forApp) {
    bootstrapOverrides = all;
  } else if (previous != null) {
    _restoreConfig(previous);
  }
  return all;
}

/// Statische Einstellung der App wiederherstellen (siehe [bootstrapLanisClient],
/// forApp). Die Overrides des Hintergrundlaufs tragen ihre eigene
/// Einstellung (lanisConfigProvider) und bleiben davon unberührt.
void _restoreConfig(LanisConfig c) {
  LanisClient.configure(
    databasePath: c.databasePath,
    secretStore: c.secretStore,
    documentCacheDirectory: c.documentCacheDirectory,
    httpAdapter: c.httpAdapter,
    userAgent: c.userAgent,
    storageEnabled: c.storageEnabled,
    storageMaxAge: c.storageMaxAge,
    storageMaxBytes: c.storageMaxBytes,
    onUnexpectedError: c.onUnexpectedError,
  );
}

/// Zuletzt erzeugte Overrides; die Familienansicht (fork/ui/live/family.dart)
/// baut damit je weiterem Konto einen eigenen ProviderContainer. Ursache:
/// liblanis kennt nur EIN aktives Konto je Container (activeAccountProvider,
/// sessionProvider); zwei Schulen gleichzeitig brauchen zwei Container.
List<Override> bootstrapOverrides = const [];
