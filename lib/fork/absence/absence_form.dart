import 'package:html/dom.dart';

import '../l10n/l10n.dart';

/// Ein Kind, für das das Elternkonto eine Abwesenheit melden kann.
class AbsencePupil {
  const AbsencePupil({
    required this.id,
    required this.name,
    required this.preselected,
    required this.allowed,
  });

  final String id;

  /// So, wie das Portal es zeigt („Vorname Nachname“).
  final String name;

  /// Vom Portal vorausgewählt (`data-preselected="true"`).
  final bool preselected;

  /// Schaltfläche ist nicht gesperrt. Gesperrt zeigt das Portal Kinder, für
  /// die die Schule keine Meldung erlaubt.
  final bool allowed;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;
}

/// Auswahl aus einem `<select>` (Art der Meldung).
class AbsenceChoice {
  const AbsenceChoice(this.value, this.label);
  final String value;
  final String label;
}

/// Ein Unterrichtsblock aus „von Block“/„bis Block“.
class AbsenceBlock {
  const AbsenceBlock({
    required this.value,
    required this.label,
    this.start,
    this.end,
  });

  final String value;

  /// Bereinigte Portal-Beschriftung, z. B. „1. Block“.
  final String label;

  /// „09:00“; aus `data-von` oder der Beschriftung.
  final String? start;
  final String? end;
}

/// Zulässiger Datumsbereich eines Feldes, wie ihn der Datepicker des
/// Portals vorgibt.
class DateRange {
  const DateRange(this.first, this.last);
  final DateTime first;
  final DateTime last;

  bool contains(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(first) && !day.isAfter(last);
  }
}

/// Eine bestehende Meldung aus der Tabelle „Aktuelle und zukünftige
/// Meldungen“ (`tbody#liste`).
class AbsenceEntry {
  const AbsenceEntry({
    required this.name,
    required this.period,
    required this.kind,
    required this.entered,
    required this.comment,
  });

  final String name;
  final String period;
  final String kind;
  final String entered;
  final String comment;
}

/// Formular „Abwesenheitsmeldung“ (abwesenheitsmeldung.php, Elternkonto).
class AbsenceForm {
  const AbsenceForm({
    required this.pupils,
    required this.kinds,
    required this.blocks,
    required this.fromRange,
    required this.toRange,
    required this.defaultFrom,
    required this.defaultTo,
    required this.rules,
    this.entries = const [],
    this.commentWarning,
  });

  final List<AbsencePupil> pupils;
  final List<AbsenceChoice> kinds;
  final List<AbsenceBlock> blocks;

  /// `null`: Portal hat keine Grenze genannt. Die Maske lässt dann nur die
  /// Vorgabe zu, statt eine eigene Regel zu raten.
  final DateRange? fromRange;
  final DateRange? toRange;
  final DateTime? defaultFrom;
  final DateTime? defaultTo;

  /// Hinweise des Portals („spätestens bis 12:00 des aktuellen Tages“ …).
  final List<String> rules;

  /// Bestehende Meldungen (leer, wenn keine).
  final List<AbsenceEntry> entries;

  /// Warnung des Portals am Kommentarfeld („Bitte keine Gesundheitsdaten
  /// eingeben.“, `#kommentarHinweis`).
  final String? commentWarning;

  List<AbsencePupil> get allowedPupils =>
      pupils.where((p) => p.allowed).toList();
}

/// Wert von `art` für eine Verspätung; alles andere gilt als Abwesenheit.
const absenceKindLate = 'verspätet';

/// Eingaben der Maske.
///
/// Abwesend („krank“): Von- und Bis-Tag, keine Blöcke. Verspätet: EIN Tag
/// („Am“) plus Block von–bis. Beleg: Portal-Skript meldungEltern.js (Export
/// 16.10.26) blendet je nach `art` die Felder `stundenVon`/`stundenBis` bzw.
/// `bis` aus. Ausgeblendete Felder schickt der Browser trotzdem mit ihrem
/// aktuellen Wert mit; [toFields] bildet das nach.
class AbsenceDraft {
  const AbsenceDraft({
    required this.pupilIds,
    required this.kind,
    required this.from,
    required this.to,
    required this.blockFrom,
    required this.blockTo,
    required this.comment,
  });

