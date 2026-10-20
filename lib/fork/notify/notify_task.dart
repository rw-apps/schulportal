import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/applets/substitutions/background.dart';
import 'package:lanis/background_service.dart';
import 'package:lanis/utils/applet_settings.dart';
import 'package:lanis/utils/logger.dart';

import '../courses_scan.dart';
import '../l10n/l10n.dart';
import '../lessons_parent.dart';
import '../parent_support.dart';
import '../ui/language.dart' show languageKey;
import '../ui/live/live_data.dart';
import '../ui/courses/courses_model.dart';
import '../ui/plan/plan_from_lanis.dart' show subjectFullName;
import '../ui/plan/plan_model.dart';
import '../class_choice.dart';
import '../data_storage.dart';
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
/// nächsten Schultag gesammelt ab 19 Uhr, dazu große Termine; Zeitfenster
/// aus den Einstellungen (isTaskWithinConstraints, background_service.dart).
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
  // Nichts darf aus dieser Aufgabe herausfallen: Ein Fehler bräche in
  // callbackDispatcher (background_service.dart) die Schleife über alle
  // Konten samt Abmelden ab (Prüfbefund 17.10.26). Grenze: Die Anmeldung
  // selbst liegt davor im Dispatcher (Lanis-Code) und ist hier nicht
  // abgedeckt.
  try {
    await _run(container, accountType, tools);
  } catch (e, st) {
    backgroundLogger.w('Fork-Benachrichtigung übersprungen: $e');
    backgroundLogger.e(e, stackTrace: st);
  }
}

