import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../calendar/event_list.dart';
import '../kit.dart';
import '../today/today_model.dart' show ChangeKind, WeekItem, minutesOf;
import '../today/today_page.dart' show schoolWeek, dayDiff, weekdayShort;
import 'plan_model.dart';

/// Tag und Woche zeigen Stunden, [events] die Termine der Schule.
enum PlanView { day, week, events }

/// Bereich „Kalender“ im Stil A + C: Stunden je Kind als Tag oder Woche
/// (mit Gruppenwahl), dazu die Termine der Schule als Liste. Ursache für die
/// Zusammenlegung (Konzept 17.10.26): Plan und Termine sind beide „was ist
/// wann“ und überschnitten sich als eigene Bereiche.
class PlanPage extends StatefulWidget {
  const PlanPage({
    super.key,
    required this.plans,
    required this.now,
    this.initialChoices = const {},
    this.onChoicesChanged,
    this.autoChoices = const {},
    this.initialNames = const {},
    this.onNamesChanged,
    this.events,
    this.onRefresh,
  });

  final List<KidPlan> plans;
  final DateTime now;

  /// Termine der Schule für die Ansicht „Termine“; null = Ansicht fehlt
  /// (Schule ohne Kalender).
  final List<WeekItem>? events;

  /// Ziehen zum Aktualisieren (Tag und Termine); null = ohne.
  final Future<void> Function()? onRefresh;

  /// Automatisch erkannte Gruppen je Kind (autoGroupChoice); die eigene Wahl
  /// geht vor, siehe effectiveChoice.
  final Map<int, GroupChoice> autoChoices;

  /// Von Hand eingetragene Lehrernamen je Kind (Kürzel → Name).
  final Map<int, Map<String, String>> initialNames;
  final void Function(Map<int, Map<String, String>> names)? onNamesChanged;

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
  late final Map<int, Map<String, String>> _names = {
    for (final e in widget.initialNames.entries) e.key: {...e.value},
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

  KidPlan get _plan =>
      widget.plans[_kid].withTeacherNames(_names[_kid] ?? const {});

  /// Eigene Wahl (gespeichert); '' = bewusst alle zeigen.
  GroupChoice get _userChoice => _choices.putIfAbsent(_kid, () => {});
  GroupChoice get _auto => widget.autoChoices[_kid] ?? const {};

  /// Was der Plan tatsächlich anwendet.
  GroupChoice get _choice => effectiveChoice(_auto, _userChoice);

  Future<void> _openGroupSheet(String short) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Kit.of(context).p.card,
      builder: (_) => GroupSheet(
        plan: _plan,
        short: short,
        chosen: chosenOption(_plan, _choice, short),
        autoChosen: chosenOption(_plan, _auto, short),
        onChoose: (lesson) {
          setState(() {
            var next = applyGroupChoice(_plan, _userChoice, short, lesson);
            if (lesson == null) {
              // „Alle zeigen“ muss auch eine automatische Wahl aufheben.
              next = {
                ...next,
                for (final o in groupOptions(_plan, short))
                  if (_auto.containsKey(o.short)) o.short: '',
              };
            }
            _choices[_kid] = next;
          });
          widget.onChoicesChanged?.call(_choices);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _nameTeacher(String kuerzel) async {
    final current =
        _names[_kid]?[kuerzel] ??
        widget.plans[_kid].teacherNames[kuerzel] ??
        '';
    final name = await showDialog<String>(
      context: context,
      builder: (_) => TeacherNameDialog(kuerzel: kuerzel, initial: current),
    );
    if (name == null || !mounted) return;
    setState(() {
      (_names[_kid] ??= {})[kuerzel] = name;
    });
    widget.onNamesChanged?.call(_names);
  }

  Future<void> _openLesson(PlanLesson lesson, String time) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Kit.of(context).p.card,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => LessonSheet(
          plan: _plan,
          lesson: lesson,
          time: time,
          onNameTeacher: (kz) async {
            await _nameTeacher(kz);
            setSheet(() {});
          },
        ),
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
            // Ab „Groß“ brach der Titel neben dem Umschalter mitten im Wort
            // um („Stundenpla/n“, Bildschirmfoto 16.10.26) – lieber kleiner.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  context.t.navCalendar,
                  style: k.pageTitle,
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(width: Sp.m),
            // Höchstens gut zwei Drittel der Breite, sonst verkleinert: Mit
            // drei Ansichten (Tag/Woche/Termine) und „Sehr groß“ wäre der
            // Umschalter sonst über den Rand gelaufen.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.68,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: _ViewToggle(
                  value: _view,
                  withEvents: widget.events != null,
                  onChanged: (v) => setState(() => _view = v),
                ),
              ),
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

    if (_view == PlanView.events) {
      final view = CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverToBoxAdapter(child: head.first),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              Sp.page,
              Sp.ml,
              Sp.page,
              bottom + Sp.xl,
            ),
            sliver: SliverToBoxAdapter(
              child: EventList(
                items: widget.events ?? const [],
                now: widget.now,
                kidColor: _plan.colorIndex,
              ),
            ),
          ),
        ],
      );
      final refresh = widget.onRefresh;
      return refresh == null
          ? view
          : RefreshIndicator(onRefresh: refresh, child: view);
    }

    final dayView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
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
              onOpenLesson: _openLesson,
            ),
          ),
        ),
      ],
    );
    final refresh = widget.onRefresh;
    return refresh == null
        ? dayView
        : RefreshIndicator(onRefresh: refresh, child: dayView);
  }
}