  final List<String> pupilIds;
  final String kind;
  final DateTime from;
  final DateTime to;
  final String blockFrom;
  final String blockTo;
  final String comment;

  bool get isLate => kind == absenceKindLate;

  /// Felder wie `$('#meldungForm').serialize()` im Portal-Skript.
  ///
  /// Kein `save`: Das Skript schickt das Formular per `$form.submit()` ab, ohne
  /// den Speichern-Knopf; dessen name/value ist daher nicht im Formular.
  /// `selectedPupils` = IDs mit Komma (Skript: `selectedPupils.join(',')`).
  /// Bei Abwesenheit tragen die verborgenen Block-Felder die Vorauswahl des
  /// Portals (erster Block); bei Verspätung ist `bis` gleich `von`.
  Map<String, String> toFields(AbsenceForm form) {
    final firstBlock = form.blocks.isEmpty ? '' : form.blocks.first.value;
    return {
      'selectedPupils': pupilIds.join(','),
      'art': kind,
      'von': formatGermanDate(from),
      'bis': formatGermanDate(isLate ? from : to),
      'stundenVon': isLate ? blockFrom : firstBlock,
      'stundenBis': isLate ? blockTo : firstBlock,
      'kommentar': comment,
    };
  }
}

/// Fehler, die die Maske vor dem Absenden anzeigt. Leer heißt: zulässig.
/// Das Portal prüft danach noch einmal selbst (Anfrage mit `check=1`).
List<String> validateAbsenceDraft(
  AbsenceForm form,
  AbsenceDraft d,
  ForkL10n t,
) {
  String day(DateTime x) => formatDate(t, t.dateFull, x);
  final errors = <String>[];
  final allowed = {for (final p in form.allowedPupils) p.id};
  if (d.pupilIds.isEmpty) errors.add(t.absenceErrChild);
  if (d.pupilIds.any((id) => !allowed.contains(id))) {
    errors.add(t.absenceErrNotAllowed);
  }
  if (!form.kinds.any((k) => k.value == d.kind)) {
    errors.add(t.absenceErrKind);
  }
  final fr = form.fromRange;
  final tr = form.toRange;
  if (fr != null && !fr.contains(d.from)) {
    errors.add(
      d.isLate
          ? t.absenceErrDayRange(day(fr.first), day(fr.last))
          : t.absenceErrStartRange(day(fr.first), day(fr.last)),
    );
  }
  if (d.isLate) {
    final bf = form.blocks.indexWhere((b) => b.value == d.blockFrom);
    final bt = form.blocks.indexWhere((b) => b.value == d.blockTo);
    if (bf < 0 || bt < 0) {
      errors.add(t.absenceErrBlocks);
    } else if (bt < bf) {
      errors.add(t.absenceErrBlockOrder);
    }
  } else {
    if (tr != null && !tr.contains(d.to)) {
      errors.add(t.absenceErrEndRange(day(tr.first), day(tr.last)));
    }
    if (_day(d.to).isBefore(_day(d.from))) {
      errors.add(t.absenceErrOrder);
    }
  }
  return errors;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

String formatGermanDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

DateTime? parseGermanDate(String? text) {
  if (text == null) return null;
  final m = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(text);
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(3)!),
    int.parse(m.group(2)!),
    int.parse(m.group(1)!),
  );
}

