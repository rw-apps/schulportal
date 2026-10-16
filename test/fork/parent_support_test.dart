import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/timetable/definition.dart';
import 'package:lanis/applets/timetable/routes.dart';
import 'package:lanis/fork/parent_support.dart';
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
}
