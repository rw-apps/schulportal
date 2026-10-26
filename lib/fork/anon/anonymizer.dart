import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'anon_words.dart';

/// Macht Portalseiten anonym, ohne ihren Aufbau zu zerstören – Grundlage
/// des anonymen Exports (anon_export.dart).
///
/// Ursache (Entscheidung 25.10.26): Für Lehrerkonten (und andere Schulen)
/// braucht die App den Aufbau der Portalseiten; der Debug-Export enthält
/// aber echte Namen, Noten und Fehlzeiten von Schülerinnen und Schülern und
/// darf von einer Lehrkraft nicht weitergegeben werden.
///
/// Regeln:
/// - Jedes Wort aus Buchstaben wird verwürfelt – gleiche Länge, gleiche
///   Groß-/Kleinschreibung, Ziffern bleiben (aus „9c“ wird z. B. „9q“).
///   Ausnahme: Wörter aus [anonKeepWords] (Beschriftungen, Füllwörter).
///   In Namensspalten gilt die Ausnahme nicht ([_nameHint]).
/// - Gleiche Wörter werden gleich verwürfelt (HMAC mit einem Schlüssel, der
///   nur im Speicher liegt). So bleiben Zusammenhänge erhalten: Dieselbe
///   Lehrkraft heißt auf Vertretungs- und Stundenplan gleich. Der Schlüssel
///   wird nie ausgegeben; ohne ihn lässt sich nichts zurückrechnen.
/// - Noten und Punkte in Notenspalten werden zufällig neu vergeben
///   ([_gradeHint]). Ursache: Auch ohne Namen könnte jemand, der die
///   Klassenliste kennt, über die alphabetische Reihenfolge Noten zuordnen.
/// - Bilder als data:-Adresse, Skripte und Kommentare fallen weg.
///
/// Grenzen:
/// - Zahlen bleiben (Stunden, Uhrzeiten, Daten, Raumnummern, interne
///   Portalnummern). Eine Note außerhalb einer erkannten Notenspalte bliebe
///   stehen; die Lehrkraft prüft die Vorschau.
/// - Der Aufbau selbst (Klassengröße, Stundenraster) bleibt sichtbar.
class Anonymizer {
  Anonymizer({
    List<int>? key,
    Random? random,
    Iterable<String> secretNumbers = const [],
  }) : _key = key ?? _randomKey(),
       _random = random ?? Random.secure(),
       _secretNumbers = {...secretNumbers};

  /// Zahlen, die trotz der Regel „Zahlen bleiben“ verschwinden müssen – die
  /// Schulnummer. Ursache (Probelauf an echten Seiten 26.10.26): Sie steht
  /// in Logo- und Stilpfaden (`img/schullogo/<Nr>/…`) und in versteckten
  /// Feldern und verriet die Schule.
  final Set<String> _secretNumbers;

  final List<int> _key;
  final Random _random;
  final _cache = <String, String>{};

  /// Stehen gebliebene Wörter – die Lehrkraft prüft sie vor dem Teilen.
  final kept = SplayTreeSet<String>();

  static List<int> _randomKey() {
    final r = Random.secure();
    return [for (var i = 0; i < 32; i++) r.nextInt(256)];
  }

