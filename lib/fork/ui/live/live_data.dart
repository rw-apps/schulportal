import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/utils/applet_settings.dart';

import '../../lessons_parent.dart';
import '../kit.dart';
import 'serial_loader.dart';
import '../plan/plan_from_lanis.dart';
import '../plan/plan_model.dart';
import '../today/today_from_lanis.dart' show classFromCourses;

/// Schlüssel der Gruppenwahl in den Einstellungen des Kontos (unter
/// `stundenplan.php/…`, getrennt von den Lanis-Schlüsseln wie
/// `hidden-lessons`).
const groupChoiceSetting = 'fork-group-choice';

/// Von Hand eingetragene Lehrernamen (Kürzel → Name), ebenfalls je Konto.
/// Bewusst nur auf dem Gerät: Echte Namen gehören nicht ins öffentliche
/// Repository (Entscheidung 16.10.26).
const teacherNamesSetting = 'fork-teacher-names';

const _settingsApplet = 'stundenplan.php';

/// Gespeicherte Map (JSON) als Kürzel → Text; Fremdes wird übergangen.
Map<String, String> settingStrings(Object? m) => <String, String>{
  if (m is Map)
    for (final e in m.entries)
      if (e.value is String) e.key.toString(): e.value as String,
};

/// Plan eines Kindes aus Stundenplan und Unterricht, dazu die automatisch
/// erkannte Gruppenwahl. Gemeinsam für alle Seiten, damit „Heute“,
/// „Kalender“ und „Unterricht“ dieselben Stunden, Gruppen und Namen zeigen.
({KidPlan plan, GroupChoice auto}) livePlan({
  required TimeTable tt,
  required Lessons lessons,
  required String firstName,
  required String schoolId,
}) {
  final names = <String, String>{};
  for (final l in lessons) {
    for (final t in l.teachers) {
      final kz = t.teacherKuerzel;
      final n = t.teacher;
      if (kz != null && n != null && n.isNotEmpty) {
        names[kz] = portalNameToDisplay(n);
      }
    }
  }
  final plan = kidPlanFromTimetable(
    tt,
    firstName: firstName,
    colorIndex: 0,
    teacherNames: names,
    courseNames: [for (final l in lessons) l.name],
    schoolId: schoolId,
  );
  final auto = autoGroupChoice(plan, [
    for (final l in lessons)
      (name: l.name, teachers: {for (final t in l.teachers) ?t.teacherKuerzel}),
  ]);
  return (plan: plan, auto: auto);
}

/// Was eine Quelle gerade hat: letzter guter Inhalt plus Zustand.
class Feed<T> {
  const Feed({
    this.content,
    this.loading = false,
    this.error,
    this.offline = false,
    this.fetchedAt,
  });

  final T? content;
  final bool loading;
  final Object? error;
  final bool offline;
  final DateTime? fetchedAt;

  bool get failed => content == null && error != null && !loading;
}

/// Alle Daten eines Kontos für die neue Oberfläche, einmal geladen.
///
/// Ursache: Vorher lud jede Seite ihre Quellen selbst (LivePlanPage und
/// LiveTodayPage je ein CombinedAppletBuilder). Mit fünf Bereichen, die sich
/// Stundenplan, Unterricht, Vertretungen und Kalender teilen, hätte das jede
/// Quelle bis zu dreimal angefragt und die Gruppenwahl an mehreren Stellen
/// gelesen. Grenze: ein Konto; die Familienansicht über mehrere Konten
/// (zweite Schule) setzt hier später eine Liste darüber.
class LiveSnapshot {
  const LiveSnapshot({
    required this.session,
    required this.supported,
    required this.timetable,
    required this.lessons,
    required this.substitutions,
    required this.calendar,
    required this.conversations,
    required this.userChoice,
    required this.ownNames,
    required this.setUserChoice,
    required this.setOwnNames,
    required this.refresh,
    required this.refreshMessages,
    this.kids = const [],
  });

