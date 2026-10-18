/// Vorlagen für Betreff und Textanfang einer neuen Nachricht (nur Daten).
///
/// Ursache Deutsch: Die Nachricht geht an die Schule, die Deutsch liest –
/// Betreff und Text bleiben daher in jeder App-Sprache deutsch; nur die
/// Beschriftung der Auswahl wird übersetzt (Schlüssel [id] in ForkL10n,
/// siehe compose_page.dart). Grenze: neue Vorlagen brauchen dort einen
/// eigenen Schlüssel.
class MessageTemplate {
  const MessageTemplate(this.id, this.subject, this.text);

  final String id;
  final String subject;
  final String text;
}

const messageTemplates = <MessageTemplate>[
  MessageTemplate(
    'homeworkQuestion',
    'Frage zur Hausaufgabe',
    'Guten Tag,\n\nwir haben eine Frage zur Hausaufgabe: ',
  ),
  MessageTemplate(
    'callback',
    'Bitte um Rückruf',
    'Guten Tag,\n\nkönnten Sie uns bitte zurückrufen? Wir sind erreichbar unter ',
  ),
  MessageTemplate(
    'appointment',
    'Termin vereinbaren',
    'Guten Tag,\n\nwir würden gern einen Gesprächstermin vereinbaren. ',
  ),
];

/// Entschuldigung für eine Fehlstunde (Wunsch 18.10.26): Betreff und Text
/// an die Lehrkraft des Fachs. Deutsch aus demselben Grund wie oben. Der
/// Grund bleibt offen („Grund: “) – den kennt nur die Familie; die Seite
/// setzt den Cursor dorthin. Grenze: Anrede ohne Namen („Guten Tag“), weil
/// das Portal Lehrkräfte teils nur mit Kürzel nennt.
({String subject, String text}) absenceExcuse({
  required String child,
  required String subject,
  required String when,
}) => (
  subject: 'Entschuldigung $child – $subject am $when',
  text:
      'Guten Tag,\n\n'
      '$child hat am $when im Fach $subject gefehlt.\n'
      'Grund: \n\n'
      'Bitte entschuldigen Sie das Fehlen.\n\n'
      'Mit freundlichen Grüßen\n',
);
