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
import 'mensa_page.dart';

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
        });
      }
    }
  }

  Future<void> _order(MealWeek? w) async {
    await pushFullScreen<void>(
      context,
      (_) => MensaPage(
        url: w == null
            ? widget.url
            : mensaUrlForWeek(widget.url, isoWeek(w.start)),
        owner: widget.owner,
        childName: widget.childName,
      ),
    );
    if (mounted) _refresh();
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
    return Scaffold(
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
        bottom: fetch == null
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
              return ListView(
                padding: const EdgeInsets.all(Sp.page),
                children: [
                  if (w == null)
                    Padding(
                      padding: const EdgeInsets.all(Sp.xl),
                      child: Text(
                        fetch == null ? t.mealLoadFailed : t.mealLoading,
                        style: k.meta,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    MealWeekView(
                      week: w,
                      now: _now,
                      colorIndex: widget.colorIndex,
                      onPrev: w.prev == null ? null : () => _go(w, -1),
                      onNext: w.next == null ? null : () => _go(w, 1),
                      onOrder: () => _order(w),
                    ),
                  if (w == null && fetch == null) ...[
                    const SizedBox(height: Sp.l),
                    FilledButton.icon(
                      onPressed: () => _order(null),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(t.mealChange),
                    ),
                  ],
                ],
              );
            },
          ),
          if (fetch != null)
            Positioned(
              left: 0,
              top: 0,
              child: MealFetcher(
                key: ValueKey('$_round:$fetch'),
                url: fetch,
                onWeek: (w) => _cache.put(widget.owner, [w]),
                onUnreadable: _unreadable,
                onDone: () {
                  if (mounted) setState(() => _fetch = null);
                },
              ),
            ),
        ],
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
  });

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: t.prevWeek,
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    week.label,
                    style: k.cardSection,
                    textAlign: TextAlign.center,
                  ),
                  if (balance != null)
                    Text(
                      t.mealBalance(balance),
                      style: k.meta,
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
        const SizedBox(height: Sp.m),
        for (final (i, d) in week.days.indexed) ...[
          if (i > 0) const SizedBox(height: Sp.s),
          _MealRow(day: d, now: now, colorIndex: colorIndex),
        ],
        if (onOrder != null) ...[
          const SizedBox(height: Sp.l),
          FilledButton.icon(
            onPressed: onOrder,
            icon: const Icon(Icons.open_in_new),
            label: Text(t.mealChange),
          ),
        ],
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

class _MealRow extends StatelessWidget {
  const _MealRow({
    required this.day,
    required this.now,
    required this.colorIndex,
  });

  final MealDay day;
  final DateTime now;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final d = day;
    final today = dayDiff(now, d.day) == 0;
    final accent = switch (d.state) {
      MealState.ordered => k.kid(colorIndex).accent,
      MealState.open => k.p.change.dot,
      MealState.missed || MealState.closed => k.p.faint,
    };
    final o = d.ordered;
    final until = d.cancelUntil;
    final String title;
    final Color ink;
    final lines = <String>[];
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
        lines.add(t.mealStillOpen);
        // Höchstens drei zur Wahl; manche Caterer bieten fünf und mehr Linien.
        for (final x in d.options.take(3)) {
          lines.add('${x.line}: ${x.name}');
        }
        if (d.options.length > 3) {
          lines.add(t.mealMoreOptions('${d.options.length - 3}'));
        }
      case MealState.missed:
        title = t.mealNothing;
        ink = k.p.muted;
        lines.add(t.mealMissed);
      case MealState.closed:
        title = d.note ?? t.mealClosed;
        ink = k.p.muted;
    }
    return Container(
      decoration: BoxDecoration(
        color: k.p.card,
        borderRadius: BorderRadius.circular(Rad.row),
        border: today
            ? Border.all(color: k.p.onNavSelected, width: Sz.frame)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
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
                    Text(
                      formatDate(t, t.dateDayMonth, d.day),
                      style: k.timeEnd,
                    ),
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
                    for (final l in lines)
                      Text(l, style: k.planMeta(k.p.muted)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
