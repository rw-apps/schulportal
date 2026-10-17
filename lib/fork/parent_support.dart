import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:riverpod/misc.dart' show Override;

import 'absence/absence_parser.dart';
import 'lessons_parent.dart';
import 'timetable_fix.dart';

/// Module, die der Fork über liblanis hinaus für weitere Kontoarten freigibt.
///
/// Ursache: liblanis bindet `stundenplan.php` fest an Schülerkonten
/// (Applets.timetable in liblanis/src/applets/definition.dart). Ein
/// Elternkonto von Schule A bekommt den Klassenplan aber
/// vollständig (Debug-Export 16.10.26 10:47: 302 auf
/// `stundenplan.php?a=detail_klasse…&p=<Kind>`, danach 200 mit `#all` und
/// `#own`), und TimetableStudentParser.parseDocumentHtml liest ihn fehlerfrei
/// (5 Tage, 4 Blöcke).
///
/// Grenze: Nur Module, deren Auslese für die Kontoart nachgewiesen ist.
/// `meinunterricht.php` erlaubt liblanis für Eltern bereits, der Schülerparser
/// stürzt dort aber ab (fehlendes `#mappen`, Eltern-Reiter heißen
/// `mappen<Kind-ID>`) — das regelt ein eigener Eltern-Parser, nicht diese Liste.
const forkExtraAccountTypes = <String, Set<AccountType>>{
  'stundenplan.php': {AccountType.parent},
};

/// Wie Session.doesSupportFeature in liblanis, plus [forkExtraAccountTypes].
bool forkSupportsApplet(
  AppletMeta applet,
  AccountType type,
  List<dynamic> travelMenu,
) {
  final offered = travelMenu.any(
    (e) => e is Map && e['link']?.toString() == applet.appletPhpUrl,
  );
  if (!offered) return false;
  return applet.supportedAccountTypes.contains(type) ||
      (forkExtraAccountTypes[applet.appletPhpUrl]?.contains(type) ?? false);
}

/// Riverpod-Overrides des Forks, angehängt in bridge/lanis_bootstrap.dart.
///
/// Ersetzt supportedAppletPhpUrlsProvider (liblanis core_providers.dart)
/// durch dieselbe Logik mit [forkSupportsApplet]. Die Abhängigkeiten
/// (sessionFeatureEpoch, session, aktives Konto) bleiben identisch, damit
/// Aktualisierung nach Anmeldung/Kontowechsel unverändert funktioniert.
List<Override> forkProviderOverrides() => [
  // Eltern-Übersicht für meinunterricht.php (fork/lessons_parent.dart);
  // Schüler laufen unverändert durch LessonsStudentParser.getHome.
  lessonsStudentParserProvider.overrideWith((ref) {
    final ctx = ref.watch(appletContextProvider);
    final parser = LessonsParentAwareParser(
      ctx,
      isConnected: () => ref.read(connectionCheckerProvider).connected,
    );
    ref.onDispose(parser.dispose);
    return parser;
  }),
  // 0. Stunde/Block in der ersten Tabellenzeile (fork/timetable_fix.dart).
  timetableParserProvider.overrideWith((ref) {
    final ctx = ref.watch(appletContextProvider);
    final parser = ForkTimetableParser(
      ctx,
      isConnected: () => ref.read(connectionCheckerProvider).connected,
    );
    ref.onDispose(parser.dispose);
    return parser;
  }),
  supportedAppletPhpUrlsProvider.overrideWith((ref) {
    ref.watch(sessionFeatureEpochProvider);
    final session = ref.watch(sessionProvider).asData?.value;
    final account = ref.watch(activeAccountProvider);
    if (session == null || account == null) return const {};
    final type = account.accountType ?? session.accountTypeOrNull;
    if (type == null) return const {};
    return {
      // Fork-Module (Krankmeldung) laufen durch dieselbe Prüfung: nur wenn
      // die Schule sie in der App-Liste führt und die Kontoart passt.
      for (final applet in [...Applets.all, ...forkApplets])
        if (forkSupportsApplet(applet, type, session.travelMenu))
          applet.appletPhpUrl,
    };
  }),
];
