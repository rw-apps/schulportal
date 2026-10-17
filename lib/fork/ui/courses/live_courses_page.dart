import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/applets/conversations/routes.dart'
    show ConversationChatPage;
import 'package:lanis/utils/file_operations.dart' as fo;

import '../../l10n/l10n.dart';
import '../kit.dart';
import '../live/live_data.dart';
import '../messages/compose_model.dart';
import '../messages/compose_page.dart';
import '../plan/plan_model.dart';
import '../today/today_from_lanis.dart' show weekItemsFromCalendar;
import 'course_detail_model.dart';
import 'course_detail_page.dart';
import 'courses_model.dart';
import 'courses_page.dart';

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
        final items = courseItemsFrom(
          s.lessons.content ?? const [],
          ownNames: s.ownNames,
          plan: live?.plan,
        );
        return CoursesPage(
          items: items,
          firstName: s.kids.isNotEmpty ? s.firstName : null,
          className: liveClassName(s),
          loading: s.lessons.content == null && !s.lessons.failed,
          onRefresh: s.refresh,
          onOpen: (i) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _detail(context, ref, s, i, live),
            ),
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
        () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ConversationChatPage(id: e.id, title: e.title),
          ),
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
        'meinunterricht.php?a=sus_view&id=${i.id}${firstHalf ? '&halb=1' : ''}',
        force: true,
      ),
      onWrite: s.offers('nachrichten.php')
          ? (kz) => Navigator.of(context).push(
              MaterialPageRoute<bool>(
                builder: (_) => ComposePage(
                  candidates: candidatesFrom(s.lessons.content ?? const []),
                  backend: portalBackend(ref),
                  initialKuerzel: kz,
                ),
              ),
            )
          : null,
      onOpenFile: (f) => fo.launchFile(
        context,
        fo.DownloadableFile(name: f.name, size: f.size, url: f.url),
        () {},
      ),
      // Abgaben nur aus dem Schülerkonto (Upload-Route gibt es nur für
      // Schüler, applets/lessons/routes.dart).
      onOpenUpload: student
          ? (u) => context.push(
              '/student/lessons/upload?url=${Uri.encodeComponent(u.url.toString())}'
              '&name=${Uri.encodeComponent(u.name)}&status=${u.status}',
            )
          : null,
    );
  }
}
