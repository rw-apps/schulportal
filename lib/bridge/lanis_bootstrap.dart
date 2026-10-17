import 'dart:async';
import 'dart:io';

import 'package:liblanis/liblanis.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod/misc.dart' show Override;

import '../core/native_adapter_instance.dart';
import '../fork/error_log.dart';
import '../fork/parent_support.dart';
import '../utils/glitchtip.dart';
import 'database_storage_migration.dart';
import 'flutter_secret_store.dart';
import 'package:lanis/fork_identity.dart';

/// Configures [LanisClient] for the Flutter host and returns Riverpod overrides.
Future<List<Override>> bootstrapLanisClient({
  FlutterSecretStore? secretStore,
}) async {
  final cacheDir = await getApplicationCacheDirectory();
  final persistentDir = await getApplicationSupportDirectory();
  final tempDir = await getTemporaryDirectory();
  final packageInfo = await PackageInfo.fromPlatform();
  final store = secretStore ?? FlutterSecretStore();
  final databasePath = await migrateLanisDatabaseFromCache(
    cacheDirectory: cacheDir,
    persistentDirectory: persistentDir,
  );

  // Fork: lokales Fehlerprotokoll ohne Inhalte (fork/error_log.dart) und
  // Bereinigung des Dateispeichers (ersetzt den Knopf „Zwischenspeicher
  // leeren“, Entscheidung 17.10.26).
  ErrorLog.instance
    ..version = '${packageInfo.version}+${packageInfo.buildNumber}'
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
  return [...overrides, ...forkProviderOverrides()];
}
