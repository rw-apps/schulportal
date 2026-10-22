import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/utils/applet_settings.dart';

import '../../courses_scan.dart';
import '../../homework_ledger.dart';
import '../../offline_store.dart';
import '../../substitution_history.dart';
import '../../lessons_parent.dart';
import '../../l10n/l10n.dart';
import '../login_errors.dart';
import '../kit.dart';
import 'feed_source.dart';
import 'serial_loader.dart';
import '../../mensa.dart';
import '../plan/lesson_times.dart';
import '../plan/plan_from_lanis.dart';
import '../plan/plan_model.dart';
import '../../kid_name.dart';
export '../../kid_name.dart' show shortFirstName;
import '../../class_choice.dart';
import '../../portal_extras.dart';
import '../today/today_from_lanis.dart' show classFromCourses;

/// Schlüssel der Gruppenwahl in den Einstellungen des Kontos (unter
/// `stundenplan.php/…`, getrennt von den Lanis-Schlüsseln wie
/// `hidden-lessons`).
const groupChoiceSetting = 'fork-group-choice';

/// Von Hand eingetragene Lehrernamen (Kürzel → Name), ebenfalls je Konto.
/// Bewusst nur auf dem Gerät: Echte Namen gehören nicht ins öffentliche
/// Repository (Entscheidung 16.10.26).
const teacherNamesSetting = 'fork-teacher-names';

/// Selbst eingetragene Stundenzeiten (LessonTimes.toMap), je Konto; nur für
/// Schulen ohne Uhrzeiten im Stundenplan.
const lessonTimesSetting = 'fork-lesson-times';

/// Gespeicherte Stundenzeiten eines Kontos, null = keine.
LessonTimes? storedLessonTimes(TypedSettings s) => LessonTimes.fromMap(
  settingStrings(
    resolveStoredAppletSetting(
      s,
      'stundenplan.php/$lessonTimesSetting',
      const <String, dynamic>{},
    ),
  ),
);

const _settingsApplet = 'stundenplan.php';

/// Zählt hoch, wenn Einstellungen von außen ersetzt wurden (Eingaben
/// übertragen, settings_transfer.dart) – jede LiveDataScope liest dann neu.
/// Ursache: _readSettings liest nur einmal je Konto; ohne Anstoß zeigte die
/// App die übernommenen Stundenzeiten erst nach einem Neustart.
final settingsRevision = ValueNotifier<int>(0);

/// Alte Adresse der Mensa-Bestellseite je Konto (bis 9341); gilt weiter für
/// Kinder ohne eigene Adresse (MensaAddresses.legacy).
const mensaUrlSetting = 'fork-mensa-url';

