import 'package:dio/dio.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/view/settings/subsettings/debug_export.dart'
    show filterPresetsForSchool;
import 'package:lanis/view/settings/subsettings/debug_export_presets.dart';

import 'anonymizer.dart';

/// Ergebnis des anonymen Exports: der Text zum Teilen und die Wörter, die
/// unverändert blieben (zur Prüfung vor dem Teilen).
class AnonExport {
  const AnonExport({required this.text, required this.kept});

  final String text;
  final List<String> kept;
}

/// Seiten des anonymen Exports je Kontoart – nur lesende Abrufe (GET bzw.
/// die POST-Abfragen, mit denen auch die App liest).
///
/// Bewusst NICHT dabei:
/// - Nachrichten, Profil, Wahlen, Abgaben, Krankmeldung: persönlicher als
///   der Aufbau wert ist; ihr Aufbau ist aus Schülerkonten bekannt.
/// - Kursseiten von Lehrkräften: Ursache (liblanis LessonsTeacherParser,
///   'deleteBookEntry'/'newBookEntry'): Auf der Lehrerseite stehen auch
///   ändernde Links. Welche nur lesen, zeigt erst die Übersicht; daher
///   folgt der Export dort keinem Link.
List<DebugExportPresetId> anonPresetsFor(AccountType? type) => [
  DebugExportPresetId.appOverview,
  DebugExportPresetId.substitutionsMain,
  DebugExportPresetId.substitutionsAjax,
  DebugExportPresetId.timetable,
  DebugExportPresetId.calendarMain,
  DebugExportPresetId.calendarEvents,
  if (type == AccountType.teacher)
    DebugExportPresetId.lessonsTeacher
  else ...[
    DebugExportPresetId.lessonsStudent,
    DebugExportPresetId.lessonsCourseDetail,
  ],
  DebugExportPresetId.studyGroups,
  DebugExportPresetId.dataStorage,
];

String _typeName(AccountType? t) => switch (t) {
  AccountType.teacher => 'Lehrkraft',
  AccountType.parent => 'Eltern',
  AccountType.student => 'Schüler',
  null => 'unbekannt',
};

/// Ruft die Seiten aus [anonPresetsFor] ab und gibt sie nur anonymisiert
/// zurück (Anonymizer). Die Rohantworten bleiben im Speicher; gebraucht
/// werden sie nur, um Folgeseiten zu finden (Kurslinks, Plan-Tage).
///
/// Ausgegeben werden je Seite: Methode, Pfad mit verwürfelten Werten,
/// Status, Inhaltstyp und der anonymisierte Inhalt. Keine Kopfzeilen und
/// keine Cookies (darin Sitzung und Schulnummer). Die Schulnummer ist
/// außerdem in [Anonymizer.secretNumbers] und verschwindet aus allen Zahlen.
Future<AnonExport> runAnonExport({
  required Dio dio,
  required AccountType? type,
  required int schoolId,
  required List<dynamic> travelMenu,
  required String version,
  DateTime? now,
  void Function(int done, int total)? onProgress,
  Anonymizer? anonymizer,
}) async {
  final a = anonymizer ?? Anonymizer(secretNumbers: ['$schoolId']);
  final wanted = anonPresetsFor(type).toSet();
  final presets = filterPresetsForSchool(
    selected: wanted,
    travelMenu: travelMenu,
  ).kept;

  final ctx = DebugExportPresetContext();
  final out = StringBuffer();
  final day = (now ?? DateTime.now()).toIso8601String().substring(0, 10);

  // Antworten, die Folgeseiten brauchen, werden vorab geholt und unten
  // wiederverwendet (kein zweiter Abruf): der Vertretungsplan (seine Tage
  // braucht substitutionsAjax) und die Kursübersicht (Kurslinks für
  // lessonsCourseDetail).
  final fetched = <String, Response<dynamic>?>{};
  Future<Response<dynamic>?> get(String name, DebugExportHttpRequest r) async =>
      fetched[name] ??= await _tryRequest(dio, r);

  if (presets.any((p) => p.needsSubstitutionHtml)) {
    final r = await get(
      DebugExportPresetId.substitutionsMain.name,
      substitutionsMainRequest(),
    );
    ctx.substitutionsHtml = _asString(r?.data);
  }
  final sections = <(String, DebugExportHttpRequest)>[];
  for (final p in presets) {
    for (final s in p.buildSections(ctx)) {
      sections.add((s.name, s.request));
      if (p.id == DebugExportPresetId.lessonsStudent) {
        ctx.lessonsHtml = _asString((await get(s.name, s.request))?.data);
      }
    }
  }

  final body = StringBuffer();
  for (final (i, (name, request)) in sections.indexed) {
    onProgress?.call(i, sections.length);
    body.writeln('=== $name: ${request.method} ${_shortUrl(a, request)} ===');
    final r = await get(name, request);
    if (r == null) {
      body.writeln('Fehler beim Abruf');
    } else {
      final ct = r.headers.value('content-type') ?? '';
      body.writeln('Status ${r.statusCode} · $ct');
      body.writeln(a.body(_asString(r.data), contentType: ct));
    }
    body.writeln();
  }
  onProgress?.call(sections.length, sections.length);

  out
    ..writeln('Schulportal-App – anonymer Export')
    ..writeln('Version $version · Konto: ${_typeName(type)} · $day')
    ..writeln(
      'Verwürfelt: alle Wörter außer Beschriftungen (gleiche Wörter gleich), '
      'Noten und Punkte zufällig, Schulnummer entfernt, keine Bilder, '
      'Skripte, Cookies oder Kopfzeilen.',
    )
    ..writeln('Unverändert: Seitenaufbau, Zahlen, Uhrzeiten, Daten und:')
    ..writeln(a.kept.join(', '))
    ..writeln()
    ..write(body);
  return AnonExport(text: out.toString(), kept: a.kept.toList());
}