  final LanisSession session;
  final Set<String> supported;
  final Feed<TimeTable> timetable;
  final Feed<Lessons> lessons;
  final Feed<SubstitutionPlan> substitutions;
  final Feed<List<CalendarEvent>> calendar;
  final Feed<List<OverviewEntry>> conversations;

  /// Eigene Gruppenwahl ('' = bewusst alle zeigen) und Lehrernamen.
  final GroupChoice userChoice;
  final Map<String, String> ownNames;
  final void Function(GroupChoice) setUserChoice;
  final void Function(Map<String, String>) setOwnNames;

  /// Alles neu vom Portal holen (Ziehen zum Aktualisieren).
  final Future<void> Function() refresh;

  /// Nur die Nachrichten neu holen (nach dem Lesen einer Unterhaltung).
  final Future<void> Function() refreshMessages;

  String get schoolId => session.account.schoolID.toString();
  String get schoolName => session.account.schoolName;
  bool offers(String phpUrl) => supported.contains(phpUrl);

  /// Kinder laut Eltern-Ansicht von „Mein Unterricht“ (leer bei
  /// Schülerkonten oder solange nicht geladen).
  final List<ChildLessons> kids;

  String get firstName {
    final k = kids;
    return k.isNotEmpty
        ? k.first.firstName
        : (session.userData['vorname'] ?? 'Kind');
  }

  List<String> get courseNames => [
    for (final l in lessons.content ?? const <Lesson>[]) l.name,
  ];
}

/// Stellt [LiveSnapshot] unterhalb bereit ([LiveData.of]).
class LiveDataScope extends ConsumerStatefulWidget {
  const LiveDataScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LiveDataScope> createState() => _LiveDataScopeState();
}

class _Source<T> {
  _Source(this.phpUrl);

  final String phpUrl;
  AppletParser<T>? parser;
  StreamSubscription<FetcherResponse<T>>? sub;
  Feed<T> feed = const Feed();

  void attach(AppletParser<T> p, VoidCallback changed) {
    if (identical(p, parser)) return;
    sub?.cancel();
    parser = p;
    feed = Feed(content: p.latestResponse?.content);
    sub = p.stream.listen((r) {
      final c = r.content ?? feed.content;
      feed = Feed(
        content: c,
        loading: r.status == FetcherStatus.fetching,
        error: r.status == FetcherStatus.error
            ? (r.error?.exception ?? 'Fehler')
            : null,
        offline: r.contentStatus == ContentStatus.offline,
        fetchedAt: r.status == FetcherStatus.done
            ? r.fetchedAt
            : feed.fetchedAt,
      );
      changed();
    });
  }

  /// Fehler, die fetchData selbst wirft (Neuanmeldung im zweiten Versuch,
  /// AppletParser.fetchData), statt sie als Antwort zu melden.
  void fail(Object e) {
    feed = Feed(content: feed.content, error: e, fetchedAt: feed.fetchedAt);
  }

  void dispose() => sub?.cancel();
}