/// Adressen der Mensa-Bestellseite je Kind (MensaAddresses, JSON).
const mensaUrlsSetting = 'fork-mensa-urls';

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
  int colorIndex = 0,
  LessonTimes? lessonTimes,
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
  final courses = <CourseRef>[
    for (final l in lessons)
      (name: l.name, teachers: {for (final t in l.teachers) ?t.teacherKuerzel}),
  ];
  final plan = kidPlanFromTimetable(
    tt,
    firstName: firstName,
    colorIndex: colorIndex,
    lessonTimes: lessonTimes,
    teacherNames: names,
    courseNames: [for (final l in lessons) l.name],
    courses: courses,
  );
  final auto = autoGroupChoice(plan, courses);
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
    required this.setMensaUrl,
    this.lessonTimes,
    this.setLessonTimes,
    this.courseScan,
    this.setCourseScan,
    this.homework = HomeworkLedger.empty,
    this.setHomework,
    this.mensa = const MensaAddresses({}),
    this.accountKey = '',
    this.kids = const [],
    this.classChoice,
    this.classExpired = false,
    this.setClass,
    this.photo,
    this.electionOpen = false,
    this.substitutionHistory = SubstitutionHistory.empty,
  });

  /// Gespeicherte Vertretungen vergangener Tage (substitution_history.dart).
  final SubstitutionHistory substitutionHistory;

  /// Vertretungstage für den Kalender: gelieferte plus gespeicherte bis
  /// heute. Nur für die Anzeige – Benachrichtigungen und „Heute“ arbeiten
  /// mit dem gelieferten Plan, sonst meldeten sie alte Änderungen erneut.
  List<SubstitutionDay> substitutionDaysWithPast(DateTime now) =>
      substitutionHistory.withPast(
        substitutions.content?.days ?? const [],
        now,
      );

  /// Profilfoto des Schülerkontos (portal_extras.dart), null = keins.
  final Uint8List? photo;

  /// Im Wahltool ist eine Wahl offen (portal_extras.dart).
  final bool electionOpen;

  /// Von Hand eingetragene Klasse (class_choice.dart), null = keine gültige.
  final ClassChoice? classChoice;

  /// Ein früherer Eintrag ist mit dem Schuljahr abgelaufen.
  final bool classExpired;

  /// Eintrag speichern; null entfernt ihn.
  final void Function(String? name)? setClass;

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

  /// Selbst eingetragene Stundenzeiten (null = keine) und Speichern
  /// (null = löschen).
  final LessonTimes? lessonTimes;
  final void Function(LessonTimes? times)? setLessonTimes;

  /// Letzte Auswertung aller Kursseiten (courses_scan.dart): anstehende
  /// Arbeiten für „Heute“, Notenzahl für den Hinweis im Hintergrund.
  final CourseScan? courseScan;
  final void Function(CourseScan scan)? setCourseScan;

  /// Abgehakte und wieder geöffnete Hausaufgaben (homework_ledger.dart).
  final HomeworkLedger homework;

  /// Ändert den Stand mit einer Funktion auf dem JEWEILS aktuellen Stand.
  /// Ursache: „Rückgängig“ in der Meldung hält einen älteren Stand fest; ein
  /// fertiger Wert von damals würde spätere Haken überschreiben.
  final void Function(HomeworkLedger Function(HomeworkLedger) update)?
  setHomework;

  /// Selbst eingetragene Mensa-Bestellseiten je Kind.
  final MensaAddresses mensa;
  final void Function(MensaKidKey kid, String? url) setMensaUrl;

  /// Lokale Kontonummer (für die Zuordnung der Mensa-Anmeldung).
  final String accountKey;
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

  /// Vorname des Kindes; leer, solange er unbekannt ist.
  ///
  /// Ursache (Prüfbefund 17.10.26): Beim Elternkonto steht in
  /// userData['vorname'] der Name des Elternteils – „Heute“ zeigte ihn, bis
  /// „Mein Unterricht“ geladen war (bei Ladefehler dauerhaft). Nur das
  /// Schülerkonto ist selbst das Kind. Die Oberfläche setzt für leer
  /// „Dein Kind“ in der Sprache ein ([livePlanOf] fallbackName).
  ///
  /// Nur der erste Vorname („Lena Marie“ → „Lena“). Ursache
  /// (Bildschirmfoto 20.10.26): Mit Zweitnamen wurde der Kopf der Karte zu
  /// lang und die Schule abgeschnitten. Grenze: Doppelnamen mit Leerzeichen
  /// („Anna Lena“) werden gekürzt, mit Bindestrich bleiben sie ganz.
  String get firstName {
    final k = kids;
    final full = k.isNotEmpty
        ? k.first.firstName
        : session.accountTypeOrNull == AccountType.parent
        ? ''
        : (session.userData['vorname'] ?? '');
    return shortFirstName(full);
  }

  /// Kind der Karte in „Heute“ (ein Kind je Konto, siehe LiveTodayPage).
  MensaKidKey get mensaKid => kids.isEmpty ? '' : kids.first.pupilId;

  /// Bestellseite des Kindes in „Heute“.
  String? get mensaUrl => mensa.of(mensaKid);

  /// Wer auf der Bestellseite angemeldet ist (MensaPage.owner).
  String mensaOwner(MensaKidKey kid) => '$accountKey:$kid';

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

