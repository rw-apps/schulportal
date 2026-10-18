import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/applets/conversations/chat_pages.dart'
    show ConversationChatPage;
import 'package:lanis/applets/lessons/student/upload_page.dart';
import 'package:lanis/utils/file_operations.dart' as fo;

import '../../courses_scan.dart';
import '../../homework_ledger.dart';
import '../../l10n/l10n.dart';
import '../kit.dart';
import '../nav.dart';
import '../live/live_data.dart';
import '../messages/compose_model.dart';
import '../messages/compose_page.dart';
import '../plan/plan_model.dart';
import '../today/today_from_lanis.dart' show weekItemsFromCalendar;
import 'course_detail_model.dart';
import 'course_detail_page.dart';
import 'courses_model.dart';
import 'courses_page.dart';
import 'grades_view.dart';
import 'homework_archive.dart';

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
            text: t.coursesFailed,
            style: Kit.of(context).meta,
            action: TextButton(
              onPressed: s.refresh,
              child: Text(t.retry, style: Kit.of(context).link),
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
        );
        final titles = {for (final i in raw) i.id: i.title};
        final hw = homeworkLists(
          s.lessons.content ?? const <Lesson>[],
          s.homework,
          subjectOf: (l) => titles[l.courseID] ?? courseTitle(l.name),
        );
        // Abgehakt in der App gilt auch für die Marke an der Kurszeile.
        final doneKeys = {for (final h in hw.done) h.key};
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
            doneCount: hw.done.length,
            onDone: (h) => toggle(h, true),
            onReopen: (h) => toggle(h, false),
            onOpenArchive: () =>
                pushInTab<void>(context, (_) => const LiveHomeworkArchive()),
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
          ),
          firstName: s.kids.isNotEmpty ? s.firstName : null,
          className: liveClassName(s),
          loading: s.lessons.content == null && !s.lessons.failed,
          onRefresh: s.refresh,
          onOpen: (i) => pushInTab<void>(
            context,
            (_) => _detail(context, ref, s, i, live),
          ),
        );
      },
    );
  }

  Widget _detail(
    BuildContext context,
    WidgetRef ref,
    LiveSnapshot s,
    CourseItem i,
    ({KidPlan plan, GroupChoice auto})? live,
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
    final calendar = s.offers('kalender.php')
        ? weekItemsFromCalendar(
            s.calendar.content ?? const [],
            now,
            className: liveClassName(s),
            days: 60,
          )
        : const [];
    final student = s.session.account.accountType == AccountType.student;
    final parser = ref.read(lessonsStudentParserProvider);
    return CourseDetailPage(
      course: CourseContext(
        title: i.title,
        fullName: i.fullName,
        teachers: teachers,
        colorSlot: i.colorSlot ?? 0,
        nextLesson: live == null
            ? null
            : nextLessonOf(
                live.plan,
                effectiveChoice(live.auto, s.userChoice),
                i.title,
                codes,
                now,
              ),
        exam: upcomingExamOf([...calendar], i.title, now),
        lastMessages: last,
        extraOffer: i.extra,
      ),
      load: ({required bool firstHalf}) => parser.getDetailedCourseView(
        courseUrl(i.id, firstHalf: firstHalf),
        force: true,
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
      onOpenFile: (f) => fo.launchFile(
        context,
        fo.DownloadableFile(name: f.name, size: f.size, url: f.url),
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
}