class _LiveDataScopeState extends ConsumerState<LiveDataScope>
    with WidgetsBindingObserver {
  final _tt = _Source<TimeTable>('stundenplan.php');
  final _lessons = _Source<Lessons>('meinunterricht.php');
  final _subs = _Source<SubstitutionPlan>('vertretungsplan.php');
  final _cal = _Source<List<CalendarEvent>>('kalender.php');
  final _conv = _Source<List<OverviewEntry>>('nachrichten.php');

  GroupChoice _choice = const {};
  Map<String, String> _names = const {};
  int? _settingsFor;
  late final _loader = SerialLoader(
    (force, only) => _run(_supported, force, only),
  );
  Set<String> _loadedFor = const {};
  Set<String> _supported = const {};
  Timer? _timer;
  DateTime? _lastLoad;

  /// Eigener Takt statt AppletParser.startAutoRefresh. Ursache: Die
  /// bisherigen Ansichten teilen dieselben Parser und schalten deren Takt
  /// beim Schließen ab (CombinedAppletBuilder.dispose → stopAutoRefresh);
  /// danach wäre „Heute“ bis zum Neustart nicht mehr nachgeladen worden
  /// (Prüfbefund 17.10.26). 10 Minuten wie refreshInterval des
  /// Vertretungsplans (applets/substitutions/definition.dart).
  static const _period = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Nur im Vordergrund und nur, was sich im Lauf des Tages ändert
    // (Vertretungen, Nachrichten). Ursache: Der Takt lief sonst auch bei
    // verdeckter App weiter und holte alle fünf Quellen (Prüfbefund
    // 17.10.26).
    _timer = Timer.periodic(_period, (_) {
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      _loader.run(
        force: true,
        only: const {'vertretungsplan.php', 'nachrichten.php'},
      );
    });
  }

  /// Zurück in die App nach mehr als 10 Minuten: neu laden, damit „Heute“
  /// nicht den Stand vom Morgen zeigt.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _lastLoad;
    if (last == null || DateTime.now().difference(last) > _period) {
      _loader.run(force: true);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    for (final s in [_tt, _lessons, _subs, _cal, _conv]) {
      s.dispose();
    }
    super.dispose();
  }

  void _readSettings(int accountId) {
    if (_settingsFor == accountId) return;
    _settingsFor = accountId;
    final s = ref.read(accountSpecificSettingsProvider);
    if (s == null) return;
    _choice = settingStrings(
      resolveStoredAppletSetting(
        s,
        '$_settingsApplet/$groupChoiceSetting',
        const <String, dynamic>{},
      ),
    );
    _names = settingStrings(
      resolveStoredAppletSetting(
        s,
        '$_settingsApplet/$teacherNamesSetting',
        const <String, dynamic>{},
      ),
    );
  }

  void _write(String key, Map<String, String> value) {
    final s = ref.read(accountSpecificSettingsProvider);
    if (s == null) return;
    persistAppletSetting(s, '$_settingsApplet/$key', value);
  }

  /// Ein Durchgang: Quellen nacheinander, wichtigste zuerst (Reihenfolge
  /// und Grund bei SerialLoader). Wirft ein Parser (Neuanmeldung
  /// fehlgeschlagen), gilt das nur für diese Quelle; die übrigen werden
  /// trotzdem geladen.
  Future<void> _run(
    Set<String> supported,
    bool force,
    Set<String>? only,
  ) async {
    for (final s in [_tt, _lessons, _subs, _cal, _conv]) {
      final p = s.parser;
      if (p == null || !supported.contains(s.phpUrl)) continue;
      if (only != null && !only.contains(s.phpUrl)) continue;
      try {
        await p.fetchData(forceRefresh: force);
      } catch (e) {
        s.fail(e);
        _changed();
      }
      if (!mounted) return;
    }
    if (only == null) _lastLoad = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).asData?.value;
    final supported = ref.watch(supportedAppletPhpUrlsProvider);
    final account = ref.watch(activeAccountProvider);
    if (session == null || account == null) {
      return LiveData(snapshot: null, child: widget.child);
    }
    _readSettings(account.localId);
    _tt.attach(ref.watch(timetableParserProvider), _changed);
    _lessons.attach(ref.watch(lessonsStudentParserProvider), _changed);
    _subs.attach(ref.watch(substitutionsParserProvider), _changed);
    _cal.attach(ref.watch(calendarParserProvider), _changed);
    _conv.attach(ref.watch(conversationsParserProvider), _changed);

    _supported = supported;
    final key = {'${account.localId}', ...supported};
    if (!_setEquals(key, _loadedFor)) {
      _loadedFor = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loader.run();
      });
    }

    final lessonsParser = _lessons.parser;
    final kids = lessonsParser is LessonsParentAwareParser
        ? lessonsParser.lastKids
        : const <ChildLessons>[];

    return LiveData(
      snapshot: LiveSnapshot(
        session: session,
        supported: supported,
        timetable: _tt.feed,
        lessons: _lessons.feed,
        substitutions: _subs.feed,
        calendar: _cal.feed,
        conversations: _conv.feed,
        userChoice: _choice,
        ownNames: _names,
        setUserChoice: (c) {
          setState(() => _choice = {...c});
          _write(groupChoiceSetting, c);
        },
        setOwnNames: (n) {
          setState(() => _names = {...n});
          _write(teacherNamesSetting, n);
        },
        refresh: () => _loader.run(force: true),
        refreshMessages: () =>
            _loader.run(force: true, only: const {'nachrichten.php'}),
        kids: kids,
      ),
      child: widget.child,
    );
  }
}

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

