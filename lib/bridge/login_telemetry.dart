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
///
/// [withLoginUrl]: Login-Link einer eben erfolgreichen Passwort-Prüfung
/// (login_guard.dart, takeLoginUrl) – dann ohne zweite Anmeldung beim
/// Portal (Prüfung 27.10.26, Befund 9).
Future<LanisSession> authenticateWithLoginTelemetry(
  Session sessionController, {
  bool withoutData = false,
  String? withLoginUrl,
}) async {
  if (withLoginUrl == null) {
    return sessionController.authenticate(withoutData: withoutData);
  }
  try {
    return await sessionController.authenticate(
      withoutData: withoutData,
      withLoginUrl: withLoginUrl,
    );
  } on NoConnectionException {
    rethrow;
  } on LanisDownException {
    rethrow;
  } catch (_) {
    // Fork: Link abgelehnt (abgelaufen, schon benutzt) → einmal regulär
    // anmelden. Ursache: Wie lange das Portal den Link der Passwort-Prüfung
    // annimmt, ist nicht belegt; ohne Rückfall scheiterte dann das
    // Hinzufügen eines Kontos mit richtigem Passwort. Grenze: Nur in diesem
    // Fehlerfall gibt es wieder zwei Anmeldungen; Verbindungsfehler und
    // Wartung werden nicht wiederholt.
    return sessionController.authenticate(withoutData: withoutData);
  }
}
