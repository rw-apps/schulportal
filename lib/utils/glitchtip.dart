import 'dart:async';

import 'package:liblanis/liblanis.dart';

/// Fehlerberichte – im Fork abgeschaltet und ohne Sentry-SDK.
///
/// Ursache (17.10.26): Die DSN zeigte auf den Server der Original-
/// Entwickler; der Fork hat keinen eigenen und sendet nichts („Kein eigener
/// Server – alles bleibt auf dem Handy“, Einstellungen → Datenschutz). Das
/// SDK (sentry_flutter) brachte trotzdem ~0,3 MB Native-Bibliothek je
/// Prozessorart und Java-Klassen in die APK. Die Funktionen bleiben als
/// leere Hülle, damit die geerbten Aufrufer (main.dart, auth.dart,
/// lanis_bootstrap.dart) unverändert bleiben.

/// [shared_settings]-Schlüssel des früheren Opt-ins (bleibt immer false).
const glitchTipEnabledKey = 'glitchtip-enabled';

bool isGlitchTipEnabled(TypedSettings shared) => false;

void setGlitchTipEnabled(TypedSettings shared, bool enabled) {
  shared.setBool(glitchTipEnabledKey, false);
}

/// Nichts wird gesendet.
Future<void> captureGlitchTipException(
  Object throwable, {
  StackTrace? stackTrace,
}) async {}

/// Nichts wird gesendet.
Future<void> captureUnexpectedAppletError(
  Object throwable,
  StackTrace stackTrace, {
  required String appletPhpUrl,
}) async {}

/// Startet die App direkt (früher unter Sentrys Fehlerbehandlung).
Future<void> initGlitchTip(FutureOr<void> Function() appRunner) async {
  await appRunner();
}

void syncGlitchTipReportingFromConfig() {}
