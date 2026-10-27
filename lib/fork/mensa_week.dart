import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

/// Bestellwoche beim Caterer, gelesen aus der Wochenseite der Bestellung –
/// Grundlage der eigenen Essensansicht (Wunsch 26.10.26, „Kantine Schritt 2“).
///
/// Ursache: Die eingebettete Bestellseite war auf dem Handy schwer lesbar
/// (feste Zeilenhöhen, kleine Knöpfe). Die App liest deshalb nur, was
/// bestellt ist, und zeigt es im eigenen Stil; bestellt und abbestellt
/// wird weiter auf der Seite selbst (MensaPage).
///
/// Zwei Aufbauten sind bekannt (parseMealWeek). Die Namen der Caterer
/// stehen bewusst nirgends im Code (mensa.dart).
///
/// Grenzen:
/// - Nur die gezeigte Woche; andere Wochen über [MealWeek.next]/[prev].
/// - Fristen stehen nur als Hinweistexte an den Knöpfen
///   („Abbestellbar bis: 29.10.26 08:30“); fehlen sie, bleibt das Feld leer.
/// - Ändert der Caterer den Aufbau, liefert [parseMealWeek] null – die App
///   zeigt dann wie bisher die Seite selbst.
class MealWeek {
  const MealWeek({
    required this.label,
    required this.days,
    this.balance,
    this.prev,
    this.next,
    this.kind = MealLayout.dayList,
    this.url,
  });

  /// Adresse, unter der diese Woche gelesen wurde (MealFetcher, MensaPage);
  /// dort bestellt MealOrderRunner. null = unbekannt.
  final String? url;

  MealWeek withUrl(String? u) => MealWeek(
    label: label,
    days: days,
    balance: balance,
    prev: prev,
    next: next,
    kind: kind,
    url: u,
  );

  /// Aufbau der Seite – bestimmt, wie die App dort bestellt.
  final MealLayout kind;

  /// „26.10. bis 30.10.2026“
  final String label;
  final List<MealDay> days;

  /// „18,00“ (Euro), null = nicht angegeben.
  final String? balance;

  /// Pfade der Nachbarwochen („/kunden/essen/2026/45/“), null = keine.
  final String? prev;
  final String? next;

  /// Guthaben als Zahl („18,00“ → 18.0); null = unbekannt.
  double? get balanceValue => parseEuro(balance);

  /// Erster Tag der Woche (Montag bzw. erster Tag der Liste).
  DateTime get start => days.first.day;

  Map<String, dynamic> toJson() => {
    'label': label,
    'balance': ?balance,
    'prev': ?prev,
    'next': ?next,
    'kind': kind.name,
    'url': ?url,
    'days': [for (final d in days) d.toJson()],
  };

  static MealWeek? fromJson(Object? j) {
    if (j is! Map) return null;
    final days = [
      for (final d in (j['days'] as List? ?? const []))
        if (MealDay.fromJson(d) case final x?) x,
    ];
    if (days.isEmpty) return null;
    return MealWeek(
      label: '${j['label'] ?? ''}',
      days: days,
      balance: j['balance'] as String?,
      prev: j['prev'] as String?,
      next: j['next'] as String?,
      url: j['url'] as String?,
      kind: MealLayout.values.firstWhere(
        (k) => k.name == j['kind'],
        orElse: () => MealLayout.dayList,
      ),
    );
  }
}

enum MealState { ordered, open, missed, closed }

/// Bekannte Aufbauten (parseMealWeek).
enum MealLayout { dayList, tabs }

class MealDay {
  const MealDay({
    required this.day,
    required this.state,
    this.ordered,
    this.options = const [],
    this.sides = const [],
    this.cancelUntil,
    this.note,
    this.canCancel = false,
  });

  /// Bestellung lässt sich noch abbestellen (Frist läuft).
  final bool canCancel;

  final DateTime day;

  /// ordered = Essen bestellt; open = nichts bestellt, Bestellung noch
  /// möglich; missed = nichts bestellt, Frist vorbei; closed = keine
  /// Essensausgabe („Mensa geschlossen“).
  final MealState state;

  /// Bestelltes Gericht (nur bei [MealState.ordered]).
  final MealOption? ordered;

  /// Bestellbare Gerichte des Tages (Menülinien mit Knopf).
  final List<MealOption> options;

  /// Beilagen ohne eigene Bestellung (Salat, Nachtisch).
  final List<MealOption> sides;

  /// „29.10.26 08:30“: bis dahin abbestellbar (nur wenn bestellt).
  final String? cancelUntil;

