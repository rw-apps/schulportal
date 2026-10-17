import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Route der neuen Oberfläche (fork/ui/preview/preview_shell.dart).
const forkHomePath = '/fork/home';

/// Startseite nach Anmeldung, Kontowechsel und Datenschutz-Bestätigung –
/// immer die neue Oberfläche (Entscheidung 17.10.26, bisherige Ansicht
/// entfernt). Früher in home_page.dart.
String firstSupportedHomePath(WidgetRef ref) => forkHomePath;

/// Wie [firstSupportedHomePath], für Stellen mit [Ref] (Router).
String firstSupportedHomePathFromRef(Ref ref) => forkHomePath;
