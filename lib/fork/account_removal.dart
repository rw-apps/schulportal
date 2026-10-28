import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:path/path.dart' as p;
import 'package:webview_flutter/webview_flutter.dart' show WebViewCookieManager;

import 'package:lanis/background_service.dart' show refreshBackgroundService;
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/language.dart' show languageProvider;
import 'package:lanis/fork/widget/home_widget_sync.dart'
    show removeHomeWidgetKid;

/// Dateicache des Kontos [localId] unter [root] (LanisConfig.
/// documentCacheDirectory) – derselbe Pfad wie
/// StorageManager.getDocumentCacheDirectory in liblanis
/// (`<root>/<Konto>/document_cache`). null ohne eingerichteten Speicher.
Directory? accountDocumentCache(String? root, int localId) =>
    root == null || root.isEmpty
    ? null
    : Directory(p.join(root, '$localId', 'document_cache'));

/// Heruntergeladene Dateien des Kontos [localId] löschen; Fehler (Datei
/// gesperrt, kein Speicher) werden geschluckt, weil das Konto dann schon
/// entfernt ist.
Future<void> deleteAccountDocuments(String? root, int localId) async {
  final dir = accountDocumentCache(root, localId);
  try {
    if (dir != null && dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  } catch (_) {}
}

/// Konto [localId] vom Gerät entfernen – der eine Weg für alle Stellen
/// (Einstellungen → Kind abmelden, Kontenliste account_tile.dart).
///
/// Ursache (Prüfung 27.10.26): Nur die Einstellungen
/// (fork/ui/settings/settings_page.dart, _logout) räumten Dateicache und
/// WebView-Cookies (Moodle-Anmeldung) auf; die Kontenliste entfernte das
/// Konto ohne beides, und „Konto zurücksetzen“ (ResetAccountPage, jetzt
/// gelöscht) sogar ohne Rückfrage. Die Rückfrage stellt weiter der Aufrufer.
/// Grenze: Die WebView-Cookies gelten für alle Konten – andere Konten melden
/// sich in Moodle neu an. Danach wird die Hintergrundabfrage neu bewertet
/// (refreshBackgroundService), damit Meldungen des Kontos verschwinden und
/// sie stoppt, wenn kein Konto mehr Meldungen will.
///
/// Startbildschirm-Widget: Das Kind verschwindet aus der Datei, ohne
/// übriges Kind wird sie gelöscht (removeHomeWidgetKid,
/// home_widget_sync.dart). Ursache (Prüfung 28.10.26): Vorher blieb ein
/// abgemeldetes Kind mit seinem letzten Stand auf dem Startbildschirm.
/// Grenze: Die übrigen Kinder werden in der Sprache der Einstellung neu
/// geschrieben (wie der Hintergrund-Lauf, notify_task.dart), nicht in der
/// des Widget-Baums.
Future<void> removeAccountFromDevice(WidgetRef ref, int localId) async {
  String? root;
  try {
    root = ref.read(lanisConfigProvider).documentCacheDirectory;
  } catch (_) {}
  String? language;
  try {
    language = ref.read(languageProvider);
  } catch (_) {}
  await ref
      .read(authControllerProvider.notifier)
      .removeAccountAndContinue(localId);
  await deleteAccountDocuments(root, localId);
  try {
    await WebViewCookieManager().clearCookies();
  } catch (_) {}
  await removeHomeWidgetKid(
    localId,
    t: forkL10nFor(
      resolveLanguage(
        language,
        PlatformDispatcher.instance.locale.languageCode,
      ),
    ),
    now: DateTime.now(),
  );
  unawaited(refreshBackgroundService());
}
