import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/core/sid_rotation_adapter.dart';

/// Stellt den Ablauf aus dem Debug-Export vom 16.10.26 nach (Schule A
/// , Elternkonto): Anmeldung setzt `sid` ohne domain, der Dateispeicher
/// setzt einen neuen `sid` MIT domain=schulportal.hessen.de.
class _FakePortal implements HttpClientAdapter {
  final List<String?> sentCookieHeaders = [];
  final Map<String, List<String>> Function(Uri uri) responder;

  _FakePortal(this.responder);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sentCookieHeaders.add(options.headers['cookie'] as String?);
    return ResponseBody.fromString('ok', 200, headers: responder(options.uri));
  }

  @override
  void close({bool force = false}) {}
}

Map<String, List<String>> _portal(Uri uri) {
  if (uri.path == '/login') {
    // Anmeldung: Schlüssel ohne domain-Attribut (Host-Cookie).
    return {
      'set-cookie': ['i=0000; secure', 'sid=ALT; path=/; secure'],
    };
  }
  if (uri.path == '/dateispeicher.php') {
    // Wortgleich zum Export (Zeile 1134), Wert ersetzt; vom Adapter zu einem
    // Kopf zusammengefasst wie im Export.
    return {
      'set-cookie': [
        'i=0000; secure,sid=NEU; path=/; domain=schulportal.hessen.de; secure',
      ],
    };
  }
  return {};
}

Future<String?> _ablauf(HttpClientAdapter adapter, _FakePortal portal) async {
  final dio = Dio()
    ..httpClientAdapter = adapter
    ..interceptors.add(CookieManager(CookieJar()));
  const base = 'https://start.schulportal.hessen.de';
  await dio.get('$base/login');
  await dio.get('$base/dateispeicher.php');
  await dio.get('$base/lerngruppen.php');
  return portal.sentCookieHeaders.last;
}

int _sidCount(String? header) =>
    RegExp(r'(^|;\s*)sid=').allMatches(header ?? '').length;

void main() {
  test('ohne Korrektur: zwei sid, der alte zuerst (dokumentiert den Fehler)',
      () async {
    final portal = _FakePortal(_portal);
    final header = await _ablauf(portal, portal);
    expect(_sidCount(header), 2);
    expect(header!.indexOf('sid=ALT') < header.indexOf('sid=NEU'), isTrue);
  });

  test('mit SidRotationAdapter: genau ein sid, und zwar der neue', () async {
    final portal = _FakePortal(_portal);
    final header = await _ablauf(SidRotationAdapter(portal), portal);
    expect(_sidCount(header), 1);
    expect(header, contains('sid=NEU'));
    expect(header, contains('i=0000'));
  });

  test('andere Hosts (Anmeldeweg login./connect.) bleiben unverändert', () {
    const v = 'sid=X; path=/; domain=schulportal.hessen.de; secure';
    // normalizeSetCookie selbst ist hostblind; die Host-Grenze liegt in fetch().
    expect(SidRotationAdapter.normalizeSetCookie(v), 'sid=X; path=/; secure');
    expect(
      SidRotationAdapter.normalizeSetCookie('i=1; domain=schulportal.hessen.de'),
      'i=1; domain=schulportal.hessen.de',
    );
  });

  test('fetch fasst fremde Hosts nicht an', () async {
    final inner = _FakePortal(
      (_) => {
        'set-cookie': ['sid=X; path=/; domain=schulportal.hessen.de'],
      },
    );
    final r = await SidRotationAdapter(inner).fetch(
      RequestOptions(path: 'https://connect.schulportal.hessen.de/'),
      null,
      null,
    );
    expect(r.headers['set-cookie']!.single, contains('domain='));
  });
}
