import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/applets/conversations/chat_pages.dart'
    show ConversationChatPage;
import 'package:lanis/applets/lessons/student/upload_page.dart';
import 'package:lanis/utils/file_operations.dart' as fo;

import '../../courses_scan.dart';
import '../../homework_ledger.dart';
import '../../lessons_student.dart' show fixedLessonFileUrl;
import '../../l10n/l10n.dart';
import '../login_errors.dart';
import '../live/page_report.dart';
import '../kit.dart';
import '../nav.dart';
import '../live/live_data.dart';
import '../live/stale_notice.dart';
import '../messages/compose_model.dart';
import '../messages/compose_page.dart';
import '../plan/plan_model.dart';
import '../live/family.dart';
import '../../exams.dart';
import '../today/today_from_lanis.dart'
    show freeDaysFrom, weekItemsFromCalendar;
import '../today/today_model.dart' show WeekItem;
import 'course_detail_model.dart';
import 'course_detail_page.dart';
import 'courses_model.dart';
import 'courses_page.dart';
import 'grades_view.dart';
import 'absences_page.dart';
import 'homework_archive.dart';
import 'homework_due.dart';

/// „Unterricht“ mit echten Daten (LiveDataScope, Quelle „Mein Unterricht“).
/// Antippen öffnet die neue Kursseite ([CourseDetailPage]); sie lädt die
/// Kursmappe über denselben Parser wie die bisherige Lanis-Seite
/// (getDetailedCourseView), der auch Elternkonten liest (Kurs-ID mit
/// „&p=Kind“, parseParentLessons).
class LiveCoursesPage extends ConsumerWidget {
  const LiveCoursesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LiveGate(
      needsTimetable: false,
      builder: (context, s) {
        final t = context.t;
        if (!s.offers('meinunterricht.php')) {
          return CoursesPage(items: const [], firstName: s.firstName);
        }
        if (s.lessons.failed) {
          return LiveMessage(
            text: withReason(t, t.coursesFailed, s.lessons.error),
            style: Kit.of(context).meta,
            action: Wrap(
              children: [
                ?pageReportButton(
                  context,
                  session: s.session,
                  phpUrl: 'meinunterricht.php',
                  error: s.lessons.error,
                ),
                TextButton(
                  onPressed: s.refresh,
                  child: Text(t.retry, style: Kit.of(context).link),
                ),
              ],
            ),
          );
        }
        final live = s.offers('stundenplan.php') && s.timetable.content != null
            ? livePlanOf(s)
            : null;
        final raw = courseItemsFrom(
          s.lessons.content ?? const [],
          ownNames: s.ownNames,
          plan: live?.plan,
          kids: s.kids,
        );
        final titles = {for (final i in raw) i.id: i.title};
        final hw = homeworkLists(
          s.lessons.content ?? const <Lesson>[],
          s.homework,
          subjectOf: (l) => titles[l.courseID] ?? courseTitle(l.name),
          dueOf: liveHomeworkDue(s),
        );
        // Abgehakt in der App gilt auch für die Marke an der Kurszeile;
        // abgelaufene ebenso (zählen wie auf Heute nicht mehr als offen,
        // Prüfung 27.10.26).
        final doneKeys = {
          for (final h in [...hw.done, ...hw.expired]) h.key,
        };
        final items = [
          for (final i in raw)
            if (i.homework != null && i.entry != null)
              i.withHomeworkDone(doneKeys.contains(homeworkKey(i.id, i.entry!)))
            else
              i,
        ];
        final hwParser = ref.read(lessonsStudentParserProvider);
        void toggle(HomeworkItem h, bool done) => setHomeworkDone(
          s: s,
          parser: hwParser,
          item: h,
          done: done,
          t: context.t,
          messenger: ScaffoldMessenger.maybeOf(context),
        );
        // Parser hier lesen, nicht im späteren Abruf: Die Übersicht lädt
        // asynchron weiter, auch wenn die Seite inzwischen neu gebaut wurde
        // (ref nach dem Abbau = Absturz 9349, siehe nav.dart _once).
        final parser = ref.read(lessonsStudentParserProvider);
        return CoursesPage(
          items: items,
          homework: HomeworkBoard(
            open: hw.open,
            done: hw.done,
            doneCount: hw.done.length,
            expiredCount: hw.expired.length,
            onDone: (h) => toggle(h, true),
            onReopen: (h) => toggle(h, false),
            onOpenArchive: () => pushInTab<void>(
              context,
              (_) => const LiveHomeworkArchive(),
              kidChips: true,
            ),
          ),
          grades: GradesSource(
            account: s.accountKey,
            courses: items,
            load: (c, {required firstHalf}) => parser.getDetailedCourseView(
              courseUrl(c.id, firstHalf: firstHalf),
              force: true,
            ),
            onCurrentLoaded: (pages) {
              final save = s.setCourseScan;
              if (save == null) return;
              save(scanFrom(items, pages, DateTime.now(), old: s.courseScan));
            },
            calendar: examCalendarOf(s, DateTime.now()),
            reauth: () => s.session.authenticate(),
          ),
          firstName: s.kids.isNotEmpty ? s.firstName : null,
          className: liveClassName(s),
          loading: s.lessons.content == null && !s.lessons.failed,
          onRefresh: s.refresh,
          // Alter Stand (stale_notice.dart) wie auf Heute.
          notices: [
            ?staleNotice(
              context,
              feeds: [s.lessons],
              now: DateTime.now(),
              onRetry: s.refresh,
            ),
          ],
          onOpen: (i) => pushInTab<void>(
            context,
            (_) => liveCourseDetail(context, ref, s, i, live, items),
            kidChips: true,
          ),
          onOpenAbsences: (id) => pushInTab<void>(
            context,
            (_) => LiveAbsencesPage(courses: items, focus: id),
            kidChips: true,
          ),
        );
      },
    );
  }
}

