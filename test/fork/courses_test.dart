import 'package:flutter/material.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/courses/courses_model.dart';
import 'package:lanis/fork/ui/courses/courses_page.dart';
import 'package:lanis/fork/ui/kit.dart';
import 'package:lanis/fork/ui/preview/demo_courses.dart';
import 'package:liblanis/liblanis.dart';

Lesson _l(
  String name, {
  String id = 'x',
  List<LessonTeacher> teachers = const [],
  DateTime? date,
  Homework? hw,
  Map<String, String>? att,
}) => Lesson(
  courseID: id,
  name: name,
  teachers: teachers,
  courseURL: Uri.parse('meinunterricht.php?id=$id'),
  attendances: att,
  currentEntry: date == null
      ? null
      : CurrentEntry(
          entryID: 'e$id',
          files: const [],
          uploads: const [],
          topicDate: date,
          topicTitle: 'Thema $id',
          homework: hw,
        ),
);

void main() {
  test('Titel, gleiche Titel, Lehrkräfte, Reihenfolge', () {
    final items = courseItemsFrom(
      [
        _l(
          'Naturwissenschaften 06 xy (061NAWI05-IGS)',
          id: '1',
          teachers: [
            LessonTeacher(teacher: 'Alt, Anna', teacherKuerzel: 'AAA'),
          ],
          date: DateTime(2026, 10, 1),
        ),
        _l('Ganztagsangebot Schach', id: '2'),
        _l('Ganztagsangebot', id: '3'),
        _l(
          'Projekt Text 6 xy',
          id: '4',
          teachers: [LessonTeacher(teacherKuerzel: 'CCC')],
          date: DateTime(2026, 10, 12),
          hw: Homework(description: 'Gedicht lernen', homeWorkDone: false),
          att: {'fehlstunden': '2', 'davon entschuldigt': '0'},
        ),
      ],
      ownNames: const {'CCC': 'Frau Muster'},
    );
    expect(items.first.title, 'Projekt Text');
    expect(items.first.teachers, ['Frau Muster']);
    expect(items.first.hasOpenHomework, isTrue);
    expect(items.first.attendance, 'Fehlstunden 2');
    expect(items[1].title, 'Naturwissenschaften');
    expect(items[1].teachers, ['Anna Alt']);
    expect(
      items.map((i) => i.title),
      containsAll(['Ganztagsangebot Schach', 'Ganztagsangebot']),
      reason: 'gleiche Überschrift → voller Name',
    );
  });

  for (final scale in [1.0, 1.4 * 1.3]) {
    testWidgets('Unterricht ohne Überlauf bei Schrift ×$scale', (t) async {
      t.view.physicalSize = const Size(1080, 2424);
      t.view.devicePixelRatio = 2.625;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: ForkL10n.localizationsDelegates,
          supportedLocales: ForkL10n.supportedLocales,
          locale: const Locale('de'),

          builder: (c, w) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: w!,
          ),
          home: Scaffold(
            backgroundColor: KitPalette.light.bg,
            body: CoursesPage(items: demoCourses(), firstName: 'Lena'),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Buch S. 42 Nr. 3–5'), findsOneWidget);
      expect(find.textContaining('offen'), findsWidgets);
    });
  }
}
