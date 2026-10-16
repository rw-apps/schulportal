import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' show parse;
import 'package:liblanis/liblanis.dart';

import 'absence_form.dart';

/// Modul „Abwesenheiten“ (Krankmeldung), das liblanis nicht kennt.
///
/// Beleg: App-Liste von Schule A für Eltern (Export 16.10.26)
/// enthält `abwesenheitsmeldung.php`; die Seite trägt den Hinweis „Die Schule
/// erlaubt für dieses Kind Meldungen.“ Grenze: Nur Elternkonten; für Schüler-
/// konten liegt keine Antwort vor.
const forkAbsenceApplet = AppletMeta(
  appletPhpUrl: 'abwesenheitsmeldung.php',
  supportedAccountTypes: [AccountType.parent],
  // Die Datumsgrenzen ändern sich mit der Uhrzeit (12-Uhr-Regel), daher
  // kurz; die Maske lädt beim Öffnen ohnehin neu.
  refreshInterval: Duration(minutes: 5),
);

/// Module des Forks, die zusätzlich zu Applets.all geprüft werden.
const forkApplets = [forkAbsenceApplet];

/// Lädt nur das Formular. Absenden gibt es hier bewusst noch nicht, siehe
/// [AbsenceDraft].
class AbsenceParser extends AppletParser<AbsenceForm> {
  AbsenceParser(
    AppletContext ctx, {
    required Future<bool> Function() isConnected,
  }) : super(ctx, forkAbsenceApplet, isConnected: isConnected);

  @override
  Future<AbsenceForm> getHome() async {
    final response = await ctx.session.dio.get(
      'https://start.schulportal.hessen.de/abwesenheitsmeldung.php'
      '?cacheBreaker=${DateTime.now().millisecondsSinceEpoch}',
    );
    final form = parseAbsenceForm(parse(response.data.toString()));
    // Kein Formular heißt fast immer: Sitzung verloren. Werfen, damit
    // AppletParser.fetchData einmal neu anmeldet und es erneut versucht.
    if (form == null) {
      throw UnknownException('abwesenheitsmeldung.php: kein meldungForm');
    }
    return form;
  }
}

final absenceParserProvider = Provider<AbsenceParser>((ref) {
  final ctx = ref.watch(appletContextProvider);
  final parser = AbsenceParser(
    ctx,
    isConnected: () => ref.read(connectionCheckerProvider).connected,
  );
  ref.onDispose(parser.dispose);
  return parser;
});