Future<void> _run(
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
  // Ohne Namen: Schülerkonto „Heute in der Schule“, Elternkonto ohne
  // geladene Kinder (Unterricht fehlgeschlagen) „bei deinem Kind“
  // (buildNotices, parent).
  final firstName = kids.isNotEmpty ? kids.first.firstName : '';
  // Sprache wie in der App (Einstellungen → Darstellung → Sprache); im
  // Hintergrund gibt es keinen Widget-Baum, daher direkt aus der Einstellung.
  String? chosen;
  try {
    chosen = container
        .read(sharedOverAccountSettingsProvider)
        .getString(languageKey);
  } catch (_) {}
  final t = forkL10nFor(
    resolveLanguage(chosen, PlatformDispatcher.instance.locale.languageCode),
  );

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
  final (:plan, :auto) = livePlan(
    tt: tt,
    lessons: lessons,
    firstName: firstName,
    lessonTimes: storedLessonTimes(s),
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
    t: t,
    parent: accountType == AccountType.parent,
    // Eigener Eintrag (class_choice.dart), sonst nur aus den Kursnamen: Die
    // Anmeldung im Hintergrund lädt keine Benutzerdaten
    // (authenticate(withoutData: true), background_service).
    className: storedClass(s)?.name ?? classFromCourses(courses),
    sent: sent.toSet(),
    subjectName: (c) => subjectFullName(c, courses),
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

  if (offersStorage(session.travelMenu)) {
    await _storageNews(
      session: session,
      s: s,
      firstName: firstName,
      t: t,
      tools: tools,
      now: now,
    );
  }

  if (offers(Applets.byPhpUrl('meinunterricht.php')) && lessons.isNotEmpty) {
    await _courseNews(
      container: container,
      s: s,
      items: courseItemsFrom(lessons, ownNames: ownNames, plan: plan),
      firstName: firstName,
      t: t,
      tools: tools,
      now: now,
    );
  }
}

/// Ab dieser Stunde sieht der Hintergrund einmal täglich in die Kursmappen.
/// Ursache: Lehrkräfte tragen Noten und Arbeitstermine meist nach dem
/// Unterricht ein; ein Abruf am Morgen fände den Vortag, der Hinweis käme
/// einen Tag zu spät.
const courseScanHour = 15;

/// Kennung der Meldung „Neu im Unterricht“ (notices.dart nutzt 1 und 2;
/// sendMessage verlangt 0–10000).
const courseNewsId = 3;

/// Kennung der Meldung „Neue Datei der Schule“.
const storageNewsId = 4;

/// Neue Dateien im Dateispeicher melden (data_storage.dart, Wunsch
/// 20.10.26) – höchstens alle [storageCheckEvery].
///
/// Ursache für das Merken der Kennungen: Der Kasten „Neue Dateien“ zeigt
/// eine Datei, bis sie heruntergeladen ist; ohne Merken käme dieselbe
/// Meldung bei jedem Lauf. Beim ersten Lauf wird nur gemerkt
/// (unseenFiles). Grenze: Dateien, die nur in Unterordnern liegen und nicht
/// im Kasten erscheinen, meldet die App nicht.
Future<void> _storageNews({
  required LanisSession session,
  required TypedSettings s,
  required String firstName,
  required ForkL10n t,
  required BackgroundTaskToolkit tools,
  required DateTime now,
}) async {
  final last = DateTime.tryParse(s.getString(storageCheckedSetting) ?? '');
  if (last != null && now.difference(last) < storageCheckEvery) return;
  final StorageView home;
  try {
    home = await loadStorage(session, 0);
  } catch (e) {
    backgroundLogger.w('Dateispeicher übersprungen: ${e.runtimeType}');
    return;
  }
  s.setString(storageCheckedSetting, now.toIso8601String());
  final raw = s.getString(storageSeenSetting);
  final seen = raw == null ? null : decodeSeen(raw);
  final fresh = unseenFiles(home, seen);
  s.setString(
    storageSeenSetting,
    encodeSeen({...?seen, for (final f in home.newFiles) f.id}),
  );
  if (fresh.isEmpty) return;
  await tools.sendMessage(
    title: firstName.isEmpty
        ? t.storageNoticeTitle
        : t.storageNoticeTitleFor(firstName),
    message: [for (final f in fresh) f.name].join('\n'),
    id: storageNewsId,
    importance: Importance.defaultImportance,
  );
}

/// Neue Noten und Arbeitstermine melden – höchstens einmal am Tag.
///
/// Lädt jede Kursseite des laufenden Halbjahrs (nacheinander, wie
/// GradesView) und vergleicht mit der gespeicherten Auswertung
/// (courses_scan.dart, newsSince). Die Meldung nennt nur das Fach, nie die
/// Note. Ursache: Hinweise stehen auch auf dem Sperrbildschirm. Grenze: rund
/// 15 Abrufe je Konto und Tag; schlagen alle fehl, versucht es der nächste
/// Lauf erneut, schlagen einzelne fehl, behalten diese Kurse ihren alten
/// Stand (scanFrom).
Future<void> _courseNews({
  required ProviderContainer container,
  required TypedSettings s,
  required List<CourseItem> items,
  required String firstName,
  required ForkL10n t,
  required BackgroundTaskToolkit tools,
  required DateTime now,
}) async {
  final old = storedCourseScan(s);
  final today = DateTime(now.year, now.month, now.day);
  if (now.hour < courseScanHour) return;
  if (old != null && !old.day.isBefore(today)) return;
  final parser = container.read(lessonsStudentParserProvider);
  final pages = <String, DetailedLesson>{};
  for (final c in items) {
    try {
      pages[c.id] = await parser.getDetailedCourseView(
        courseUrl(c.id, firstHalf: false),
        force: true,
      );
    } catch (e) {
      backgroundLogger.w('Kursseite übersprungen: ${e.runtimeType}');
    }
  }
  if (pages.isEmpty) return;
  final fresh = scanFrom(items, pages, now, old: old);
  final news = newsSince(old, fresh, {for (final c in items) c.id: c.title});
  storeCourseScan(s, fresh);
  final lines = [
    for (final subject in news.marks) t.noticeNewMark(subject),
    for (final e in news.exams)
      t.noticeNewExam(e.subject, e.kind, formatDate(t, t.dateShort, e.day)),
  ];
  if (lines.isEmpty) return;
  await tools.sendMessage(
    title: firstName.isEmpty
        ? t.courseNewsTitle
        : t.courseNewsTitleFor(firstName),
    message: lines.join('\n'),
    id: courseNewsId,
    importance: Importance.defaultImportance,
  );
}
