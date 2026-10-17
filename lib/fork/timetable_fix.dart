import 'package:html/dom.dart';
import 'package:liblanis/liblanis.dart';

/// Stundenplan mit Einträgen in der ersten Tabellenzeile (0. Stunde/Block).
///
/// Ursache (Bildschirmfoto Portal vs. App 17.10.26): liblanis
/// (TimetableStudentParser.parseRoomPlan/parseRows) überspringt die erste
/// Zeile jeder Tabelle als „leere Kopfzeile“. Schule A führt dort aber den
/// 0. Block (KL, 08:00–08:45, an allen fünf Tagen; Beleg auch im Export vom
/// 16.10.26) – die Klassenstunde fehlte daher in Heute und Kalender. Jetzt:
/// Steht in der ersten Zeile ein Eintrag (`.stunde`), wird davor eine leere
/// Zeile eingefügt, die liblanis überspringen darf; Zeiten und Rowspans
/// bleiben dabei richtig zugeordnet (dieselbe Rechnung wie für Folgezeilen).
/// Grenze: Eine leere 0. Zeile (Schule B, „0. Stunde“ ohne Einträge) bleibt
/// unverändert übersprungen.
TimeTable parseTimetableKeepingFirstRow(Document document) {
  for (final id in const ['all', 'own']) {
    final tbody = document.querySelector('#$id tbody');
    if (tbody == null || tbody.children.isEmpty) continue;
    final first = tbody.children.first;
    if (first.querySelector('.stunde') == null) continue;
    final dummy = Element.tag('tr');
    for (var i = 0; i < first.children.length; i++) {
      dummy.append(Element.tag('td'));
    }
    tbody.insertBefore(dummy, first);
  }
  return TimetableStudentParser.parseDocumentHtml(document);
}

/// Parser mit [parseTimetableKeepingFirstRow]; sonst wie liblanis.
class ForkTimetableParser extends TimetableStudentParser {
  ForkTimetableParser(super.ctx, {super.isConnected});

  @override
  TimeTable parseDocument(Document document) =>
      parseTimetableKeepingFirstRow(document);
}
