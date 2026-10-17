import 'data/portal_rules.dart';

/// Normalisiert eine eingetragene Adresse der Mensa-Bestellseite:
/// „bestellung.example.de“ → „https://bestellung.example.de“; leer = null.
///
/// Die Adresse trägt jede Familie selbst ein (Mehr → Essen bestellen),
/// gespeichert je Kind auf dem Gerät (mensa.dart). Ursache: Eine feste
/// Zuordnung Schulnummer → Caterer im Code verriet im öffentlichen
/// Repository die Schule (Entscheidung 17.10.26). Die Seite öffnet in der App
/// (MensaPage); das Passwort tippt man in die Seite des Caterers, die App
/// speichert es nicht – nur dessen Sitzungs-Cookie bleibt im WebView.
///
/// Sicherheitsprüfung 17.10.26: nur https („http://“ wird zu https), keine
/// Anmeldedaten in der Adresse („user@host“ wird abgelehnt) – sonst ließe
/// sich eine täuschende Adresse eintragen oder weitergeben.
String? normalizeMensaUrl(String? raw) {
  final t = raw?.trim() ?? '';
  if (t.isEmpty) return null;
  final withScheme = RegExp(r'^https?://', caseSensitive: false).hasMatch(t)
      ? t.replaceFirst(RegExp(r'^http://', caseSensitive: false), 'https://')
      : 'https://$t';
  final uri = Uri.tryParse(withScheme);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      !uri.host.contains('.') ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri.toString();
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

/// Vorschlag für die Mensa-Bestellseite aus der App-Liste der Schule.
///
/// Ursache (Wunsch 17.10.26): Manche Schulen führen die Essensbestellung als
/// externen Link in ihrer App-Liste; dann muss die Familie die Adresse nicht
/// suchen. Erkannt an [PortalRules.mensaLink] in Name oder Link; nur
/// Adressen außerhalb des Schulportals und nur, was [normalizeMensaUrl]
/// annimmt. Grenze: Nur ein Vorschlag – die Familie bestätigt ihn im Dialog;
/// führt die Schule keinen Link, bleibt das Feld leer wie bisher.
String? mensaSuggestion(List<dynamic> travelMenu) {
  for (final e in travelMenu) {
    if (e is! Map) continue;
    final link = '${e['link'] ?? ''}'.trim();
    final text = '${e['Name'] ?? ''} $link';
    if (!PortalRules.mensaLink.hasMatch(text)) continue;
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(link)) continue;
    final url = normalizeMensaUrl(link);
    if (url == null) continue;
    final host = Uri.parse(url).host.toLowerCase();
    if (host == 'schulportal.hessen.de' ||
        host.endsWith('.schulportal.hessen.de')) {
      continue;
    }
    return url;
  }
  return null;
}
