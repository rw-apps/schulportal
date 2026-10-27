import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart' show sharedOverAccountSettingsProvider;

import '../../l10n/l10n.dart';
import '../../mensa.dart' show isoWeek, mensaUrlForWeek, mensaWeekUrl;
import '../../mensa_store.dart';
import '../../mensa_week.dart';
import '../kit.dart';
import '../nav.dart';
import '../today/today_page.dart' show dayDiff, schoolWeek;
import '../../demo/demo_entry.dart' show blockedInDemo;
import 'meal_fetcher.dart';
import 'meal_order.dart';
import 'meal_remind_sheet.dart';
import 'mensa_page.dart';

/// Seite der Woche zum Bestellen: gelesene Adresse, auf die Woche von
/// [day] gesetzt (mensaUrlForWeek); beim Reiter-Aufbau ohne `week=` in der
/// Adresse wird es ergänzt. Grenze: Ohne Wochenmuster (Tagesliste) bleibt
/// es die gelesene Adresse – zeigt sie eine andere Woche, bricht
/// MealOrderRunner ab, statt falsch zu bestellen.
String mealWeekPageUrl(MealWeek w, DateTime day, String base) {
  var u = w.url ?? base;
  if (w.kind == MealLayout.tabs && !u.contains('week=')) {
    final x = Uri.parse(u);
    final wk = isoWeek(day);
    u = x
        .replace(
          queryParameters: {
            ...x.queryParameters,
            'week': '${wk.year}_${wk.week}',
          },
        )
        .toString();
  }
  return mensaUrlForWeek(u, isoWeek(day));
}

/// Seite „Essen · Kind“: gespeicherte Wochen sofort, im Hintergrund neu
/// gelesen (MealFetcher). Lässt sich die Seite des Caterers nicht lesen und
/// ist nichts gespeichert, ersetzt sie sich durch die Seite selbst
/// (MensaPage) – so bleibt es für unbekannte Caterer wie bisher.
class MealWeekPage extends ConsumerStatefulWidget {
  const MealWeekPage({
    super.key,
    required this.url,
    required this.owner,
    this.childName,
    this.colorIndex = 0,
    this.now,
  });

  final String url;
  final String owner;
  final String? childName;
  final int colorIndex;

  /// Nur Tests.
  final DateTime? now;

  @override
  ConsumerState<MealWeekPage> createState() => _MealWeekPageState();
}

class _MealWeekPageState extends ConsumerState<MealWeekPage> {
  late final DateTime _now = widget.now ?? DateTime.now();
  final _cache = MealCache.instance;
  DateTime? _shown;
  String? _fetch;
  DateTime? _want;
  int _count = 2;
  int _round = 0;

  DateTime get _thisWeek => schoolWeek(_now).first;

  /// Zuletzt gelesene Wochenseite statt Startseite (mealBaseUrl).
  String get _base => mealBaseUrl(widget.url, _cache.of(widget.owner));

  @override
  void initState() {
    super.initState();
    try {
      _cache.attach(ref.read(sharedOverAccountSettingsProvider));
    } catch (_) {}
    _refresh();
  }

  /// Demo: feste Wochen (demo_meals.dart), nichts zu lesen.
  bool get _demo => _cache.demo != null;

  void _refresh() => setState(() {
    if (_demo) return;
    _round++;
    _fetch = mensaUrlForWeek(_base, isoWeek(_thisWeek));
    _want = _thisWeek;
    _count = 2;
  });

  List<MealWeek> get _weeks => _cache.of(widget.owner)?.weeks ?? const [];

  MealWeek? get _week {
    final want = _shown ?? _thisWeek;
    for (final w in _weeks) {
      if (dayDiff(schoolWeek(w.start).first, want) == 0) return w;
    }
    return _weeks.isEmpty ? null : _weeks.first;
  }

