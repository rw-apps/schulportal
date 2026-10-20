import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../generated/l10n.dart';

const sphBase = 'https://start.schulportal.hessen.de';

const _xhrFormHeaders = <String, String>{
  'Accept': '*/*',
  'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
  'Sec-Fetch-Dest': 'empty',
  'Sec-Fetch-Mode': 'cors',
  'Sec-Fetch-Site': 'same-origin',
};

const _conversationsXhrHeaders = <String, String>{
  ..._xhrFormHeaders,
  'X-Requested-With': 'XMLHttpRequest',
};

enum DebugExportPresetId {
  appOverview,
  absences,
  substitutionsMain,
  timetable,
  calendarMain,
  lessonsStudent,
  lessonsCourseDetail,
  lessonsTeacher,
  dataStorage,
  dataStorageFolders,
  studyGroups,
  substitutionsAjax,
  calendarEvents,
  conversations,
  elections,
  profile,
}

/// Built request ready for [Dio.request].
class DebugExportHttpRequest {
  final String method;
  final String url;
  final Map<String, dynamic>? queryParameters;
  final Object? data;
  final Map<String, String> headers;
  final String? contentType;

  const DebugExportHttpRequest({
    required this.method,
    required this.url,
    this.queryParameters,
    this.data,
    this.headers = const {},
    this.contentType,
  });

  DebugExportHttpRequest copyWith({
    String? method,
    String? url,
    Map<String, dynamic>? queryParameters,
    Object? data,
    Map<String, String>? headers,
    String? contentType,
  }) {
    return DebugExportHttpRequest(
      method: method ?? this.method,
      url: url ?? this.url,
      queryParameters: queryParameters ?? this.queryParameters,
      data: data ?? this.data,
      headers: headers ?? this.headers,
      contentType: contentType ?? this.contentType,
    );
  }
}

/// One logged subsection produced by a preset (e.g. one AJAX date).
class DebugExportSection {
  final String name;
  final DebugExportHttpRequest request;
  final String? note;

  const DebugExportSection({
    required this.name,
    required this.request,
    this.note,
  });
}

/// Shared state while expanding selected presets into HTTP sections.
class DebugExportPresetContext {
  String? substitutionsHtml;

  /// Fork: Antwort von meinunterricht.php (gesetzt im Runner nach dem Preset
  /// lessonsStudent), Quelle der Kurs-Links für [parseCourseDetailLinks].
  String? lessonsHtml;

  /// Fork: Antwort von dateispeicher.php (Startordner), Quelle der Ordner für
  /// [parseDataStorageFolders].
  String? dataStorageHtml;
}

/// Fork: bis zu [max] Ordnernummern aus dem Startordner des Dateispeichers
/// (`data-dir="6"`). Ursache (Wunsch 20.10.26, Dateispeicher in der App):
/// Der Export enthielt nur den Startordner; wie ein Ordner mit Dateien
/// aussieht (table#files, liblanis DataStorageParser.getNode), war an
/// echten Daten nicht prüfbar.
List<int> parseDataStorageFolders(String html, {int max = 3}) {
  final ids = <int>[];
  for (final m in RegExp(r'data-dir="(\d+)"').allMatches(html)) {
    final id = int.parse(m.group(1)!);
    if (id == 0 || ids.contains(id)) continue;
    ids.add(id);
    if (ids.length >= max) break;
  }
  return ids;
}

/// Fork: bis zu [max] verschiedene Kurs-Detail-Links aus meinunterricht.php.
///
/// Ursache: Für Elternkonten fehlte eine echte Antwort der Kursseite
/// (`meinunterricht.php?a=sus_view&id=…&p=<Kind>`, Export Schule A 16.10.26); ohne
/// sie lässt sich die Detailansicht für Eltern nicht bauen. Grenze: Links mit
/// `halb=` (Halbjahres-Varianten derselben Mappe) werden ausgelassen, damit
/// zwei VERSCHIEDENE Kurse kommen.
List<String> parseCourseDetailLinks(String html, {int max = 2}) {
  final links = <String>[];
  for (final m in RegExp(
    r'href="(meinunterricht\.php\?a=sus_view[^"]*)"',
  ).allMatches(html)) {
    final link = m.group(1)!.replaceAll('&amp;', '&');
    if (link.contains('halb=') || links.contains(link)) continue;
    links.add(link);
    if (links.length >= max) break;
  }
  return links;
}