/// Kursseite eines Kurses mit Lehrkräften, Nachrichten und Terminen des
/// Kontos [s] (auch aus der Ansicht „Alle“, im Rahmen des Kontos).
Widget liveCourseDetail(
  BuildContext context,
  WidgetRef ref,
  LiveSnapshot s,
  CourseItem i,
  ({KidPlan plan, GroupChoice auto})? live,
  List<CourseItem> items,
) {
  final now = DateTime.now();
  final codes = {...i.teacherCodes}..remove('');
  final teachers = [
    for (var n = 0; n < i.teachers.length; n++)
      (n < i.teacherCodes.length ? i.teacherCodes[n] : '', i.teachers[n]),
  ];
  // Neueste Unterhaltung je Lehrkraft (Übersicht ist neueste zuerst).
  final last = <String, (String, VoidCallback)>{};
  for (final e in s.conversations.content ?? const <OverviewEntry>[]) {
    final kz = e.shortName ?? '';
    if (!codes.contains(kz) || last.containsKey(kz) || e.hidden) continue;
    last[kz] = (
      e.date,
      () => pushInTab<void>(
        context,
        (_) => ConversationChatPage(id: e.id, title: e.title),
      ),
    );
  }
  final student = s.session.account.accountType == AccountType.student;
  final parser = ref.read(lessonsStudentParserProvider);
  // Offene Hausaufgaben wie in der Liste (homeworkLists), nur dieses Kurses.
  final hw = homeworkLists(
    s.lessons.content ?? const <Lesson>[],
    s.homework,
    subjectOf: (_) => i.title,
    dueOf: liveHomeworkDue(s),
  );
  // Farbe des Kindes: Rahmen des Kontos (Ansicht „Alle“), sonst das
  // aktive Konto in der Familie.
  final account = s.session.account.localId;
  final kidColor =
      FamilyMember.around(context)?.colorIndex ??
      FamilyData.of(context)
          .where((m) => m.snapshot.session.account.localId == account)
          .firstOrNull
          ?.colorIndex ??
      0;
  return CourseDetailPage(
    course: CourseContext(
      kidColor: kidColor,
      // Abgelaufene sind nicht erledigt: auf der Kursseite weiter als offen
      // (nicht abgehakt), nicht mit Haken (Prüfung 27.10.26).
      openHomework: {
        for (final h in [...hw.open, ...hw.expired])
          if (h.course == i.id) h.entry,
      },
      title: i.title,
      fullName: i.fullName,
      teachers: teachers,
      // Fach ohne Kindnamen (CourseItem.subject); Kurse der Geschwister
      // haben im gezeigten Plan keine Stunde (CourseItem.inShownPlan).
      nextLesson: live == null || !i.inShownPlan
          ? null
          : nextLessonOf(
              live.plan,
              effectiveChoice(live.auto, s.userChoice),
              i.subject,
              codes,
              now,
              free: s.offers('kalender.php')
                  ? freeDaysFrom(
                      s.calendar.content ?? const [],
                      now,
                      className: liveClassName(s),
                      days: 22,
                    )
                  : const {},
            ),
      calendarExams: examCalendarOf(s, now),
      lastMessages: last,
      extraOffer: i.extra,
    ),
    load: ({required bool firstHalf}) => parser.getDetailedCourseView(
      courseUrl(i.id, firstHalf: firstHalf),
      force: true,
    ),
    onOpenAbsences: () => pushInTab<void>(
      context,
      (_) => LiveAbsencesPage(courses: items, focus: i.id),
      kidChips: true,
    ),
    onWrite: s.offers('nachrichten.php')
        // Eingabe-Seiten über der ganzen App (nav.dart, pushFullScreen).
        ? (kz) => pushFullScreen<bool>(
            context,
            (_) => ComposePage(
              candidates: candidatesFrom(s.lessons.content ?? const []),
              backend: portalBackend(ref),
              initialKuerzel: kz,
            ),
          )
        : null,
    // Dateiname in der Adresse kodiert (fixedLessonFileUrl, Ursache dort:
    // liblanis student_parser.dart:238 hängt ihn roh an).
    onOpenFile: (f) => fo.launchFile(
      context,
      fo.DownloadableFile(
        name: f.name,
        size: f.size,
        url: fixedLessonFileUrl(f.url, f.name),
      ),
      () {},
    ),
    // Abgaben nur aus dem Schülerkonto und nur Adressen aus „Mein
    // Unterricht“ (isLessonsUploadUrl, Sicherheitsprüfung 17.10.26) – die
    // Seite lädt sie mit der Portal-Sitzung.
    onOpenUpload: student
        ? (u) {
            if (!isLessonsUploadUrl(u.url.toString())) return;
            pushFullScreen<void>(
              context,
              (_) => UploadScreen(
                url: u.url.toString(),
                name: u.name,
                status: u.status,
              ),
            );
          }
        : null,
  );
}