String _shortUrl(Anonymizer a, DebugExportHttpRequest r) {
  final u = r.url.replaceFirst('$sphBase/', '');
  final q = r.queryParameters;
  if (q == null || q.isEmpty) return a.url(u);
  final s = q.entries.map((e) => '${e.key}=${e.value}').join('&');
  return a.url(u.contains('?') ? '$u&$s' : '$u?$s');
}

String _asString(Object? d) => d is String ? d : '${d ?? ''}';

Future<Response<dynamic>?> _tryRequest(
  Dio dio,
  DebugExportHttpRequest r,
) async {
  try {
    return await _request(dio, r);
  } catch (_) {
    return null;
  }
}

/// Wie runDebugExportPresets: Weiterleitungen (302) höchstens zweimal, als
/// GET ohne Inhalt.
Future<Response<dynamic>> _request(Dio dio, DebugExportHttpRequest r) async {
  var current = r;
  for (var hop = 0; ; hop++) {
    final res = await dio.request<dynamic>(
      current.url,
      options: Options(
        method: current.method,
        headers: current.headers,
        contentType: current.contentType,
        followRedirects: false,
        validateStatus: (_) => true,
      ),
      data: current.data,
      queryParameters: current.queryParameters,
    );
    final loc = res.headers.value('location');
    if (res.statusCode != 302 || loc == null || hop >= 2) return res;
    current = DebugExportHttpRequest(
      method: 'GET',
      url: Uri.parse(current.url).resolve(loc.trim()).toString(),
      headers: current.headers,
    );
  }
}

/// Eine einzelne Seite abrufen und anonymisieren – für „Anonym senden“ bei
/// einer Seite, die die App nicht lesen konnte (page_report.dart).
/// Ursache (Entwurf 26.10.26): Statt des ganzen Exports nur die Seite, an
/// der es scheiterte – kleiner und genau passend zum Fehler.
Future<AnonExport> anonPage({
  required Dio dio,
  required DebugExportHttpRequest request,
  required int schoolId,
  required String version,
  required String label,
  Anonymizer? anonymizer,
}) async {
  final a = anonymizer ?? Anonymizer(secretNumbers: ['$schoolId']);
  final r = await _request(dio, request);
  final ct = r.headers.value('content-type') ?? '';
  final page = a.body(_asString(r.data), contentType: ct);
  final text = StringBuffer()
    ..writeln('Schulportal-App – anonyme Seite: $label')
    ..writeln('Version $version · ${request.method} ${_shortUrl(a, request)}')
    ..writeln('Status ${r.statusCode} · $ct')
    ..writeln('Unverändert: ${a.kept.join(', ')}')
    ..writeln()
    ..write(page);
  return AnonExport(text: text.toString(), kept: a.kept.toList());
}