class LiveData extends InheritedWidget {
  const LiveData({super.key, required this.snapshot, required super.child});

  final LiveSnapshot? snapshot;

  static LiveSnapshot? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiveData>()?.snapshot;

  @override
  bool updateShouldNotify(LiveData oldWidget) => true;
}

/// Klasse des Kindes: aus den Benutzerdaten, sonst aus den Kursnamen
/// (classFromCourses, Ursache dort).
String liveClassName(LiveSnapshot s) =>
    s.session.userData['klasse'] ?? classFromCourses(s.courseNames);

/// Plan und automatische Gruppenwahl, sobald der Stundenplan da ist.
({KidPlan plan, GroupChoice auto})? livePlanOf(LiveSnapshot s) {
  final tt = s.timetable.content;
  if (tt == null) return null;
  final r = livePlan(
    tt: tt,
    lessons: s.lessons.content ?? const [],
    firstName: s.firstName,
    schoolId: s.schoolId,
  );
  return (plan: r.plan.withTeacherNames(s.ownNames), auto: r.auto);
}

/// Wartet auf [LiveData] und den Stundenplan; zeigt sonst Laden, Fehler mit
/// „Erneut versuchen“ oder den Hinweis, dass die Schule keinen Plan anbietet.
class LiveGate extends StatelessWidget {
  const LiveGate({
    super.key,
    required this.builder,
    this.needsTimetable = true,
  });

  final Widget Function(BuildContext context, LiveSnapshot s) builder;
  final bool needsTimetable;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final s = LiveData.of(context);
    if (s == null) return const Center(child: CircularProgressIndicator());
    if (!needsTimetable) return builder(context, s);
    if (!s.offers('stundenplan.php')) {
      return LiveMessage(
        text: 'Die Schule bietet für dieses Konto keinen Stundenplan an.',
        style: k.meta,
      );
    }
    if (s.timetable.content == null) {
      if (s.timetable.failed) {
        return LiveMessage(
          text: s.timetable.offline
              ? 'Keine Verbindung und noch nichts gespeichert.'
              : 'Der Stundenplan ließ sich nicht laden.',
          style: k.meta,
          action: TextButton(
            onPressed: s.refresh,
            child: Text('Erneut versuchen', style: k.link),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return builder(context, s);
  }
}

class LiveMessage extends StatelessWidget {
  const LiveMessage({required this.text, required this.style, this.action});

  final String text;
  final TextStyle style;
  final Widget? action;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(Sp.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: style),
          ?action,
        ],
      ),
    ),
  );
}

/// Offene Hausaufgaben: Kurse, deren neuester Eintrag eine Hausaufgabe hat,
/// die nicht als erledigt markiert ist (Lesson.currentEntry, liblanis).
/// Grenze: nur der neueste Eintrag je Kurs – ältere offene Aufgaben zeigt
/// auch die Übersicht des Portals nicht.
int liveOpenHomework(LiveSnapshot s) => [
  for (final l in s.lessons.content ?? const <Lesson>[])
    if (l.currentEntry?.homework case final h? when !h.homeWorkDone) l,
].length;

/// Ungelesene, nicht ausgeblendete Nachrichten laut Übersicht.
int liveUnreadMessages(LiveSnapshot s) => [
  for (final e in s.conversations.content ?? const <OverviewEntry>[])
    if (e.unread && !e.hidden) e,
].length;
