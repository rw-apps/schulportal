/// Link, der Google Kalender mit „Kalender hinzufügen?“ für [feed] öffnet.
///
/// Ursache (Wunsch 18.10.26): Abonnieren per Adresse geht bei Google nur
/// auf der Webseite (Weitere Kalender → Per URL); Kopieren und Einfügen am
/// Handy ist umständlich. Google nimmt die Adresse als `cid` mit Schema
/// `webcal://` an (nicht offiziell dokumentiert, verbreitet genutzt:
/// til.simonwillison.net/ics/google-calendar-ics-subscribe-link). Grenze:
/// Google holt abonnierte Kalender höchstens etwa einmal am Tag neu; geht
/// das Format bei Google einmal verloren, bleibt „Adresse kopieren“.
Uri googleCalendarSubscribeUrl(String feed) {
  final f = feed.trim();
  final webcal = f.replaceFirst(RegExp(r'^(https?|webcal)://'), 'webcal://');
  return Uri.https('calendar.google.com', '/calendar/render', {
    'cid': webcal.startsWith('webcal://') ? webcal : 'webcal://$webcal',
  });
}
