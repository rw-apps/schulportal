import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:liblanis/liblanis.dart';

/// Woran ein Abruf oder eine Anmeldung gescheitert ist – Grundlage für die
/// Meldungen (login_errors.dart) und das Fehlerprotokoll (error_log.dart).
enum FaultKind {
  /// Portal lehnt Benutzername oder Passwort ab.
  wrongCredentials,

  /// Anmeldedaten unvollständig gespeichert.
  incomplete,

  /// Portal sperrt nach zu vielen Fehlversuchen (LoginTimeoutException).
  locked,

  /// Portal meldet Wartung bzw. Störung (LanisDownException, HTTP 503).
  down,

  /// Portal antwortet mit einem Serverfehler (HTTP 5xx).
  server,

  /// Keine Antwort: Gerät offline oder Portal nicht erreichbar.
  unreachable,

  /// Alles andere – möglicherweise ein Fehler der App.
  other,
}

class PortalFault {
  const PortalFault(this.kind, {this.status});

  final FaultKind kind;

  /// HTTP-Status bei [FaultKind.server].
  final int? status;

  /// Liegt die Ursache beim Portal oder an der Verbindung, nicht an der App?
  bool get notTheApp =>
      kind == FaultKind.down ||
      kind == FaultKind.server ||
      kind == FaultKind.unreachable;
}

final _statusCode = RegExp(r'status code of (\d{3})');

const _timeouts = {
  DioExceptionType.connectionTimeout,
  DioExceptionType.sendTimeout,
  DioExceptionType.receiveTimeout,
  DioExceptionType.connectionError,
};

/// Ordnet [e] einer [FaultKind] zu.
///
/// Ursache (Rückmeldung 22.10.26, Bildschirmfoto „Anmeldung fehlgeschlagen
/// … UnknownException: … status code of 500“): Antwortet das Portal mit
/// HTTP 500, verpackt liblanis den Fehler in LanisSession.authenticate als
/// UnknownException mit dem englischen Dio-Text. Die App zeigte dann „Etwas
/// Unerwartetes ist passiert“ und den Text – es wirkte, als läge der Fehler
/// bei der App.
///
/// Erkannt wird der Status deshalb an drei Stellen: an der DioException
/// selbst (Abrufe, die liblanis nicht umpackt), an der Meldung der
/// LanisException (Dio: „… has a status code of 500 …“,
/// DioException._badResponseExceptionMessage) und Zeitüberschreitungen an
/// „took longer than“ bzw. „The connection errored“.
///
/// Grenze: Der Text ist der von Dio 5.x; ändert Dio ihn, fällt ein
/// Serverfehler wieder auf [FaultKind.other] zurück (Test in
/// portal_fault_test.dart hält die Texte fest). 4xx gilt bewusst nicht als
/// Portalfehler: 404 oder 403 heißt eher, dass sich das Portal geändert hat
/// und die App nachziehen muss.
PortalFault portalFault(Object e) {
  switch (e) {
    case WrongCredentialsException():
      return const PortalFault(FaultKind.wrongCredentials);
    case CredentialsIncompleteException():
      return const PortalFault(FaultKind.incomplete);
    case LoginTimeoutException():
      return const PortalFault(FaultKind.locked);
    case LanisDownException():
      return const PortalFault(FaultKind.down);
    case NoConnectionException() || NetworkException():
      return const PortalFault(FaultKind.unreachable);
    case DioException(:final response?) when (response.statusCode ?? 0) >= 500:
      return PortalFault(FaultKind.server, status: response.statusCode);
    case DioException(:final type) when _timeouts.contains(type):
      return const PortalFault(FaultKind.unreachable);
    case DioException(:final error?):
      return portalFault(error);
    case SocketException() || TimeoutException() || HandshakeException():
      return const PortalFault(FaultKind.unreachable);
    case LanisException(:final cause):
      final code = int.tryParse(_statusCode.firstMatch(cause)?.group(1) ?? '');
      if (code != null && code >= 500) {
        return PortalFault(FaultKind.server, status: code);
      }
      if (cause.contains('took longer than') ||
          cause.contains('The connection errored')) {
        return const PortalFault(FaultKind.unreachable);
      }
  }
  return const PortalFault(FaultKind.other);
}

/// Kurzer Zusatz fürs Fehlerprotokoll, z. B. „Portal 500“; null = nichts.
/// Ursache: Im Bericht stand bei einem Serverfehler nur „UnknownException“
/// (Rückmeldung 21.10.26: „UnknownException 480×“) – man sah nicht, dass
/// das Portal gestört war.
String? faultTag(Object e) {
  final f = portalFault(e);
  return switch (f.kind) {
    FaultKind.server => 'Portal ${f.status}',
    FaultKind.down => 'Portal Wartung',
    FaultKind.unreachable => 'keine Verbindung',
    _ => null,
  };
}
