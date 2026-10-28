import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/asymmetric/api.dart';

import '../exceptions.dart';

/// Lanis RSA handshake + AES decrypt for SPH payloads.
class Cryptor {
  static const int passphraseSize = 46;
  late encrypt.Key key;
  bool authenticated = false;
  late Dio dio;

  Future<RSAPublicKey?> getPublicKey() async {
    try {
      final response = await dio.post(
        'https://start.schulportal.hessen.de/ajax.php',
        queryParameters: {'f': 'rsaPublicKey'},
        options: Options(
          headers: {
            'Accept': '*/*',
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Sec-Fetch-Dest': 'empty',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Site': 'same-origin',
          },
        ),
      );

      if (response.statusCode == 503) {
        throw LanisDownException();
      }

      return encrypt.RSAKeyParser().parse(
            jsonDecode(response.toString())['publickey'],
          )
          as RSAPublicKey;
    } on SocketException {
      return null;
    } on DioException {
      return null;
    }
  }

  Future<String?> handshake(String encryptedKey) async {
    try {
      final response = await dio.post(
        'https://start.schulportal.hessen.de/ajax.php',
        queryParameters: {'f': 'rsaHandshake', 's': Random().nextInt(2000)},
        data: {'key': encryptedKey},
        options: Options(
          headers: {
            'Accept': '*/*',
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Sec-Fetch-Dest': 'empty',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Site': 'same-origin',
          },
        ),
      );
      return jsonDecode(response.toString())['challenge'];
    } on SocketException {
      return null;
    } on DioException {
      return null;
    }
  }

  encrypt.Key generateKey() => encrypt.Key.fromSecureRandom(passphraseSize);

  Uint8List encryptKey(RSAPublicKey publicKey) =>
      _encryptKeyWith(publicKey, key);

  static Uint8List _encryptKeyWith(RSAPublicKey publicKey, encrypt.Key k) {
    final rsa = encrypt.RSA(
      publicKey: publicKey,
      encoding: encrypt.RSAEncoding.PKCS1,
    );
    return rsa.encrypt(k.bytes).bytes;
  }

  bool checkForEqualEncryption(Uint8List challenge) =>
      _challengeMatches(challenge, key);

  /// Fork: false statt Absturz bei unlesbarer Antwort des Handshakes.
  /// Ursache (Prüfung 27.10.26, liblanis-Befund 10): `decryptedChallenge!`
  /// warf TypeError, wenn die Antwort nicht mit „Salted__“ begann, und eine
  /// kaputte Polsterung warf ArgumentError – beides kam als roher Fehler
  /// statt [EncryptionCheckFailedException] aus der Anmeldung.
  static bool _challengeMatches(Uint8List challenge, encrypt.Key k) {
    try {
      final decryptedChallenge = decryptWithKey(challenge, k);
      if (decryptedChallenge == null) return false;
      return base64.encode(decryptedChallenge) == base64.encode(k.bytes);
    } catch (_) {
      return false;
    }
  }

  static Uint8List bytesToKeys(Uint8List salt, encrypt.Key key) {
    Uint8List concatenatedHashes = Uint8List(0);
    Uint8List currentHash = Uint8List(0);
    var enoughBytesForKey = false;
    Uint8List preHash = Uint8List(0);

    while (!enoughBytesForKey) {
      if (currentHash.isNotEmpty) {
        preHash = Uint8List.fromList(currentHash + key.bytes + salt);
      } else {
        preHash = Uint8List.fromList(key.bytes + salt);
      }

      currentHash = md5.convert(preHash).bytes as Uint8List;
      concatenatedHashes = Uint8List.fromList(concatenatedHashes + currentHash);
      if (concatenatedHashes.length >= 48) enoughBytesForKey = true;
    }

    return concatenatedHashes;
  }

