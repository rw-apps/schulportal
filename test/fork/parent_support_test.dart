import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/timetable/definition.dart';
import 'package:lanis/applets/timetable/routes.dart';
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
    expect(
      AppDefinitions.getByPhpIdentifier('abwesenheitsmeldung.php').routePath,
      '/parent/absence/home',
    );
  });

  test('Schüler unverändert, Lehrkraft bekommt keinen Stundenplan dazu', () {
    expect(forkSupportsApplet(Applets.timetable, AccountType.student, schoolA), isTrue);
    expect(forkSupportsApplet(Applets.timetable, AccountType.teacher, schoolA), isFalse);
  });

  test('Stundenplan hat einen Routen-Zweig je Kontoart', () {
    final ctx = AppletRouteContext(
      rootNavigatorKey: GlobalKey<NavigatorState>(),
      homeBody: (_) => throw UnimplementedError(),
    );
    final paths = buildTimetableRoutes(ctx).whereType<GoRoute>().map((r) => r.path);
    expect(paths, containsAll(['/student/timetable', '/parent/timetable']));
    expect(timeTableDefinition.supportedAccountTypes, contains(AccountType.parent));
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
