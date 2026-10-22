import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/fork/error_log.dart';
import 'package:lanis/fork/l10n/gen/fork_l10n_de.dart';
import 'package:lanis/fork/portal_fault.dart';
import 'package:lanis/fork/ui/login_errors.dart';

final _req = RequestOptions(path: 'https://start.schulportal.hessen.de/');

DioException _status(int code) => DioException.badResponse(
  statusCode: code,
  requestOptions: _req,
  response: Response(requestOptions: _req, statusCode: code),
);

// Wie LanisSession.authenticate: DioException → UnknownException(e.message).
UnknownException _wrapped(DioException e) =>
    UnknownException(e.message ?? e.toString());

void main() {
  final t = ForkL10nDe();

  group('portalFault', () {
    test('HTTP 500 aus der Anmeldung (Dio-Text in UnknownException)', () {
      final f = portalFault(_wrapped(_status(500)));
      expect(f.kind, FaultKind.server);
      expect(f.status, 500);
      expect(f.notTheApp, isTrue);
    });

    test('HTTP 502 als DioException', () {
      final f = portalFault(_status(502));
      expect((f.kind, f.status), (FaultKind.server, 502));
    });

    test('4xx gilt nicht als Portalfehler', () {
      expect(portalFault(_wrapped(_status(404))).kind, FaultKind.other);
      expect(portalFault(_status(403)).kind, FaultKind.other);
    });

    test('Zeitüberschreitung, auch als Text in UnknownException', () {
      final d = DioException.receiveTimeout(
        timeout: const Duration(seconds: 8),
        requestOptions: _req,
      );
      expect(portalFault(d).kind, FaultKind.unreachable);
      expect(portalFault(_wrapped(d)).kind, FaultKind.unreachable);
      final c = DioException.connectionError(requestOptions: _req, reason: 'x');
      expect(portalFault(_wrapped(c)).kind, FaultKind.unreachable);
    });

    test('typisierte Fehler von liblanis', () {
      expect(portalFault(LanisDownException()).kind, FaultKind.down);
      expect(portalFault(NoConnectionException()).kind, FaultKind.unreachable);
      expect(
        portalFault(WrongCredentialsException()).kind,
        FaultKind.wrongCredentials,
      );
      expect(portalFault(LoginTimeoutException('16')).kind, FaultKind.locked);
      expect(portalFault(UnknownException('boom')).kind, FaultKind.other);
      expect(portalFault(const FormatException('x')).kind, FaultKind.other);
    });
  });

  test('Meldung: Serverfehler nennt Portal und Code, nicht die App', () {
    final m = loginErrorText(t, _wrapped(_status(500)));
    expect(m.title, t.loginServerTitle);
    expect(m.text, contains('nicht an der App'));
  });

  test('Seitenmeldung mit Grund', () {
    expect(
      withReason(t, t.timetableFailed, _status(503)),
      '${t.timetableFailed} ${t.reasonServer}',
    );
    expect(
      withReason(t, t.timetableFailed, NoConnectionException()),
      '${t.timetableFailed} ${t.reasonUnreachable}',
    );
    expect(
      withReason(t, t.timetableFailed, UnknownException('x')),
      t.timetableFailed,
    );
    expect(withReason(t, t.timetableFailed, null), t.timetableFailed);
  });

  test('technische Zeile: nur erste Zeile, gekürzt', () {
    final line = technicalLine(_wrapped(_status(404)));
    expect(line, startsWith('UnknownException: This exception was thrown'));
    expect(line, isNot(contains('\n')));
    expect(line.length, lessThanOrEqualTo(160));
  });

  test('Fehlerprotokoll: Serverfehler mit Portal-Zusatz am Typ', () {
    final log = ErrorLog.instance..clear();
    addTearDown(log.clear);
    log.record('stundenplan.php', _wrapped(_status(500)), StackTrace.empty);
    log.record('stundenplan.php', UnknownException('x'), StackTrace.empty);
    expect(
      log.records.map((r) => r.type),
      containsAll(['UnknownException · Portal 500', 'UnknownException']),
    );
  });
}
