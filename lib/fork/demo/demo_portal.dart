import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;

import 'demo_pages.dart';
import 'demo_school.dart';

/// Ein erfundenes Schulportal im Speicher – Grundlage des Demo-Modus.
///
/// Ursache (Entscheidung 26.10.26): Die Demo soll den ganzen Weg der App
/// zeigen (Anmeldung, Lesen der Seiten, Anzeige), nicht nachgebaute
/// Bildschirme. Deshalb antwortet dieser Adapter anstelle des Netzes auf
/// genau die Anfragen, die liblanis und lib/fork stellen; die Leser bleiben
/// unverändert.
///
/// Wer angemeldet ist, erkennt der Adapter am Cookie `sid=demo-<Name>`, das
/// er bei der Anmeldung setzt – so laufen Eltern- und Schülerkonto der Demo
/// nebeneinander (FamilyScope).
///
/// Verschlüsselung: liblanis (Cryptor.initialize) verlangt einen
/// RSA-/AES-Handshake wie beim echten Portal; der Adapter spielt die
/// Gegenseite mit einem zur Laufzeit erzeugten Schlüsselpaar (kein
/// Schlüssel im Repo). Nachrichten verschlüsselt er mit dem so vereinbarten
/// Sitzungsschlüssel.
///
/// Grenzen:
/// - Nur lesen. Alles, was im Portal etwas ändern würde (Hausaufgabe
///   abhaken, Nachricht senden, Krankmeldung), beantwortet er mit einem
///   Fehler; die App zeigt dann ihre normale Fehlermeldung.
/// - Unbekannte Adressen → 404.
class DemoPortal implements HttpClientAdapter {
  DemoPortal({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final _keys = <String, Uint8List>{};
  pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey>? _pair;

  DemoClock get _clock => DemoClock(_now());

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = requestStream == null
        ? ''
        : utf8.decode(
            (await requestStream.toList()).expand((b) => b).toList(),
            allowMalformed: true,
          );
    final form = _form(body);
    final uri = o.uri;
    final q = {...uri.queryParameters, ...form};
    final cookie = o.headers['cookie']?.toString() ?? '';
    final sid = RegExp(r'sid=(demo-[\w.]+)').firstMatch(cookie)?.group(1);
    final user = demoUserNamed(sid?.substring(5) ?? '') ?? demoParent;
    final host = uri.host;
    final path = uri.path;

    // ---- Anmeldung ----
    if (host == 'login.schulportal.hessen.de') {
      final name = form['user2'] ?? '';
      if (demoUserNamed(name) == null) {
        return _html('<html><body>Login fehlgeschlagen</body></html>');
      }
      return _redirect(
        'https://connect.schulportal.hessen.de/?demo=$name',
        // Für alle Portal-Hosts, damit connect.… es mitschickt.
        cookie: 'demologin=$name; Domain=schulportal.hessen.de; Path=/',
      );
    }
    if (host == 'connect.schulportal.hessen.de') {
      final name = RegExp(r'demologin=([\w.]+)').firstMatch(cookie)?.group(1);
      return _redirect(
        'https://start.schulportal.hessen.de/index.php?demo=${name ?? ''}',
      );
    }
    if (path == '/index.php' && q['demo'] != null) {
      return _html(
        '<html><body>Demo</body></html>',
        cookie: 'sid=demo-${q['demo']}; path=/',
      );
    }
    switch (path) {
      case '/':
      case '/index.php':
        return _html('<html><body>Schulportal Demo</body></html>');
      case '/ajax_login.php':
        return _text('1');
      case '/ajax.php' when q['f'] == 'rsaPublicKey':
        return _json(jsonEncode({'publickey': _publicPem()}));
      case '/ajax.php' when q['f'] == 'rsaHandshake':
        return _json(jsonEncode({'challenge': _handshake(sid, q['key'])}));
      case '/startseite.php' when q['f'] == 'apps':
        return _json(appsJson(user));
      case '/benutzerverwaltung.php' when q['a'] == 'userData':
        return _html(userDataPage(user));
      case '/abwesenheitsmeldung.php' when o.method == 'POST':
        return _text(absenceCheckJson);
      case '/abwesenheitsmeldung.php':
        return _html(absencePage(user, _clock));
      case '/stundenplan.php':
        return _html(timetablePage(user.pupils.first, _clock));
      case '/vertretungsplan.php' when o.method == 'POST':
        return _json(substitutionsAjax(user.pupils, q['tag'] ?? '', _clock));
      case '/vertretungsplan.php':
        return _html(substitutionsPage(_clock));
      case '/kalender.php' when q['f'] == 'getEvents':
        return _json(calendarEvents(user.pupils, _clock));
      case '/kalender.php':
        return _html(calendarPage());
      case '/meinunterricht.php' when q['a'] == 'sus_view':
        final page = coursePage(user, q['id'] ?? '', _clock);
        return page == null ? _status(404) : _html(page);
      case '/meinunterricht.php' when q['a'] == null:
        return _html(lessonsPage(user, _clock));
      case '/nachrichten.php' when q['a'] == 'searchRecipt':
        // Empfängersuche beim Schreiben (ConversationsParser.searchTeacher).
        final term = (q['q'] ?? '').toLowerCase();
        return _json(
          jsonEncode({
            'items': [
              for (final t in demoTeachers.values)
                if ('${t.full} ${t.code}'.toLowerCase().contains(term))
                  {
                    'type': 'lul',
                    'id': 'l-demo-${t.code}',
                    'logo': 'fa fa-user',
                    'text': '${t.last}, ${t.first} (${t.code})',
                  },
            ],
          }),
        );
      case '/nachrichten.php' when q['a'] == null && o.method == 'GET':
        // Seite selbst: nur für canChooseType (#MsgOptions fehlt).
        return _html('<html><body>Nachrichten</body></html>');
      case '/nachrichten.php' when q['a'] == 'headers':
        return _json(
          jsonEncode({
            'rows': _encrypt(sid, messageRows(user, _clock)),
            'total': demoMessagesFor(user).length,
          }),
        );
      case '/nachrichten.php' when q['a'] == 'read':
        final m = messageRead(user, q['msg'] ?? '', _clock);
        if (m == null) return _status(404);
        return _json(
          jsonEncode({
            'message': _encrypt(sid, m),
            'time': '${_now().millisecondsSinceEpoch ~/ 1000}',
          }),
        );
    }
    // Ändernde Aufrufe und Unbekanntes: nicht in der Demo.
    return _status(404);
  }

  @override
  void close({bool force = false}) {}

  // ---- Antworten ----------------------------------------------------------

  static Map<String, String> _form(String body) {
    if (body.isEmpty || !body.contains('=')) return const {};
    try {
      return Uri.splitQueryString(body);
    } catch (_) {
      return const {};
    }
  }

  static ResponseBody _reply(
    String body,
    String type, {
    int status = 200,
    String? cookie,
    String? location,
  }) => ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: [type],
      'set-cookie': ?(cookie == null ? null : [cookie]),
      'location': ?(location == null ? null : [location]),
    },
  );

  static ResponseBody _html(String b, {String? cookie}) =>
      _reply(b, 'text/html; charset=UTF-8', cookie: cookie);
  // JSON als text/html wie beim Portal: liblanis liest `response.data`
  // als Text (jsonDecode(response.data.toString())); mit application/json
  // hätte Dio schon eine Map daraus gemacht.
  static ResponseBody _json(String b) => _reply(b, 'text/html; charset=UTF-8');
  static ResponseBody _text(String b) => _reply(b, 'text/plain');
  static ResponseBody _status(int s) => _reply('', 'text/plain', status: s);
  static ResponseBody _redirect(String to, {String? cookie}) =>
      _reply('', 'text/html', status: 302, cookie: cookie, location: to);

  // ---- Verschlüsselung (Gegenstück zu liblanis Cryptor) ---------------------

  pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey> get _rsa =>
      _pair ??= () {
        final rnd = pc.FortunaRandom()
          ..seed(
            pc.KeyParameter(
              Uint8List.fromList([
                for (var i = 0; i < 32; i++) Random.secure().nextInt(256),
              ]),
            ),
          );
        final gen = pc.RSAKeyGenerator()
          ..init(
            pc.ParametersWithRandom(
              pc.RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 64),
              rnd,
            ),
          );
        final p = gen.generateKeyPair();
        return pc.AsymmetricKeyPair(
          p.publicKey as pc.RSAPublicKey,
          p.privateKey as pc.RSAPrivateKey,
        );
      }();

  /// Öffentlicher Schlüssel als PEM „RSA PUBLIC KEY“ (PKCS#1: n, e) – das
  /// liest encrypt.RSAKeyParser in Cryptor.getPublicKey.
  String _publicPem() {
    final k = _rsa.publicKey;
    final der = _derSeq([_derInt(k.modulus!), _derInt(k.exponent!)]);
    final b64 = base64.encode(der);
    final lines = [
      for (var i = 0; i < b64.length; i += 64)
        b64.substring(i, min(i + 64, b64.length)),
    ];
    return '-----BEGIN RSA PUBLIC KEY-----\n${lines.join('\n')}\n'
        '-----END RSA PUBLIC KEY-----';
  }

  /// Sitzungsschlüssel entschlüsseln, merken und verschlüsselt zurückgeben
  /// (Cryptor.checkForEqualEncryption vergleicht genau das).
  String _handshake(String? sid, String? encryptedKey) {
    final rsa = enc.Encrypter(
      enc.RSA(privateKey: _rsa.privateKey, encoding: enc.RSAEncoding.PKCS1),
    );
    final key = Uint8List.fromList(
      rsa.decryptBytes(enc.Encrypted.fromBase64(encryptedKey ?? '')),
    );
    _keys[sid ?? ''] = key;
    return _aes(key, key);
  }

  String _encrypt(String? sid, String text) =>
      _aes(_keys[sid ?? ''] ?? Uint8List(46), utf8.encode(text));

  /// „Salted__“ + Salz + AES-256-CBC wie OpenSSL (Cryptor.encryptString).
  static String _aes(Uint8List key, List<int> data) {
    final rnd = Random.secure();
    final salt = Uint8List.fromList([
      for (var i = 0; i < 8; i++) rnd.nextInt(256),
    ]);
    var derived = <int>[];
    var block = <int>[];
    while (derived.length < 48) {
      block = md5.convert([...block, ...key, ...salt]).bytes;
      derived = [...derived, ...block];
    }
    final aes = enc.Encrypter(
      enc.AES(
        enc.Key(Uint8List.fromList(derived.sublist(0, 32))),
        mode: enc.AESMode.cbc,
      ),
    );
    final ct = aes.encryptBytes(
      data,
      iv: enc.IV(Uint8List.fromList(derived.sublist(32, 48))),
    );
    return base64.encode([...utf8.encode('Salted__'), ...salt, ...ct.bytes]);
  }

  static List<int> _derLen(int n) {
    if (n < 128) return [n];
    final bytes = <int>[];
    for (var v = n; v > 0; v >>= 8) {
      bytes.insert(0, v & 0xff);
    }
    return [0x80 | bytes.length, ...bytes];
  }

  static List<int> _derInt(BigInt v) {
    var hex = v.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    final bytes = [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];
    if (bytes.first & 0x80 != 0) bytes.insert(0, 0);
    return [0x02, ..._derLen(bytes.length), ...bytes];
  }

  static List<int> _derSeq(List<List<int>> parts) {
    final content = parts.expand((p) => p).toList();
    return [0x30, ..._derLen(content.length), ...content];
  }
}