/// Liest die Eltern-Seite `abwesenheitsmeldung.php`.
///
/// Aufbau nach dem Export von Schule A (16.10.26):
/// `form#meldungForm` mit Kind-Schaltflächen `button.pupil-select-btn`
/// (`data-pupil-id`, `data-pupil-name`, `data-preselected`), `select[name=art]`,
/// Textfeldern `von`/`bis`, `select[name=stundenVon|stundenBis]` (Optionen mit
/// `data-von`/`data-bis`) und `kommentar`. Die Datumsgrenzen stehen nur im
/// Datepicker-Skript (`.datepickergroupvon` bzw. `…bis` mit `startDate`/
/// `endDate`).
///
/// Gibt `null` zurück, wenn kein Formular da ist (meist: Sitzung verloren).
AbsenceForm? parseAbsenceForm(Document doc) {
  final form = doc.querySelector('form#meldungForm');
  if (form == null) return null;

  final pupils = [
    for (final b in form.querySelectorAll('button.pupil-select-btn'))
      if (b.attributes['data-pupil-id'] case final id? when id.isNotEmpty)
        AbsencePupil(
          id: id,
          name: (b.attributes['data-pupil-name'] ?? b.text).trim(),
          preselected: b.attributes['data-preselected'] == 'true',
          allowed:
              !b.attributes.containsKey('disabled') &&
              !b.classes.contains('disabled'),
        ),
  ];

  final kinds = [
    for (final o in form.querySelectorAll('select[name="art"] option'))
      AbsenceChoice(o.attributes['value'] ?? o.text.trim(), _clean(o.text)),
  ];

  final blocks = [
    for (final o in form.querySelectorAll('select[name="stundenVon"] option'))
      _block(o),
  ];

  final scripts = doc.querySelectorAll('script').map((s) => s.text).join('\n');

  final rules = [
    for (final li in doc.querySelectorAll('#content .alert li'))
      _clean(li.text),
  ].where((r) => r.isNotEmpty).toList();

  return AbsenceForm(
    pupils: pupils,
    kinds: kinds,
    blocks: blocks,
    fromRange: _pickerRange(scripts, 'von'),
    toRange: _pickerRange(scripts, 'bis'),
    defaultFrom: parseGermanDate(
      form.querySelector('input[name="von"]')?.attributes['value'],
    ),
    defaultTo: parseGermanDate(
      form.querySelector('input[name="bis"]')?.attributes['value'],
    ),
    rules: rules,
    entries: [
      for (final tr in doc.querySelectorAll('tbody#liste tr'))
        if (tr.querySelectorAll('td') case final td when td.length >= 3)
          AbsenceEntry(
            name: _clean(td[0].text),
            period: _clean(td[1].text),
            kind: _clean(td[2].text),
            entered: td.length > 3 ? _clean(td[3].text) : '',
            comment: td.length > 4 ? _clean(td[4].text) : '',
          ),
    ],
    commentWarning: () {
      final w = doc.querySelector('#kommentarHinweis')?.text;
      return w == null || _clean(w).isEmpty ? null : _clean(w);
    }(),
  );
}

AbsenceBlock _block(Element o) {
  final text = _clean(o.text);
  final times = RegExp(
    r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})',
  ).firstMatch(text);
  String? hm(String? v) => v == null || v.length < 5 ? v : v.substring(0, 5);
  final label = text
      .replaceAll(RegExp(r'\(.*\)'), '')
      .replaceAllMapped(RegExp(r'^(\d+)\.\s*'), (m) => '${m[1]}. ')
      .trim();
  return AbsenceBlock(
    value: o.attributes['value'] ?? '',
    label: label,
    start: hm(o.attributes['data-von']) ?? times?.group(1),
    end: hm(o.attributes['data-bis']) ?? times?.group(2),
  );
}

DateRange? _pickerRange(String scripts, String which) {
  final m = RegExp(
    'datepickergroup$which[\\s\\S]*?startDate:\\s*"([\\d.]+)"[\\s\\S]*?endDate:\\s*"([\\d.]+)"',
  ).firstMatch(scripts);
  final first = parseGermanDate(m?.group(1));
  final last = parseGermanDate(m?.group(2));
  if (first == null || last == null) return null;
  return DateRange(first, last);
}

String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