  void _go(MealWeek w, int dir) {
    final target = DateTime(w.start.year, w.start.month, w.start.day + 7 * dir);
    setState(() => _shown = schoolWeek(target).first);
    // Auch gespeicherte Wochen neu lesen: Bestellstand und Fristen ändern
    // sich (Bildschirmfoto 27.10.26 – alte Woche ohne „Bestellen“).
    if (!_demo) {
      final link = dir > 0 ? w.next : w.prev;
      if (link != null) {
        setState(() {
          _round++;
          _fetch = Uri.parse(_base).resolve(link).toString();
          _want = schoolWeek(target).first;
          _count = 1;
        });
      }
    }
  }

  Future<void> _order(MealWeek? w) async {
    if (blockedInDemo(context)) return;
    await pushFullScreen<void>(
      context,
      (_) => MensaPage(
        url: widget.url,
        open: w == null
            ? (_base == widget.url ? null : mensaWeekUrl(_base, DateTime.now()))
            : mealWeekPageUrl(w, w.start, _base),
        owner: widget.owner,
        childName: widget.childName,
      ),
    );
    if (mounted) _refresh();
  }

  /// Laufender Bestell- bzw. Abbestellvorgang (MealOrderRunner).
  ({MealDay day, MealOption? option, String url})? _job;
  int _jobRound = 0;

  Future<void> _change(MealWeek w, MealDay d, MealOption? o) async {
    // Nicht parallel zu einem Abruf: Beide Ansichten teilen die Anmeldung
    // beim Caterer, und ein Wochenwechsel dort könnte das Speichern in eine
    // andere Woche lenken (Prüfung 27.10.26).
    if (_job != null || _fetch != null) return;
    if (blockedInDemo(context)) return;
    if (!await confirmMealChange(context, day: d, option: o)) return;
    if (!mounted || _job != null || _fetch != null) return;
    setState(() {
      _jobRound++;
      _job = (day: d, option: o, url: mealWeekPageUrl(w, d.day, _base));
    });
  }

  void Function(MealOrderResult) _onResultFor(int round) =>
      (r) => _done(round, r);

