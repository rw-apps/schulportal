import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/applets/substitutions/background.dart';
import 'package:lanis/background_service.dart';
import 'package:lanis/utils/applet_settings.dart';
import 'package:lanis/utils/logger.dart';

import '../courses_scan.dart';
import '../kid_name.dart';
import '../exams.dart';
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
import '../portal_extras.dart';
import '../ui/today/today_from_lanis.dart'
    show classFromCourses, weekItemsFromCalendar;
import '../mensa_store.dart';
import '../ui/today/kid_hints.dart' show nextSchoolDay;
import '../ui/today/today_from_lanis.dart' show applySubstitutions;
import '../ui/today/today_model.dart' show hasTime, minutesOf;
import 'notices.dart';
import 'summary.dart';

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
  // Nur der erste Vorname, wie in der App (kid_name.dart). Ohne geladene
  // Kinder (Schülerkonto, Unterricht fehlgeschlagen) der gemerkte Name –
  // beim Schülerkonto nur, wenn mehrere Konten auf dem Gerät sind; allein
  // auf dem eigenen Handy bleibt „Heute in der Schule“.
  final loadedName = kids.isNotEmpty
      ? shortFirstName(kids.first.firstName)
      : '';
  rememberKidName(tools.settings, loadedName);
  final firstName = loadedName.isNotEmpty
      ? loadedName
      : (accountType == AccountType.parent || tools.multiAccount)
      ? storedKidName(tools.settings)
      : '';
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

  // Sammel-Benachrichtigung (summary.dart, Wunsch 27.10.26): Ausfälle und
  // Vertretungen von heute und dem nächsten Schultag sowie nicht bestelltes
  // Essen als aktueller Stand dieses Kontos. Die Einzelmeldungen zu
  // Änderungen entfallen dafür (buildNotices bekommt keine Vertretungen
  // mehr und meldet nur noch große Termine am Vorabend).
  try {
    final shared = container.read(sharedOverAccountSettingsProvider);
    final r = applySubstitutions(
      plan: plan.withTeacherNames(ownNames),
      choice: effectiveChoice(auto, userChoice),
      days: subs.days,
      now: now,
      t: t,
      subjectName: (c) => subjectFullName(c, courses),
    );
    putSummaryItems(
      shared,
      '${tools.accountId}/plan',
      changeSummaryItems(
        scope: '${tools.accountId}',
        name: firstName,
        changes: r.changes,
        now: now,
        next: nextSchoolDay(now),
        t: t,
        endOf: {
          for (final l in r.today)
            l.slot: hasTime(l) ? minutesOf(l.end).minutes : 24 * 60,
        },
      ),
    );
    final cache = MealCache.instance..attach(shared);
    final meals = <SummaryItem>[];
    for (final e in cache.notifier.value.entries) {
      if (!e.key.startsWith('${tools.accountId}:')) continue;
      final kidKey = e.key.substring('${tools.accountId}:'.length);
      final kid = kids.where((k) => k.pupilId == kidKey).firstOrNull;
      meals.addAll(
        mealSummaryItems(
          name: kid == null ? firstName : shortFirstName(kid.firstName),
          owner: e.key,
          days: mealReminderDays(
            e.value,
            now,
            weekdays: mealRemindDays(shared, e.key),
          ),
          now: now,
          t: t,
        ),
      );
    }
    putSummaryItems(shared, '${tools.accountId}/meals', meals);
  } catch (e) {
    backgroundLogger.w('Sammelmeldung übersprungen: ${e.runtimeType}');
  }

  final sent = [
    for (final k in s.getJsonList(sentNoticesSetting) ?? const []) '$k',
  ];
  final notices = buildNotices(
    plan: plan.withTeacherNames(ownNames),
    choice: effectiveChoice(auto, userChoice),
    substitutions: const [],
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

  if (offersModule(session.travelMenu, electionModule)) {
    await _electionNews(
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
      withCalendar: offers(Applets.byPhpUrl('kalender.php')),
      className: storedClass(s)?.name ?? classFromCourses(courses),
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

/// Kennung der Meldung „Wahl offen“.
const electionNewsId = 5;

/// Eine neu geöffnete Wahl im Wahltool melden (portal_extras.dart, Wunsch
/// 20.10.26) – höchstens alle [electionCheckEvery], einmal je Wahl.
///
/// Ursache für das Merken des Stands: Eine Wahl läuft oft Tage; gemeldet
/// wird nur der Wechsel von „keine“ zu „offen“. Grenze: Folgen zwei Wahlen
/// ohne Pause aufeinander, meldet die App nur die erste.
Future<void> _electionNews({
  required LanisSession session,
  required TypedSettings s,
  required String firstName,
  required ForkL10n t,
  required BackgroundTaskToolkit tools,
  required DateTime now,
}) async {
  final last = DateTime.tryParse(s.getString(electionCheckedSetting) ?? '');
  if (last != null && now.difference(last) < electionCheckEvery) return;
  final bool open;
  try {
    open = await loadElectionOpen(session);
  } catch (e) {
    backgroundLogger.w('Wahltool übersprungen: ${e.runtimeType}');
    return;
  }
  s.setString(electionCheckedSetting, now.toIso8601String());
  final before = s.getBool(electionOpenSetting) ?? false;
  s.setBool(electionOpenSetting, open);
  if (!open || before) return;
  await tools.sendMessage(
    title: firstName.isEmpty
        ? t.electionTitlePlain
        : t.electionTitle(firstName),
    message: t.electionText,
    id: electionNewsId,
    importance: Importance.defaultImportance,
  );
}

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
  bool withCalendar = false,
  String className = '',
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

  // Arbeiten, die nur im Schulkalender stehen (exams.dart, gemeinsame
  // Regel). Ursache (Prüfung 20.10.26): Gemeldet wurden bisher nur
  // Kursmappen-Arbeiten. Gemerkt wird, was schon gemeldet ist; der erste
  // Lauf merkt nur (sonst käme jede vorhandene Arbeit als „neu“). Eine schon
  // gemeldete Kalender-Arbeit, die später in der Kursmappe auftaucht, gilt
  // dort nicht noch einmal als neu.
  var calendarExams = const <UpcomingExam>[];
  if (withCalendar) {
    try {
      final events = await container
          .read(calendarParserProvider)
          .getCalendar(startDate: now, endDate: halfYearEnd(now));
      calendarExams = upcomingExamsOf(
        scan: fresh.upcoming(now),
        calendar: weekItemsFromCalendar(
          events,
          now,
          className: className,
          days: daysUntil(now, halfYearEnd(now)),
        ),
        now: now,
        until: halfYearEnd(now),
      ).where((e) => e.fromCalendar).toList();
    } catch (e) {
      backgroundLogger.w('Kalender für Arbeiten: ${e.runtimeType}');
    }
  }
  final known = s.getJsonList(calendarExamsSeenSetting);
  final ex = examNews(
    scanNews: news.exams,
    calendarOnly: calendarExams,
    known: known == null ? null : [for (final k in known) '$k'],
    now: now,
  );
  if (withCalendar) s.setJsonList(calendarExamsSeenSetting, ex.remember);
  final lines = [
    for (final subject in news.marks) t.noticeNewMark(subject),
    for (final e in ex.scan)
      t.noticeNewExam(e.subject, e.kind, formatDate(t, t.dateShort, e.day)),
    for (final e in ex.calendar)
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

/// Gemeldete Kalender-Arbeiten (Schlüssel [calendarExamKey]), je Konto.
const calendarExamsSeenSetting = 'fork-notify/calendar-exams';

/// „2026-11-02|Physik“ – Tag und Fach; die Art zählt nicht (sie ändert sich
/// eher als das Fach, etwa „Test“ → „Lernkontrolle“).
String calendarExamKey(UpcomingExam e) =>
    '${e.day.year.toString().padLeft(4, '0')}-'
    '${e.day.month.toString().padLeft(2, '0')}-'
    '${e.day.day.toString().padLeft(2, '0')}|${e.subject}';

/// Welche Arbeiten melden? [scanNews]: neu in der Kursmappe (newsSince);
/// [calendarOnly]: Kalender-Arbeiten ohne Kursmappen-Eintrag; [known]:
/// schon gemeldete Kalender-Arbeiten (null = erster Lauf, nur merken).
/// Kursmappen-Arbeiten, die schon als Kalender-Arbeit gemeldet wurden,
/// entfallen. [remember]: neuer Merkzettel ohne vergangene Tage.
({List<ScanExam> scan, List<UpcomingExam> calendar, List<String> remember})
examNews({
  required List<ScanExam> scanNews,
  required List<UpcomingExam> calendarOnly,
  required List<String>? known,
  required DateTime now,
}) {
  final seen = {...?known};
  final announced = [
    for (final k in seen)
      UpcomingExam(day: _keyDay(k), subject: _keySubject(k), kind: ''),
  ];
  final today = DateTime(now.year, now.month, now.day);
  return (
    scan: [
      for (final e in scanNews)
        if (!announced.any((c) => sameExam(e, c))) e,
    ],
    calendar: known == null
        ? const []
        : [
            for (final e in calendarOnly)
              if (!seen.contains(calendarExamKey(e))) e,
          ],
    remember: [
      for (final k in {...seen, ...calendarOnly.map(calendarExamKey)})
        if (!_keyDay(k).isBefore(today)) k,
    ],
  );
}

DateTime _keyDay(String k) =>
    DateTime.tryParse(k.split('|').first) ?? DateTime(2000);

String _keySubject(String k) {
  final i = k.indexOf('|');
  return i < 0 ? '' : k.substring(i + 1);
}

/// Nach allen Konten: Sammel-Benachrichtigung zeigen bzw. entfernen
/// (summary.dart). [accounts]: Konten mit erlaubten Benachrichtigungen –
/// Einträge anderer (gelöschter, abgeschalteter) Konten fallen weg.
Future<void> showForkSummary(
  ProviderContainer container,
  Set<int> accounts,
) async {
  try {
    final shared = container.read(sharedOverAccountSettingsProvider);
    String? chosen;
    try {
      chosen = shared.getString(languageKey);
    } catch (_) {}
    final t = forkL10nFor(
      resolveLanguage(chosen, PlatformDispatcher.instance.locale.languageCode),
    );
    pruneSummarySources(shared, {for (final a in accounts) '$a'});
    await showSummary(shared, t);
  } catch (e) {
    backgroundLogger.w('Sammelmeldung: ${e.runtimeType}');
  }
}
