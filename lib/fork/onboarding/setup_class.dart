import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import '../lessons_parent.dart';
import '../ui/today/today_from_lanis.dart' show classFromCourses;

/// Klasse und Vorname direkt nach der Anmeldung, für „Konto eingerichtet“
/// (Entwurf 20.10.26 k3). [show] = false für Lehrkräfte.
///
/// Ursache für die eigene Abfrage: Bei der Einrichtung läuft LiveDataScope
/// noch nicht. Schülerkonten nennen die Klasse in den Benutzerdaten,
/// Elternkonten nur in den Kursnamen – dafür eine Anfrage an
/// meinunterricht.php (höchstens 10 s). Grenze: Scheitert sie, steht
/// „Klasse nicht erkannt“, und die App erkennt sie später beim Laden.
typedef SetupClass = ({String detected, String kidName, bool show});

Future<SetupClass> detectSetupClass(WidgetRef ref) async {
  try {
    final session = await ref.read(sessionProvider.future);
    if (session == null) return (detected: '', kidName: '', show: false);
    final type = session.accountTypeOrNull;
    if (type == AccountType.teacher) {
      return (detected: '', kidName: '', show: false);
    }
    final own = (session.userData['klasse'] ?? '').trim();
    final student = (session.userData['vorname'] ?? '').trim();
    if (own.isNotEmpty) {
      return (
        detected: own,
        kidName: type == AccountType.parent ? '' : student,
        show: true,
      );
    }
    if (!ref
        .read(supportedAppletPhpUrlsProvider)
        .contains('meinunterricht.php')) {
      return (
        detected: '',
        kidName: type == AccountType.parent ? '' : student,
        show: true,
      );
    }
    final parser = ref.read(lessonsStudentParserProvider);
    final lessons = await parser.getHome().timeout(const Duration(seconds: 10));
    final kids = parser is LessonsParentAwareParser
        ? parser.lastKids
        : const <ChildLessons>[];
    return (
      detected: classFromCourses([for (final l in lessons) l.name]),
      kidName: kids.isNotEmpty
          ? kids.first.firstName
          : (type == AccountType.parent ? '' : student),
      show: true,
    );
  } catch (_) {
    return (detected: '', kidName: '', show: true);
  }
}