  void _done(int round, MealOrderResult r) {
    final job = _job;
    // Nur das Ergebnis des laufenden Vorgangs zählt.
    if (!mounted || job == null || round != _jobRound) return;
    final shown = _week;
    if (r.week case final w?) _cache.put(widget.owner, [w]);
    setState(() => _job = null);
    final t = context.t;
    final dish = job.option?.name ?? job.day.ordered?.name ?? '';
    final text = switch (r.outcome) {
      MealOrderOutcome.ok =>
        job.option == null ? t.mealCancelDone(dish) : t.mealOrderDone(dish),
      MealOrderOutcome.notDone => [t.mealChangeNotDone, ?r.message].join('\n'),
      MealOrderOutcome.unclear => [t.mealChangeFailed, ?r.message].join('\n'),
    };
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: Duration(seconds: r.ok ? 4 : 10),
        action: r.ok
            ? null
            : SnackBarAction(
                label: t.mealOpenCaterer,
                onPressed: () => _order(shown),
              ),
      ),
    );
  }

  /// Seite nicht lesbar: merken; ohne gespeicherte Wochen bleibt der
  /// Hinweis mit „Bestellen oder ändern“ und „Details“ stehen.
  ///
  /// Bis 9419 ersetzte sich die Ansicht dann gleich durch MensaPage. Grenze
  /// der Änderung (27.10.26): Für einen unbekannten Caterer ist das ein
  /// Tipp mehr – ab dem zweiten Öffnen geht Heute wegen
  /// MealEntry.unreadable ohnehin direkt zur Seite. Dafür bleibt der Verlauf
  /// des Abrufs (MealTrace) sichtbar, um Fehler auf dem Gerät zu finden.
  void _unreadable() => _cache.markUnreadable(widget.owner);

  bool _details = false;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final name = widget.childName;
    final fetch = _fetch;
    // Während des Bestellens nicht verlassen: sonst bliebe offen, ob die
    // Seite des Caterers die Bestellung angenommen hat.
    return PopScope(
      canPop: _job == null,
      child: Scaffold(
        backgroundColor: k.p.bg,
        appBar: AppBar(
          backgroundColor: k.p.bg,
          surfaceTintColor: k.p.bg,
          title: Text(
            name == null || name.isEmpty
                ? t.mealWeekTitle
                : t.mealWeekTitleFor(name),
            style: k.section,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: t.mealRemindTitle,
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () async {
                await showMealRemindSheet(context, widget.owner);
                if (mounted) setState(() {});
              },
            ),
          ],
          bottom: fetch == null && _job == null
              ? null
              : const PreferredSize(
                  preferredSize: Size.fromHeight(Sz.progress),
                  child: LinearProgressIndicator(minHeight: Sz.progress),
                ),
        ),
        // Abruf und Bestellung arbeiten in eingebetteten Ansichten in
        // voller Größe HINTER der Seite (hiddenWebView, meal_fetcher.dart);
        // die deckende Fläche darüber verbirgt sie.
        body: Stack(
          children: [
            if (_job case final j?)
              Positioned.fill(
                child: MealOrderRunner(
                  key: ValueKey('job$_jobRound'),
                  url: j.url,
                  owner: widget.owner,
                  day: j.day.day,
                  option: j.option,
                  onResult: _onResultFor(_jobRound),
                ),
              ),
            if (fetch != null)
              Positioned.fill(
                child: MealFetcher(
                  key: ValueKey('$_round:$fetch'),
                  url: fetch,
                  owner: widget.owner,
                  want: _want,
                  weeks: _count,
                  onWeek: (w) => _cache.put(widget.owner, [w]),
                  onUnreadable: _unreadable,
                  onDone: () {
                    if (mounted) setState(() => _fetch = null);
                  },
                ),
              ),
            Positioned.fill(
              key: const ValueKey('page'),
              child: ColoredBox(
                color: k.p.bg,
                child: ValueListenableBuilder(
                  valueListenable: _cache.notifier,
                  builder: (context, _, _) {
                    final w = _week;
                    if (w != null) {
                      return MealWeekView(
                        week: w,
                        now: _now,
                        colorIndex: widget.colorIndex,
                        onPrev: w.prev == null || _job != null
                            ? null
                            : () => _go(w, -1),
                        onNext: w.next == null || _job != null
                            ? null
                            : () => _go(w, 1),
                        onOrder: () => _order(w),
                        // Während eines Vorgangs keine weiteren Knöpfe.
                        onOrderOption: _job != null || fetch != null
                            ? null
                            : (d, o) => _change(w, d, o),
                        onCancel: _job != null || fetch != null
                            ? null
                            : (d) => _change(w, d, null),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.all(Sp.page),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(Sp.xl),
                          child: Text(
                            fetch == null ? t.mealLoadFailed : t.mealLoading,
                            style: k.meta,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (fetch == null)
                          FilledButton.icon(
                            onPressed: () => _order(null),
                            icon: const Icon(Icons.open_in_new),
                            label: Text(t.mealChange),
                          ),
                        if (fetch == null &&
                            MealTrace.of(widget.owner).isNotEmpty) ...[
                          const SizedBox(height: Sp.m),
                          TextButton(
                            onPressed: () =>
                                setState(() => _details = !_details),
                            child: Text(t.mealFetchDetails),
                          ),
                          if (_details)
                            SelectableText(
                              MealTrace.of(widget.owner).join('\n'),
                              style: k.trace,
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bestellte Essen einer Woche im Stil der App (mensa_week.dart).
///
/// Ursache (Wunsch 26.10.26, „Kantine Schritt 2“): Die Seite des Caterers
/// war in der App schwer lesbar. Hier steht je Tag nur, was zählt: bestellt
/// (Gericht, Menülinie, Abbestellfrist), nichts bestellt (noch möglich bzw.
/// Frist vorbei) oder keine Essensausgabe.
///
/// Aufbau (Rückmeldung 27.10.26, „Kopf- und Fußzeile fixieren“): Woche und
/// Guthaben stehen fest oben, „Bestellen oder ändern“ fest unten über der
/// Systemleiste (SafeArea); nur die Tage scrollen. Vorher lief beides mit
/// und der Knopf lag halb unter der Gestenleiste.
///
/// Farbstreifen links wie in der Terminliste (event_list.dart): Kinderfarbe
/// = bestellt, Gelb = nichts bestellt, aber noch möglich (Essen ist laut
/// Farbregel Gelb), Grau = vorbei bzw. geschlossen.
///
/// Grenze: Nur lesen. „Bestellen oder ändern“ öffnet die Seite des
/// Caterers für diese Woche ([onOrder]).
class MealWeekView extends StatelessWidget {
  const MealWeekView({
    super.key,
    required this.week,
    required this.now,
    required this.colorIndex,
    this.onPrev,
    this.onNext,
    this.onOrder,
    this.onOrderOption,
    this.onCancel,
  });

  /// Gericht bestellen bzw. Tag abbestellen in der App (Entwurf 27.10.26);
  /// null = keine Knöpfe, nur „Bestellen oder ändern“.
  final void Function(MealDay day, MealOption option)? onOrderOption;
  final void Function(MealDay day)? onCancel;

  final MealWeek week;
  final DateTime now;
  final int colorIndex;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onOrder;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final balance = week.balance;
    // Unter 15 €: gelb mit „bitte Geld überweisen“ (mensa_store.dart).
    final low = (week.balanceValue ?? mealLowBalance) < mealLowBalance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kopf: fest.
        Container(
          color: k.p.bg,
          padding: const EdgeInsets.fromLTRB(Sp.s, 0, Sp.s, Sp.s),
          child: Row(
            children: [
              IconButton(
                tooltip: t.prevWeek,
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        week.label,
                        style: k.cardSection,
                        maxLines: 1,
                      ),
                    ),
                    if (balance != null)
                      Text(
                        low
                            ? '${t.mealBalance(balance)} · ${t.mealTransferShort}'
                            : t.mealBalance(balance),
                        style: low ? k.boxText(k.p.change) : k.meta,
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: t.nextWeek,
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        Container(height: Sz.frame, color: k.p.line),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Sp.page, Sp.m, Sp.page, Sp.m),
            children: [
              for (final (i, d) in week.days.indexed) ...[
                if (i > 0) const SizedBox(height: Sp.s),
                _MealRow(
                  day: d,
                  now: now,
                  colorIndex: colorIndex,
                  onOrderOption: onOrderOption,
                  onCancel: onCancel,
                ),
              ],
            ],
          ),
        ),
        // Fuß: fest, über der Gesten- bzw. Navigationsleiste.
        if (onOrder != null)
          Container(
            decoration: BoxDecoration(
              color: k.p.bg,
              border: Border(
                top: BorderSide(color: k.p.line, width: Sz.frame),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Sp.page,
                  Sp.m,
                  Sp.page,
                  Sp.m,
                ),
                // Bestellt die App selbst, ist die Seite des Caterers nur
                // noch der Ausweg (umrandet statt gefüllt).
                child: onOrderOption != null
                    ? OutlinedButton.icon(
                        onPressed: onOrder,
                        icon: const Icon(Icons.open_in_new),
                        label: Text(t.mealOpenCaterer),
                      )
                    : FilledButton.icon(
                        onPressed: onOrder,
                        icon: const Icon(Icons.open_in_new),
                        label: Text(t.mealChange),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

/// „29.10.26 08:30“ → „08:30“, wenn es der Tag des Essens ist.
String _shortUntil(String until, DateTime day) {
  final m = RegExp(
    r'^(\d{1,2})\.(\d{1,2})\.\d{2,4}\s+(\d{1,2}:\d{2})$',
  ).firstMatch(until.trim());
  if (m == null) return until;
  if (int.parse(m[1]!) == day.day && int.parse(m[2]!) == day.month) {
    return m[3]!;
  }
  return until;
}

/// Ein Tag. Offene Tage („Nichts bestellt“) zeigen nur die Zahl der
/// Gerichte zur Wahl und klappen auf Antippen auf. Ursache (Bildschirmfoto
/// 27.10.26): Mit drei Gerichten je Tag ausgeschrieben war eine Woche
/// mehrere Bildschirme lang, und das Bestellte ging darin unter.
class _MealRow extends StatefulWidget {
  const _MealRow({
    required this.day,
    required this.now,
    required this.colorIndex,
    this.onOrderOption,
    this.onCancel,
  });

  final void Function(MealDay day, MealOption option)? onOrderOption;
  final void Function(MealDay day)? onCancel;

  final MealDay day;
  final DateTime now;
  final int colorIndex;

  @override
  State<_MealRow> createState() => _MealRowState();
}

class _MealRowState extends State<_MealRow> {
  var _open = false;

  /// Offener Tag in drei Ebenen (Rückmeldung 27.10.26: „stärker
  /// differenzieren“): „Nichts bestellt“ mit gelber Marke „noch
  /// bestellbar“ in einer Zeile, darunter in Linkfarbe die Zahl zur Wahl
  /// mit Pfeil; aufgeklappt die Gerichte in einem Kasten über die ganze
  /// Kartenbreite (Rückmeldung 27.10.26 früh: „Platz nicht optimal
  /// genutzt“ – vorher standen Kasten und Pfeil neben der Datumsspalte).
  Widget _pill(Kit k, ForkL10n t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Sp.s, vertical: Sp.xxs),
    decoration: BoxDecoration(
      color: k.p.change.bg,
      borderRadius: BorderRadius.circular(Rad.pill),
    ),
    child: Text(
      t.mealStillOpen,
      style: k.tileCaption.copyWith(color: k.p.change.ink),
    ),
  );

  Widget _openBox(Kit k, ForkL10n t, MealDay d) => Container(
    decoration: BoxDecoration(
      color: k.p.inset,
      borderRadius: BorderRadius.circular(Rad.bar),
    ),
    padding: const EdgeInsets.only(left: Sp.m, right: Sp.xs),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, x) in d.options.indexed) ...[
          if (i > 0) Container(height: Sz.frame, color: k.p.line),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.s),
            // Aufbau (Wunsch 27.10.26): rechts der Preis direkt über einem
            // umrandeten „Bestellen“. Zwei Zeilen statt zwei Spalten: Die
            // Menülinie (Großbuchstaben, gesperrt) läuft bis zum Preis über
            // fast die ganze Breite – in einer schmalen linken Spalte brach
            // „VEGETARISCHER BRATLING“ um (Entwurf 27.10.26). Grenze: Sehr
            // lange Linien brechen weiterhin um.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        x.line.isEmpty ? '' : upperFor(t, x.line),
                        style: k.planNowLabel,
                      ),
                    ),
                    if (_nbsp(x.price) case final p?) ...[
                      const SizedBox(width: Sp.s),
                      Text(p, style: k.planNowLabel),
                    ],
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: Text(x.name, style: k.planMeta(k.p.ink))),
                    if (x.orderable && widget.onOrderOption != null) ...[
                      const SizedBox(width: Sp.m),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, Sz.buttonTiny),
                          padding: const EdgeInsets.symmetric(
                            horizontal: Sp.l,
                            vertical: Sp.xs,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(color: k.p.onNavSelected),
                        ),
                        onPressed: () => widget.onOrderOption!(d, x),
                        child: Text(t.mealOrderAction, style: k.link),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final d = widget.day;
    final today = dayDiff(widget.now, d.day) == 0;
    final accent = switch (d.state) {
      MealState.ordered => k.kid(widget.colorIndex).accent,
      MealState.open => k.p.change.dot,
      MealState.missed || MealState.closed => k.p.faint,
    };
    final o = d.ordered;
    final until = d.cancelUntil;
    final canOpen = d.state == MealState.open && d.options.isNotEmpty;
    final lines = <String>[];
    final List<Widget> content;
    switch (d.state) {
      case MealState.ordered:
        lines.add(
          [
            if (o!.line.isNotEmpty) o.line,
            t.mealOrdered,
            if (until != null) t.mealCancelUntil(_shortUntil(until, d.day)),
          ].join(' · '),
        );
        if (d.sides.isNotEmpty) {
          lines.add(t.mealSides(d.sides.map((s) => s.name).join(', ')));
        }
        content = [
          Text(o.name, style: k.planSubject(k.p.ink)),
          for (final l in lines) Text(l, style: k.planMeta(k.p.muted)),
          if (d.canCancel && widget.onCancel != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, Sz.buttonTiny),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => widget.onCancel!(d),
                child: Text(
                  t.mealCancelAction,
                  style: k.link.copyWith(color: k.p.cancel.ink),
                ),
              ),
            ),
        ];
      case MealState.open:
        content = [
          Wrap(
            spacing: Sp.s,
            runSpacing: Sp.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(t.mealNothing, style: k.planSubject(k.p.change.ink)),
              _pill(k, t),
            ],
          ),
          if (d.options.isNotEmpty) ...[
            const SizedBox(height: Sp.xxs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.mealChoices(d.options.length),
                  style: k.planMeta(k.p.onNavSelected),
                ),
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: Sz.icon,
                  color: k.p.onNavSelected,
                ),
              ],
            ),
          ],
        ];
      case MealState.missed:
        content = [
          Text(t.mealNothing, style: k.planSubject(k.p.muted)),
          Text(t.mealMissed, style: k.planMeta(k.p.muted)),
        ];
      case MealState.closed:
        content = [
          Text(d.note ?? t.mealClosed, style: k.planSubject(k.p.muted)),
        ];
    }
    final head = Padding(
      padding: const EdgeInsets.all(Sp.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: Sz.slotColumn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  today ? t.dayToday : formatDate(t, 'ccc', d.day),
                  style: k.timeStart,
                ),
                Text(formatDate(t, t.dateDayMonth, d.day), style: k.timeEnd),
              ],
            ),
          ),
          const SizedBox(width: Sp.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content,
            ),
          ),
        ],
      ),
    );
    return Material(
      color: k.p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Rad.row),
        side: today
            ? BorderSide(color: k.p.onNavSelected, width: Sz.frame)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: Sp.xs, color: accent),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (canOpen)
                    InkWell(
                      onTap: () => setState(() => _open = !_open),
                      child: head,
                    )
                  else
                    head,
                  if (canOpen && _open)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Sp.m, 0, Sp.m, Sp.m),
                      child: _openBox(k, t, d),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rückfrage vor dem Bestellen bzw. Abbestellen in der App; true = ja.
