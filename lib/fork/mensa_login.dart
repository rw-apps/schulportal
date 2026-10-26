import 'dart:convert';

import 'package:liblanis/liblanis.dart' show SecretStore;

import '../bridge/flutter_secret_store.dart';

/// Gemerkte Anmeldung beim Caterer je Kind (`konto:kind`, MensaPage.owner).
///
/// Ursache (Wunsch 27.10.26): Die Anmeldung der eingebetteten Seite hielt
/// nur bis zum Schließen der App (die Caterer setzen Sitzungs-Cookies, ein
/// „Angemeldet bleiben“ gibt es bei beiden nicht). Danach zeigte „Essen“
/// wieder die Anmeldeseite, und Heute kannte kein Essen. Jetzt fragt die App
/// nach einer Anmeldung einmal, ob sie sie merken soll, und meldet sich bei
/// abgelaufener Sitzung selbst an (MensaPage, MealFetcher).
///
/// Sicherheit:
/// - Benutzername und Passwort liegen nur im geschützten Speicher des
///   Geräts (Android Keystore, wie das Schulportal-Passwort).
/// - Eingesetzt nur auf genau dem Host, auf dem sie eingegeben wurden
///   ([MensaLogin.host]); die eingebettete Seite lässt ohnehin nur die
///   eingetragene Seite zu (mensaAllows).
/// - Je Seitenaufruf höchstens ein Versuch: Schlägt er fehl (Passwort
///   geändert), zeigt die App die Anmeldeseite wie bisher.
/// Grenze: Mit Captcha oder Bestätigungscode geht es nicht.
class MensaLogin {
  const MensaLogin({
    required this.host,
    required this.user,
    required this.pass,
  });

  final String host;
  final String user;
  final String pass;
}

/// Austauschbar für Tests.
SecretStore mensaSecrets = FlutterSecretStore();

String _key(String owner) => 'fork-mensa-login/$owner';

/// Gemerkte Anmeldung; null = keine bzw. abgelehnt.
Future<MensaLogin?> readMensaLogin(String owner) async {
  try {
    final raw = await mensaSecrets.read(_key(owner));
    final v = raw == null ? null : jsonDecode(raw);
    if (v is! Map || v['never'] == true) return null;
    final h = v['h'], u = v['u'], p = v['p'];
    if (h is! String || u is! String || p is! String) return null;
    return MensaLogin(host: h, user: u, pass: p);
  } catch (_) {
    return null;
  }
}

/// Hat man „Nicht merken“ gewählt? Dann fragt die App nicht wieder.
Future<bool> mensaLoginDeclined(String owner) async {
  try {
    final raw = await mensaSecrets.read(_key(owner));
    final v = raw == null ? null : jsonDecode(raw);
    return v is Map && v['never'] == true;
  } catch (_) {
    return false;
  }
}

Future<void> saveMensaLogin(String owner, MensaLogin l) => mensaSecrets.write(
  _key(owner),
  jsonEncode({'h': l.host, 'u': l.user, 'p': l.pass}),
);

Future<void> declineMensaLogin(String owner) =>
    mensaSecrets.write(_key(owner), jsonEncode({'never': true}));

/// Beim Löschen der Bestelladresse (live_data.setMensaUrl) mit löschen.
Future<void> forgetMensaLogin(String owner) async {
  try {
    await mensaSecrets.delete(_key(owner));
  } catch (_) {}
}

/// Name des Kanals, über den [mensaLoginCaptureJs] meldet.
const mensaLoginChannel = 'ForkMensaLogin';

/// Liest beim Absenden (Formular, Knopf, Eingabetaste) Benutzername und
/// Passwort aus der Seite und meldet sie an die App. Benutzername = das
/// letzte ausgefüllte Text-, E-Mail- oder Telefonfeld vor dem Passwortfeld
/// (im selben Formular, sonst auf der Seite). Grenze: Seiten, die das
/// Passwort außerhalb eines Eingabefelds abfragen, erkennt es nicht.
const mensaLoginCaptureJs = r'''
(function () {
  if (window.__forkLoginHook) return;
  window.__forkLoginHook = true;
  function grab() {
    var ps = document.querySelectorAll('input[type=password]');
    var pw = null;
    for (var i = 0; i < ps.length; i++) { if (ps[i].value) { pw = ps[i]; break; } }
    if (!pw) return;
    var ins = (pw.form || document).querySelectorAll('input');
    var user = null;
    for (var j = 0; j < ins.length; j++) {
      var x = ins[j];
      if (x === pw) break;
      var ty = (x.type || 'text').toLowerCase();
      if ((ty === 'text' || ty === 'email' || ty === 'tel') && x.value) user = x;
    }
    if (!user) return;
    try {
      ForkMensaLogin.postMessage(JSON.stringify(
        { u: user.value, p: pw.value, h: location.host }));
    } catch (e) {}
  }
  document.addEventListener('submit', grab, true);
  document.addEventListener('click', function (e) {
    var t = e.target;
    if (t && t.closest && t.closest('button,input[type=submit],a')) grab();
  }, true);
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') grab();
  }, true);
})();
''';

/// Füllt eine sichtbare Anmeldemaske mit [l] und sendet sie ab; Ergebnis
/// „filled“ bzw. „none“ (keine Maske gefunden). Werte als JSON eingesetzt,
/// damit Anführungszeichen im Passwort nichts kaputt machen.
String mensaLoginFillJs(MensaLogin l) =>
    '''
(function (u, p) {
  function shown(x) { return !!(x.offsetWidth || x.offsetHeight || x.getClientRects().length); }
  var ps = Array.prototype.filter.call(
    document.querySelectorAll('input[type=password]'), shown);
  if (!ps.length) return 'none';
  var pw = ps[0];
  var ins = (pw.form || document).querySelectorAll('input');
  var user = null;
  for (var j = 0; j < ins.length; j++) {
    var x = ins[j];
    if (x === pw) break;
    var ty = (x.type || 'text').toLowerCase();
    if ((ty === 'text' || ty === 'email' || ty === 'tel') && shown(x)) user = x;
  }
  if (!user) return 'none';
  var set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
  function put(el, v) {
    set.call(el, v);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }
  put(user, u);
  put(pw, p);
  var f = pw.form;
  var b = (f || document).querySelector('button[type=submit],input[type=submit]') ||
    (f ? f.querySelector('button') : null);
  // Ohne Formular: nächster Knopf in der Umgebung des Passwortfelds.
  for (var a = pw.parentElement, n = 0; !b && a && n < 5; a = a.parentElement, n++) {
    b = a.querySelector('button,input[type=submit],[role=button]');
  }
  setTimeout(function () {
    if (b) b.click();
    else if (f) { if (f.requestSubmit) f.requestSubmit(); else f.submit(); }
  }, 50);
  return 'filled';
})(${jsonEncode(l.user)}, ${jsonEncode(l.pass)})
''';
