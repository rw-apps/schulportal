import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:html/parser.dart' show parse;
import 'package:lanis/fork/timetable_fix.dart';
import 'package:lanis/fork/ui/live/live_data.dart';

String _row(String label, String time, List<String> cells) =>
    '<tr><td><span class="hidden-xs print-show"><b>$label</b><br />'
    '<span class="VonBis"><small>$time</small></span></span></td>'
    '${cells.map((c) => c.isEmpty ? '<td>&nbsp;</td>' : '<td rowspan="1"><div class="stunde"><b>$c</b> R1 <br /><small> AB </small></div></td>').join()}</tr>';

/// Aufbau wie Schule A (Export 16.10.26), erfundene Einträge: erste Zeile
/// ist der 0. Block mit Klassenstunde.
String _html(String tbody) =>
    '<div id="all"><table><tbody>$tbody</tbody></table></div>'
    '<div id="own"><table><tbody>$tbody</tbody></table></div>';

void main() {
  test('0. Block in der ersten Zeile bleibt erhalten', () {
    final tt = parseTimetableKeepingFirstRow(
      parse(
        _html(
          [
            _row('0. Block', '08:00 - 08:45', ['KL', 'KL', 'KL', 'KL', 'KL']),
            _row('1.Block', '09:00 - 10:15', ['M', 'D', '', 'E', 'M']),
          ].join(),
        ),
      ),
    );
    final p = livePlan(tt: tt, lessons: const [], firstName: 'A').plan;
    expect(p.slots.map((s) => s.start), ['08:00', '09:00']);
    expect(p.days[0][0].options.single.short, 'KL');
    expect(p.days[0][1].options.single.short, 'M');
    expect(p.days[2][1].isEmpty, isTrue);
  });

  test('leere erste Zeile bleibt übersprungen', () {
    final tt = parseTimetableKeepingFirstRow(
      parse(
        _html(
          [
            _row('0. Stunde', '07:10 - 07:55', ['', '', '', '', '']),
            _row('1. Stunde', '08:00 - 08:45', ['M', 'D', 'E', 'F', 'G']),
          ].join(),
        ),
      ),
    );
    final p = livePlan(tt: tt, lessons: const [], firstName: 'A').plan;
    expect(p.slots.map((s) => s.start), ['08:00']);
    expect(p.days[4][0].options.single.short, 'G');
  });

  test('Seite ohne Plantabelle ist ein Fehler, kein leerer Plan', () {
    LanisClient.configure();
    addTearDown(LanisClient.reset);
    final container = ProviderContainer(overrides: LanisClient.overrides);
    addTearDown(container.dispose);
    final account = ClearTextAccount(
      localId: 1,
      schoolID: 1,
      username: 'x',
      password: 'x',
      schoolName: 'X',
      accountType: AccountType.student,
    );
    final db = container.read(lanisDatabaseProvider);
    final session = LanisSession(
      account: account,
      config: LanisClient.config!,
      connectionChecker: ConnectionChecker(),
    );
    final parser = ForkTimetableParser(
      AppletContext(
        session: session,
        database: db,
        account: account,
        accountSettings: TypedSettings.shared(db),
      ),
    );
    expect(
      () => parser.parseDocument(
        parse(
          '<html><body><table><tr><td>Anmeldung</td></tr></table></body></html>',
        ),
      ),
      throwsA(isA<UnknownException>()),
    );
    // Mit Tabelle, aber ohne Einträge: leerer Plan, kein Fehler.
    final empty = parser.parseDocument(
      parse(
        '<div id="all"><table><tbody><tr><td></td></tr></tbody></table></div>',
      ),
    );
    expect(empty.planForAll, isEmpty);
  });

  // Fehlerbericht 27.10.26: Art der Seite ohne Plan, ohne Inhalte.
  test('Seite ohne Plan: Anmeldung, Wartung, Länge', () {
    final login = emptyTimetablePageKind(
      parse('<html><body><form><input type="password"></form></body></html>'),
    );
    expect(login, {
      'login': 1,
      'wartung': 0,
      'text': 0,
      'anmeld': 0,
      'weiter': 0,
    });
    final down = emptyTimetablePageKind(
      parse(
        '<html><body><p>Das Schulportal ist wegen Wartung nicht '
        'erreichbar.</p></body></html>',
      ),
    );
    expect(down['wartung'], 1);
    expect(down['login'], 0);
    expect(down['text'], 1);
    // Fehlerbericht 30.10.26: Sitzungsende mit Weiterleitung.
    final gone = emptyTimetablePageKind(
      parse(
        '<html><head><script>window.location="index.php"</script></head>'
        '<body><p>Sie wurden abgemeldet.</p></body></html>',
      ),
    );
    expect(gone['anmeld'], 1);
    expect(gone['weiter'], 1);
    expect(down['anmeld'], 0);
    expect(down['weiter'], 0);
  });
}
