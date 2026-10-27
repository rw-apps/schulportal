import 'package:liblanis/liblanis.dart';

/// Ob [html] die Vertretungsplan-Seite einer angemeldeten Sitzung ist – auch
/// eine ganz ohne Vertretungen.
///
/// Merkmale aus liblanis substitutions/parser.dart: Tage als `data-tag`
/// (:214, :328), Tagesblöcke `#tagDD_MM_YYYY` (:221), Tabellen `#vtable…`
/// (:247), „Letzte Aktualisierung“ (:345). Dazu, für einen leeren Plan ohne
/// Tagesblöcke, der Seitentitel „Vertretungsplan – Schulportal Hessen“
/// (Aufbau wie demo_pages.dart _page) und der Abmelde-Link
/// `index.php?logout`, den nur angemeldete Seiten tragen (liblanis
/// session.dart:165 meldet über genau diese Adresse ab).
///
/// Grenze: Eine leere Planseite des echten Portals lag nicht als Beleg vor;
/// die beiden letzten Merkmale sind die Absicherung dafür. Fehlen auch sie,
/// zeigt die App den gespeicherten Stand mit Hinweis statt „keine
/// Vertretungen“ – das ist der sichere Fehler.
bool looksLikeSubstitutionPage(String html) {
  if (html.contains('data-tag=')) return true;
  if (RegExp(
    r'''id\s*=\s*["']?(tag\d{2}_\d{2}_\d{4}|vtable)''',
  ).hasMatch(html)) {
    return true;
  }
  if (RegExp(r'Letzte\s+Aktualisierung', caseSensitive: false).hasMatch(html)) {
    return true;
  }
  if (RegExp(
    r'<title>\s*Vertretungsplan',
    caseSensitive: false,
  ).hasMatch(html)) {
    return true;
  }
  return html.contains('index.php?logout');
}

/// SubstitutionsParser, der eine Seite ohne Vertretungsplan als Fehler
/// meldet statt als leeren Plan.
///
/// Ursache (Prüfung 27.10.26, liblanis substitutions/parser.dart:84–93 und
/// :325–339): Eine abgelaufene Sitzung liefert auf `vertretungsplan.php`
/// eine 302 ohne Inhalt bzw. die Anmeldeseite (Dio folgt nicht,
/// session.dart:92; 302 gilt als Erfolg, :94). getSubstitutionDates findet
/// keine Tage, parseSubstitutionsNonAJAX keine Blöcke – heraus kommt ein
/// LEERER Plan ohne Fehler. Damit meldete sich liblanis nicht neu an
/// (applet_parser.dart:150–153 nur im Fehlerfall), legte den leeren Plan
/// offline ab und überschrieb den guten (applet_parser.dart:187–193); die
/// App zeigte „keine Vertretungen“. Jetzt: Fehler → einmal neu anmelden und
/// erneut versuchen; scheitert das auch, bleibt der gespeicherte Plan mit
/// „Gespeicherter Stand von …“ (stale_notice.dart). Gleiches Muster wie
/// ForkTimetableParser (timetable_fix.dart).
///
/// Grenze: Geprüft wird nur die Hauptseite (getSubstitutionPlanDocument,
/// auch im Hintergrundlauf über getHome). Die Tages-Abrufe (AJAX) prüft
/// liblanis selbst (parseAjaxDayJson wirft bei HTML, parser.dart:117).
class ForkSubstitutionsParser extends SubstitutionsParser {
  ForkSubstitutionsParser(super.ctx, {super.isConnected});

  @override
  Future<String> getSubstitutionPlanDocument() async {
    final html = await super.getSubstitutionPlanDocument();
    checkSubstitutionPage(html);
    return html;
  }
}

/// Wirft, wenn [html] keine Vertretungsplan-Seite ist
/// ([looksLikeSubstitutionPage]); die Fehlerseite des Portals wie liblanis
/// (getSubstitutionDates, parser.dart:325) als UnauthorizedException.
void checkSubstitutionPage(String html) {
  if (html.contains('Fehler - Schulportal Hessen - ')) {
    throw UnauthorizedException();
  }
  if (!looksLikeSubstitutionPage(html)) {
    throw UnknownException('vertretungsplan.php: keine Planseite');
  }
}
