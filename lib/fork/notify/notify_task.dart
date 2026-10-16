import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/applets/substitutions/background.dart';
import 'package:lanis/background_service.dart';
import 'package:lanis/utils/applet_settings.dart';
import 'package:lanis/utils/logger.dart';

import '../lessons_parent.dart';
import '../parent_support.dart';
import '../ui/live/live_data.dart';
import '../ui/plan/plan_from_lanis.dart' show subjectFullName;
import '../ui/plan/plan_model.dart';
import '../ui/today/today_from_lanis.dart' show classFromCourses;
import 'notices.dart';

/// Schlüssel der schon gemeldeten Einträge (je Konto).
const sentNoticesSetting = 'fork-notify/sent';

/// Hintergrundaufgabe für vertretungsplan.php (ersetzt die Lanis-Aufgabe).
///
/// Ursache (Konzept 17.10.26): Lanis meldete bei jeder Änderung ALLE Zeilen
/// des Vertretungsplans der Klasse, auch die der anderen Gruppen und ohne
/// Bezug zur eigenen Stunde. Jetzt: nur, was die Stunden des Kindes betrifft
/// (gleiche Zuordnung wie „Heute“, applySubstitutions), heute sofort, für den
/// nächsten Schultag gesammelt ab 19 Uhr, dazu große Termine; Ruhezeit
/// 21–6 Uhr (buildNotices).
///
/// Grenze: Ohne Stundenplan im Portal (z. B. Lehrkräfte) läuft die
/// bisherige Lanis-Aufgabe weiter. Android lässt die App nur etwa alle 15
/// bis 60 Minuten nachsehen (Einstellung „Benachrichtigungen“), die Meldung
/// kann also so viel später kommen.
Future<void> forkSubstitutionsTask(
  ProviderContainer container,
  AccountType accountType,
  BackgroundTaskToolkit tools,
) async {
  final session = container.read(sessionProvider).asData?.value;
  if (session == null) return;
  bool offers(AppletMeta a) =>
      forkSupportsApplet(a, accountType, session.travelMenu);
  final timetableMeta = Applets.byPhpUrl('stundenplan.php');
  if (!offers(timetableMeta)) {
    await substitutionsBackgroundTask(container, accountType, tools);
    return;
  }
  final now = DateTime.now();
  if (inQuietHours(now)) return;

  // Ein Fehler hier darf die Schleife über die Konten nicht abbrechen
  // (callbackDispatcher, background_service.dart): sonst entfiele für alle
  // folgenden Konten die Meldung und das Abmelden (Prüfbefund 17.10.26).
  final TimeTable tt;
  final SubstitutionPlan subs;
  try {
    tt = await container.read(timetableParserProvider).getHome();
    subs = await container.read(substitutionsParserProvider).getHome();
  } catch (e, st) {
    backgroundLogger.w('Fork-Benachrichtigung übersprungen: $e');
    backgroundLogger.e(e, stackTrace: st);
    return;
  }
  Lessons lessons = const [];
  try {
    if (offers(Applets.byPhpUrl('meinunterricht.php'))) {
      lessons = await container.read(lessonsStudentParserProvider).getHome();
    }
  } catch (_) {
    // Ohne Namen geht es auch (Kürzel statt Namen).
  }
  final parser = container.read(lessonsStudentParserProvider);
  final kids = parser is LessonsParentAwareParser
      ? parser.lastKids
      : const <ChildLessons>[];
  // Schülerkonto (keine Kinder): ohne Namen („Heute in der Schule“). Die
  // Anmeldung im Hintergrund lädt keine Benutzerdaten (withoutData).
  final firstName = kids.isNotEmpty ? kids.first.firstName : '';

  var events = const <CalendarEvent>[];
  if (now.hour >= eveningHour) {
    try {
      if (offers(Applets.byPhpUrl('kalender.php'))) {
        events = await container
            .read(calendarParserProvider)
            .getCalendar(
              startDate: now,
              endDate: now.add(const Duration(days: 3)),
            );
      }
    } catch (_) {
      // Ohne Kalender bleiben die Vertretungen.
    }
  }

  final s = tools.settings;
  final userChoice = settingStrings(
    resolveStoredAppletSetting(
      s,
      'stundenplan.php/$groupChoiceSetting',
      const <String, dynamic>{},
    ),
  );
  final ownNames = settingStrings(
    resolveStoredAppletSetting(
      s,
      'stundenplan.php/$teacherNamesSetting',
      const <String, dynamic>{},
    ),
  );
  final schoolId = session.account.schoolID.toString();
  final (:plan, :auto) = livePlan(
    tt: tt,
    lessons: lessons,
    firstName: firstName,
    schoolId: schoolId,
  );
  final courses = [for (final l in lessons) l.name];
  final sent = [
    for (final k in s.getJsonList(sentNoticesSetting) ?? const []) '$k',
  ];
  final notices = buildNotices(
    plan: plan.withTeacherNames(ownNames),
    choice: effectiveChoice(auto, userChoice),
    substitutions: subs.days,
    events: events,
    now: now,
    className: session.userData['klasse'] ?? classFromCourses(courses),
    sent: sent.toSet(),
    subjectName: (c) => subjectFullName(c, courses, schoolId: schoolId),
  );
  var remembered = sent;
  for (final n in notices) {
    await tools.sendMessage(
      title: n.title,
      message: n.lines.join('\n'),
      id: n.id,
      importance: Importance.high,
    );
    remembered = rememberKeys(remembered, n.keys);
  }
  if (notices.isNotEmpty) s.setJsonList(sentNoticesSetting, remembered);
}