///
/// Ursache (Entwurf 27.10.26): Bestellen kostet Geld und geht auf der Seite
/// des Caterers – deshalb immer mit Tag, Linie, Gericht und Preis bestätigen.
Future<bool> confirmMealChange(
  BuildContext context, {
  required MealDay day,
  MealOption? option,
}) async {
  final cancel = option == null;
  final o = option ?? day.ordered;
  final r = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: Kit.of(context).p.card,
    builder: (sheet) {
      final k = Kit.of(sheet);
      final t = sheet.t;
      final until = day.cancelUntil;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                cancel ? t.mealCancelTitle : t.mealOrderTitle,
                style: k.sheetTitle,
              ),
              const SizedBox(height: Sp.m),
              Text(
                [
                  formatDate(t, t.dateShort, day.day),
                  if (o != null && o.line.isNotEmpty) o.line,
                ].join(' · '),
                style: k.meta,
              ),
              if (o != null) Text(o.name, style: k.planSubject(k.p.ink)),
              if (!cancel && o?.price != null)
                Text(_nbsp(o!.price)!, style: k.meta),
              if (until != null && cancel)
                Text(t.mealCancelUntil(until), style: k.meta),
              const SizedBox(height: Sp.m),
              Text(t.mealChangeHint, style: k.meta),
              const SizedBox(height: Sp.l),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheet).pop(false),
                      child: Text(t.cancel),
                    ),
                  ),
                  const SizedBox(width: Sp.m),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheet).pop(true),
                      child: Text(
                        cancel ? t.mealCancelAction : t.mealOrderAction,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return r ?? false;
}

/// Preis ohne Umbruch zwischen Betrag und „€“. Ursache (Bildschirmfoto
/// 27.10.26): Bei langen Menülinien („VEGETARISCHER BRATLING · 3,00 €“)
/// stand das „€“ allein in der nächsten Zeile.
String? _nbsp(String? price) => price?.replaceAll(' ', '\u00A0');
