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
