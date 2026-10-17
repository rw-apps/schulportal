/// Normalisiert eine eingetragene Adresse der Mensa-Bestellseite:
/// „bestellung.example.de“ → „https://bestellung.example.de“; leer = null.
///
/// Die Adresse trägt jede Familie selbst ein (Mehr → Essen bestellen),
/// gespeichert je Konto auf dem Gerät. Ursache: Eine feste Zuordnung
/// Schulnummer → Caterer im Code verriet im öffentlichen Repository die
/// Schule (Entscheidung 17.10.26). Grenze: Die App öffnet nur die Seite im
/// Browser; Anmeldung und Bestellung bleiben dort, kein Passwort in der App.
String? normalizeMensaUrl(String? raw) {
  final t = raw?.trim() ?? '';
  if (t.isEmpty) return null;
  final withScheme = RegExp(r'^https?://', caseSensitive: false).hasMatch(t)
      ? t
      : 'https://$t';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) return null;
  return withScheme;
}

/// Bietet die Schule eine Lernplattform (Moodle) an?
///
/// Ursache: Lanis zeigte „Moodle öffnen“ bei jedem Konto (home_page.dart);
/// Schule A führt Moodle aber nicht in ihrer App-Liste (Export 16.10.26:
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
