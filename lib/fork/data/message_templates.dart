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
