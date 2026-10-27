import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart' show sharedOverAccountSettingsProvider;

import '../../l10n/l10n.dart';
import '../../mensa.dart' show isoWeek, mensaUrlForWeek;
import '../../mensa_store.dart';
import '../../mensa_week.dart';
import '../kit.dart';
import '../nav.dart';
import '../today/today_page.dart' show dayDiff, schoolWeek;
import 'meal_fetcher.dart';
import 'meal_order.dart';
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

  @override
  void initState() {
    super.initState();
    try {
      _cache.attach(ref.read(sharedOverAccountSettingsProvider));
    } catch (_) {}
    _refresh();
  }

  void _refresh() => setState(() {
    _round++;
    _fetch = mensaUrlForWeek(widget.url, isoWeek(_thisWeek));
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
    final have = _weeks.any(
      (x) => dayDiff(schoolWeek(x.start).first, schoolWeek(target).first) == 0,
    );
    setState(() => _shown = schoolWeek(target).first);
    if (!have) {
      final link = dir > 0 ? w.next : w.prev;
      if (link != null) {
        setState(() {
          _round++;
          _fetch = Uri.parse(widget.url).resolve(link).toString();
          _want = schoolWeek(target).first;
          _count = 1;
        });
      }
    }
  }

  Future<void> _order(MealWeek? w) async {
    await pushFullScreen<void>(
      context,
      (_) => MensaPage(
        url: widget.url,
        open: w == null ? null : mensaUrlForWeek(widget.url, isoWeek(w.start)),
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
    if (_job != null) return;
    if (!await confirmMealChange(context, day: d, option: o)) return;
    if (!mounted) return;
    setState(() {
      _jobRound++;
      _job = (day: d, option: o, url: mealWeekPageUrl(w, d.day, widget.url));
    });
  }

  void _done(MealOrderResult r, MealWeek shown) {
    final job = _job;
    if (!mounted || job == null) return;
    if (r.week case final w?) _cache.put(widget.owner, [w]);
    setState(() => _job = null);
    final t = context.t;
    final dish = job.option?.name ?? job.day.ordered?.name ?? '';
    final text = r.ok
        ? (job.option == null ? t.mealCancelDone(dish) : t.mealOrderDone(dish))
        : [t.mealChangeFailed, ?r.message].join('\n');
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

  void _unreadable() {
    _cache.markUnreadable(widget.owner);
    if (!mounted || _weeks.isNotEmpty) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MensaPage(
          url: widget.url,
          owner: widget.owner,
          childName: widget.childName,
        ),
      ),
    );
  }

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
          bottom: fetch == null && _job == null
              ? null
              : const PreferredSize(
                  preferredSize: Size.fromHeight(Sz.progress),
                  child: LinearProgressIndicator(minHeight: Sz.progress),
                ),
        ),
        body: Stack(
          children: [
            ValueListenableBuilder(
              valueListenable: _cache.notifier,
              builder: (context, _, _) {
                final w = _week;
                if (w != null) {
                  return MealWeekView(
                    week: w,
                    now: _now,
                    colorIndex: widget.colorIndex,
                    onPrev: w.prev == null ? null : () => _go(w, -1),
                    onNext: w.next == null ? null : () => _go(w, 1),
                    onOrder: () => _order(w),
                    // Während eines Vorgangs keine weiteren Knöpfe.
                    onOrderOption: _job != null
                        ? null
                        : (d, o) => _change(w, d, o),
                    onCancel: _job != null ? null : (d) => _change(w, d, null),
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
                  ],
                );
              },
            ),
            if (_job case final j?)
              Positioned(
                left: 0,
                top: 0,
                child: IgnorePointer(
                  child: MealOrderRunner(
                    key: ValueKey('job$_jobRound'),
                    url: j.url,
                    owner: widget.owner,
                    day: j.day.day,
                    option: j.option,
                    onResult: (r) => _done(r, _week ?? _weeks.first),
                  ),
                ),
              ),
            if (fetch != null)
              Positioned(
                left: 0,
                top: 0,
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
  /// differenzieren“): Zustand als gelbe Marke „noch bestellbar“, daneben
  /// in Linkfarbe die Zahl zur Wahl (antippbar), aufgeklappt die Gerichte
  /// in einem eigenen Kasten – Menülinie klein darüber, Gericht darunter.
  List<Widget> _openParts(Kit k, ForkL10n t, MealDay d) => [
    const SizedBox(height: Sp.xs),
    Wrap(
      spacing: Sp.s,
      runSpacing: Sp.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.s,
            vertical: Sp.xxs,
          ),
          decoration: BoxDecoration(
            color: k.p.change.bg,
            borderRadius: BorderRadius.circular(Rad.pill),
          ),
          child: Text(
            t.mealStillOpen,
            style: k.tileCaption.copyWith(color: k.p.change.ink),
          ),
        ),
        if (d.options.isNotEmpty)
          Text(
            t.mealChoices(d.options.length),
            style: k.planMeta(k.p.onNavSelected),
          ),
      ],
    ),
    if (_open && d.options.isNotEmpty) ...[
      const SizedBox(height: Sp.s),
      Container(
        decoration: BoxDecoration(
          color: k.p.inset,
          borderRadius: BorderRadius.circular(Rad.bar),
        ),
        padding: const EdgeInsets.symmetric(horizontal: Sp.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, x) in d.options.indexed) ...[
              if (i > 0) Container(height: Sz.frame, color: k.p.line),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Sp.s),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (x.line.isNotEmpty)
                            Text(upperFor(t, x.line), style: k.planNowLabel),
                          Text(x.name, style: k.planMeta(k.p.ink)),
                          if (x.price != null)
                            Text(x.price!, style: k.planMeta(k.p.muted)),
                        ],
                      ),
                    ),
                    if (x.orderable && widget.onOrderOption != null)
                      TextButton(
                        onPressed: () => widget.onOrderOption!(d, x),
                        child: Text(t.mealOrderAction, style: k.link),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  ];

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
    final String title;
    final Color ink;
    final lines = <String>[];
    final canOpen = d.state == MealState.open && d.options.isNotEmpty;
    switch (d.state) {
      case MealState.ordered:
        title = o!.name;
        ink = k.p.ink;
        lines.add(
          [
            if (o.line.isNotEmpty) o.line,
            t.mealOrdered,
            if (until != null) t.mealCancelUntil(_shortUntil(until, d.day)),
          ].join(' · '),
        );
        if (d.sides.isNotEmpty) {
          lines.add(t.mealSides(d.sides.map((s) => s.name).join(', ')));
        }
      case MealState.open:
        title = t.mealNothing;
        ink = k.p.change.ink;
      case MealState.missed:
        title = t.mealNothing;
        ink = k.p.muted;
        lines.add(t.mealMissed);
      case MealState.closed:
        title = d.note ?? t.mealClosed;
        ink = k.p.muted;
    }
    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: Sp.xs, color: accent),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.m, Sp.m, 0, Sp.m),
            child: SizedBox(
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
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.s, Sp.m, Sp.m, Sp.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: k.planSubject(ink)),
                  for (final l in lines) Text(l, style: k.planMeta(k.p.muted)),
                  if (d.state == MealState.open) ..._openParts(k, t, d),
                  if (d.state == MealState.ordered &&
                      d.canCancel &&
                      widget.onCancel != null)
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
                ],
              ),
            ),
          ),
          if (canOpen)
            Padding(
              padding: const EdgeInsets.only(right: Sp.s),
              child: Icon(
                _open ? Icons.expand_less : Icons.expand_more,
                color: k.p.muted,
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
      child: canOpen
          ? InkWell(onTap: () => setState(() => _open = !_open), child: row)
          : row,
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
              if (!cancel && o?.price != null) Text(o!.price!, style: k.meta),
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