  String encryptString(String decryptedData) {
    final salt = encrypt.SecureRandom(8).bytes;
    final derivedKeyAndIV = bytesToKeys(salt, key);
    final derivedKey = encrypt.Key(derivedKeyAndIV.sublist(0, 32));
    final derivedIV = encrypt.IV(derivedKeyAndIV.sublist(32, 48));
    final aes = encrypt.Encrypter(
      encrypt.AES(derivedKey, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );
    final encryptedData = aes.encrypt(decryptedData, iv: derivedIV).bytes;
    final finalEncrypted = utf8.encode('Salted__') + salt + encryptedData;
    return base64.encode(finalEncrypted);
  }

  static List<int>? decryptWithKey(
    Uint8List encryptedDataWithSalt,
    encrypt.Key key,
  ) {
    // Fork: erst Länge und Kennung prüfen, dann zerschneiden. Ursache
    // (Prüfung 27.10.26, liblanis-Befund 10): sublist(16) lief vor jeder
    // Prüfung und warf bei weniger als 16 Byte RangeError; utf8.decode warf
    // bei Binärdaten FormatException statt null („nicht gesalzen“).
    // Grenze: Ein zu kurzer oder ungesalzener Inhalt gilt jetzt als null wie
    // ein fehlendes „Salted__“; kaputte Chiffretexte dahinter werfen weiter
    // (AES), das fängt [decryptEncodedTags] je Tag ab.
    if (encryptedDataWithSalt.length < 16) return null;
    if (!_hasSaltedPrefix(encryptedDataWithSalt)) return null;
    final encryptedData = encrypt.Encrypted.fromBase64(
      base64.encode(encryptedDataWithSalt.sublist(16)),
    );

    final salt = encryptedDataWithSalt.sublist(8, 16);
    final derivedKeyAndIV = bytesToKeys(salt, key);
    final derivedKey = encrypt.Key(derivedKeyAndIV.sublist(0, 32));
    final derivedIV = encrypt.IV(derivedKeyAndIV.sublist(32, 48));
    final aes = encrypt.Encrypter(
      encrypt.AES(derivedKey, mode: encrypt.AESMode.cbc),
    );
    return aes.decryptBytes(encryptedData, iv: derivedIV);
  }

  List<int>? decrypt(Uint8List encryptedDataWithSalt) {
    return decryptWithKey(encryptedDataWithSalt, key);
  }

  static String? decryptWithKeyString(String encryptedData, encrypt.Key key) {
    final decryptedBytes = decryptWithKey(base64.decode(encryptedData), key);
    if (decryptedBytes != null) {
      return utf8.decode(decryptedBytes);
    }
    return null;
  }

  String? decryptString(String encryptedData) {
    return decryptWithKeyString(encryptedData, key);
  }

  static final Uint8List _salted = ascii.encode('Salted__');

  static bool _hasSaltedPrefix(Uint8List data) {
    for (var i = 0; i < _salted.length; i++) {
      if (data[i] != _salted[i]) return false;
    }
    return true;
  }

  /// Fork: ein kaputtes `<encoded>` reißt die Seite nicht mehr mit.
  ///
  /// Ursache (Prüfung 27.10.26, liblanis-Befund 10): Ein einziges Tag mit
  /// unlesbarem Inhalt (kein Base64, falsche Länge, falsche Polsterung, kein
  /// UTF-8) warf im Antwort-Interceptor (LanisSession.prepareDio) – der
  /// ganze Abruf scheiterte, auch wenn alle übrigen Tags lesbar waren. Jetzt
  /// bleibt ein solches Tag unverändert stehen (der Leser sieht es als
  /// unbekanntes Element) und es gibt einen Protokolleintrag
  /// (dart:developer log, Name „liblanis.cryptor“) ohne den Inhalt.
  ///
  /// Grenze: Ist KEIN Tag der Antwort lesbar, aber mindestens eines kaputt,
  /// wirft sie weiter wie 0.1.4. Das ist das Bild eines falschen Schlüssels
  /// (Sitzung beim Portal neu, Schlüssel alt); der Fehler löst in
  /// AppletParser.fetchData die Neuanmeldung aus, die den Schlüssel erneuert.
  /// Ein Tag ohne „Salted__“ wird wie bisher zu einem leeren Text.
  String decryptEncodedTags(String htmlString) {
    final exp = RegExp(r'<encoded>(.*?)</encoded>');
    var decrypted = 0;
    Object? firstError;
    StackTrace? firstStack;
    final result = htmlString.replaceAllMapped(exp, (match) {
      final encodedContent = match.group(1) ?? '';
      try {
        final decryptedContent = decryptString(encodedContent);
        // Fork: nur echte Klartexte zählen (Prüfung 28.10.26) – ein leerer
        // oder ungesalzener Tag (null) belegt keinen richtigen Schlüssel;
        // sonst blieb bei falschem Schlüssel die Neuanmeldung aus.
        if (decryptedContent != null) decrypted++;
        return decryptedContent ?? '';
      } catch (e, stack) {
        firstError ??= e;
        firstStack ??= stack;
        developer.log(
          'Unreadable <encoded> tag left as is '
          '(${encodedContent.length} chars, ${e.runtimeType})',
          name: 'liblanis.cryptor',
        );
        return match.group(0)!;
      }
    });
    if (firstError != null && decrypted == 0) {
      Error.throwWithStackTrace(firstError!, firstStack!);
    }
    return result;
  }

  /// Decrypt [encryptedData] on a background isolate using this instance's key.
  Future<String?> decryptStringInIsolate(String encryptedData) {
    final keyBytes = key.bytes;
    return Isolate.run(() {
      final k = encrypt.Key(Uint8List.fromList(keyBytes));
      return decryptWithKeyString(encryptedData, k);
    });
  }

  /// Fork: neuer Schlüssel erst nach erfolgreichem Handshake.
  ///
  /// Ursache (Prüfung 27.10.26, liblanis-Befund 3): 0.1.4 setzte [key] VOR
  /// dem Handshake. Antworten, die währenddessen eintrafen, entschlüsselte
  /// der Interceptor (LanisSession.prepareDio, [decryptEncodedTags]) schon
  /// mit dem Schlüssel, den das Portal noch gar nicht kannte; scheiterte der
  /// Handshake, blieb dieser unbekannte Schlüssel stehen. Jetzt läuft der
  /// Handshake mit einem Kandidaten, [key] wechselt erst, wenn das Portal
  /// ihn bestätigt hat. Eine unlesbare Challenge (kein Base64) zählt als
  /// [EncryptionCheckFailedException] statt als roher FormatException.
  ///
  /// Grenze: Nach gescheitertem Handshake bleiben [key] und [authenticated]
  /// wie vorher – passt der alte Schlüssel nicht mehr zur neuen Sitzung,
  /// scheitert der nächste Abruf und meldet sich neu an.
  Future<void> initialize(Dio dioClient) async {
    dio = dioClient;
    final candidate = generateKey();

    final publicKey = await getPublicKey();
    if (publicKey == null) {
      throw NetworkException();
    }

    final encryptedKey = _encryptKeyWith(publicKey, candidate);
    final challenge = await handshake(base64.encode(encryptedKey));
    if (challenge == null) {
      throw NetworkException();
    }

    final Uint8List challengeBytes;
    try {
      challengeBytes = base64.decode(challenge);
    } on FormatException {
      throw EncryptionCheckFailedException();
    }
    if (_challengeMatches(challengeBytes, candidate)) {
      key = candidate;
      authenticated = true;
      return;
    }

    throw EncryptionCheckFailedException();
  }
}