// ---- Kopf ---------------------------------------------------------------

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.value,
    required this.onChanged,
    this.withEvents = false,
  });

  final PlanView value;
  final ValueChanged<PlanView> onChanged;
  final bool withEvents;

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
        children: [
          seg(PlanView.day, context.t.viewDay),
          seg(PlanView.week, context.t.viewWeek),
          if (withEvents) seg(PlanView.events, context.t.viewEvents),
        ],
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
          Text(context.t.chooseGroupLabel, style: k.meta),
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
                      Text(
                        weekdayShort(context.t, week[i]),
                        style: k.weekDay(i == selected),
                      ),
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
    this.onOpenLesson,
    this.now,
  });

  final KidPlan plan;
  final int day;
  final GroupChoice choice;
  final ValueChanged<String> onOpenGroup;

  /// Antippen einer Stunde: Details mit „Name eintragen“.
  final void Function(PlanLesson lesson, String time)? onOpenLesson;

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
          context.t.noLessonsThisDay,
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
                context.t.pauseUntil(plan.slots[b.firstSlot].start),
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
            onOpenLesson: onOpenLesson,
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
    this.onOpenLesson,
  });

  final KidPlan plan;
  final DayBlock block;
  final DateTime? now;
  final ValueChanged<String> onOpenGroup;
  final void Function(PlanLesson lesson, String time)? onOpenLesson;

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
    String? teacher;
    String? second;
    Widget? trailing;
    VoidCallback? onTap;
    var strike = false;

    switch (block.content) {
      case ResolvedNone():
        bg = k.p.bg;
        ink = sub = k.p.faint;
        title = context.t.freePeriod;
      case ResolvedOpen o:
        bg = k.p.inset;
        title = isSameSubjectChoice(o.options)
            ? context.t.subjectGroups(o.subject, o.options.length)
            : groupShortLabel(plan, o.short);
        meta = context.t.notChosenYet(label);
        trailing = TextButton(
          onPressed: () => onOpenGroup(o.short),
          child: Text(context.t.choose, style: k.link),
        );
      case ResolvedLesson r:
        final x = r.lesson;
        title = x.subject;
        meta = x.room;
        teacher = plan.teacherFull(x.teacher);
        if (onOpenLesson != null) {
          onTap = () => onOpenLesson!(x, '$start–$end');
        }
        if (x.change == ChangeKind.cancelled) {
          bg = k.p.cancel.bg;
          ink = sub = k.p.cancel.ink;
          strike = true;
          second = context.t.cancelledCap;
        } else if (x.change != null) {
          bg = k.p.change.bg;
          ink = sub = k.p.change.ink;
          final what = x.change == ChangeKind.substitution
              ? context.t.changeSubstitution
              : context.t.changeRoom;
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
            tooltip: context.t.otherGroup,
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
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(Rad.signal),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
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
                                      running ? context.t.lessonRunning : label,
                                      style: k.planMeta(sub),
                                    ),
                                    const SizedBox(width: Sp.xs),
                                  ],
                                ],
                              ),
                              // Raum unauffällig, Lehrkraft kräftig („mehr
                              // Kontur“, Rückmeldung 16.10.26).
                              if ((meta ?? '').isNotEmpty || teacher != null)
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      if ((meta ?? '').isNotEmpty)
                                        TextSpan(
                                          text: meta,
                                          style: k.planMeta(sub),
                                        ),
                                      if ((meta ?? '').isNotEmpty &&
                                          teacher != null)
                                        TextSpan(
                                          text: ' · ',
                                          style: k.planMeta(sub),
                                        ),
                                      if (teacher != null)
                                        TextSpan(
                                          text: teacher,
                                          style: k.planTeacher(ink),
                                        ),
                                    ],
                                  ),
                                ),
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
                Text(weekdayShort(context.t, week[d]), style: k.gridHead(sel)),
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
        final t = context.t;
        lines.add((same ? o.subject : t.cellChoice, k.cellShort(ink)));
        lines.add((
          same
              ? t.cellGroups(o.options.length)
              : t.cellSubjects(o.options.length),
          k.cellRoom(ink),
        ));
        lines.add((t.cellChoose, k.cellTeacher(ink)));
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
          lines.add((context.t.lessonCancelled, k.cellRoom(ink)));
        } else {
          if (x.change == ChangeKind.roomChange && x.changeDetail != null) {
            lines.add((x.room ?? '', k.cellRoom(ink)));
          } else if (x.room != null) {
            lines.add((x.room!, k.cellRoom(ink)));
          }
          if (x.change == ChangeKind.substitution) {
            lines.add((context.t.changeSubstitution, k.cellTeacher(ink)));
          } else if (x.change == ChangeKind.roomChange) {
            lines.add((context.t.changeRoom, k.cellTeacher(ink)));
          } else if (x.teacher != null) {
            lines.add((plan.teacherCell(x.teacher)!, k.cellTeacher(ink)));
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
    this.autoChosen,
  });

  final KidPlan plan;
  final String short;
  final PlanLesson? chosen;

  /// Von der App erkannte Gruppe (Kurs-Lehrkraft), zur Kennzeichnung.
  final PlanLesson? autoChosen;

  /// null = Wahl aufheben (wieder alle Gruppen zeigen).
  final ValueChanged<PlanLesson?> onChoose;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final base = groupOptions(plan, short);
    // Team-Wahl (beide Kurs-Lehrkräfte) ist keine einzelne Gruppe des
    // Plans, steht aber als eigene Zeile oben, damit sie sichtbar bleibt.
    bool listed(PlanLesson t) =>
        base.any((o) => o.short == t.short && o.groupKey == t.groupKey);
    final team = [?autoChosen, ?chosen].where((t) => !listed(t)).firstOrNull;
    final options = [?team, ...base];
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
              sameSubject
                  ? context.t.groupSheetTitle(label)
                  : context.t.whichSubject,
              style: k.sheetTitle,
            ),
            const SizedBox(height: Sp.xs),
            Text(
              sameSubject
                  ? context.t.groupSheetSame(label, plan.firstName)
                  : context.t.groupSheetParallel(label, plan.firstName),
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
                                      ? context.t.groupOf(
                                          plan.teacherFull(g.teacher) ??
                                              g.groupKey,
                                        )
                                      : g.subject,
                                  style: k.planSubject(k.p.ink),
                                ),
                                Text(
                                  sameSubject
                                      ? [
                                          if (g.room != null)
                                            context.t.roomValue(g.room!),
                                        ].join()
                                      : [
                                          ?plan.teacherFull(g.teacher),
                                          ?g.room,
                                        ].join(' · '),
                                  style: k.planMeta(k.p.muted),
                                ),
                                if (autoChosen != null &&
                                    autoChosen!.short == g.short &&
                                    autoChosen!.groupKey == g.groupKey)
                                  Text(
                                    context.t.detectedViaCourse,
                                    style: k.planMeta(
                                      k.kid(plan.colorIndex).label,
                                    ),
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
                child: Text(context.t.showAllAgain, style: k.link),
              ),
          ],
        ),
      ),
    );
  }
}

