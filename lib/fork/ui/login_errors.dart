import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import '../l10n/l10n.dart';
import '../login_guard.dart';
import '../portal_fault.dart';
import 'kit.dart';
import 'settings/error_report_page.dart';

/// Überschrift und Erklärung zu einem Anmeldefehler – für Menschen, nicht
/// für Entwickler.
///
/// Ursache (Rückmeldung 19.10.26, Bildschirmfoto „Kritischer Fehler! …
/// LoginTimeoutException: Too many failed logins. Wait 16s“): Die Fehler-
/// seite der Vorlage zeigte den englischen Fehlertyp und bat, ihn zu melden
/// – auch bei Fällen, die gar kein Fehler der App sind (gesperrtes Konto,
/// falsches Passwort, Portal nicht erreichbar).
///
/// Seit 22.10.26 über portalFault (portal_fault.dart): Ein Serverfehler des
/// Portals (HTTP 5xx) hat eine eigene Meldung „Störung beim Schulportal“,
/// statt als „Etwas Unerwartetes“ zu erscheinen. „Keine Verbindung“ nennt
/// beide Möglichkeiten (Gerät offline oder Portal antwortet nicht): Die
/// Prüfung von liblanis (ConnectionChecker.testConnection) fragt nur das
/// Portal selbst und kann sie nicht unterscheiden.
///
/// Texte kurz, ohne Fehlercode und ohne Wegbeschreibung in die
/// Einstellungen (Rückmeldung 22.10.26: „kürzer, klarer, einfacher“; „wie
/// öffne ich die Fehlersuche?“). Der Code steht im Fehlerprotokoll
/// (faultTag), der Weg zum Bericht ist ein Knopf „Fehler melden“
/// (openErrorReport).
({String title, String text}) loginErrorText(ForkL10n t, Object e) {
  final f = portalFault(e);
  return switch (f.kind) {
    FaultKind.wrongCredentials => (
      title: t.loginWrongTitle,
      text: t.loginWrongText,
    ),
    FaultKind.locked => (
      title: t.loginLockedTitle,
      text: t.loginLockedText(
        e is LoginTimeoutException ? int.tryParse(e.time.trim()) ?? 60 : 60,
      ),
    ),
    FaultKind.down => (title: t.loginDownTitle, text: t.loginDownText),
    FaultKind.server => (title: t.loginServerTitle, text: t.loginServerText),
    FaultKind.unreachable => (
      title: t.loginOfflineTitle,
      text: t.loginOfflineText,
    ),
    FaultKind.incomplete => (
      title: t.loginWrongTitle,
      text: t.loginIncompleteText,
    ),
    FaultKind.other => (title: t.loginOtherTitle, text: t.loginOtherText),
  };
}

/// Ein Satz zur Ursache, wenn eine Seite nicht laden konnte („Der
/// Stundenplan ließ sich nicht laden.“ + Grund); null = Ursache unklar.
/// Ursache wie bei [loginErrorText]: Ohne Grund wirkte jeder Ausfall des
/// Portals wie ein Fehler der App.
String? loadFailureReason(ForkL10n t, Object? e) {
  if (e == null) return null;
  final f = portalFault(e);
  return switch (f.kind) {
    FaultKind.server => t.reasonServer,
    FaultKind.down => t.reasonDown,
    FaultKind.unreachable => t.reasonUnreachable,
    // Seite kam an, ließ sich aber nicht lesen – meist unbekannter Aufbau
    // (Lehrerkonto, andere Schule). Dazu „Anonym senden“ (page_report.dart).
    FaultKind.other => t.reasonUnknownPage,
    _ => null,
  };
}

/// „Der Stundenplan ließ sich nicht laden.“ mit Grund, falls bekannt.
String withReason(ForkL10n t, String text, Object? e) {
  final r = loadFailureReason(t, e);
  return r == null ? text : '$text $r';
}

/// Technische Zeile unter „Etwas Unerwartetes“: Fehlertyp und erste Zeile
/// der Meldung, höchstens [max] Zeichen. Ursache (Bildschirmfoto
/// 22.10.26): Der volle Dio-Text füllte zehn Zeilen mit Englisch.
String technicalLine(Object e, {int max = 160}) {
  final cause = e is LanisException ? e.cause : '$e';
  final first = cause.split('\n').first.trim();
  final line = '${e.runtimeType}: $first';
  return line.length <= max ? line : '${line.substring(0, max - 1)}…';
}

/// Neues Passwort für das Konto [accountId] abfragen, beim Portal prüfen und
/// speichern. true = gespeichert.
///
/// Geprüft wird mit EINER Anmeldung (LanisSession.getLoginURL) – nicht
/// während einer Sperre des Portals, die verlängerte sie nur
/// (login_guard.dart). Grenze: Ein falsch getipptes neues Passwort zählt
/// beim Portal als Fehlversuch; die Meldung sagt das.
///
/// Der Login-Link der Prüfung wird für die Anmeldung danach hinterlegt
/// (handOverLoginUrl): „Erneut versuchen“ der Aufrufer (startup.dart →
/// AuthController.retry, login_failure_card.dart → FamilyScope._start)
/// meldet sich damit nicht ein zweites Mal an. Ursache (Prüfung 27.10.26,
/// Befund 9). Grenze: nur innerhalb von [loginUrlHandoffMaxAge].
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
  final String url;
  try {
    url = await LanisSession.getLoginURL(
      account.copyWith(password: pw),
      config,
    );
  } catch (e) {
    noteLoginResult(settings, pw, e);
    messenger?.showSnackBar(SnackBar(content: Text(loginErrorText(t, e).text)));
    return false;
  }
  await ref.read(accountsProvider.notifier).updatePassword(accountId, pw);
  noteLoginResult(settings, pw, null);
  handOverLoginUrl(accountId, url);
  return true;
}

/// Öffnet „Erkannte Probleme“ (ErrorReportPage) direkt – von der
/// Fehlerseite beim Start und von der Karte auf „Heute“. Ursache
/// (Rückmeldung 22.10.26): Der Text verwies auf „Einstellungen →
/// Fehlersuche“; die Fehlerseite beim Start lässt sich aber nicht
/// schließen, die Einstellungen waren von dort gar nicht erreichbar.
Future<void> openErrorReport(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const ErrorReportPage()));
