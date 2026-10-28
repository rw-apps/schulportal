import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:liblanis/liblanis.dart';

/// Schutz vor Anmelde-Schleifen, die das Konto im Portal sperren.
///
/// Ursache (Rückmeldung 19.10.26, Konto einer Mutter, „auch auf der Webseite
/// nicht“): Das Schulportal sperrt ein Konto nach mehreren falschen
/// Anmeldungen mit wachsender Wartezeit (`authErrorLocktime`,
/// LoginTimeoutException) – für App UND Webseite. Stimmte das gespeicherte
/// Passwort nicht mehr, meldete die App sich bei jedem Hintergrundlauf
/// (alle 15–60 Minuten, background_service.dart), bei jedem Start und für
/// jedes weitere Konto (FamilyScope) erneut falsch an; jede dieser Anmeldungen
/// verlängerte die Sperre.
///
/// Jetzt je Konto:
/// - Abgelehntes Passwort: Kennung (SHA-256, nie das Passwort) merken; mit
///   DIESEM Passwort keine automatische Anmeldung mehr. Ein neues Passwort
///   (andere Kennung) hebt das auf, ebenso eine erfolgreiche Anmeldung.
///   Bewusst angetipptes „Erneut versuchen“ ([userInitiated]) darf trotzdem
///   – falls die Ablehnung ein Ausrutscher des Portals war.
/// - Sperre des Portals: deren Ende merken; bis dahin keinen Versuch, auch
///   nicht auf Knopfdruck – er verlängerte die Sperre nur.
///
/// Grenze: Wer auf der Webseite falsch tippt, sperrt das Konto weiter; das
/// sieht die App erst beim nächsten Versuch.
const _rejectedKey = 'fork-auth/rejected-password';
const _lockedKey = 'fork-auth/locked-until';

String _fingerprint(String password) =>
    sha256.convert(utf8.encode(password)).toString();

/// Ende einer bekannten Sperre; null = keine.
DateTime? lockedUntil(TypedSettings s, {DateTime? now}) {
  final until = DateTime.tryParse(s.getString(_lockedKey) ?? '');
  if (until == null) return null;
  return until.isAfter(now ?? DateTime.now()) ? until : null;
}

/// Wurde genau dieses Passwort schon abgelehnt?
bool passwordRejected(TypedSettings s, String password) =>
    s.getString(_rejectedKey) == _fingerprint(password);

/// Wirft, statt das Portal zu fragen, wenn der Versuch sicher scheitert oder
/// die Sperre verlängern würde.
void checkLoginAllowed(
  TypedSettings s,
  String password, {
  required bool userInitiated,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final until = lockedUntil(s, now: t);
  if (until != null) {
    final secs = until.difference(t).inSeconds + 1;
    throw LoginTimeoutException('$secs');
  }
  if (!userInitiated && passwordRejected(s, password)) {
    throw WrongCredentialsException();
  }
}

/// Ergebnis einer echten Anmeldung festhalten ([error] null = Erfolg).
void noteLoginResult(
  TypedSettings s,
  String password,
  Object? error, {
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  if (error == null) {
    s.remove(_rejectedKey);
    s.remove(_lockedKey);
  } else if (error is WrongCredentialsException) {
    s.setString(_rejectedKey, _fingerprint(password));
  } else if (error is LoginTimeoutException) {
    final secs = int.tryParse(error.time.trim()) ?? 60;
    // Etwas Luft, damit der nächste Versuch sicher nach dem Ende liegt.
    s.setString(
      _lockedKey,
      t.add(Duration(seconds: secs + 5)).toIso8601String(),
    );
  }
}

/// Anmelden mit Schutz: vorher prüfen, danach festhalten.
Future<T> guardedLogin<T>(
  TypedSettings s,
  String password,
  Future<T> Function() login, {
  bool userInitiated = false,
}) async {
  checkLoginAllowed(s, password, userInitiated: userInitiated);
  try {
    final r = await login();
    noteLoginResult(s, password, null);
    return r;
  } catch (e) {
    noteLoginResult(s, password, e);
    rethrow;
  }
}

/// last_login eines Kontos auf den Wert vor einer Anmeldung zurücksetzen
/// ([before] null = vorher nie angemeldet).
///
/// Ursache: Session.authenticate (liblanis) setzt last_login bei JEDER
/// Anmeldung, und die App startet mit dem jüngsten Konto
/// (getPreferredStartupAccount). Anmeldungen, die der Nutzer nicht als
/// Wechsel gemeint hat – weitere Konten der Familie, Hintergrundlauf
/// (background_service.dart) –, machten sonst ein anderes Konto „aktiv“.
Future<void> restoreLastLogin(
  LanisDatabase db,
  int id,
  DateTime? before,
) async {
  if (before == null) {
    await db.clearLastLogin(id);
  } else {
    await db.updateLastLogin(id, at: before);
  }
}

/// Höchstalter eines übergebenen Login-Links ([handOverLoginUrl]).
const loginUrlHandoffMaxAge = Duration(seconds: 60);

final _loginUrls = <int, ({String url, DateTime at})>{};

/// Login-Link einer eben erfolgreichen Passwort-Prüfung für die gleich
/// folgende Anmeldung des Kontos [accountId] hinterlegen.
///
/// Ursache (Prüfung 27.10.26, Befund 9): Neues Konto (view/login/auth.dart)
/// und neues Passwort (changeAccountPassword, fork/ui/login_errors.dart)
/// prüfen das Passwort mit LanisSession.getLoginURL – das IST die Anmeldung
/// beim Portal (Benutzer/Passwort an login.schulportal.hessen.de). Die
/// anschließende Anmeldung (Session.authenticate) schickte dieselben Daten
/// ein zweites Mal: zwei Anmeldungen je Konto, der Link der ersten blieb
/// ungenutzt. Jetzt löst Session.authenticate(withLoginUrl:) diesen Link
/// ein – wie liblanis' eigener Weg (EasyAccounts.validateCredentials →
/// EasyLanisClient.login(loginUrl:)). Eingelöst wird er in
/// AuthController._authenticate (aktives Konto) und FamilyScope._start
/// (weiteres Konto).
///
/// Grenze: nur einmal und nur [loginUrlHandoffMaxAge] lang; danach (oder
/// wenn ein anderes Konto angemeldet wird) meldet sich die App wie bisher
/// selbst an. Wie lange das Portal den Link annimmt, ist nicht belegt – in
/// beiden Abläufen liegen nur Sekunden dazwischen. Leere Links (getLoginURL
/// ohne Weiterleitung) werden nicht hinterlegt.
void handOverLoginUrl(int accountId, String url, {DateTime? now}) {
  if (url.isEmpty) return;
  _loginUrls[accountId] = (url: url, at: now ?? DateTime.now());
}

/// Hinterlegten Login-Link des Kontos holen und verbrauchen; null = keiner
/// (oder zu alt).
String? takeLoginUrl(int accountId, {DateTime? now}) {
  final h = _loginUrls.remove(accountId);
  if (h == null) return null;
  final age = (now ?? DateTime.now()).difference(h.at);
  if (age.isNegative || age > loginUrlHandoffMaxAge) return null;
  return h.url;
}

/// Nur für Tests: alle hinterlegten Links vergessen.
void clearLoginUrlHandoffs() => _loginUrls.clear();
