/// Verweise, die nur an einer Schule gelten (Schulnummer → Adresse).
///
/// Mensa: Die Schule A (0000) lässt das Mittagessen über den
/// Caterer Caterer bestellen (Angabe der Eltern 17.10.26 mit
/// Bildschirmfoto der Anmeldeseite). Grenze: Die App öffnet nur die Seite im
/// Browser; Anmeldung und Bestellung bleiben dort, die App speichert kein
/// Passwort. Andere Schulen haben (noch) keinen Eintrag – dann kein Knopf.
const mensaLinks = <String, String>{
  '0000': 'https://example.org/login/',
};

String? mensaUrlFor(String schoolId) => mensaLinks[schoolId];

/// Bietet die Schule eine Lernplattform (Moodle) an?
///
/// Ursache: Lanis zeigte „Moodle öffnen“ bei jedem Konto (home_page.dart);
/// die Schule A führt Moodle aber nicht in ihrer App-Liste (Export 16.10.26:
/// Abwesenheiten, Dateiverteilung, Kalender, mein Unterricht, Nachrichten,
/// Stundenplan, Vertretungsplan, Videokonferenz …), und das Öffnen schlug
/// fehl (Rückmeldung 17.10.26). Erkannt am Eintrag der App-Liste
/// (Session.travelMenu): Name oder Link mit „Moodle“/„Lernplattform“ oder
/// eine Moodle-Instanz des Landes (mo1234.schulportal.hessen.de). Grenze:
/// Nennt eine Schule ihre Plattform anders, fehlt der Knopf – lieber das als
/// ein Knopf, der ins Leere führt.
bool offersMoodle(List<dynamic> travelMenu) => travelMenu.any((e) {
  if (e is! Map) return false;
  final text = '${e['Name'] ?? ''} ${e['link'] ?? ''}'.toLowerCase();
  return text.contains('moodle') ||
      text.contains('lernplattform') ||
      RegExp(r'\bmo\d+\.schulportal').hasMatch(text);
});
