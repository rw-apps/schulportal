import 'package:flutter/material.dart';

import '../kit.dart';
import '../today/today_model.dart' show ChangeKind, minutesOf;
import '../today/today_page.dart' show schoolWeek, dayDiff;
import 'plan_model.dart';

const _wd = ['Mo', 'Di', 'Mi', 'Do', 'Fr'];

enum PlanView { day, week }

/// Seite „Plan“ im Stil A + C: je Kind, Tag oder Woche, Gruppenwahl.
class PlanPage extends StatefulWidget {
  const PlanPage({
    super.key,
    required this.plans,
    required this.now,
    this.initialChoices = const {},
    this.onChoicesChanged,
  });

  final List<KidPlan> plans;
  final DateTime now;

  /// Gewählte Gruppen je Kind (Index in [plans]).
  final Map<int, GroupChoice> initialChoices;

  /// Meldet jede neue Gruppenwahl nach außen (Vorschau: bleibt beim
  /// Wechsel der Leiste erhalten; später: Speicherung je Konto).
  final void Function(Map<int, GroupChoice> choices)? onChoicesChanged;

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  int _kid = 0;
  PlanView _view = PlanView.day;
  late int _day;
  late final Map<int, GroupChoice> _choices = {
    for (final e in widget.initialChoices.entries) e.key: {...e.value},
  };

  List<DateTime> get _week => schoolWeek(widget.now);

  /// Index des heutigen Tages in [_week], sonst null (Wochenende).
  int? get _todayIndex {
    for (var i = 0; i < 5; i++) {
      if (dayDiff(_week[i], widget.now) == 0) return i;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _day = _todayIndex ?? 0;
  }

  KidPlan get _plan => widget.plans[_kid];
  GroupChoice get _choice => _choices.putIfAbsent(_kid, () => {});

  Future<void> _openGroupSheet(String short) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Kit.of(context).p.card,
      builder: (_) => GroupSheet(
        plan: _plan,
        short: short,
        chosen: chosenOption(_plan, _choice, short),
        onChoose: (lesson) {
          setState(() {
            _choices[_kid] = applyGroupChoice(_plan, _choice, short, lesson);
          });
          widget.onChoicesChanged?.call(_choices);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final open = openGroupSubjects(_plan, _choice).toList()..sort();

    final head = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(Sp.page + Sp.xs, Sp.xl, Sp.page, 0),
        child: Row(
          children: [
            Expanded(child: Text('Stundenplan', style: k.pageTitle)),
            _ViewToggle(
              value: _view,
              onChanged: (v) => setState(() => _view = v),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(Sp.page, Sp.ml, Sp.page, 0),
        child: _KidChips(
          plans: widget.plans,
          selected: _kid,
          onSelect: (i) => setState(() => _kid = i),
        ),
      ),
      if (open.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.page, Sp.s, Sp.page, 0),
          child: _OpenGroupsHint(
            plan: _plan,
            shorts: open,
            onChoose: _openGroupSheet,
          ),
        ),
    ];

    if (_view == PlanView.week) {
      // Woche ohne Scrollen: Raster bekommt die ganze Resthöhe und teilt sie
      // auf die Stunden auf (WeekGrid). Seitenrand schmaler als sonst, damit
      // die fünf Spalten breiter werden.
      return SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...head,
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(Sp.s, Sp.ml, Sp.s, bottom + Sp.s),
                child: WeekGrid(
                  plan: _plan,
                  week: _week,
                  today: _todayIndex,
                  now: widget.now,
                  choice: _choice,
                  onOpenGroup: _openGroupSheet,
                  onOpenDay: (d) => setState(() {
                    _day = d;
                    _view = PlanView.day;
                  }),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: head,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Sp.page, Sp.ml, Sp.page, 0),
          sliver: SliverToBoxAdapter(
            child: _DayPicker(
              week: _week,
              selected: _day,
              today: _todayIndex,
              onSelect: (i) => setState(() => _day = i),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(Sp.page, Sp.ml, Sp.page, bottom + Sp.xl),
          sliver: SliverToBoxAdapter(
            child: DayPlan(
              plan: _plan,
              day: _day,
              choice: _choice,
              now: _day == _todayIndex ? widget.now : null,
              onOpenGroup: _openGroupSheet,
            ),
          ),
        ),
      ],
    );
  }
}

// ---- Kopf ---------------------------------------------------------------

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.value, required this.onChanged});

  final PlanView value;
  final ValueChanged<PlanView> onChanged;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    Widget seg(PlanView v, String label) {
      final sel = v == value;
      return Semantics(
        selected: sel,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.pill),
          onTap: () => onChanged(v),
          child: Container(
            height: Sz.buttonSmall - Sp.s,
            padding: const EdgeInsets.symmetric(horizontal: Sp.ml),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? k.p.strong : null,
              borderRadius: BorderRadius.circular(Rad.pill),
            ),
            child: Text(label, style: k.chipLabel(sel, k.p.onStrong)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(Sp.xs),
      decoration: BoxDecoration(
        color: k.p.card,
        borderRadius: BorderRadius.circular(Rad.pill + Sp.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg(PlanView.day, 'Tag'), seg(PlanView.week, 'Woche')],
      ),
    );
  }
}

