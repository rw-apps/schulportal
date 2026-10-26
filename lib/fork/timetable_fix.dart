import 'package:html/dom.dart';
import 'package:liblanis/liblanis.dart';

import 'error_log.dart';

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
  var inserted = 0;
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
    inserted++;
  }
  final tt = TimetableStudentParser.parseDocumentHtml(document);
  // Diagnose (Rückmeldung 17.10.26: Plan eines Kontos plötzlich leer): Ein
  // Plan ohne jeden Eintrag landet mit Zählwerten im Fehlerprotokoll –
  // Tabellen, Zeilen, Einträge im HTML, eingefügte Leerzeilen. Keine Inhalte.
  int entries(List<TimetableDay>? d) =>
      d?.fold<int>(0, (a, x) => a + x.length) ?? 0;
  if (entries(tt.planForOwn) == 0 && entries(tt.planForAll) == 0) {
    ErrorLog.instance.notice('stundenplan.php', 'EmptyTimetable', {
      'all': document.querySelector('#all') == null ? 0 : 1,
      'own': document.querySelector('#own') == null ? 0 : 1,
      'rows': document.querySelectorAll('tbody tr').length,
      'stunden': document.querySelectorAll('.stunde').length,
      'vonbis': document.querySelectorAll('.VonBis').length,
      'inserted': inserted,
    });
  }
  return tt;
}

/// Parser mit [parseTimetableKeepingFirstRow]; sonst wie liblanis.
class ForkTimetableParser extends TimetableStudentParser {
  ForkTimetableParser(super.ctx, {super.isConnected});

  /// Seite ohne jede Plantabelle (weder `#all` noch `#own`) gilt als
  /// Fehler, nicht als leerer Plan.
  ///
  /// Ursache (Fehlerbericht 26.10.26: „EmptyTimetable(all=0 own=0 rows=1
  /// stunden=0)“ 7× in drei Tagen, dazu einmal rows=0): Das Portal lieferte
  /// eine Seite ohne Stundenplan – meist eine abgelaufene Sitzung oder eine
  /// Fehlerseite. Als Ergebnis gewertet, überschrieb sie den gespeicherten
  /// Plan (AppletParser._getHome legt jedes Ergebnis offline ab) und die
  /// Woche stand leer da. Jetzt: Fehler → liblanis meldet sich einmal neu an
  /// und versucht es erneut (AppletParser.fetchData, secondTry); scheitert
  /// das auch, bleibt der gespeicherte Plan mit dem Hinweis „Gespeicherter
  /// Stand von …“ (stale_notice.dart).
  ///
  /// Grenze: Eine Seite MIT Tabelle, aber ohne Einträge (z. B. Plan noch
  /// nicht freigegeben) bleibt ein leerer Plan – das kann echt sein.
  @override
  TimeTable parseDocument(Document document) {
    final tt = parseTimetableKeepingFirstRow(document);
    if (document.querySelector('#all') == null &&
        document.querySelector('#own') == null) {
      throw UnknownException('stundenplan.php: keine Plantabelle');
    }
    return tt;
  }
}
