import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parse;
import 'package:lanis/fork/absence/absence_form.dart';
import 'package:lanis/fork/absence/absence_parser.dart';
import 'package:lanis/fork/demo/demo_mode.dart';
import 'package:lanis/fork/demo/demo_pages.dart';
import 'package:lanis/fork/demo/demo_school.dart';
import 'package:lanis/fork/homework_ledger.dart';

/// Demo-Prüfung 27.10.26: Krankmeldung, Archiv „Nicht abgehakt“.
void main() {
  final now = DateTime(2026, 10, 27, 10);

  test('Demo-Krankmeldung: Formular lesbar, Prüfung zulässig', () {
    final f = parseAbsenceForm(parse(absencePage(demoParent, DemoClock(now))))!;
    expect(f.allowedPupils.map((p) => p.firstName), ['Jonas']);
    expect(f.kinds.length, 2);
    expect(f.blocks.length, 4);
    expect(f.fromRange?.first, DateTime(2026, 10, 27));
    expect(f.defaultFrom, DateTime(2026, 10, 27));
    expect(f.rules, isNotEmpty);
    expect(parseAbsenceCheck(absenceCheckJson).ok, isTrue);
    expect(appsJson(demoParent), contains('abwesenheitsmeldung.php'));
    expect(appsJson(demoStudent), isNot(contains('abwesenheitsmeldung.php')));
  });

  test('Demo-Protokoll: eine alte Aufgabe ist abgelaufen', () {
    final ledger = demoHomeworkLedger(now);
    final x = homeworkLists(
      const [],
      ledger,
      subjectOf: (l) => l.name,
      now: now,
    );
    expect(x.open, isEmpty);
    expect(x.expired.single.subject, 'Geschichte');
    expect(x.done, isEmpty);
  });
}