typedef DebugExportSectionBuilder =
    List<DebugExportSection> Function(DebugExportPresetContext ctx);

class DebugExportPreset {
  final DebugExportPresetId id;
  final String Function(AppLocalizations l10n) label;

  /// Needs the substitutions main HTML (for `data-tag` date discovery).
  final bool needsSubstitutionHtml;

  final DebugExportSectionBuilder buildSections;

  /// Fork: Modul-Datei laut App-Liste der Schule (`link` in
  /// startseite.php?a=ajax&f=apps), null = immer abfragen.
  ///
  /// Ursache: Export Schule A/Eltern 16.10.26 10:19 — `dateispeicher.php` gibt es
  /// an der Schule nicht; das Portal antwortete mit einer Fehlerseite, setzte
  /// einen neuen, NICHT angemeldeten sid und alle folgenden Presets liefen auf
  /// „Login nötig“. Nicht freigeschaltete Module werden daher übersprungen.
  final String? modulePhp;

  const DebugExportPreset({
    required this.id,
    required this.label,
    this.modulePhp,
    required this.buildSections,
    this.needsSubstitutionHtml = false,
  });
}

DebugExportHttpRequest _get(String path) =>
    DebugExportHttpRequest(method: 'GET', url: '$sphBase/$path');

DebugExportHttpRequest substitutionsMainRequest() =>
    _get('vertretungsplan.php');

/// [tag] must be `dd.MM.yyyy` as used by the substitutions parser.
DebugExportHttpRequest substitutionsAjaxRequest(String tag) =>
    DebugExportHttpRequest(
      method: 'POST',
      url: '$sphBase/vertretungsplan.php',
      queryParameters: const {'a': 'my'},
      data: {'tag': tag, 'ganzerPlan': 'true'},
      headers: _xhrFormHeaders,
      contentType: Headers.formUrlEncodedContentType,
    );

DebugExportHttpRequest calendarEventsRequest({
  required DateTime startDate,
  required DateTime endDate,
  String searchQuery = '',
}) {
  final formatter = DateFormat('yyyy-MM-dd');
  final start = formatter.format(startDate);
  final end = formatter.format(endDate);
  return DebugExportHttpRequest(
    method: 'POST',
    url: '$sphBase/kalender.php',
    queryParameters: {
      'f': 'getEvents',
      's': searchQuery,
      'start': start,
      'end': end,
    },
    data: 'f=getEvents&start=$start&end=$end&s=$searchQuery',
    headers: _xhrFormHeaders,
    contentType: Headers.formUrlEncodedContentType,
  );
}

/// Default calendar XHR range: first day of this month through last day of next.
({DateTime start, DateTime end}) defaultCalendarExportRange([DateTime? now]) {
  final n = now ?? DateTime.now();
  final start = DateTime(n.year, n.month, 1);
  final end = DateTime(n.year, n.month + 2, 0);
  return (start: start, end: end);
}

/// Same date discovery idea as [SubstitutionsParser.getSubstitutionDates].
List<String> parseSubstitutionPlanDates(String document) {
  final datePattern = RegExp(r'data-tag="(\d{2})\.(\d{2})\.(\d{4})"');
  final matches = datePattern.allMatches(document);
  final uniqueDates = <String>[];
  for (final match in matches) {
    final day = int.parse(match.group(1) ?? '00');
    final month = int.parse(match.group(2) ?? '00');
    final year = int.parse(match.group(3) ?? '00');
    final dateString = DateFormat(
      'dd.MM.yyyy',
    ).format(DateTime(year, month, day));
    if (!uniqueDates.contains(dateString)) {
      uniqueDates.add(dateString);
    }
  }
  return uniqueDates;
}

List<DebugExportSection> _single(
  DebugExportPresetId id,
  DebugExportHttpRequest request,
) => [DebugExportSection(name: id.name, request: request)];

