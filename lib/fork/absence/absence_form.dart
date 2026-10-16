import 'package:html/dom.dart';

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

  List<AbsencePupil> get allowedPupils =>
      pupils.where((p) => p.allowed).toList();
}

/// Was die Maske absenden würde, als Formularfelder des Portals.
///
/// Grenze: Wie das Portal-Skript (`module/abwesenheitsmeldung/js/
/// meldungEltern.js`) `selectedPupils` befüllt und ob es per Ajax abschickt,
/// ist noch nicht belegt. Deshalb gibt es hier nur die Felder, kein Senden.
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

  Map<String, String> toFields() => {
    'selectedPupils': pupilIds.join(','),
    'art': kind,
    'von': formatGermanDate(from),
    'bis': formatGermanDate(to),
    'stundenVon': blockFrom,
    'stundenBis': blockTo,
    'kommentar': comment,
    'save': '1',
  };
}

/// Fehler, die die Maske vor dem Absenden anzeigt. Leer heißt: zulässig.
List<String> validateAbsenceDraft(AbsenceForm form, AbsenceDraft d) {
  final errors = <String>[];
  final allowed = {for (final p in form.allowedPupils) p.id};
  if (d.pupilIds.isEmpty) errors.add('Bitte ein Kind auswählen.');
  if (d.pupilIds.any((id) => !allowed.contains(id))) {
    errors.add('Für dieses Kind erlaubt die Schule keine Meldung.');
  }
  if (!form.kinds.any((k) => k.value == d.kind)) {
    errors.add('Unbekannte Art der Meldung.');
  }
  final fr = form.fromRange;
  final tr = form.toRange;
  if (fr != null && !fr.contains(d.from)) {
    errors.add(
      'Beginn nur ${formatGermanDate(fr.first)} bis ${formatGermanDate(fr.last)}.',
    );
  }
  if (tr != null && !tr.contains(d.to)) {
    errors.add(
      'Ende nur ${formatGermanDate(tr.first)} bis ${formatGermanDate(tr.last)}.',
    );
  }
  if (_day(d.to).isBefore(_day(d.from))) {
    errors.add('Das Ende liegt vor dem Beginn.');
  }
  final bf = form.blocks.indexWhere((b) => b.value == d.blockFrom);
  final bt = form.blocks.indexWhere((b) => b.value == d.blockTo);
  if (bf < 0 || bt < 0) {
    errors.add('Bitte Block von und bis wählen.');
  } else if (_day(d.from) == _day(d.to) && bt < bf) {
    errors.add('Der letzte Block liegt vor dem ersten.');
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
    for (final o
        in form.querySelectorAll('select[name="art"] option'))
      AbsenceChoice(o.attributes['value'] ?? o.text.trim(), _clean(o.text)),
  ];

  final blocks = [
    for (final o in form.querySelectorAll('select[name="stundenVon"] option'))
      _block(o),
  ];

  final scripts = doc
      .querySelectorAll('script')
      .map((s) => s.text)
      .join('\n');

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
  );
}

AbsenceBlock _block(Element o) {
  final text = _clean(o.text);
  final times = RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})').firstMatch(text);
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
