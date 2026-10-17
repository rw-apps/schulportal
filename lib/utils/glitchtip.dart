import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:liblanis/liblanis.dart';

import '../fork/error_log.dart';

/// Fehlerberichte – im Fork abgeschaltet und ohne Sentry-SDK.
///
/// Ursache (17.10.26): Die DSN zeigte auf den Server der Original-
/// Entwickler; der Fork hat keinen eigenen und sendet nichts („Kein eigener
/// Server – alles bleibt auf dem Handy“, Einstellungen → Datenschutz). Das
/// SDK (sentry_flutter) brachte trotzdem ~0,3 MB Native-Bibliothek je
/// Prozessorart und Java-Klassen in die APK. Die Funktionen bleiben als
/// Hülle, damit die geerbten Aufrufer (main.dart, auth.dart,
/// lanis_bootstrap.dart) unverändert bleiben; seit 9343 schreiben sie ins
/// lokale Fehlerprotokoll ohne Inhalte (fork/error_log.dart).

/// [shared_settings]-Schlüssel des früheren Opt-ins (bleibt immer false).
const glitchTipEnabledKey = 'glitchtip-enabled';

bool isGlitchTipEnabled(TypedSettings shared) => false;

void setGlitchTipEnabled(TypedSettings shared, bool enabled) {
  shared.setBool(glitchTipEnabledKey, false);
}

/// Nur lokal erfasst (ErrorLog), nichts wird gesendet.
Future<void> captureGlitchTipException(
  Object throwable, {
  StackTrace? stackTrace,
}) async => ErrorLog.instance.record('start', throwable, stackTrace);

/// Lesefehler eines Bereichs; nur lokal erfasst. Der Bereich ohne Anfrage-
/// teil, damit keine Kurs- oder Kind-ID ins Protokoll gerät.
Future<void> captureUnexpectedAppletError(
  Object throwable,
  StackTrace stackTrace, {
  required String appletPhpUrl,
}) async => ErrorLog.instance.record(
  appletPhpUrl.split('?').first,
  throwable,
  stackTrace,
);

/// Startet die App; nicht abgefangene Fehler landen im lokalen Protokoll.
///
/// Ursache: Ohne Haken blieben Abstürze unsichtbar, sobald die Meldung
/// weggeklickt war. Grenze: Fehler, die vor diesem Aufruf passieren (Laden
/// der Lizenzdatei), fehlen.
Future<void> initGlitchTip(FutureOr<void> Function() appRunner) async {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    ErrorLog.instance.record('ui', details.exception, details.stack);
    (previous ?? FlutterError.presentError)(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorLog.instance.record('app', error, stack);
    return false;
  };
  await appRunner();
}

void syncGlitchTipReportingFromConfig() {}