class _LiveDataScopeState extends ConsumerState<LiveDataScope>
    with WidgetsBindingObserver {
  final _tt = FeedSource<TimeTable>('stundenplan.php');
  final _lessons = FeedSource<Lessons>(
    'meinunterricht.php',
    store: lessonsCodec,
  );
  final _subs = FeedSource<SubstitutionPlan>('vertretungsplan.php');
  final _cal = FeedSource<List<CalendarEvent>>(
    'kalender.php',
    store: calendarCodec,
  );
  final _conv = FeedSource<List<OverviewEntry>>('nachrichten.php');

  GroupChoice _choice = const {};
  Map<String, String> _names = const {};
  LessonTimes? _times;
  CourseScan? _scan;
  HomeworkLedger _homework = HomeworkLedger.empty;
  SubstitutionHistory _subsHistory = SubstitutionHistory.empty;
  SubstitutionPlan? _subsRecorded;
  ClassChoice? _class;
  bool _classExpired = false;
  Uint8List? _photo;
  bool _electionOpen = false;
  DateTime? _electionChecked;
  MensaAddresses _mensa = const MensaAddresses({});
  int? _settingsFor;
  late final _loader = SerialLoader((force, only) async {
    await _run(_supported, force, only);
    _scheduleRetry();
  });
  Set<String> _loadedFor = const {};
  Set<String> _supported = const {};
  Timer? _timer;
  DateTime? _lastLoad;

  /// Schneller Wiederholversuch nach einem Fehler ([_scheduleRetry]).
  Timer? _retry;
  final _backoff = RetryBackoff(retryDelays);

  /// Abstände der Wiederholversuche nach einem Fehler; danach wieder der
  /// 10-Minuten-Takt ([_period]). Ursache (Rückmeldung 21.10.26, Vorschlag
  /// c): Nach einem Ausfall stand der alte Stand sonst bis zu 10 Minuten,
  /// obwohl das Portal oft nach ein, zwei Minuten wieder antwortet.
  static const retryDelays = [
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

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
    settingsRevision.addListener(_onSettingsReplaced);
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
    _rereadScan();
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
    settingsRevision.removeListener(_onSettingsReplaced);
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _retry?.cancel();
    for (final s in [_tt, _lessons, _subs, _cal, _conv]) {
      s.dispose();
    }
    super.dispose();
  }

  void _onSettingsReplaced() {
    final id = _settingsFor;
    if (!mounted || id == null) return;
    setState(() {
      _settingsFor = null;
      _readSettings(id);
    });
    // Fotos an/aus (Einstellungen) gilt sofort; das Wahltool bleibt getaktet.
    _loadExtras(false);
  }

  /// Auswertung der Kursseiten neu aus dem Speicher lesen. Ursache
  /// (Prüfung 20.10.26): _readSettings liest nur einmal je Konto; die
  /// tägliche Auswertung im Hintergrund (notify_task.dart) kam so erst nach
  /// einem Neustart in „Alle“, Heute und Kalender an, während die
  /// Hinweise schon den neuen Stand kannten. Grenze: nur beim Zurückkehren
  /// in die App und beim Ziehen zum Aktualisieren, nicht laufend.
  void _rereadScan() {
    if (!mounted || _settingsFor == null) return;
    final s = ref.read(accountSpecificSettingsProvider);
    if (s == null) return;
    final fresh = storedCourseScan(s);
    if (fresh == null) return;
    final old = _scan;
    if (old != null && jsonEncode(old.toJson()) == jsonEncode(fresh.toJson())) {
      return;
    }
    setState(() => _scan = fresh);
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
    _times = storedLessonTimes(s);
    _scan = storedCourseScan(s);
    _homework = HomeworkLedger.decode(s.getString(homeworkLedgerSetting));
    _subsHistory = SubstitutionHistory.decode(
      s.getString(substitutionHistorySetting),
    );
    _subsRecorded = null;
    _class = storedClass(s);
    _classExpired = classExpired(s);
    _mensa = MensaAddresses.decode(
      s.getString('fork/$mensaUrlsSetting'),
      legacy: s.getString('fork/$mensaUrlSetting'),
    );
  }

  /// Jeden gelieferten Vertretungsplan in die Ablage übernehmen
  /// (substitution_history.dart). Nur einmal je Plan-Objekt: Der Aufruf
  /// steht im Aufbau und läuft sonst bei jedem setState.
  void _recordSubstitutions() {
    final plan = _subs.feed.content;
    if (plan == null || identical(plan, _subsRecorded)) return;
    _subsRecorded = plan;
    final next = _subsHistory.record(plan.days, DateTime.now());
    final raw = next.encode();
    if (raw == _subsHistory.encode()) return;
    _subsHistory = next;
    ref
        .read(accountSpecificSettingsProvider)
        ?.setString(substitutionHistorySetting, raw);
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
    if (only == null) {
      _lastLoad = DateTime.now();
      await _loadExtras(force);
    }
  }

  /// Nach jedem Durchgang: Sind Quellen fehlgeschlagen, nach
  /// [retryDelays] nur diese erneut holen (im Vordergrund); gelingt alles,
  /// beginnt die Folge beim nächsten Fehler wieder bei einer Minute.
  /// Grenze: Nach dem dritten Versuch übernimmt der 10-Minuten-Takt.
  void _scheduleRetry() {
    if (!mounted) return;
    final failed = {
      for (final s in [_tt, _lessons, _subs, _cal, _conv])
        if (s.parser != null &&
            _supported.contains(s.phpUrl) &&
            s.feed.error != null)
          s.phpUrl,
    };
    if (_retry?.isActive ?? false) return;
    final wait = _backoff.after(failed: failed.isNotEmpty);
    if (wait == null) {
      _retry?.cancel();
      _retry = null;
      return;
    }
    _retry = Timer(wait, () {
      _retry = null;
      if (!mounted) return;
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != null && state != AppLifecycleState.resumed) return;
      _loader.run(force: true, only: failed);
    });
  }

  /// Wahltool und Profilfoto (portal_extras.dart), nach den Hauptquellen.
  /// Ursache für die Taktung: Beides ändert sich selten; das Wahltool wird
  /// höchstens alle [electionCheckEvery] gefragt, das Foto liegt
  /// [photoMaxAge] im Cache des Kontos.
  Future<void> _loadExtras(bool force) async {
    final session = ref.read(sessionProvider).asData?.value;
    if (session == null || !mounted) return;
    final last = _electionChecked;
    if (offersModule(session.travelMenu, electionModule) &&
        (last == null ||
            DateTime.now().difference(last) > electionCheckEvery)) {
      try {
        final open = await loadElectionOpen(session);
        _electionChecked = DateTime.now();
        if (mounted) setState(() => _electionOpen = open);
      } catch (_) {}
    }
    final showPhotos =
        ref
            .read(sharedOverAccountSettingsProvider)
            .getBool(showPhotosSetting) ??
        true;
    if (!showPhotos) {
      if (_photo != null && mounted) setState(() => _photo = null);
      return;
    }
    if (session.accountTypeOrNull != AccountType.student) return;
    final Directory cache;
    try {
      final dir = ref.read(storageManagerProvider)?.getDocumentCacheDirectory();
      if (dir == null) return;
      cache = dir;
    } catch (_) {
      return;
    }
    final bytes = await loadProfilePhoto(session, cache, force: force);
    if (mounted) setState(() => _photo = bytes);
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
    _recordSubstitutions();
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

    final snapshot = LiveSnapshot(
      session: session,
      supported: supported,
      timetable: _tt.feed,
      lessons: _lessons.feed,
      substitutions: _subs.feed,
      substitutionHistory: _subsHistory,
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
      refresh: () {
        _rereadScan();
        return _loader.run(force: true);
      },
      mensa: _mensa,
      lessonTimes: _times,
      setLessonTimes: (v) {
        setState(() => _times = v);
        _write(lessonTimesSetting, v?.toMap() ?? const {});
      },
      courseScan: _scan,
      // Die Notenübersicht ruft das am Ende ihres Ladens auf – dann kann
      // diese Seite schon abgebaut sein (Kontowechsel); ohne die Prüfung
      // käme ref nach dem Abbau (Absturz 9349).
      homework: _homework,
      setHomework: (update) {
        if (!mounted) return;
        final v = update(_homework);
        setState(() => _homework = v);
        ref
            .read(accountSpecificSettingsProvider)
            ?.setString(homeworkLedgerSetting, v.encode());
      },
      setCourseScan: (v) {
        if (!mounted) return;
        setState(() => _scan = v);
        final st = ref.read(accountSpecificSettingsProvider);
        if (st != null) storeCourseScan(st, v);
      },
      accountKey: '${account.localId}',
      setMensaUrl: (kid, u) {
        final next = _mensa.withUrl(kid, u);
        setState(() => _mensa = next);
        final s = ref.read(accountSpecificSettingsProvider);
        s?.setString('fork/$mensaUrlsSetting', next.encode());
        // Alte Kontoadresse nur löschen, wenn MensaAddresses sie verwirft.
        if (next.legacy == null) s?.setString('fork/$mensaUrlSetting', null);
      },
      refreshMessages: () =>
          _loader.run(force: true, only: const {'nachrichten.php'}),
      kids: kids,
      classChoice: _class,
      classExpired: _classExpired,
      photo: _photo,
      electionOpen: _electionOpen,
      setClass: (name) {
        final s = ref.read(accountSpecificSettingsProvider);
        if (s == null || !mounted) return;
        final c = storeClass(s, name);
        setState(() {
          _class = c;
          _classExpired = false;
        });
      },
    );
    // Vorname für die Hinweise im Hintergrund merken (kid_name.dart);
    // schreibt nur bei Änderung.
    final name = snapshot.firstName;
    if (name.isNotEmpty) {
      final st = ref.read(accountSpecificSettingsProvider);
      if (st != null) rememberKidName(st, name);
    }
    return LiveData(snapshot: snapshot, child: widget.child);
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

/// Klasse des Kindes: der eigene Eintrag (class_choice.dart), sonst die
/// erkannte ([detectedClassName]).
String liveClassName(LiveSnapshot s) =>
    s.classChoice?.name ?? detectedClassName(s);

/// Fotos aus dem Portal zeigen (Einstellungen → Darstellung), Standard an.
const showPhotosSetting = 'fork/show-photos';

/// Von der App erkannte Klasse: aus den Benutzerdaten, sonst aus den
/// Kursnamen (classFromCourses, Ursache dort); '' = unbekannt.
String detectedClassName(LiveSnapshot s) => (s.session.userData['klasse'] ?? '')
    .trim()
    .ifEmptyThen(() => classFromCourses(s.courseNames));

extension on String {
  String ifEmptyThen(String Function() other) => isEmpty ? other() : this;
}

/// Plan und automatische Gruppenwahl, sobald der Stundenplan da ist.
/// [fallbackName]: Anzeige, solange der Vorname unbekannt ist („Dein Kind“).
({KidPlan plan, GroupChoice auto})? livePlanOf(
  LiveSnapshot s, {
  String fallbackName = '',
  int colorIndex = 0,
}) {
  final tt = s.timetable.content;
  if (tt == null) return null;
  final r = livePlan(
    tt: tt,
    lessons: s.lessons.content ?? const [],
    firstName: s.firstName.isEmpty ? fallbackName : s.firstName,
    colorIndex: colorIndex,
    lessonTimes: s.lessonTimes,
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
    final t = context.t;
    final s = LiveData.of(context);
    if (s == null) return const Center(child: CircularProgressIndicator());
    if (!needsTimetable) return builder(context, s);
    if (!s.offers('stundenplan.php')) {
      return LiveMessage(text: t.noTimetable, style: k.meta);
    }
    if (s.timetable.content == null) {
      if (s.timetable.failed) {
        return LiveMessage(
          text: s.timetable.offline
              ? t.offlineNothingSaved
              : withReason(t, t.timetableFailed, s.timetable.error),
          style: k.meta,
          action: TextButton(
            onPressed: s.refresh,
            child: Text(t.retry, style: k.link),
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

/// Offene Hausaufgaben: neueste Einträge mit Hausaufgabe, die weder Portal
/// noch App als erledigt führen, dazu in der App wieder geöffnete
/// (homeworkLists). Grenze: Ältere offene Aufgaben, die nie in der App
/// standen, zeigt auch die Übersicht des Portals nicht.
int liveOpenHomework(LiveSnapshot s) => homeworkLists(
  s.lessons.content ?? const <Lesson>[],
  s.homework,
  subjectOf: (l) => l.name,
).open.length;

/// Ungelesene, nicht ausgeblendete Nachrichten laut Übersicht.
int liveUnreadMessages(LiveSnapshot s) => [
  for (final e in s.conversations.content ?? const <OverviewEntry>[])
    if (e.unread && !e.hidden) e,
].length;