List<DebugExportSection> _buildSubstitutionsAjax(DebugExportPresetContext ctx) {
  final html = ctx.substitutionsHtml;
  final dates = html != null ? parseSubstitutionPlanDates(html) : <String>[];
  if (dates.isEmpty) {
    final today = DateFormat('dd.MM.yyyy').format(DateTime.now());
    return [
      DebugExportSection(
        name: '${DebugExportPresetId.substitutionsAjax.name}@$today',
        request: substitutionsAjaxRequest(today),
        note:
            'No substitution dates found in main HTML; '
            'using today ($today) for AJAX.',
      ),
    ];
  }
  return [
    for (final date in dates)
      DebugExportSection(
        name: '${DebugExportPresetId.substitutionsAjax.name}@$date',
        request: substitutionsAjaxRequest(date),
        note: dates.first == date
            ? 'Substitution dates: ${dates.join(', ')}'
            : null,
      ),
  ];
}

List<DebugExportSection> _buildCalendarEvents(DebugExportPresetContext ctx) {
  final range = defaultCalendarExportRange();
  return _single(
    DebugExportPresetId.calendarEvents,
    calendarEventsRequest(startDate: range.start, endDate: range.end),
  );
}

/// Ordered list used by the picker and the export runner.
final debugExportPresets = <DebugExportPreset>[
  // Fork: App-Übersicht der Schule. Ursache: Die übrigen Presets decken nur
  // Applets ab, die liblanis schon kennt; welche Module eine Schule darüber
  // hinaus freigeschaltet hat (z. B. Krankmeldung/Abwesenheit, Elternbriefe),
  // zeigt nur diese Liste — dieselbe Quelle wie Session.getFastTravelMenu()
  // in liblanis (session.dart). Grenze: liefert nur Namen/Links, keine Inhalte.
  DebugExportPreset(
    id: DebugExportPresetId.appOverview,
    label: (l) => l.debugExportPresetAppOverview,
    buildSections: (_) => _single(
      DebugExportPresetId.appOverview,
      _get('startseite.php?a=ajax&f=apps'),
    ),
  ),
  // Fork: Krankmeldung. Ursache: Schule A führt das Modul „Abwesenheiten“
  // (abwesenheitsmeldung.php, App-Liste 16.10.26); liblanis kennt es nicht.
  // Grenze: nur GET der Übersichtsseite — es wird nichts abgeschickt.
  DebugExportPreset(
    id: DebugExportPresetId.absences,
    label: (l) => l.debugExportPresetAbsences,
    modulePhp: 'abwesenheitsmeldung.php',
    // Fork: dazu das Portal-Skript der Seite (statische Datei, nur lesen).
    // Ursache: Wie es `selectedPupils` befüllt, abschickt und die Liste
    // `#liste` nachlädt, steht nur dort; ohne das lässt sich das Absenden
    // der Krankmeldung nicht sicher nachbauen.
    buildSections: (_) => [
      ..._single(DebugExportPresetId.absences, _get('abwesenheitsmeldung.php')),
      DebugExportSection(
        name: '${DebugExportPresetId.absences.name}Script',
        request: _get('module/abwesenheitsmeldung/js/meldungEltern.js'),
      ),
    ],
  ),
  DebugExportPreset(
    id: DebugExportPresetId.substitutionsMain,
    modulePhp: 'vertretungsplan.php',
    label: (l) => l.debugExportPresetSubstitutionsMain,
    needsSubstitutionHtml: true,
    buildSections: (_) => _single(
      DebugExportPresetId.substitutionsMain,
      substitutionsMainRequest(),
    ),
  ),
  DebugExportPreset(
    id: DebugExportPresetId.timetable,
    modulePhp: 'stundenplan.php',
    label: (l) => l.debugExportPresetTimetable,
    buildSections: (_) =>
        _single(DebugExportPresetId.timetable, _get('stundenplan.php')),
  ),
  DebugExportPreset(
    id: DebugExportPresetId.calendarMain,
    modulePhp: 'kalender.php',
    label: (l) => l.debugExportPresetCalendarMain,
    buildSections: (_) =>
        _single(DebugExportPresetId.calendarMain, _get('kalender.php')),
  ),
  DebugExportPreset(
    id: DebugExportPresetId.lessonsStudent,
    modulePhp: 'meinunterricht.php',
    label: (l) => l.debugExportPresetLessonsStudent,
    buildSections: (_) =>
        _single(DebugExportPresetId.lessonsStudent, _get('meinunterricht.php')),
  ),
  // Fork: Kurs-Detailseiten (nur GET). Braucht lessonsStudent davor; ohne
  // dessen Antwort entstehen keine Abschnitte.
  DebugExportPreset(
    id: DebugExportPresetId.lessonsCourseDetail,
    modulePhp: 'meinunterricht.php',
    label: (l) => l.debugExportPresetLessonsCourseDetail,
    buildSections: (ctx) => [
      for (final (i, link) in parseCourseDetailLinks(
        ctx.lessonsHtml ?? '',
      ).indexed)
        DebugExportSection(
          name: '${DebugExportPresetId.lessonsCourseDetail.name}#${i + 1}',
          request: _get(link),
        ),
    ],
  ),
  DebugExportPreset(
    id: DebugExportPresetId.lessonsTeacher,
    modulePhp: 'meinunterricht.php',
    label: (l) => l.debugExportPresetLessonsTeacher,
    buildSections: (_) => _single(
      DebugExportPresetId.lessonsTeacher,
      _get('meinunterricht.php?jump=no'),
    ),
  ),
  DebugExportPreset(
    id: DebugExportPresetId.dataStorage,
    modulePhp: 'dateispeicher.php',
    label: (l) => l.debugExportPresetDataStorage,
    buildSections: (_) => _single(
      DebugExportPresetId.dataStorage,
      _get('dateispeicher.php?a=view&folder=0'),
    ),
  ),
  // Fork: Ordner des Dateispeichers (nur GET), braucht dataStorage davor.
  DebugExportPreset(
    id: DebugExportPresetId.dataStorageFolders,
    modulePhp: 'dateispeicher.php',
    label: (l) => l.debugExportPresetDataStorageFolders,
    buildSections: (ctx) => [
      for (final id in parseDataStorageFolders(ctx.dataStorageHtml ?? ''))
        DebugExportSection(
          name: '${DebugExportPresetId.dataStorageFolders.name}#$id',
          request: _get('dateispeicher.php?a=view&folder=$id'),
        ),
    ],
  ),
  DebugExportPreset(
    id: DebugExportPresetId.studyGroups,
    modulePhp: 'lerngruppen.php',
    label: (l) => l.debugExportPresetStudyGroups,
    buildSections: (_) =>
        _single(DebugExportPresetId.studyGroups, _get('lerngruppen.php')),
  ),
  DebugExportPreset(
    id: DebugExportPresetId.substitutionsAjax,
    modulePhp: 'vertretungsplan.php',
    label: (l) => l.debugExportPresetSubstitutionsAjax,
    needsSubstitutionHtml: true,
    buildSections: _buildSubstitutionsAjax,
  ),
  DebugExportPreset(
    id: DebugExportPresetId.calendarEvents,
    modulePhp: 'kalender.php',
    label: (l) => l.debugExportPresetCalendarEvents,
    buildSections: _buildCalendarEvents,
  ),
  DebugExportPreset(
    id: DebugExportPresetId.conversations,
    modulePhp: 'nachrichten.php',
    label: (l) => l.debugExportPresetConversations,
    buildSections: (_) => _single(
      DebugExportPresetId.conversations,
      const DebugExportHttpRequest(
        method: 'POST',
        url: '$sphBase/nachrichten.php',
        data: {'a': 'headers', 'getType': 'All', 'last': '0'},
        headers: _conversationsXhrHeaders,
        contentType: Headers.formUrlEncodedContentType,
      ),
    ),
  ),
  // Fork (Wunsch 20.10.26): Wahltool und Profilseiten, nur GET. Ursache:
  // Für den Hinweis auf offene Wahlen und das Kinderfoto fehlte die echte
  // Seitenstruktur. Grenze: Eine Wahl, die gerade nicht läuft, zeigt nur die
  // leere Seite; das Foto steht als Bildadresse darin, nicht als Bild.
  DebugExportPreset(
    id: DebugExportPresetId.elections,
    modulePhp: 'wahl.php',
    label: (l) => l.debugExportPresetElections,
    buildSections: (_) =>
        _single(DebugExportPresetId.elections, _get('wahl.php')),
  ),
  DebugExportPreset(
    id: DebugExportPresetId.profile,
    label: (l) => l.debugExportPresetProfile,
    buildSections: (_) => [
      DebugExportSection(
        name: '${DebugExportPresetId.profile.name}Foto',
        request: _get('benutzerverwaltung.php?a=userFoto'),
      ),
      DebugExportSection(
        name: '${DebugExportPresetId.profile.name}Autologins',
        request: _get('benutzerverwaltung.php?a=userAutologins'),
      ),
    ],
  ),
];
