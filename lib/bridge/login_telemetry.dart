import 'package:liblanis/liblanis.dart';

/// Authentifiziert die Sitzung — im Fork OHNE Login-Meldung.
///
/// Ursache der Änderung: Das Original schickte nach jedem Login in Release-
/// Builds ungefragt schoolid, versioncode und platform an
/// lanis-logger.orion.alessioc42.dev (server: lanis-mobile/school-monitor-backend);
/// der Server sah dabei zwangsläufig die IP. Es gab weder Schalter noch Hinweis
/// im Einführungstext (intl_de.arb „introAnalytics“ nennt nur Fehlerberichte).
///
/// Grenze: Name und Signatur bleiben, damit die zwei Aufrufer
/// (features/auth/auth_controller.dart, applets/lessons/student/course_overview.dart)
/// unverändert bleiben und Upstream-Merges dort konfliktfrei laufen.
Future<LanisSession> authenticateWithLoginTelemetry(
  Session sessionController, {
  bool withoutData = false,
}) {
  return sessionController.authenticate(withoutData: withoutData);
}