class _KidChips extends StatelessWidget {
  const _KidChips({
    required this.plans,
    required this.selected,
    required this.onSelect,
  });

  final List<KidPlan> plans;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Wrap(
      spacing: Sp.s,
      runSpacing: Sp.s,
      children: [
        for (final (i, p) in plans.indexed)
          Builder(
            builder: (context) {
              final tone = k.kid(p.colorIndex);
              final sel = i == selected;
              return Semantics(
                selected: sel,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.pill),
                  onTap: () => onSelect(i),
                  child: Container(
                    height: Sz.buttonSmall,
                    padding: const EdgeInsets.symmetric(horizontal: Sp.l),
                    decoration: BoxDecoration(
                      color: sel ? tone.tint : k.p.card,
                      borderRadius: BorderRadius.circular(Rad.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: Sz.dot + Sp.xxs,
                          height: Sz.dot + Sp.xxs,
                          decoration: BoxDecoration(
                            color: tone.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: Sp.s),
                        Text(p.firstName, style: k.chipLabel(sel, tone.onTint)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Eine Zeile „Gruppe wählen: [Textil] [ER / KR / Eth]“. Die Erklärung
/// steht erst in der Auswahl selbst (GroupSheet). Ursache: Der Hinweis als
/// Karte mit Text nahm im ersten Entwurf ~130 dp über dem Raster ein.
class _OpenGroupsHint extends StatelessWidget {
  const _OpenGroupsHint({
    required this.plan,
    required this.shorts,
    required this.onChoose,
  });

  final KidPlan plan;
  final List<String> shorts;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Icon(Icons.group_work_outlined, size: Sz.icon, color: k.p.muted),
          const SizedBox(width: Sp.xs + Sp.xxs),
          Text('Gruppe wählen:', style: k.meta),
          for (final s in shorts) ...[
            const SizedBox(width: Sp.s),
            Material(
              color: k.p.change.bg,
              borderRadius: BorderRadius.circular(Rad.pill),
              child: InkWell(
                borderRadius: BorderRadius.circular(Rad.pill),
                onTap: () => onChoose(s),
                child: Container(
                  height: Sz.buttonSmall - Sp.s,
                  padding: const EdgeInsets.symmetric(horizontal: Sp.ml),
                  alignment: Alignment.center,
                  child: Text(
                    groupShortLabel(plan, s),
                    style: k.button(k.p.change.ink),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.week,
    required this.selected,
    required this.today,
    required this.onSelect,
  });

  final List<DateTime> week;
  final int selected;
  final int? today;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Row(
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) const SizedBox(width: Sp.xs + Sp.xxs),
          Expanded(
            child: Semantics(
              selected: i == selected,
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(Rad.day),
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: Sp.s),
                  decoration: BoxDecoration(
                    color: i == selected ? k.p.strong : null,
                    borderRadius: BorderRadius.circular(Rad.day),
                  ),
                  child: Column(
                    children: [
                      Text(_wd[i], style: k.weekDay(i == selected)),
                      Text('${week[i].day}', style: k.weekNum(i == selected)),
                      const SizedBox(height: Sp.xxs),
                      Container(
                        width: Sz.dotSmall,
                        height: Sz.dotSmall,
                        decoration: BoxDecoration(
                          // Punkt markiert „heute“, wenn ein anderer Tag
                          // gewählt ist.
                          color: i == today && i != selected ? k.p.ink : null,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---- Tagesansicht -----------------------------------------------------------

/// Ein Tag als Liste: Uhrzeit links, Abschnitt rechts; Pausen ab 30 Min.
class DayPlan extends StatelessWidget {
  const DayPlan({
    super.key,
    required this.plan,
    required this.day,
    required this.choice,
    required this.onOpenGroup,
    this.now,
  });

  final KidPlan plan;
  final int day;
  final GroupChoice choice;
  final ValueChanged<String> onOpenGroup;

  /// Nur gesetzt, wenn [day] heute ist; dann „läuft“ und erledigt.
  final DateTime? now;

  static const pauseRowMinutes = 30;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final blocks = dayBlocks(plan, day, choice);
    if (blocks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Sp.xl),
        child: Text(
          'An diesem Tag kein Unterricht.',
          style: k.meta,
          textAlign: TextAlign.center,
        ),
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (i > 0) {
        final gap =
            minutesOf(plan.slots[b.firstSlot].start).minutes -
            minutesOf(plan.slots[blocks[i - 1].lastSlot].end).minutes;
        if (gap >= pauseRowMinutes) {
          rows.add(
            Padding(
              padding: const EdgeInsets.only(
                left: Sz.slotColumn + Sp.m,
                top: Sp.xs,
                bottom: Sp.xs,
              ),
              child: Text(
                'Pause bis ${plan.slots[b.firstSlot].start}',
                style: k.rowPause,
              ),
            ),
          );
        }
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.s),
          child: _DayRow(
            plan: plan,
            block: b,
            now: now,
            onOpenGroup: onOpenGroup,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.plan,
    required this.block,
    required this.now,
    required this.onOpenGroup,
  });

  final KidPlan plan;
  final DayBlock block;
  final DateTime? now;
  final ValueChanged<String> onOpenGroup;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final tone = k.kid(plan.colorIndex);
    final start = plan.slots[block.firstSlot].start;
    final end = plan.slots[block.lastSlot].end;
    final s = minutesOf(start).minutes;
    final e = minutesOf(end).minutes;
    final t = now == null ? null : now!.hour * 60 + now!.minute;
    final running = t != null && t >= s && t < e;
    final done = t != null && t >= e;
    final label = blockLabel(plan, block);

    Color bg = k.p.card;
    Color ink = k.p.ink;
    Color sub = k.p.muted;
    String title;
    String? meta;
    String? second;
    Widget? trailing;
    var strike = false;

    switch (block.content) {
      case ResolvedNone():
        bg = k.p.bg;
        ink = sub = k.p.faint;
        title = 'Freistunde';
      case ResolvedOpen o:
        bg = k.p.inset;
        title = isSameSubjectChoice(o.options)
            ? '${o.subject} · ${o.options.length} Gruppen'
            : groupShortLabel(plan, o.short);
        meta = '$label · noch nicht gewählt';
        trailing = TextButton(
          onPressed: () => onOpenGroup(o.short),
          child: Text('Wählen', style: k.link),
        );
      case ResolvedLesson r:
        final x = r.lesson;
        title = x.subject;
        meta = [?x.room, ?plan.teacherFull(x.teacher)].join(' · ');
        if (x.change == ChangeKind.cancelled) {
          bg = k.p.cancel.bg;
          ink = sub = k.p.cancel.ink;
          strike = true;
          second = 'Fällt aus';
        } else if (x.change != null) {
          bg = k.p.change.bg;
          ink = sub = k.p.change.ink;
          final what = x.change == ChangeKind.substitution
              ? 'Vertretung'
              : 'Raumwechsel';
          second = [what, ?x.changeDetail].join(': ');
        } else if (running) {
          bg = tone.tint;
          ink = tone.onTint;
          sub = tone.meta;
        } else if (done) {
          ink = sub = k.p.faint;
        }
        if (_isParallelSubject(plan, x.short)) {
          trailing = IconButton(
            tooltip: 'Andere Gruppe',
            onPressed: () => onOpenGroup(x.short),
            icon: Icon(Icons.swap_horiz, size: Sz.icon, color: sub),
          );
        }
    }

    final progress = running ? (t - s) / (e - s) : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: Sz.slotColumn,
          child: Padding(
            padding: const EdgeInsets.only(top: Sp.ml),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(start, style: done ? k.timeEnd : k.timeStart),
                Text(end, style: k.timeEnd),
              ],
            ),
          ),
        ),
        const SizedBox(width: Sp.m),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(Rad.signal),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.ml, Sp.m, Sp.s, Sp.m),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: k
                                        .planSubject(ink)
                                        .copyWith(
                                          decoration: strike
                                              ? TextDecoration.lineThrough
                                              : null,
                                          decorationColor: ink,
                                        ),
                                  ),
                                ),
                                // Bei offener Wahl steht rechts „Wählen“;
                                // die Stunde zusätzlich drückte den Titel
                                // zusammen („Textil · 4 Gruppen1. Block“).
                                if (block.content is! ResolvedOpen) ...[
                                  Text(
                                    running ? 'läuft' : label,
                                    style: k.planMeta(sub),
                                  ),
                                  const SizedBox(width: Sp.xs),
                                ],
                              ],
                            ),
                            if (meta != null && meta.isNotEmpty)
                              Text(meta, style: k.planMeta(sub)),
                            if (second != null)
                              Text(second, style: k.planMeta(ink)),
                          ],
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
                if (progress != null)
                  SizedBox(
                    height: Sz.progress,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0, 1),
                      child: ColoredBox(color: tone.accent),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

bool _isParallelSubject(KidPlan plan, String short) => plan.days.any(
  (d) => d.any((c) => c.isParallel && c.options.any((o) => o.short == short)),
);

// ---- Wochenraster -------------------------------------------------------

/// Woche als Raster, das die verfügbare Höhe ganz ausfüllt.
///
/// Zeilenhöhe = (freie Höhe − Kopf − Abstände) / Stunden, zwischen
/// [Sz.gridRowMin] und [Sz.gridRowMax]; unter dem Minimum wird gescrollt. Pausen ab 15 Minuten sind
/// eine größere Lücke ([Sz.gridBreak]), damit Vormittagsblöcke erkennbar
/// sind. Heute: Spalte hinterlegt, Jetzt-Linie in Kinderfarbe.
class WeekGrid extends StatelessWidget {
  const WeekGrid({
    super.key,
    required this.plan,
    required this.week,
    required this.today,
    required this.now,
    required this.choice,
    required this.onOpenGroup,
    required this.onOpenDay,
  });

  final KidPlan plan;
  final List<DateTime> week;
  final int? today;
  final DateTime now;
  final GroupChoice choice;
  final ValueChanged<String> onOpenGroup;
  final ValueChanged<int> onOpenDay;

  static const breakMinutes = 15;
  static const headHeight = Sz.buttonSmall - Sp.s;

  @override
  Widget build(BuildContext context) {
    final used = usedSlots(plan);
    if (used.isEmpty) return const SizedBox.shrink();

    // Lücke VOR jeder benutzten Stunde (erste: 0).
    final gaps = <double>[
      for (var i = 0; i < used.length; i++)
        i == 0
            ? 0
            : (minutesOf(plan.slots[used[i]].start).minutes -
                          minutesOf(plan.slots[used[i - 1]].end).minutes >=
                      breakMinutes
                  ? Sz.gridBreak
                  : Sz.gridGap),
    ];
    final gapSum = gaps.fold<double>(0, (a, b) => a + b);

    return LayoutBuilder(
      builder: (context, c) {
        final free = c.maxHeight - headHeight - Sp.s - gapSum;
        final rowH = (free / used.length).clamp(Sz.gridRowMin, Sz.gridRowMax);
        final tops = <int, double>{};
        var y = 0.0;
        for (var i = 0; i < used.length; i++) {
          y += gaps[i];
          tops[used[i]] = y;
          y += rowH;
        }
        final bodyH = y;
        final grid = _grid(context, used, tops, rowH, bodyH);
        final needed = headHeight + Sp.s + bodyH;
        return needed > c.maxHeight + 0.5
            ? SingleChildScrollView(child: grid)
            : grid;
      },
    );
  }

  Widget _grid(
    BuildContext context,
    List<int> used,
    Map<int, double> tops,
    double rowH,
    double bodyH,
  ) {
    final k = Kit.of(context);

    Widget head(int d) {
      final sel = d == today;
      return InkWell(
        borderRadius: BorderRadius.circular(Rad.day),
        onTap: () => onOpenDay(d),
        child: Container(
          height: headHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? k.p.strong : null,
            borderRadius: BorderRadius.circular(Rad.day),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(_wd[d], style: k.gridHead(sel)),
                const SizedBox(width: Sp.xs),
                Text('${week[d].day}.', style: k.gridHeadDate(sel)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: Sz.gridLabel + Sz.gridGap),
            for (var d = 0; d < 5; d++) ...[
              if (d > 0) const SizedBox(width: Sz.gridGap),
              Expanded(child: head(d)),
            ],
          ],
        ),
        const SizedBox(height: Sp.s),
        SizedBox(
          height: bodyH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: Sz.gridLabel,
                child: Stack(
                  children: [
                    for (final s in used)
                      Positioned(
                        top: tops[s],
                        height: rowH,
                        left: 0,
                        right: 0,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                plan.slots[s].label.split(' ').first,
                                style: k.gridSlot,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                plan.slots[s].start,
                                style: k.gridTime,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Sz.gridGap),
              for (var d = 0; d < 5; d++) ...[
                if (d > 0) const SizedBox(width: Sz.gridGap),
                Expanded(
                  child: _dayColumn(context, d, used, tops, rowH, bodyH),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _dayColumn(
    BuildContext context,
    int d,
    List<int> used,
    Map<int, double> tops,
    double rowH,
    double bodyH,
  ) {
    final k = Kit.of(context);
    final tone = k.kid(plan.colorIndex);
    final isToday = d == today;
    final blocks = _blocks(d, used);
    final nowY = isToday ? _nowY(used, tops, rowH) : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (isToday)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tone.tint.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(Rad.cell),
              ),
            ),
          ),
        for (final b in blocks)
          if (b.content is! ResolvedNone)
            Positioned(
              top: tops[b.firstSlot],
              height: tops[b.lastSlot]! + rowH - tops[b.firstSlot]!,
              left: 0,
              right: 0,
              child: _GridCell(
                plan: plan,
                block: b,
                isToday: isToday,
                now: now,
                onOpenGroup: onOpenGroup,
                onOpenDay: () => onOpenDay(d),
              ),
            ),
        if (nowY != null)
          Positioned(
            top: nowY - Sz.nowLine / 2,
            left: -Sz.gridGap,
            right: -Sz.gridGap,
            height: Sz.nowLine,
            child: IgnorePointer(child: ColoredBox(color: tone.accent)),
          ),
      ],
    );
  }

  /// Senkrechte Lage von „jetzt“ in der Spalte; null vor Beginn/nach Ende.
  double? _nowY(List<int> used, Map<int, double> tops, double rowH) {
    final t = now.hour * 60 + now.minute;
    for (var i = 0; i < used.length; i++) {
      final slot = plan.slots[used[i]];
      final s = minutesOf(slot.start).minutes;
      final e = minutesOf(slot.end).minutes;
      if (t >= s && t < e) return tops[used[i]]! + (t - s) / (e - s) * rowH;
      if (t < s) {
        // In einer Pause: Linie mittig in die Lücke davor.
        if (i == 0) return null;
        return tops[used[i]]! -
            (tops[used[i]]! - tops[used[i - 1]]! - rowH) / 2;
      }
    }
    return null;
  }

  /// Gleiche aufeinanderfolgende Stunden werden EIN hoher Block.
  List<DayBlock> _blocks(int day, List<int> used) {
    final res = [for (final s in used) resolveCell(plan.days[day][s], choice)];
    bool same(Resolved a, Resolved b) => switch ((a, b)) {
      (ResolvedLesson x, ResolvedLesson y) => x.lesson.sameAs(y.lesson),
      (ResolvedOpen x, ResolvedOpen y) => x.short == y.short,
      _ => false,
    };
    final out = <DayBlock>[];
    for (var i = 0; i < used.length; i++) {
      if (out.isNotEmpty &&
          used[i] == out.last.lastSlot + 1 &&
          same(out.last.content, res[i])) {
        final b = out.removeLast();
        out.add(
          DayBlock(
            firstSlot: b.firstSlot,
            lastSlot: used[i],
            content: b.content,
          ),
        );
      } else {
        out.add(
          DayBlock(firstSlot: used[i], lastSlot: used[i], content: res[i]),
        );
      }
    }
    return out;
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.plan,
    required this.block,
    required this.isToday,
    required this.now,
    required this.onOpenGroup,
    required this.onOpenDay,
  });

  final KidPlan plan;
  final DayBlock block;
  final bool isToday;
  final DateTime now;
  final ValueChanged<String> onOpenGroup;
  final VoidCallback onOpenDay;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final tone = k.kid(plan.colorIndex);
    final s = minutesOf(plan.slots[block.firstSlot].start).minutes;
    final e = minutesOf(plan.slots[block.lastSlot].end).minutes;
    final t = now.hour * 60 + now.minute;
    final running = isToday && t >= s && t < e;

    Color bg;
    Color ink;
    Color? border;
    final lines = <(String, TextStyle)>[];
    var strike = false;
    VoidCallback onTap = onOpenDay;

    switch (block.content) {
      case ResolvedNone():
        return const SizedBox.shrink();
      case ResolvedOpen o:
        bg = k.p.change.bg;
        ink = k.p.change.ink;
        border = k.p.change.dot;
        final same = isSameSubjectChoice(o.options);
        lines.add((same ? o.subject : 'Wahl', k.cellShort(ink)));
        lines.add((
          same ? '${o.options.length} Gruppen' : '${o.options.length} Fächer',
          k.cellRoom(ink),
        ));
        lines.add(('wählen', k.cellTeacher(ink)));
        onTap = () => onOpenGroup(o.short);
      case ResolvedLesson r:
        final x = r.lesson;
        final f = k.subjectAt(subjectColorSlots(plan)[x.short] ?? 0);
        bg = f.bg;
        ink = f.ink;
        if (x.change == ChangeKind.cancelled) {
          bg = k.p.cancel.bg;
          ink = k.p.cancel.ink;
          border = k.p.cancel.dot;
          strike = true;
        } else if (x.change != null) {
          bg = k.p.change.bg;
          ink = k.p.change.ink;
          border = k.p.change.dot;
        }
        lines.add((gridName(x), k.cellShort(ink)));
        if (x.change == ChangeKind.cancelled) {
          lines.add(('fällt aus', k.cellRoom(ink)));
        } else {
          if (x.change == ChangeKind.roomChange && x.changeDetail != null) {
            lines.add((x.room ?? '', k.cellRoom(ink)));
          } else if (x.room != null) {
            lines.add((x.room!, k.cellRoom(ink)));
          }
          if (x.change == ChangeKind.substitution) {
            lines.add(('Vertretung', k.cellTeacher(ink)));
          } else if (x.change == ChangeKind.roomChange) {
            lines.add(('Raumwechsel', k.cellTeacher(ink)));
          } else if (x.teacher != null) {
            lines.add((plan.teacherLast(x.teacher)!, k.cellTeacher(ink)));
          }
        }
    }
    if (running) border = tone.accent;

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Rad.cell),
        side: border == null
            ? BorderSide.none
            : BorderSide(color: border, width: Sz.cellBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Sp.xs + Sp.xxs,
            Sp.xs + Sp.xxs,
            Sp.xs,
            Sp.xs,
          ),
          // Zeilen nur, soweit Platz ist: Was nicht passt, wird
          // abgeschnitten statt überzulaufen (kurze Einzelstunden zeigen so
          // Fach + Raum, Doppelstunden zusätzlich die Lehrkraft).
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zu breite Zeilen werden verkleinert statt mit „…“
                // gekürzt (erster Wurf: „Deuts…“, „Biolog…“ bei Schrift
                // ×1,15 und ~60 dp Zellbreite).
                for (final (i, (text, style)) in lines.indexed)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      text,
                      maxLines: 1,
                      softWrap: false,
                      style: i == 0 && strike
                          ? style.copyWith(
                              decoration: TextDecoration.lineThrough,
                              decorationColor: ink,
                            )
                          : style,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Gruppenwahl --------------------------------------------------------

/// Auswahl der eigenen Gruppe (oder des eigenen Fachs bei Religion/Ethik);
/// gilt für die ganze Woche.
class GroupSheet extends StatelessWidget {
  const GroupSheet({
    super.key,
    required this.plan,
    required this.short,
    required this.chosen,
    required this.onChoose,
  });

  final KidPlan plan;
  final String short;
  final PlanLesson? chosen;

  /// null = Wahl aufheben (wieder alle Gruppen zeigen).
  final ValueChanged<PlanLesson?> onChoose;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final options = groupOptions(plan, short);
    final label = groupLabel(plan, short);
    final sameSubject = options.map((o) => o.subject).toSet().length == 1;
    bool isChosen(PlanLesson o) =>
        chosen != null &&
        chosen!.short == o.short &&
        chosen!.groupKey == o.groupKey;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              sameSubject ? '$label – Gruppe wählen' : 'Welches Fach?',
              style: k.sheetTitle,
            ),
            const SizedBox(height: Sp.xs),
            Text(
              sameSubject
                  ? 'Gilt für alle $label-Stunden von ${plan.firstName}. '
                        'Die anderen Gruppen werden ausgeblendet.'
                  : 'Parallel laufen $label. Wähle, was ${plan.firstName} '
                        'hat; die anderen werden ausgeblendet.',
              style: k.meta,
            ),
            const SizedBox(height: Sp.m),
            for (final g in options)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.s),
                child: Material(
                  color: isChosen(g) ? k.kid(plan.colorIndex).tint : k.p.inset,
                  borderRadius: BorderRadius.circular(Rad.signal),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Rad.signal),
                    onTap: () => onChoose(g),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Sp.l,
                        vertical: Sp.m,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sameSubject
                                      ? 'Gruppe ${plan.teacherFull(g.teacher) ?? g.groupKey}'
                                      : g.subject,
                                  style: k.planSubject(k.p.ink),
                                ),
                                Text(
                                  sameSubject
                                      ? [
                                          if (g.room != null) 'Raum ${g.room}',
                                        ].join()
                                      : [
                                          ?plan.teacherFull(g.teacher),
                                          ?g.room,
                                        ].join(' · '),
                                  style: k.planMeta(k.p.muted),
                                ),
                              ],
                            ),
                          ),
                          if (isChosen(g))
                            Icon(
                              Icons.check,
                              size: Sz.icon,
                              color: k.kid(plan.colorIndex).label,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (chosen != null)
              TextButton(
                onPressed: () => onChoose(null),
                child: Text('Wieder alle zeigen', style: k.link),
              ),
          ],
        ),
      ),
    );
  }
}
