import 'package:flutter/material.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/kit.dart';
import 'package:lanis/fork/ui/messages/compose_model.dart';
import 'package:lanis/fork/ui/messages/compose_page.dart';
import 'package:lanis/fork/ui/messages/messages_page.dart';
import 'package:lanis/fork/ui/preview/demo_courses.dart';
import 'package:liblanis/liblanis.dart';

Lesson _l(String name, List<LessonTeacher> t) =>
    Lesson(courseID: name, name: name, teachers: t, courseURL: Uri.parse('x'));

/// Erfundenes Portal: Suche nach Nachnamen, Versand wird nur protokolliert.
class _FakeBackend implements ComposeBackend {
  final sent = <({List<String> receivers, String subject, String text})>[];
  final directory = const [
    ReceiverEntry('l-1', 'Alt, Anna', true),
    ReceiverEntry('l-2', 'Alt, Bernd', true),
    ReceiverEntry('l-3', 'Bau, Clara', true),
    ReceiverEntry('s-9', 'Alt, Schüler', false),
  ];

  @override
  Future<List<ReceiverEntry>> search(String q) async => [
    for (final r in directory)
      if (r.name.toLowerCase().contains(q.toLowerCase())) r,
  ];

  @override
  Future<bool> send({
    required List<String> receivers,
    required String subject,
    required String text,
  }) async {
    sent.add((receivers: receivers, subject: subject, text: text));
    return true;
  }
}

void main() {
  final lessons = [
    _l('Mathematik 06 xy', [
      LessonTeacher(teacher: 'Alt, Anna', teacherKuerzel: 'AAA'),
    ]),
    _l('Training Klasse 6', [
      LessonTeacher(teacher: 'Alt, Anna', teacherKuerzel: 'AAA'),
      LessonTeacher(teacher: 'Bau, Clara', teacherKuerzel: 'CCC'),
    ]),
    _l('Sport', [LessonTeacher(teacher: 'Zett, Zora', teacherKuerzel: 'ZZZ')]),
  ];

  test('Empfänger aus dem Unterricht, je Kürzel einmal mit Fächern', () {
    final c = candidatesFrom(lessons);
    expect(c.map((x) => x.display), ['Anna Alt', 'Clara Bau', 'Zora Zett']);
    expect(c.first.subjects, ['Mathematik', 'Training Klasse']);
    expect(c.first.lastName, 'Alt');
    final big = candidatesFrom([
      _l('Ganztag', [
        for (final x in ['P', 'Q', 'R', 'S'])
          LessonTeacher(teacher: '$x, $x', teacherKuerzel: x),
      ]),
      ...lessons,
    ]);
    expect(big.first.display, 'Anna Alt', reason: 'große Teams ans Ende');
  });

  test(
    'Portal-Treffer: Lehrkraft mit Nachname, bei mehreren der Vorname',
    () async {
      final b = _FakeBackend();
      final anna = candidatesFrom(lessons).first;
      final hits = matchReceivers(await b.search(anna.lastName), anna);
      expect(hits.map((h) => h.id), [
        'l-1',
      ], reason: 'Bernd Alt und Schüler raus');
      final zora = candidatesFrom(lessons).last;
      expect(matchReceivers(await b.search(zora.lastName), zora), isEmpty);
    },
  );

  Future<void> pump(WidgetTester t, Widget w, {double scale = 1.0}) async {
    t.view.physicalSize = const Size(1080, 2424);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),

        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: w,
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('Schreiben: Empfänger, Vorlage, Rückfrage, Versand', (t) async {
    final b = _FakeBackend();
    await pump(t, ComposePage(candidates: candidatesFrom(lessons), backend: b));
    expect(find.text('Erst Empfänger wählen'), findsOneWidget);
    await t.tap(find.text('Anna Alt'));
    await t.pumpAndSettle();
    await t.tap(find.text('Zora Zett'));
    await t.pumpAndSettle();
    expect(find.text('Über das Portal nicht erreichbar'), findsOneWidget);
    await t.tap(find.text('Frage zur Hausaufgabe'));
    await t.pumpAndSettle();
    final send = find.text('Senden an Anna Alt');
    await t.ensureVisible(send);
    await t.pumpAndSettle();
    await t.tap(send);
    await t.pumpAndSettle();
    expect(find.text('Nachricht senden?'), findsOneWidget);
    expect(b.sent, isEmpty, reason: 'erst nach Bestätigung');
    await t.tap(find.text('Senden').last);
    await t.pumpAndSettle();
    expect(b.sent.single.receivers, ['l-1']);
    expect(b.sent.single.subject, 'Frage zur Hausaufgabe');
  });

  for (final scale in [1.0, 1.4 * 1.3]) {
    testWidgets('Nachrichten und Schreiben ohne Überlauf ×$scale', (t) async {
      await pump(
        t,
        Scaffold(
          backgroundColor: KitPalette.light.bg,
          body: MessagesPage(items: demoMessages(), onCompose: () {}),
        ),
        scale: scale,
      );
      expect(t.takeException(), isNull);
      expect(find.text('1 ungelesen'), findsOneWidget);
      await pump(
        t,
        ComposePage(
          candidates: candidatesFrom(lessons),
          backend: _FakeBackend(),
        ),
        scale: scale,
      );
      expect(t.takeException(), isNull);
    });
  }
}