/// „Unterricht · Alle“ mit echten Daten aller Kinder (AllCoursesView).
///
/// Jede Aktion läuft im Rahmen des jeweiligen Kontos: Abhaken über dessen
/// Parser und Stand, Kursseite und Abwesenheiten über FamilyMember.scope.
/// Arbeiten nach der gemeinsamen Regel (exams.dart, upcomingExamsOf) bis
/// Halbjahresende – dieselben Zeilen wie beim einzelnen Kind. Grenze:
/// Kursmappen-Arbeiten sind so aktuell wie die letzte Auswertung des Kontos
/// (CourseScan).
class LiveAllCoursesPage extends ConsumerWidget {
  const LiveAllCoursesPage({super.key, required this.members});

  final List<FamilyMember> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final now = DateTime.now();
    final homework = <(DateTime, AllHomework)>[];
    final doneHomework = <(DateTime, AllHomework)>[];
    final exams = <AllExam>[];
    final missing = <AllMissing>[];
    final withDone = <FamilyMember>[];
    var done = 0;
    var expired = 0;
    var loading = false;
    final shown = [
      for (final m in members)
        if (m.snapshot.offers('meinunterricht.php')) m,
    ];
    for (final m in shown) {
      final s = m.snapshot;
      if (s.lessons.content == null && !s.lessons.failed) loading = true;
      final kid = (name: kidLabel(s), color: m.colorIndex);
      final live = s.offers('stundenplan.php') && s.timetable.content != null
          ? livePlanOf(s)
          : null;
      final raw = courseItemsFrom(
        s.lessons.content ?? const [],
        ownNames: s.ownNames,
        plan: live?.plan,
        kids: s.kids,
      );
      final byId = {for (final i in raw) i.id: i};
      final hw = homeworkLists(
        s.lessons.content ?? const <Lesson>[],
        s.homework,
        subjectOf: (l) => byId[l.courseID]?.title ?? courseTitle(l.name),
        dueOf: liveHomeworkDue(s),
      );
      // Parser des Kontos lesen, solange die Seite steht (nav.dart, _once).
      final c = m.container;
      final parser = c == null
          ? ref.read(lessonsStudentParserProvider)
          : c.read(lessonsStudentParserProvider);
      void toggle(HomeworkItem h, bool d) => setHomeworkDone(
        s: s,
        parser: parser,
        item: h,
        done: d,
        t: t,
        messenger: ScaffoldMessenger.maybeOf(context),
      );
      AllHomework entry(HomeworkItem h) {
        final course = byId[h.course];
        return AllHomework(
          item: h,
          kid: kid,
          onDone: () => toggle(h, true),
          onReopen: () => toggle(h, false),
          onOpen: course == null
              ? null
              : () => pushInTab<void>(
                  context,
                  (_) => Consumer(
                    builder: (c, r, _) =>
                        liveCourseDetail(c, r, s, course, live, raw),
                  ),
                  kidChips: true,
                  member: m,
                ),
        );
      }

      for (final h in hw.open) {
        homework.add((h.given ?? DateTime(2000), entry(h)));
      }
      for (final h in hw.done) {
        doneHomework.add((h.done ?? h.given ?? DateTime(2000), entry(h)));
      }
      if (hw.done.isNotEmpty || hw.expired.isNotEmpty) {
        done += hw.done.length;
        expired += hw.expired.length;
        withDone.add(m);
      }
      for (final e in upcomingExamsOf(
        scan: s.courseScan?.upcoming(now) ?? const [],
        calendar: examCalendarOf(s, now),
        now: now,
        until: halfYearEnd(now),
      )) {
        exams.add(AllExam(exam: e, kid: kid));
      }
      for (final i in raw.where((i) => i.missing > 0)) {
        missing.add(
          AllMissing(
            item: i,
            kid: kid,
            onTap: () => pushInTab<void>(
              context,
              (_) => LiveAbsencesPage(courses: raw, focus: i.id),
              kidChips: true,
              member: m,
            ),
          ),
        );
      }
    }
    homework.sort((a, b) => b.$1.compareTo(a.$1));
    doneHomework.sort((a, b) => b.$1.compareTo(a.$1));
    exams.sort((a, b) => a.exam.day.compareTo(b.exam.day));
    Future<void> refreshAll() async {
      for (final m in shown) {
        await m.snapshot.refresh();
      }
    }