  static final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);
  static final _letter = RegExp(r'\p{L}', unicode: true);
  static final _upper = RegExp(r'\p{Lu}', unicode: true);
  static const _lowerPool = 'abcdefghijklmnopqrstuvwxyz';

  /// Ein Wort verwürfeln: Buchstaben zufällig (fest je Wort), Ziffern und
  /// Länge bleiben.
  String scramble(String word) => _cache.putIfAbsent(word, () {
    final seed = Hmac(sha256, _key).convert(utf8.encode(word)).bytes;
    var i = 0;
    final out = StringBuffer();
    for (final ch in word.runes.map(String.fromCharCode)) {
      if (_letter.hasMatch(ch)) {
        final c = _lowerPool[seed[i++ % seed.length] % _lowerPool.length];
        out.write(_upper.hasMatch(ch) ? c.toUpperCase() : c);
      } else {
        out.write(ch);
      }
    }
    return out.toString();
  });

  /// Freitext: Wörter verwürfeln, außer [anonKeepWords] (nicht bei
  /// [names]). Satzzeichen, Leerraum und reine Zahlen bleiben.
  String text(String s, {bool names = false}) => s.replaceAllMapped(_word, (m) {
    final w = m[0]!;
    if (!_letter.hasMatch(w)) {
      return _secretNumbers.contains(w) ? '0' * w.length : w;
    }
    if (!names && anonKeepWords.contains(w.toLowerCase())) {
      kept.add(w.toLowerCase());
      return w;
    }
    return scramble(w);
  });

  // ---- Noten ---------------------------------------------------------------

  static final _gradeHeader = RegExp(
    r'note|noten|punkte|bewertung|leistung|fehl|versäum|anwesen',
    caseSensitive: false,
  );
  static final _grade = RegExp(r'^\s*(\d{1,2})\s*([+-]?)\s*$');

  /// Note oder Punktzahl durch einen Zufallswert desselben Formats ersetzen.
  String randomGrade(String s) {
    final m = _grade.firstMatch(s);
    if (m == null) return s;
    final n = int.parse(m[1]!);
    // 1–6 als Schulnote, sonst Punkte 0–15. Grenze: Eine Punktzahl bis 6
    // wird zur Schulnote – für den Aufbau gleichgültig.
    final v = n <= 6 ? 1 + _random.nextInt(6) : _random.nextInt(16);
    return s.replaceFirst(m[1]! + m[2]!, '$v${m[2]}');
  }

  // ---- HTML ----------------------------------------------------------------

  static const _keepAttrs = {
    'class',
    'id',
    'name',
    'for',
    'type',
    'style',
    'colspan',
    'rowspan',
    'role',
    'width',
    'height',
    'align',
    'valign',
    'border',
    'cellpadding',
    'cellspacing',
    'target',
    'rel',
    'method',
    'lang',
    'dir',
    'scope',
    'tabindex',
    'charset',
    'http-equiv',
    'media',
    'size',
    'maxlength',
    'checked',
    'selected',
    'disabled',
    'readonly',
    'multiple',
    'hidden',
    'enctype',
    'autocomplete',
    'data-toggle',
    'data-target',
    'data-dismiss',
  };
  static const _urlAttrs = {'href', 'src', 'action', 'data-href', 'data-url'};
  static final _nameAttr = RegExp(
    r'name|lehrer|lehrkraft|teacher|schueler|schüler|vertret|person|kuerzel|kürzel|absender|empf',
    caseSensitive: false,
  );

  /// Ganze Seite oder Bruchstück.
  String html(String body) {
    final full = RegExp(
      r'<html|<!doctype',
      caseSensitive: false,
    ).hasMatch(body);
    if (full) {
      final doc = html_parser.parse(body);
      _walk(doc);
      return doc.outerHtml;
    }
    final frag = html_parser.parseFragment(body);
    _walk(frag);
    return frag.outerHtml;
  }

  void _walk(Node node) {
    for (final child in node.nodes.toList()) {
      switch (child) {
        case Comment():
          child.remove();
        case Element(localName: 'script'):
          child.nodes.clear();
          _attributes(child);
        case Element(localName: 'style'):
          _attributes(child);
        case Element():
          _attributes(child);
          _walk(child);
        case Text():
          child.text = _textNode(child);
        default:
          _walk(child);
      }
    }
  }

  String _textNode(Text t) {
    final parent = t.parent;
    final names = parent != null && _nameHint(parent);
    if (parent != null && _gradeHint(parent) && _grade.hasMatch(t.text)) {
      return randomGrade(t.text);
    }
    return text(t.text, names: names);
  }

  void _attributes(Element e) {
    for (final key in e.attributes.keys.toList()) {
      final k = '$key';
      final v = e.attributes[key]!;
      if (_keepAttrs.contains(k)) continue;
      if (_urlAttrs.contains(k)) {
        e.attributes[key] = url(v);
      } else {
        e.attributes[key] = text(v, names: _nameAttr.hasMatch(k));
      }
    }
  }

  /// Adresse: Pfad bleibt, Werte der Parameter werden wie Text behandelt;
  /// data:-Adressen (eingebettete Bilder, etwa Fotos) fallen weg.
  String url(String u) {
    if (u.trimLeft().toLowerCase().startsWith('data:')) return 'data:,';
    final q = u.indexOf('?');
    final path = _path(q < 0 ? u : u.substring(0, q));
    if (q < 0) return path;
    final query = u
        .substring(q + 1)
        .replaceAllMapped(
          RegExp(r'([^&#=;]+)=([^&#]*)'),
          (m) =>
              _actionParams.contains(m[1]) ? m[0]! : '${m[1]}=${text(m[2]!)}',
        );
    return '$path?$query';
  }

  /// Pfad: Seiten (`*.php`) bleiben, alles andere wie Text – in Pfaden zu
  /// Logos und Stilen stehen Schulnummer und Prüfsummen der Schule.
  String _path(String p) => p
      .split('/')
      .map((seg) => seg.endsWith('.php') ? seg : text(seg))
      .join('/');

  /// Parameter, die die Seite wählen statt Daten zu tragen
  /// (`meinunterricht.php?a=sus_view`, `startseite.php?a=ajax&f=apps`).
  static const _actionParams = {'a', 'f', 'jump', 'getType'};

  /// Steht [e] in einer Namensspalte oder trägt eine Namensklasse?
  bool _nameHint(Element e) {
    for (Element? x = e; x != null; x = x.parent) {
      if (_nameAttr.hasMatch('${x.className} ${x.id}')) return true;
      if (x.localName == 'td') {
        final h = _columnHeader(x);
        return h != null && _nameAttr.hasMatch(h);
      }
      if (x.localName == 'tr' || x.localName == 'table') return false;
    }
    return false;
  }

  bool _gradeHint(Element e) {
    for (Element? x = e; x != null; x = x.parent) {
      if (RegExp(
        r'note|grade|punkt',
        caseSensitive: false,
      ).hasMatch('${x.className} ${x.id}')) {
        return true;
      }
      if (x.localName == 'td') {
        final h = _columnHeader(x);
        return h != null && _gradeHeader.hasMatch(h);
      }
      if (x.localName == 'tr' || x.localName == 'table') return false;
    }
    return false;
  }

  /// Kopf der Spalte von [td]: gleiche Position in der ersten Zeile mit
  /// th-Zellen. Grenze: colspan in der Kopfzeile verschiebt die Zuordnung;
  /// dann greift die Regel nicht (Wörter werden trotzdem verwürfelt).
  String? _columnHeader(Element td) {
    final row = td.parent;
    if (row == null) return null;
    final index = row.children
        .where((c) => c.localName == 'td' || c.localName == 'th')
        .toList()
        .indexOf(td);
    Element? table = row;
    while (table != null && table.localName != 'table') {
      table = table.parent;
    }
    if (table == null || index < 0) return null;
    for (final tr in table.querySelectorAll('tr')) {
      final ths = tr.children.where((c) => c.localName == 'th').toList();
      if (ths.isEmpty) continue;
      return index < ths.length ? ths[index].text : null;
    }
    return null;
  }

  // ---- JSON ----------------------------------------------------------------

  static final _nameKey = RegExp(
    r'name|lehrer|lehrkraft|teacher|vertret|kuerzel|kürzel|person|verantwortlich|responsible|absender|sender|empf|user',
    caseSensitive: false,
  );

  String json(String body) {
    final Object? data;
    try {
      data = jsonDecode(body);
    } on FormatException {
      return text(body);
    }
    return const JsonEncoder.withIndent(' ').convert(_json(data, ''));
  }

  Object? _json(Object? v, String key) => switch (v) {
    Map() => {
      for (final e in v.entries) '${e.key}': _json(e.value, '${e.key}'),
    },
    List() => [for (final x in v) _json(x, key)],
    String() when v.contains('<') && v.contains('>') => html(v),
    String() when _urlKey(key) => url(v),
    String() when _gradeHeader.hasMatch(key) && _grade.hasMatch(v) =>
      randomGrade(v),
    String() => text(v, names: _nameKey.hasMatch(key)),
    num() when _secretNumbers.contains('$v') => 0,
    _ => v,
  };

  bool _urlKey(String k) =>
      k == 'link' || k == 'url' || k == 'href' || k == 'logo' || k == 'src';

  /// Antwort beliebigen Typs: JSON, HTML oder Text.
  String body(String s, {String? contentType}) {
    final t = s.trimLeft();
    if ((contentType?.contains('json') ?? false) ||
        t.startsWith('{') ||
        t.startsWith('[')) {
      return json(s);
    }
    if (t.startsWith('<') || (contentType?.contains('html') ?? false)) {
      return html(s);
    }
    return text(s);
  }
}
