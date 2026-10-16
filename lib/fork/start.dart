import 'package:liblanis/liblanis.dart' show TypedSettings;

/// Route der neuen Oberfläche (fork/ui/preview/preview_shell.dart).
const forkHomePath = '/fork/home';

/// Geräteweite Einstellung: Startet die App mit der neuen Oberfläche?
///
/// Ursache: Konzept 17.10.26 – Umstellung, sobald Heute, Kalender, Unterricht
/// und Nachrichten im neuen Stil fertig sind (Version 4.1.0+9326). Grenze:
/// Die bisherige Ansicht bleibt vollständig erreichbar („Mehr“ → „Alle
/// Funktionen“) und lässt sich unter „Mehr“ wieder als Start wählen.
const newUiStartKey = 'fork-ui/start-new';

bool newUiIsStart(TypedSettings shared) =>
    shared.getBool(newUiStartKey) ?? true;
