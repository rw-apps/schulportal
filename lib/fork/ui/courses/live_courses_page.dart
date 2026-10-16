import 'package:flutter/material.dart';

import 'package:lanis/applets/lessons/student/course_overview.dart';

import '../kit.dart';
import '../live/live_data.dart';
import 'courses_model.dart';
import 'courses_page.dart';

/// „Unterricht“ mit echten Daten (LiveDataScope, Quelle „Mein Unterricht“).
/// Antippen öffnet die Kursseite der bisherigen Ansicht
/// (CourseOverviewAnsicht) mit allen Einträgen, Anwesenheit und Dateien –
/// sie liest auch Elternkonten korrekt (Grenze bei LessonsParentAwareParser).
class LiveCoursesPage extends StatelessWidget {
  const LiveCoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LiveGate(
      needsTimetable: false,
      builder: (context, s) {
        if (!s.offers('meinunterricht.php')) {
          return CoursesPage(items: const [], firstName: s.firstName);
        }
        if (s.lessons.failed) {
          return LiveMessage(
            text: 'Der Unterricht ließ sich nicht laden.',
            style: Kit.of(context).meta,
            action: TextButton(
              onPressed: s.refresh,
              child: Text('Erneut versuchen', style: Kit.of(context).link),
            ),
          );
        }
        final items = courseItemsFrom(
          s.lessons.content ?? const [],
          ownNames: s.ownNames,
        );
        return CoursesPage(
          items: items,
          firstName: s.kids.isNotEmpty ? s.firstName : null,
          loading: s.lessons.content == null && !s.lessons.failed,
          onRefresh: s.refresh,
          onOpen: (i) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CourseOverviewAnsicht(
                dataFetchURL: 'meinunterricht.php?a=sus_view&id=${i.id}',
                title: i.fullName,
              ),
            ),
          ),
        );
      },
    );
  }
}
