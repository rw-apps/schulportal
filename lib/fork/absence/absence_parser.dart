import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' show parse;
import 'package:liblanis/liblanis.dart';

import 'absence_form.dart';

/// Modul „Abwesenheiten“ (Krankmeldung), das liblanis nicht kennt.
///
/// Beleg: App-Liste von Schule A für Eltern (Export 16.10.26)
/// enthält `abwesenheitsmeldung.php`; die Seite trägt den Hinweis „Die Schule
/// erlaubt für dieses Kind Meldungen.“ Grenze: Nur Elternkonten; für Schüler-
/// konten liegt keine Antwort vor.
const forkAbsenceApplet = AppletMeta(
  appletPhpUrl: 'abwesenheitsmeldung.php',
  supportedAccountTypes: [AccountType.parent],
  // Die Datumsgrenzen ändern sich mit der Uhrzeit (12-Uhr-Regel), daher
  // kurz; die Maske lädt beim Öffnen ohnehin neu.
  refreshInterval: Duration(minutes: 5),
);

/// Module des Forks, die zusätzlich zu Applets.all geprüft werden.
const forkApplets = [forkAbsenceApplet];

/// Lädt das Formular samt bestehender Meldungen.
class AbsenceParser extends AppletParser<AbsenceForm> {
  AbsenceParser(
    AppletContext ctx, {
    required Future<bool> Function() isConnected,
  }) : super(ctx, forkAbsenceApplet, isConnected: isConnected);

  @override
  Future<AbsenceForm> getHome() async {
    final response = await ctx.session.dio.get(
      'https://start.schulportal.hessen.de/abwesenheitsmeldung.php'
      '?cacheBreaker=${DateTime.now().millisecondsSinceEpoch}',
    );
    final form = parseAbsenceForm(parse(response.data.toString()));
    // Kein Formular heißt fast immer: Sitzung verloren. Werfen, damit
    // AppletParser.fetchData einmal neu anmeldet und es erneut versucht.
    if (form == null) {
      throw UnknownException('abwesenheitsmeldung.php: kein meldungForm');
    }
    return form;
  }
}

final absenceParserProvider = Provider<AbsenceParser>((ref) {
  final ctx = ref.watch(appletContextProvider);
  final parser = AbsenceParser(
    ctx,
    isConnected: () => ref.read(connectionCheckerProvider).connected,
  );
  ref.onDispose(parser.dispose);
  return parser;
});

/// Antwort der Portal-Prüfung.
class AbsenceCheck {
  const AbsenceCheck(this.ok, this.errors);
  final bool ok;
  final List<String> errors;
}

/// Liest die JSON-Antwort der Prüfung `{success: bool, errors: [..]}`
/// (Portal-Skript meldungEltern.js). Fehlertexte können HTML enthalten,
/// die Tags werden entfernt. Unlesbare Antwort = nicht ok, mit Hinweis.
AbsenceCheck parseAbsenceCheck(Object? data) {
  Object? json = data;
  if (data is String) {
    try {
      json = jsonDecode(data);
    } on FormatException {
      return const AbsenceCheck(false, [
        'Das Portal hat die Prüfung nicht wie erwartet beantwortet.',
      ]);
    }
  }
  if (json is! Map) {
    return const AbsenceCheck(false, [
      'Das Portal hat die Prüfung nicht wie erwartet beantwortet.',
    ]);
  }
  if (json['success'] == true) return const AbsenceCheck(true, []);
  final raw = json['errors'];
  final errors = raw is List
      ? [
          for (final e in raw)
            e
                .toString()
                .replaceAll(RegExp(r'<[^>]+>'), ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim(),
        ].where((e) => e.isNotEmpty).toList()
      : <String>[];
  return AbsenceCheck(
    false,
    errors.isEmpty ? ['Das Portal hat die Meldung abgelehnt.'] : errors,
  );
}

const _absenceUrl =
    'https://start.schulportal.hessen.de/abwesenheitsmeldung.php';

/// Fragt das Portal, ob es die Meldung annehmen würde. Speichert nichts.
///
/// Beleg: Portal-Skript meldungEltern.js (Export 16.10.26) schickt das
/// Formular zuerst mit `check=1` per Ajax und erwartet JSON
/// `{success, errors}`; erst bei Erfolg sendet es das Formular ein zweites Mal
/// OHNE `check` – erst das ist die Meldung. Dieses zweite Senden ist in der
/// App bewusst nicht eingebaut (Entscheidung 16.10.26: vorerst nur prüfen).
Future<AbsenceCheck> checkAbsence(
  LanisSession session,
  Map<String, String> fields,
) async {
  assert(!fields.containsKey('save'));
  final r = await session.dio.post(
    _absenceUrl,
    data: {...fields, 'check': '1'},
    options: Options(
      contentType: Headers.formUrlEncodedContentType,
      responseType: ResponseType.plain,
      headers: {'X-Requested-With': 'XMLHttpRequest'},
    ),
  );
  return parseAbsenceCheck(r.data);
}