  /// Hinweis der Seite, z. B. „Mensa geschlossen“ oder die Bestellfrist.
  final String? note;

  Map<String, dynamic> toJson() => {
    'day': '${day.year}-${day.month}-${day.day}',
    'state': state.name,
    'ordered': ?ordered?.toJson(),
    'options': [for (final o in options) o.toJson()],
    'sides': [for (final o in sides) o.toJson()],
    'cancelUntil': ?cancelUntil,
    'note': ?note,
    if (canCancel) 'canCancel': true,
  };

  static MealDay? fromJson(Object? j) {
    if (j is! Map) return null;
    final p = '${j['day']}'.split('-').map(int.tryParse).toList();
    if (p.length != 3 || p.contains(null)) return null;
    final state = MealState.values.where((s) => s.name == j['state']);
    if (state.isEmpty) return null;
    List<MealOption> list(Object? l) => [
      for (final o in (l as List? ?? const []))
        if (MealOption.fromJson(o) case final x?) x,
    ];
    return MealDay(
      day: DateTime(p[0]!, p[1]!, p[2]!),
      state: state.first,
      ordered: MealOption.fromJson(j['ordered']),
      options: list(j['options']),
      sides: list(j['sides']),
      cancelUntil: j['cancelUntil'] as String?,
      note: j['note'] as String?,
      canCancel: j['canCancel'] == true,
    );
  }
}

class MealOption {
  const MealOption({
    required this.line,
    required this.name,
    this.allergens,
    this.price,
    this.orderable = false,
    this.id,
  });

  /// Kennung auf der Seite des Caterers zum Bestellen (meal_order.dart):
  /// Tagesliste „Kind-Menü“ aus `tr#smo-…`, Reiter das `rel` der Menülinie.
  final String? id;

  /// „3,00 €“, wenn die Seite ihn nennt.
  final String? price;

  /// Lässt sich dieses Gericht jetzt noch bestellen (Knopf nicht gesperrt)?
  final bool orderable;

  /// Menülinie („Veggie“).
  final String line;
  final String name;

  /// „G, Lak, Wz“
  final String? allergens;

  Map<String, dynamic> toJson() => {
    'line': line,
    'name': name,
    'allergens': ?allergens,
    'price': ?price,
    if (orderable) 'orderable': true,
    'id': ?id,
  };

  static MealOption? fromJson(Object? j) => j is Map && j['name'] is String
      ? MealOption(
          line: '${j['line'] ?? ''}',
          name: j['name'] as String,
          allergens: j['allergens'] as String?,
          price: j['price'] as String?,
          orderable: j['orderable'] == true,
          id: j['id'] as String?,
        )
      : null;
}

/// „1.234,50“ / „18,00“ / „-3,00“ → Zahl; null, wenn nicht lesbar.
double? parseEuro(String? s) {
  if (s == null) return null;
  final m = RegExp(r'-?\d[\d.]*(,\d+)?').firstMatch(s.replaceAll(' ', ''));
  if (m == null) return null;
  return double.tryParse(m[0]!.replaceAll('.', '').replaceAll(',', '.'));
}

