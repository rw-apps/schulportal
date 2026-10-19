import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import '../l10n/l10n.dart';
import '../login_guard.dart';
import 'kit.dart';

/// Überschrift und Erklärung zu einem Anmeldefehler – für Menschen, nicht
/// für Entwickler.
///
/// Ursache (Rückmeldung 19.10.26, Bildschirmfoto „Kritischer Fehler! …
/// LoginTimeoutException: Too many failed logins. Wait 16s“): Die Fehler-
/// seite der Vorlage zeigte den englischen Fehlertyp und bat, ihn zu melden
/// – auch bei Fällen, die gar kein Fehler der App sind (gesperrtes Konto,
/// falsches Passwort, Portal nicht erreichbar).
({String title, String text}) loginErrorText(ForkL10n t, Object e) =>
    switch (e) {
      WrongCredentialsException() => (
        title: t.loginWrongTitle,
        text: t.loginWrongText,
      ),
      LoginTimeoutException(:final time) => (
        title: t.loginLockedTitle,
        text: t.loginLockedText(int.tryParse(time.trim()) ?? 60),
      ),
      LanisDownException() => (title: t.loginDownTitle, text: t.loginDownText),
      NoConnectionException() || NetworkException() => (
        title: t.loginOfflineTitle,
        text: t.loginOfflineText,
      ),
      CredentialsIncompleteException() => (
        title: t.loginWrongTitle,
        text: t.loginIncompleteText,
      ),
      _ => (title: t.loginOtherTitle, text: t.loginOtherText),
    };

/// Neues Passwort für das Konto [accountId] abfragen, beim Portal prüfen und
/// speichern. true = gespeichert.
///
/// Geprüft wird mit EINER Anmeldung (LanisSession.getLoginURL) – nicht
/// während einer Sperre des Portals, die verlängerte sie nur
/// (login_guard.dart). Grenze: Ein falsch getipptes neues Passwort zählt
/// beim Portal als Fehlversuch; die Meldung sagt das.
Future<bool> changeAccountPassword(
  BuildContext context,
  WidgetRef ref,
  int accountId,
) async {
  final t = context.t;
  final k = Kit.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final db = ref.read(lanisDatabaseProvider);
  final config = ref.read(lanisConfigProvider);
  final account = await db.getAccount(accountId);
  if (account == null || !context.mounted) return false;
  final settings = TypedSettings.account(db, accountId);
  final until = lockedUntil(settings);
  if (until != null) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          t.loginLockedText(until.difference(DateTime.now()).inSeconds + 1),
        ),
      ),
    );
    return false;
  }
  final controller = TextEditingController();
  final pw = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(t.passwordNewTitle, style: k.sheetTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              if (account.schoolName.isNotEmpty) account.schoolName,
              account.username,
            ].join(' · '),
            style: k.meta,
          ),
          const SizedBox(height: Sp.m),
          TextField(
            controller: controller,
            obscureText: true,
            autocorrect: false,
            autofocus: true,
            autofillHints: const [AutofillHints.password],
            style: k.body,
            decoration: InputDecoration(labelText: t.passwordNewLabel),
            onSubmitted: (v) => Navigator.pop(c, v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: Text(t.cancel, style: k.link),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, controller.text),
          child: Text(t.save),
        ),
      ],
    ),
  );
  controller.dispose();
  if (pw == null || pw.isEmpty) return false;
  try {
    await LanisSession.getLoginURL(account.copyWith(password: pw), config);
  } catch (e) {
    noteLoginResult(settings, pw, e);
    messenger?.showSnackBar(SnackBar(content: Text(loginErrorText(t, e).text)));
    return false;
  }
  await ref.read(accountsProvider.notifier).updatePassword(accountId, pw);
  noteLoginResult(settings, pw, null);
  return true;
}