    return AllCoursesView(
      now: now,
      homework: [for (final h in homework) h.$2],
      doneHomework: [for (final h in doneHomework) h.$2],
      exams: exams,
      missing: missing,
      doneCount: done,
      expiredCount: expired,
      loading: loading,
      onRefresh: refreshAll,
      notices: [
        ?staleNotice(
          context,
          feeds: [for (final m in shown) m.snapshot.lessons],
          now: now,
          onRetry: refreshAll,
        ),
      ],
      onOpenArchive: withDone.isEmpty
          ? null
          : () async {
              final m = withDone.length == 1
                  ? withDone.single
                  : await pickFamilyMember(
                      context,
                      withDone,
                      title: t.archiveForWhom,
                    );
              if (m == null || !context.mounted) return;
              await pushInTab<void>(
                context,
                (_) => const LiveHomeworkArchive(),
                kidChips: true,
                member: m,
              );
            },
    );
  }
}

/// Kalender des Kontos bis Halbjahresende, nach Klasse gefiltert – Quelle
/// der Kalender-Arbeiten für Unterricht (Alle und Kind gleich).
List<WeekItem> examCalendarOf(LiveSnapshot s, DateTime now) =>
    s.offers('kalender.php')
    ? weekItemsFromCalendar(
        s.calendar.content ?? const [],
        now,
        className: liveClassName(s),
        days: daysUntil(now, halfYearEnd(now)),
      )
    : const <WeekItem>[];
