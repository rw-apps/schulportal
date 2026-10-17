import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/absence/absence_parser.dart';
import 'package:lanis/fork/parent_support.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:liblanis/liblanis.dart';

void main() {
  // App-Liste von Schule A (nur Modulnamen, keine Personendaten).
  const schoolA = [
    {'link': 'abwesenheitsmeldung.php'},
    {'link': 'kalender.php'},
    {'link': 'meinunterricht.php'},
    {'link': 'nachrichten.php'},
    {'link': 'stundenplan.php'},
    {'link': 'vertretungsplan.php'},
  ];

  test('Eltern: Stundenplan freigegeben, nicht angebotene Module nicht', () {
    expect(forkSupportsApplet(Applets.timetable, AccountType.parent, schoolA), isTrue);
    expect(forkSupportsApplet(Applets.dataStorage, AccountType.parent, schoolA), isFalse);
    expect(forkSupportsApplet(Applets.studyGroups, AccountType.parent, schoolA), isFalse);
  });

  test('Krankmeldung: nur Eltern und nur, wenn die Schule sie anbietet', () {
    expect(forkSupportsApplet(forkAbsenceApplet, AccountType.parent, schoolA), isTrue);
    expect(forkSupportsApplet(forkAbsenceApplet, AccountType.student, schoolA), isFalse);
    expect(
      forkSupportsApplet(forkAbsenceApplet, AccountType.parent, const [
        {'link': 'stundenplan.php'},
      ]),
      isFalse,
    );
  });

  test('Schüler unverändert, Lehrkraft bekommt keinen Stundenplan dazu', () {
    expect(forkSupportsApplet(Applets.timetable, AccountType.student, schoolA), isTrue);
    expect(forkSupportsApplet(Applets.timetable, AccountType.teacher, schoolA), isFalse);
  });

  test('veralteter Schülerpfad wird für Eltern umgeschrieben', () {
    // Ablauf vom 16.10.26: Zweig-Startpfad /student/… für ein Elternkonto.
    expect(
      rewriteAccountTypedPrefix('/student/timetable/home', AccountType.parent),
      '/parent/timetable/home',
    );
    expect(
      rewriteAccountTypedPrefix('/student/lessons/home?x=1', AccountType.teacher),
      '/teacher/lessons/home?x=1',
    );
    expect(rewriteAccountTypedPrefix('/parent/timetable/home', AccountType.parent), isNull);
    expect(rewriteAccountTypedPrefix('/common/substitutions/home', AccountType.parent), isNull);
    expect(rewriteAccountTypedPrefix('/welcome', AccountType.parent), isNull);
  });
}
