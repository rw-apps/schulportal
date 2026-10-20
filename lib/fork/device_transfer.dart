import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Übertragung von Zugangsdaten und Eingaben auf ein neues Gerät per
/// QR-Code in zwei Schritten (Wunsch 20.10.26).
///
/// 1. Das NEUE Gerät erzeugt ein Schlüsselpaar (X25519) und zeigt den
///    öffentlichen Schlüssel als QR-Code ([offerCode]).
/// 2. Das ALTE Gerät scannt ihn, verschlüsselt die Daten für genau diesen
///    Schlüssel ([sealPayload]: eigener Einmalschlüssel, ECDH, HKDF-SHA256,
///    AES-256-GCM) und zeigt das Ergebnis als QR-Code(s); das neue Gerät
///    scannt sie und entschlüsselt ([openPayload]).
///
/// Ursache für zwei Schritte statt eines QR-Codes mit den Daten: Ein Code
/// mit Passwörtern wäre ein Foto der Passwörter. So kann nur das Gerät, das
/// den ersten Code zeigte, den zweiten lesen; ein abfotografierter zweiter
/// Code nützt niemandem. Der Prüfcode ([checkCode]) auf beiden Geräten
/// zeigt, dass das alte Gerät wirklich den Code des neuen gescannt hat.
///
/// Grenzen: Wer den ERSTEN Code durch einen eigenen ersetzt und die Prüfcodes
/// nicht vergleicht, bekäme die Daten – deshalb der Vergleich. Der
/// Schlüssel des neuen Geräts lebt nur im Arbeitsspeicher, bis die Seite
/// geschlossen wird.
const _offerPrefix = 'SPT1K:';
const _dataPrefix = 'SPT1D:';
const _info = 'schulportal-geraet-v1';

/// Zeichen je Daten-QR-Code. Ursache: Größere Codes lassen sich von einem
/// Bildschirm schlecht abscannen; ab mehr Daten folgen mehrere Codes.
const transferChunkSize = 700;

final _x25519 = X25519();
final _aes = AesGcm.with256bits();
final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

String _b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');
Uint8List _unb64(String s) =>
    base64Url.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));

/// Schlüsselpaar des neuen Geräts.
Future<SimpleKeyPair> newTransferKey() => _x25519.newKeyPair();

/// Inhalt des ersten QR-Codes (öffentlicher Schlüssel des neuen Geräts).
Future<String> offerCode(SimpleKeyPair key) async {
  final pub = await key.extractPublicKey();
  return '$_offerPrefix${_b64(pub.bytes)}';
}

/// Öffentlicher Schlüssel aus dem ersten QR-Code; null = kein solcher Code.
Uint8List? parseOffer(String code) {
  if (!code.startsWith(_offerPrefix)) return null;
  try {
    final b = _unb64(code.substring(_offerPrefix.length));
    return b.length == 32 ? b : null;
  } catch (_) {
    return null;
  }
}

/// Prüfcode zum Vergleichen auf beiden Geräten („482 913“).
Future<String> checkCode(List<int> publicKey) async {
  final h = await Sha256().hash(publicKey);
  final n = ((h.bytes[0] << 16) | (h.bytes[1] << 8) | h.bytes[2]) % 1000000;
  final s = n.toString().padLeft(6, '0');
  return '${s.substring(0, 3)} ${s.substring(3)}';
}

Future<SecretKey> _key(
  SecretKey shared,
  List<int> senderPub,
  List<int> receiverPub,
) => _hkdf.deriveKey(
  secretKey: shared,
  nonce: [...senderPub, ...receiverPub],
  info: utf8.encode(_info),
);

/// [payload] für den Empfänger verschlüsseln und in QR-Inhalte teilen.
Future<List<String>> sealPayload(
  Map<String, dynamic> payload,
  Uint8List receiverPub, {
  Random? random,
}) async {
  final eph = await _x25519.newKeyPair();
  final ephPub = (await eph.extractPublicKey()).bytes;
  final shared = await _x25519.sharedSecretKey(
    keyPair: eph,
    remotePublicKey: SimplePublicKey(receiverPub, type: KeyPairType.x25519),
  );
  final key = await _key(shared, ephPub, receiverPub);
  final plain = gzip.encode(utf8.encode(jsonEncode(payload)));
  final box = await _aes.encrypt(plain, secretKey: key);
  final blob = _b64([
    ...ephPub,
    ...box.nonce,
    ...box.cipherText,
    ...box.mac.bytes,
  ]);
  final r = random ?? Random.secure();
  final id = r.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
  final n = (blob.length / transferChunkSize).ceil().clamp(1, 99);
  return [
    for (var i = 0; i < n; i++)
      '$_dataPrefix$id:${i + 1}/$n:'
          '${blob.substring(i * transferChunkSize, min(blob.length, (i + 1) * transferChunkSize))}',
  ];
}

