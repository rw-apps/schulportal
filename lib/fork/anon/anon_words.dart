/// Wörter, die der anonyme Export (anonymizer.dart) unverändert lässt:
/// Beschriftungen des Portals und deutsche Füllwörter. Alles andere wird
/// verwürfelt.
///
/// Ursache (Entscheidung 25.10.26): Ohne die festen Beschriftungen
/// („Vertreter“, „entfällt“, Spaltenköpfe) ist der Aufbau einer Seite nicht
/// mehr zu erkennen; die Parser (liblanis SubstitutionsParser, TimetableParser,
/// LessonsTeacherParser) suchen genau nach ihnen.
///
/// Grenze: Ein Nachname, der zugleich ein Wort dieser Liste ist („Neu“,
/// „Kurz“), bliebe außerhalb von Namensspalten stehen. Deshalb enthält die
/// Liste bewusst keine Eigenschaftswörter, die häufige Nachnamen sind
/// (klein, lang, weiß, schwarz, braun, fröhlich …), und in Namensspalten
/// gilt sie gar nicht (Anonymizer.text, names: true). Die Lehrkraft sieht
/// vor dem Teilen die Liste aller stehen gebliebenen Wörter.
library;

const anonKeepWords = <String>{
  // Füllwörter
  'der', 'die', 'das', 'den', 'dem', 'des', 'ein', 'eine', 'einen', 'einem',
  'einer', 'eines', 'und', 'oder', 'aber', 'mit', 'ohne', 'von', 'vom', 'zu',
  'zum', 'zur', 'im', 'in', 'ins', 'am', 'an', 'auf', 'aus', 'bei', 'bis',
  'für', 'nach', 'vor', 'über', 'unter', 'ab', 'als', 'auch', 'noch', 'nur',
  'nicht', 'kein', 'keine', 'keinen', 'alle', 'allen', 'jetzt', 'hier', 'wird',
  'werden', 'wurde', 'ist', 'sind', 'hat', 'haben', 'kann', 'können', 'bitte',
  'sie', 'ihr', 'ihre', 'ihren', 'sich', 'es', 'er', 'wir', 'du', 'dein',
  'deine', 'mein', 'meine', 'meinen', 'sowie', 'bzw', 'ggf', 'z', 'b', 'ca',
  'nr', 'neu', 'neue', 'neuen', 'neuer', 'heute', 'morgen', 'gestern',
  'diese', 'dieser', 'dieses', 'gibt', 'zeigen', 'zeige', 'anzeigen',
  // Fächer (Rückmeldung zum Entwurf 26.10.26: ohne sie sähe die Demo
  // keine echten Fächer; ein Fach ist keine Person). Bewusst nur
  // ausgeschriebene Namen: Fachkürzel („BIO“, „ETHI“) sehen aus wie
  // Lehrerkürzel und werden verwürfelt.
  'deutsch', 'mathematik', 'mathe', 'englisch', 'französisch', 'latein',
  'spanisch', 'italienisch', 'biologie', 'chemie', 'physik', 'geschichte',
  'erdkunde', 'geographie', 'politik', 'wirtschaft', 'powi', 'religion',
  'evangelische', 'katholische', 'ev', 'kath', 'ethik', 'philosophie',
  'sport', 'musik', 'kunst', 'informatik', 'darstellendes', 'spiel',
  'naturwissenschaften',
  'gesellschaftslehre',
  'arbeitslehre',
  'förderunterricht',
  'klassenlehrerstunde', 'tutorium', 'ag',
  // Zeit
  'montag', 'dienstag', 'mittwoch', 'donnerstag', 'freitag', 'samstag',
  'sonntag', 'mo', 'di', 'mi', 'do', 'fr', 'sa', 'so', 'januar', 'februar',
  'märz', 'april', 'mai', 'juni', 'juli', 'august', 'september', 'oktober',
  'november', 'dezember', 'jan', 'feb', 'mär', 'apr', 'jun', 'jul', 'aug',
  'sep', 'okt', 'nov', 'dez', 'uhr', 'tag', 'tage', 'woche', 'wochen',
  'monat', 'jahr', 'schuljahr', 'halbjahr', 'datum', 'zeit', 'uhrzeit',
  'beginn', 'ende', 'start', 'ganztägig', 'ganzer', 'ganzen', 'std',
  'stunde', 'stunden', 'pause', 'kw', 'ferien', 'feiertag',
  // Vertretungsplan
  'vertretung', 'vertretungen', 'vertretungsplan', 'vertreter',
  'vertreterkuerzel', 'vertreterin', 'lehrer', 'lehrerin', 'lehrerkuerzel',
  'lehrkraft', 'lehrkräfte', 'klasse', 'klassen', 'fach', 'fächer', 'raum',
  'räume', 'hinweis', 'hinweise', 'art', 'entfall', 'entfällt', 'fällt',
  'ausfall', 'statt', 'verlegung', 'verlegt', 'raumänderung', 'raumwechsel',
  'betreuung', 'aufsicht', 'freisetzung', 'sondereinsatz', 'klausur',
  'klausuren', 'prüfung', 'eva', 'selbststudium', 'aufgaben', 'plan',
  'stand', 'aktualisiert', 'zuletzt', 'nachrichten', 'abwesend',
  'abwesende', 'abwesenheit', 'abwesenheiten', 'gültig', 'lerngruppe',
  'lerngruppen', 'kurs', 'kurse', 'kurses', 'kursmappe', 'unterricht',
  'ausfälle', 'zusatz', 'zusatzstunde', 'tausch', 'mitbetreuung',
  // Mein Unterricht, Kalender, Dateien
  'thema', 'themen', 'inhalt', 'inhalte', 'hausaufgabe',
  'hausaufgaben', 'erledigt', 'offen', 'anwesenheit', 'anwesenheiten',
  'anwesend', 'fehlend', 'entschuldigt', 'unentschuldigt', 'verspätet',
  'noten', 'note', 'punkte', 'leistung', 'leistungen', 'bewertung',
  'kommentar', 'bemerkung', 'bemerkungen', 'eintrag', 'einträge', 'abgabe',
  'abgaben', 'hochladen', 'upload', 'datei', 'dateien', 'ordner',
  'dateispeicher', 'größe', 'download', 'herunterladen', 'kalender',
  'termin', 'termine', 'kategorie', 'kategorien', 'ort', 'beschreibung',
  'verantwortlich', 'öffentlich', 'privat', 'schule', 'schüler',
  'schülerin', 'schülerinnen', 'eltern', 'teilnehmer', 'mitglieder',
  'buch', 'heft', 'hefte', 'historie', 'übersicht', 'details', 'detail',
  'information', 'informationen', 'info', 'infos', 'name', 'vorname',
  'nachname', 'kürzel', 'stundenplan', 'gesamt', 'liste', 'tabelle',
  'aktuell', 'aktuelle', 'aktuellen', 'vorherige', 'nächste', 'zurück',
  'weiter', 'speichern', 'abbrechen', 'löschen', 'bearbeiten', 'drucken',
  'suche', 'suchen', 'filter', 'gruppe', 'gruppen', 'auswahl', 'wählen',
  'login', 'logout', 'abmelden', 'startseite', 'hilfe', 'kontakt',
  'impressum', 'datenschutz', 'schulportal', 'hessen', 'portal', 'apps',
  'modul', 'module', 'benutzer', 'konto', 'profil', 'einstellungen',
  'ja', 'nein', 'leer', 'fehler', 'erfasst', 'sichtbar',
  'php', 'html', 'pdf', 'jpg', 'png', 'docx', 'xlsx', 'pptx', 'txt',
  'true', 'false', 'null', 'all', 'my', 'view', 'ajax',
};