/// Details einer Stunde mit „Name eintragen“ je Lehrkraft.
class LessonSheet extends StatelessWidget {
  const LessonSheet({
    super.key,
    required this.plan,
    required this.lesson,
    required this.time,
    required this.onNameTeacher,
  });

  final KidPlan plan;
  final PlanLesson lesson;
  final String time;
  final ValueChanged<String> onNameTeacher;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final kuerzel = KidPlan.kuerzelOf(lesson.teacher);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(lesson.subject, style: k.sheetTitle),
            const SizedBox(height: Sp.xs),
            Text(
              [
                time,
                if (lesson.room != null) context.t.roomValue(lesson.room!),
              ].join(' · '),
              style: k.meta,
            ),
            const SizedBox(height: Sp.l),
            for (final kz in kuerzel)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.s),
                child: Material(
                  color: k.p.inset,
                  borderRadius: BorderRadius.circular(Rad.signal),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Rad.signal),
                    onTap: () => onNameTeacher(kz),
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
                                  plan.teacherNames[kz] ??
                                      context.t.nameUnknown,
                                  style: k.planTeacher(k.p.ink),
                                ),
                                Text(context.t.teacherCode(kz), style: k.meta),
                              ],
                            ),
                          ),
                          Icon(
                            plan.teacherNames.containsKey(kz)
                                ? Icons.edit_outlined
                                : Icons.person_add_alt,
                            size: Sz.icon,
                            color: k.p.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (kuerzel.isEmpty) Text(context.t.noTeacherGiven, style: k.meta),
            Text(context.t.tapToNameTeacher, style: k.meta),
          ],
        ),
      ),
    );
  }
}

/// Eingabe eines Lehrernamens zu einem Kürzel. Leer = eigenen Eintrag
/// löschen (dann gilt wieder der Name aus dem Portal bzw. das Kürzel).
class TeacherNameDialog extends StatefulWidget {
  const TeacherNameDialog({
    super.key,
    required this.kuerzel,
    required this.initial,
  });

  final String kuerzel;
  final String initial;

  @override
  State<TeacherNameDialog> createState() => _TeacherNameDialogState();
}

class _TeacherNameDialogState extends State<TeacherNameDialog> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t.nameFor(widget.kuerzel)),
      content: TextField(
        controller: _c,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: context.t.teacherNameHint),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _c.text.trim()),
          child: Text(context.t.save),
        ),
      ],
    );
  }
}