/// Sammelt die Daten-QR-Codes einer Übertragung (Reihenfolge egal).
class ChunkCollector {
  String? _id;
  int _total = 0;
  final _parts = <int, String>{};

  int get received => _parts.length;
  int get total => _total;
  bool get complete => _total > 0 && _parts.length == _total;

  /// true = neuer Teil angenommen.
  bool add(String code) {
    final m = RegExp(
      r'^SPT1D:([0-9a-f]{4}):(\d{1,2})/(\d{1,2}):([A-Za-z0-9_\-]+)$',
    ).firstMatch(code);
    if (m == null) return false;
    final id = m[1]!;
    final i = int.parse(m[2]!);
    final n = int.parse(m[3]!);
    if (n < 1 || i < 1 || i > n) return false;
    if (_id != id) {
      // Neue Übertragung (anderes altes Gerät oder neu gestartet).
      _id = id;
      _total = n;
      _parts.clear();
    }
    if (_parts.containsKey(i)) return false;
    _parts[i] = m[4]!;
    return true;
  }

  String get blob => [for (var i = 1; i <= _total; i++) _parts[i]!].join();
}

/// Entschlüsseln; null = falscher Schlüssel oder beschädigt.
Future<Map<String, dynamic>?> openPayload(
  String blob,
  SimpleKeyPair receiver,
) async {
  try {
    final b = _unb64(blob);
    if (b.length < 32 + 12 + 16) return null;
    final ephPub = b.sublist(0, 32);
    final nonce = b.sublist(32, 44);
    final mac = b.sublist(b.length - 16);
    final cipher = b.sublist(44, b.length - 16);
    final receiverPub = (await receiver.extractPublicKey()).bytes;
    final shared = await _x25519.sharedSecretKey(
      keyPair: receiver,
      remotePublicKey: SimplePublicKey(ephPub, type: KeyPairType.x25519),
    );
    final key = await _key(shared, ephPub, receiverPub);
    final plain = await _aes.decrypt(
      SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
      secretKey: key,
    );
    final v = jsonDecode(utf8.decode(gzip.decode(plain)));
    return v is Map<String, dynamic> ? v : null;
  } catch (_) {
    return null;
  }
}

// ---- Inhalt ----------------------------------------------------------------

const _format = 'schulportal-geraet';

class TransferAccount {
  const TransferAccount({
    required this.schoolId,
    required this.schoolName,
    required this.username,
    required this.password,
  });

  final int schoolId;
  final String schoolName;
  final String username;
  final String password;

  Map<String, dynamic> toJson() => {
    'i': schoolId,
    'n': schoolName,
    'u': username,
    'p': password,
  };

  static TransferAccount? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['i'];
    final u = j['u'];
    final p = j['p'];
    if (id is! int || u is! String || p is! String || u.isEmpty) return null;
    return TransferAccount(
      schoolId: id,
      schoolName: '${j['n'] ?? ''}',
      username: u,
      password: p,
    );
  }
}

/// Zugangsdaten und Eingaben (settings_transfer.dart: Kontoschlüssel →
/// Einstellung → Rohwert).
Map<String, dynamic> buildDevicePayload(
  List<TransferAccount> accounts,
  Map<String, Map<String, String>> settings,
) => {
  'f': _format,
  'v': 1,
  'a': [for (final a in accounts) a.toJson()],
  's': settings,
};

({List<TransferAccount> accounts, Map<String, Map<String, String>> settings})?
parseDevicePayload(Map<String, dynamic> p) {
  if (p['f'] != _format) return null;
  final raw = p['a'];
  final accounts = [
    if (raw is List)
      for (final a in raw) ?TransferAccount.fromJson(a),
  ];
  final s = p['s'];
  final settings = <String, Map<String, String>>{
    if (s is Map)
      for (final e in s.entries)
        if (e.value is Map)
          '${e.key}': {
            for (final x in (e.value as Map).entries)
              if (x.value is String) '${x.key}': x.value as String,
          },
  };
  return (accounts: accounts, settings: settings);
}
