import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/offline_store.dart';
import 'package:lanis/fork/ui/live/feed_source.dart';
import 'package:liblanis/liblanis.dart';

/// Ablage und Rückfall bei Portalfehlern (feed_source.dart,
/// offline_store.dart) – synthetisch, Datenbank im Speicher.
class _Cal extends AppletParser<List<CalendarEvent>> {
  _Cal(AppletContext ctx)
    : super(ctx, Applets.calendar, isConnected: () async => true);

  @override
  Future<List<CalendarEvent>> getHome() async => const [];
}

CalendarEvent _event(String title) => CalendarEvent(
  startTime: DateTime(2026, 10, 22, 8),
  endTime: DateTime(2026, 10, 22, 9),
  secret: false,
  id: '1',
  isNew: false,
  public: true,
  private: false,
  allDay: false,
  category: CalendarEventCategory(id: 3, colorArgb: 0xFF00AA00, name: 'Schule'),
  description: 'Aula',
  title: title,
);

void main() {
  late LanisDatabase db;
  late AppletContext ctx;
  final checkers = <ConnectionChecker>[];

  setUp(() async {
    db = LanisDatabase.open();
    final id = await db.addAccount(
      schoolId: 1234,
      schoolName: 'Muster-Gymnasium',
      username: 'lena.muster',
      password: 'x',
    );
    final account = ClearTextAccount(
      localId: id,
      schoolID: 1234,
      username: 'lena.muster',
      password: 'x',
      schoolName: 'Muster-Gymnasium',
      accountType: AccountType.student,
    );
    final c = ConnectionChecker();
    checkers.add(c);
    ctx = AppletContext(
      session: LanisSession(
        account: account,
        config: const LanisConfig(),
        connectionChecker: c,
      ),
      database: db,
      account: account,
      accountSettings: TypedSettings.account(db, id),
    );
  });
  tearDown(() {
    for (final c in checkers) {
      c.dispose();
    }
    checkers.clear();
  });

  FetcherResponse<T> error<T>() => FetcherResponse<T>(
    status: FetcherStatus.error,
    error: ExceptionWithStackTrace(
      exception: Exception('Portal antwortet nicht'),
      stackTrace: StackTrace.empty,
    ),
  );

  test('Kalender: gespeichert, nach Neustart bei Fehler wieder da', () async {
    final first = _Cal(ctx);
    final a = FeedSource<List<CalendarEvent>>(
      'kalender.php',
      store: calendarCodec,
    )..attach(first, () {});
    first.addResponse(
      FetcherResponse(
        status: FetcherStatus.done,
        content: [_event('Wandertag')],
        error: null,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(a.feed.offline, isFalse);

    // Neustart: neuer Parser ohne Inhalt, Portal antwortet nicht.
    final second = _Cal(ctx);
    final b = FeedSource<List<CalendarEvent>>(
      'kalender.php',
      store: calendarCodec,
    )..attach(second, () {});
    second.addResponse(error<List<CalendarEvent>>());
    await Future<void>.delayed(Duration.zero);
    final e = b.feed.content!.single;
    expect(e.title, 'Wandertag');
    expect(e.category!.name, 'Schule');
    expect(b.feed.offline, isTrue);
    expect(b.feed.error, isNotNull);
    expect(b.feed.fetchedAt, isNotNull);

    // Gelingt der nächste Abruf, ist es kein gespeicherter Stand mehr.
    second.addResponse(
      FetcherResponse(
        status: FetcherStatus.done,
        content: [_event('Neu')],
        error: null,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(b.feed.offline, isFalse);
    expect(b.feed.content!.single.title, 'Neu');
  });

  test('Vertretungsplan: Ablage von liblanis auch bei Portalfehler', () async {
    final plan = SubstitutionPlan(
      days: [
        SubstitutionDay(
          parsedDate: '21.10.2026',
          substitutions: [
            Substitution(
              tag: '21.10.2026',
              tag_en: '',
              stunde: '1',
              art: 'Entfall',
            ),
          ],
        ),
      ],
    );
    db.setAppletOfflineData(
      accountId: ctx.accountId,
      appletId: 'vertretungsplan.php',
      json: jsonEncode(plan),
    );
    final p = SubstitutionsParser(ctx, isConnected: () async => true);
    final s = FeedSource<SubstitutionPlan>('vertretungsplan.php')
      ..attach(p, () {});
    p.addResponse(error<SubstitutionPlan>());
    await Future<void>.delayed(Duration.zero);
    expect(s.feed.content!.days.single.substitutions.single.art, 'Entfall');
    expect(s.feed.offline, isTrue);
  });

  test('Fehler beim Abruf selbst (fail) stellt ebenfalls wieder her', () {
    final p = _Cal(ctx);
    db.setAppletOfflineData(
      accountId: ctx.accountId,
      appletId: forkOfflineId('kalender.php'),
      json: calendarCodec.encode([_event('Gespeichert')], null),
    );
    final s = FeedSource<List<CalendarEvent>>(
      'kalender.php',
      store: calendarCodec,
    )..attach(p, () {});
    s.fail(Exception('Neuanmeldung gescheitert'));
    expect(s.feed.content!.single.title, 'Gespeichert');
    expect(s.feed.offline, isTrue);
  });

  test('Unterricht: Hausaufgabe und Anwesenheit überstehen die Ablage', () {
    final l = Lesson(
      courseID: 'k1',
      name: 'Mathematik 9x',
      courseURL: Uri.parse('https://example.org/k1'),
      teachers: [LessonTeacher(teacher: 'Anna Berg', teacherKuerzel: 'ABG')],
      attendances: const {'anwesend': '12'},
      currentEntry: CurrentEntry(
        entryID: 'e1',
        topicTitle: 'Brüche',
        topicDate: DateTime(2026, 10, 20),
        homework: Homework(description: 'S. 42 Nr. 3', homeWorkDone: false),
        files: const [],
        uploads: const [],
      ),
    );
    final back = lessonsCodec
        .decode(lessonsCodec.encode([l], null), null)
        .single;
    expect(back.courseID, 'k1');
    expect(back.teachers.single.teacherKuerzel, 'ABG');
    expect(back.attendances, {'anwesend': '12'});
    expect(back.currentEntry!.homework!.description, 'S. 42 Nr. 3');
    expect(back.currentEntry!.topicDate, DateTime(2026, 10, 20));
  });
}