String _text(Element? e) =>
    (e?.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Kommas wie getippt bereinigen: „Reis ,Joghurt“ → „Reis, Joghurt“
/// (Bildschirmfoto 27.10.26).
String _tidy(String s) => s
    .replaceAll(RegExp(r'\s+,'), ',')
    .replaceAll(RegExp(r',(?=[A-Za-zÄÖÜäöüß])'), ', ')
    .trim();

/// Gerichtname: `<br>` als Leerzeichen.
String _dish(Element e) {
  final c = e.clone(true);
  for (final br in c.querySelectorAll('br')) {
    br.replaceWith(Text(' '));
  }
  return _text(c);
}

String? _tip(Element row, String method) {
  final b = row.querySelector('button[data-method="$method"]');
  final v = b?.attributes['data-original-title']?.trim();
  return v == null || v.isEmpty ? null : v;
}

/// Wochenseite → [MealWeek]; null, wenn keiner der bekannten Aufbauten
/// passt (andere Seite, Abmeldung, geänderter Aufbau).
///
/// Zwei Aufbauten (je ein Caterer der Familie, Seiten vom 26.10.26):
/// - Tagesliste `.small_view` mit `a.day-meal` ([_parseDayList]),
/// - Reiter je Tag `#menucontent .tab-pane.day[name=JJJJ-MM-TT]` mit
///   `.panel.menue` je Menülinie ([_parseTabs]).
MealWeek? parseMealWeek(String source) {
  final doc = html.parse(source);
  return _parseDayList(doc) ?? _parseTabs(doc);
}

String _two(int v) => v.toString().padLeft(2, '0');

/// „26.10. bis 30.10.2026“ aus erstem und letztem Tag.
String _labelOf(List<MealDay> days) {
  final a = days.first.day;
  final b = days.last.day;
  return '${_two(a.day)}.${_two(a.month)}. bis '
      '${_two(b.day)}.${_two(b.month)}.${b.year}';
}

/// Reiter je Tag. Bestellt ist die Menülinie mit `active` (Seite mit
/// Bestellung, 26.10.26: zusätzlich `panel-primary`, Haken gesetzt, Knopf
/// „Abbestellen“ sichtbar) bzw. deren `rel` im versteckten Feld
/// `.hiddenmenuefield`. `disabled` = nicht mehr bestellbar. Grenze: Eine
/// Abbestellfrist nennt die Seite nicht.
MealWeek? _parseTabs(Document doc) {
  final panes = doc.querySelectorAll('#menucontent .tab-pane.day');
  if (panes.isEmpty) return null;
  final days = <MealDay>[];
  for (final pane in panes) {
    final d = DateTime.tryParse(pane.attributes['name'] ?? '');
    if (d == null) continue;
    final day = DateTime(d.year, d.month, d.day);
    final chosen = pane.querySelector('.hiddenmenuefield')?.attributes['value'];
    final panels = pane.querySelectorAll('.panel.menue');
    if (panels.isEmpty) {
      days.add(MealDay(day: day, state: MealState.closed));
      continue;
    }
    final options = <MealOption>[];
    MealOption? ordered;
    List<MealOption> sides = const [];
    var orderable = false;
    var canCancel = false;
    for (final p in panels) {
      final body = p.querySelector('.panel-body p');
      if (body == null) continue;
      final small = _text(body.querySelector('small'));
      final c = body.clone(true);
      c.querySelector('small')?.remove();
      for (final br in c.querySelectorAll('br')) {
        br.replaceWith(Text('\n'));
      }
      // Zeilen: Gericht (ggf. über mehrere Zeilen), „Dessert: …“, Hinweis
      // „Kennzeichnungen entnehmen Sie …“ (entfällt).
      final lines = [
        for (final l in c.text.split('\n'))
          if (l.replaceAll(RegExp(r'\s+'), ' ').trim() case final t
              when t.isNotEmpty && !t.startsWith('Kennzeichnungen'))
            t,
      ];
      final extra = <MealOption>[];
      final dish = <String>[];
      for (final l in lines) {
        final m = RegExp(
          r'^(Dessert|Nachtisch|Beilage):\s*(.+)$',
        ).firstMatch(l);
        if (m != null) {
          extra.add(MealOption(line: m[1]!, name: m[2]!));
        } else {
          dish.add(l.endsWith(',') ? l.substring(0, l.length - 1) : l);
        }
      }
      if (dish.isEmpty) continue;
      final open = !p.classes.contains('disabled');
      final price = _text(p.querySelector('.badge'));
      final rel = p.attributes['rel'];
      final o = MealOption(
        line: _text(p.querySelector('.panel-title')),
        name: _tidy(dish.join(', ')),
        allergens: small.isEmpty ? null : small,
        price: price.isEmpty ? null : price,
        orderable: open,
        id: rel,
      );
      options.add(o);
      if (open) orderable = true;
      if (p.classes.contains('active') ||
          (chosen != null && chosen.isNotEmpty && chosen == rel)) {
        ordered = o;
        sides = extra;
        // Abbestellen: Knopf „Abbestellen“ vorhanden, Linie nicht gesperrt.
        canCancel =
            open && p.querySelector('button[onclick*="cancelOrder"]') != null;
      }
    }
    days.add(
      MealDay(
        day: day,
        state: ordered != null
            ? MealState.ordered
            : (options.isEmpty
                  ? MealState.closed
                  : (orderable ? MealState.open : MealState.missed)),
        ordered: ordered,
        options: options,
        sides: sides,
        canCancel: canCancel,
      ),
    );
  }
  if (days.isEmpty) return null;
  String? link(String arrow) {
    for (final a in doc.querySelectorAll('#datenauswahl a')) {
      if (_text(a) == arrow) return a.attributes['href'];
    }
    return null;
  }

  final balance = _text(doc.querySelector('#guthaben'));
  return MealWeek(
    label: _labelOf(days),
    days: days,
    balance: balance.isEmpty ? null : balance,
    prev: link('«'),
    next: link('»'),
    kind: MealLayout.tabs,
  );
}

/// Tagesliste für schmale Bildschirme (siehe Klassenkommentar).
MealWeek? _parseDayList(Document doc) {
  final small = doc.querySelector('.small_view');
  final label = _text(small?.querySelector('.week-switch .week'));
  final links = small?.querySelectorAll('a.day-meal') ?? const <Element>[];
  final end = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})\s*$').firstMatch(label);
  if (small == null || links.isEmpty || end == null) return null;
  final endYear = int.parse(end[3]!);
  final endMonth = int.parse(end[2]!);

  final days = <MealDay>[];
  for (final a in links) {
    final m = RegExp(
      r'(\d{1,2})\.(\d{1,2})\.',
    ).firstMatch(_text(a.querySelector('.short-date')));
    if (m == null) continue;
    final month = int.parse(m[2]!);
    // Woche über den Jahreswechsel („28.12. bis 01.01.2027“).
    final year = month > endMonth ? endYear - 1 : endYear;
    final day = DateTime(year, month, int.parse(m[1]!));
    final id = (a.attributes['href'] ?? '').replaceFirst('#', '');
    final rows = id.isEmpty
        ? const <Element>[]
        : (doc.getElementById(id)?.querySelectorAll('tr') ?? const []);
    if (rows.isEmpty || rows.every((r) => r.classes.contains('day-closed'))) {
      // Erste Zelle ohne die unsichtbare Menülinie: „Mensa geschlossen“.
      final cell = rows.isEmpty
          ? null
          : rows.first.querySelector('td')?.clone(true);
      cell?.querySelector('span')?.remove();
      final note = cell == null ? null : _text(cell);
      days.add(
        MealDay(
          day: day,
          state: MealState.closed,
          note: note == null || note.isEmpty ? null : note,
        ),
      );
      continue;
    }
    final options = <MealOption>[];
    final sides = <MealOption>[];
    MealOption? ordered;
    String? cancelUntil;
    String? orderNote;
    var orderable = false;
    var canCancel = false;
    for (final r in rows) {
      if (r.classes.contains('day-closed')) continue;
      final name = r.querySelector('span[id^="child-meal-"]');
      if (name == null) continue;
      final form = r.querySelector('form');
      final plus = r.querySelector('button[data-method="plus"]');
      final o = MealOption(
        line: _text(r.querySelector('b')),
        name: _tidy(_dish(name)),
        allergens: _text(r.querySelector('small')).isEmpty
            ? null
            : _text(r.querySelector('small')),
        orderable:
            form != null && plus != null && !plus.classes.contains('disabled'),
        id: r.id.startsWith('smo-') ? r.id.substring(4) : null,
      );
      if (form == null) {
        sides.add(o);
        continue;
      }
      options.add(o);
      if (o.orderable) orderable = true;
      // Die Hinweistexte der Knöpfe stehen nur in der breiten Tabelle
      // (`td#mo-…` zu `tr#smo-…`); die Tagesliste hat sie nicht immer.
      final wide = doc.getElementById((r.id).replaceFirst('smo-', 'mo-'));
      String? tip(String method) =>
          _tip(r, method) ?? (wide == null ? null : _tip(wide, method));
      if (form.attributes['data-order-status'] == '1') {
        ordered = o;
        final minusBtn = r.querySelector('button[data-method="minus"]');
        canCancel = minusBtn != null && !minusBtn.classes.contains('disabled');
        final minus = tip('minus');
        final until = minus == null
            ? null
            : RegExp(r'bis:?\s*(.+)$').firstMatch(minus)?[1];
        cancelUntil = until?.trim();
      } else {
        orderNote ??= tip('plus');
      }
    }
    days.add(
      MealDay(
        day: day,
        state: ordered != null
            ? MealState.ordered
            : (orderable ? MealState.open : MealState.missed),
        ordered: ordered,
        options: options,
        sides: sides,
        cancelUntil: cancelUntil,
        note: ordered == null ? orderNote : null,
        canCancel: canCancel,
      ),
    );
  }
  if (days.isEmpty) return null;
  String? link(String side) {
    final a = small.querySelector('.week-switch a.$side');
    final h = a?.attributes['href'];
    return h == null || h == '#' || h.isEmpty ? null : h;
  }

  final balance = _text(doc.querySelector('#header_account_balance_value'));
  return MealWeek(
    label: label,
    days: days,
    balance: balance.isEmpty ? null : balance,
    prev: link('left'),
    next: link('right'),
  );
}
