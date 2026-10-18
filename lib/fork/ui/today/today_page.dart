import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../kit.dart';
import '../word_fit.dart';
import 'today_model.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Abstand in Kalendertagen. Über UTC gerechnet, weil `difference` in
/// Ortszeit über die Zeitumstellung (z. B. 25.10.26) 23 Stunden ergibt und
/// `inDays` dann einen Tag zu wenig liefert.
int dayDiff(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// „DIENSTAG, 20. OKTOBER“ (Muster [ForkL10n.dateLong] der Sprache).
String dateCaps(ForkL10n t, DateTime d) =>
    upperFor(t, formatDate(t, t.dateLong, d));

/// Begrüßung nach Tageszeit.
String greetingFor(ForkL10n t, DateTime now) => now.hour < 11
    ? t.greetingMorning
    : (now.hour < 18 ? t.greetingDay : t.greetingEvening);

/// „Heute“, „Morgen“ oder „Do 22.10.“ relativ zu [now].
String relativeDay(ForkL10n t, DateTime day, DateTime now) {
  final diff = dayDiff(now, day);
  if (diff == 0) return t.dayToday;
  if (diff == 1) return t.dayTomorrow;
  return formatDate(t, t.dateShort, day);
}

/// Kurzer Wochentag („Mo“) – Standalone-Form „ccc“, ohne Punkt.
String weekdayShort(ForkL10n t, DateTime d) => formatDate(t, 'ccc', d);

/// Kurzform der Stunde für die schmale Spalte der Tagesliste: „2. Block“ →
/// „2.“, „1.–2. Block“ → „1.–2.“. Ursache: Mit echten Daten von Schule A brach
/// „Block“ in der Spalte (Sz.slotColumn) in eine zweite Zeile um
/// (Bildschirmfoto 16.10.26). Überschrift und Kasten behalten das Wort.
String listSlot(String slot) =>
    slot.replaceAll(RegExp(r'\s+(Block|Stunde|Std\.?)$'), '');

/// Montag bis Freitag der laufenden Woche; am Wochenende die nächste.
/// Mit dem DateTime-Konstruktor statt Duration gerechnet: Duration zählt
/// 24 Stunden und landete über die Zeitumstellung bei 23:00 am Vortag
/// (Test: Samstag 24.10.26 → Montag 26.10.26).
List<DateTime> schoolWeek(DateTime now) {
  final shift = now.weekday >= DateTime.saturday ? 7 : 0;
  final mondayDay = now.day - (now.weekday - 1) + shift;
  return [
    for (var i = 0; i < 5; i++) DateTime(now.year, now.month, mondayDay + i),
  ];
}

/// Seite „Heute“ (Entwurf A + C, abgenommen 16.10.26).
class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.data,
    this.onReportAbsence,
    this.onOpenHomework,
    this.onOpenMessages,
    this.onOpenCalendar,
    this.onOrderMeal,
    this.onRefresh,
  });

  final FamilyToday data;
  final void Function(ChildToday child)? onReportAbsence;
  final void Function(ChildToday child)? onOpenHomework;
  final void Function(ChildToday child)? onOpenMessages;
  final VoidCallback? onOpenCalendar;
  final void Function(ChildToday child)? onOrderMeal;

  /// Ziehen zum Aktualisieren; null = ohne (Beispieldaten).
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    // Enthält bei Scaffold(extendBody: true) die Höhe der schwebenden Leiste.
    final bottom = MediaQuery.paddingOf(context).bottom;

    final view = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Sp.page + Sp.xs,
              Sp.xl,
              Sp.page + Sp.xs,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateCaps(t, data.now), style: k.dateCaps),
                  const SizedBox(height: Sp.xs),
                  Text(greetingFor(t, data.now), style: k.greeting),
                ],
              ),
            ),
          ),
        ),
        // Keine Wochenleiste Mo–Fr mehr (entfernt 17.10.26, Rückmeldung
        // „verstehe ich nicht“): Sie war nicht antippbar, ihre Punkte
        // unerklärt, und dieselben Termine stehen unten unter „Demnächst“
        // (UpcomingTiles) und im Reiter Kalender. Samstags zeigte sie schon
        // die nächste Woche ohne markierten Tag.
        if (importantItems(data).isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Sp.page, Sp.ml, Sp.page, 0),
            sliver: SliverToBoxAdapter(child: ImportantBox(data: data)),
          ),
        if (data.isDemo)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Sp.page, Sp.ml, Sp.page, 0),
            sliver: SliverToBoxAdapter(
              child: Text(
                t.demoNote,
                style: k.meta,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Sp.page, Sp.ml, Sp.page, 0),
          sliver: SliverList.separated(
            itemCount: data.kids.length,
            separatorBuilder: (_, _) => const SizedBox(height: Sp.ml),
            itemBuilder: (context, i) => KidCard(
              kid: data.kids[i],
              now: data.now,
              onReportAbsence: onReportAbsence,
              onOpenHomework: onOpenHomework,
              onOpenMessages: onOpenMessages,
              onOrderMeal: onOrderMeal,
            ),
          ),
        ),
        if (data.week.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.only(top: Sp.xl, bottom: bottom + Sp.xl),
            sliver: SliverToBoxAdapter(
              child: UpcomingTiles(data: data, onOpenAll: onOpenCalendar),
            ),
          )
        else
          SliverToBoxAdapter(child: SizedBox(height: bottom + Sp.xl)),
      ],
    );
    final refresh = onRefresh;
    if (refresh == null) return view;
    return RefreshIndicator(onRefresh: refresh, child: view);
  }
}

/// Farbpunkt (Kind bzw. Änderungsart) in Kasten „Wichtig“ und „Demnächst“.
class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: Sz.dot,
    height: Sz.dot,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

// ---- Kasten „Wichtig heute und morgen“ -------------------------------------

/// Änderungen aller Kinder für heute und morgen, nach Tag sortiert.
List<(ChildToday, ChangeItem)> importantItems(FamilyToday data) {
  final today = _day(data.now);
  final items = <(ChildToday, ChangeItem)>[
    for (final kid in data.kids)
      for (final c in kid.changes)
        if (dayDiff(today, c.day) case 0 || 1) (kid, c),
  ];
  items.sort((a, b) => a.$2.day.compareTo(b.$2.day));
  return items;
}

class ImportantBox extends StatelessWidget {
  const ImportantBox({super.key, required this.data});

  final FamilyToday data;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final items = importantItems(data);
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.l, Sp.ml, Sp.l, Sp.ml),
      decoration: BoxDecoration(
        color: k.p.change.bg,
        borderRadius: BorderRadius.circular(Rad.box),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            upperFor(context.t, context.t.importantTitle),
            style: k.boxTitle,
          ),
          for (final (kid, c) in items) ...[
            const SizedBox(height: Sp.s + Sp.xxs),
            _ImportantRow(kid: kid, item: c, now: data.now),
          ],
        ],
      ),
    );
  }
}

class _ImportantRow extends StatelessWidget {
  const _ImportantRow({
    required this.kid,
    required this.item,
    required this.now,
  });

  final ChildToday kid;
  final ChangeItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final tone = item.kind == ChangeKind.cancelled ? k.p.cancel : k.p.change;
    final what = switch (item.kind) {
      ChangeKind.cancelled => t.lessonCancelled,
      ChangeKind.roomChange => '${t.changeRoom} ${item.detail ?? ''}'.trim(),
      ChangeKind.substitution =>
        '${t.changeSubstitution} ${item.detail ?? ''}'.trim(),
    };
    final when = lowerFor(t, relativeDay(t, item.day, now));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Sp.xs + 1),
          child: _Dot(color: k.kid(kid.colorIndex).accent),
        ),
        const SizedBox(width: Sp.s + Sp.xxs),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${kid.firstName} · $when ${item.slot} ${item.subject}',
                  style: k.boxStrong(tone),
                ),
                TextSpan(text: ' – $what', style: k.boxText(tone)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---- Karte je Kind ----------------------------------------------------------

class KidCard extends StatefulWidget {
  const KidCard({
    super.key,
    required this.kid,
    required this.now,
    this.onReportAbsence,
    this.onOpenHomework,
    this.onOpenMessages,
    this.onOrderMeal,
    this.initiallyExpanded = false,
  });

  final ChildToday kid;
  final DateTime now;
  final void Function(ChildToday child)? onReportAbsence;
  final void Function(ChildToday child)? onOpenHomework;
  final void Function(ChildToday child)? onOpenMessages;
  final void Function(ChildToday child)? onOrderMeal;
  final bool initiallyExpanded;

  @override
  State<KidCard> createState() => _KidCardState();
}

class _KidCardState extends State<KidCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final kid = widget.kid;
    final tone = k.kid(kid.colorIndex);
    final status = dayStatus(kid.lessons, widget.now);

    final meta = [
      kid.school,
      kid.className,
      ?kid.periodsLabel,
    ].where((s) => s.isNotEmpty).join(' · ');

    return Container(
      padding: const EdgeInsets.all(Sp.lx),
      decoration: BoxDecoration(
        color: k.p.card,
        borderRadius: BorderRadius.circular(Rad.card),
        boxShadow: k.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: Sz.avatar,
                height: Sz.avatar,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.accent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  // Leerer Name (offline, unbekannt) darf nicht abstürzen.
                  kid.firstName.isEmpty ? '?' : kid.firstName.characters.first,
                  style: k.avatarLetter.copyWith(color: k.p.card),
                ),
              ),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kid.firstName, style: k.cardName),
                    Text(meta, style: k.cardMeta),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.ml),
          _NowPanel(kid: kid, status: status, tone: tone),
          if (kid.lessons.isNotEmpty) ...[
            const SizedBox(height: Sp.ml),
            _DayBar(kid: kid, status: status, tone: tone, now: widget.now),
            const SizedBox(height: Sp.s),
            if (_expanded)
              _DayList(kid: kid, status: status, tone: tone, now: widget.now),
            _ToggleButton(
              expanded: _expanded,
              onTap: () => setState(() => _expanded = !_expanded),
            ),
          ],
          if (kid.mealHint != null) ...[
            const SizedBox(height: Sp.m),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.restaurant, size: Sz.icon, color: k.p.muted),
                const SizedBox(width: Sp.s),
                Expanded(child: Text(kid.mealHint!, style: k.cardMeta)),
              ],
            ),
          ],
          ..._actions(context, k),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, Kit k) {
    final kid = widget.kid;
    final items = <Widget>[
      if (kid.openHomework > 0)
        _ActionButton(
          icon: Icons.menu_book_outlined,
          label: context.t.homeworkCount(kid.openHomework),
          onTap: widget.onOpenHomework == null
              ? null
              : () => widget.onOpenHomework!(kid),
        ),
      if (kid.unreadMessages > 0)
        _ActionButton(
          icon: Icons.mail_outline,
          label: context.t.unreadCount(kid.unreadMessages),
          onTap: widget.onOpenMessages == null
              ? null
              : () => widget.onOpenMessages!(kid),
        ),
      if (kid.mensaUrl != null)
        _ActionButton(
          icon: Icons.restaurant_menu,
          label: context.t.orderMeal,
          onTap: widget.onOrderMeal == null
              ? null
              : () => widget.onOrderMeal!(kid),
        ),
      if (kid.canReportAbsence)
        _ActionButton(
          icon: Icons.thermostat,
          label: context.t.reportSick,
          strong: true,
          onTap: widget.onReportAbsence == null
              ? null
              : () => widget.onReportAbsence!(kid),
        ),
    ];
    if (items.isEmpty) return const [];
    // Zwei je Zeile; ein übrig bleibender Knopf nimmt die ganze Breite.
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(const SizedBox(height: Sp.s));
      rows.add(
        Row(
          children: [
            Expanded(child: items[i]),
            if (i + 1 < items.length) ...[
              const SizedBox(width: Sp.s),
              Expanded(child: items[i + 1]),
            ],
          ],
        ),
      );
    }
    return [const SizedBox(height: Sp.xs), ...rows];
  }
}

/// Fläche „JETZT · 3./4. STD. · NOCH 30 MIN.“
class _NowPanel extends StatelessWidget {
  const _NowPanel({
    required this.kid,
    required this.status,
    required this.tone,
  });

  final ChildToday kid;
  final DayStatus status;
  final KidTone tone;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final l = kid.lessons;
    String label;
    String title;
    String? meta;

    String details(DayLesson x) => [
      hasTime(x) ? '${x.start}–${x.end}' : x.slot,
      ?x.room,
      ?x.teacher,
      if (x.change == ChangeKind.substitution)
        '${t.changeSubstitution} ${x.changeDetail ?? ''}'.trim(),
      if (x.change == ChangeKind.roomChange)
        '${t.changeRoom} ${x.changeDetail ?? ''}'.trim(),
    ].join(' · ');

    switch (status.phase) {
      case DayPhase.running:
        final x = l[status.current!];
        label = upperFor(t, t.nowRunning(x.slot, status.minutesLeft!));
        title = x.subject;
        meta = details(x);
      case DayPhase.before:
      case DayPhase.gap:
        final x = l[status.next!];
        label = upperFor(
          t,
          status.phase == DayPhase.before
              ? t.nowFirst(x.slot, x.start)
              : t.nowNext(x.slot, x.start),
        );
        title = x.subject;
        meta = details(x);
      case DayPhase.over:
        final last = l.lastWhere((x) => !x.cancelled);
        label = upperFor(t, t.schoolOverLabel);
        title = t.schoolOverTitle;
        meta = t.lastLessonEnded(last.end);
      case DayPhase.noLessons:
        label = upperFor(t, t.dayToday);
        title = t.noLessons;
        meta = null;
      case DayPhase.untimed:
        final x = l[status.next!];
        label = upperFor(t, t.todayFromSlot(x.slot));
        title = x.subject;
        meta = details(x);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.ml),
      decoration: BoxDecoration(
        color: tone.tint,
        borderRadius: BorderRadius.circular(Rad.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: k.nowLabel(tone)),
          const SizedBox(height: Sp.xxs),
          Text(title, style: k.nowSubject(tone)),
          if (meta != null) Text(meta, style: k.nowMeta(tone)),
        ],
      ),
    );
  }
}

/// Tagesleiste: ein Abschnitt je (Doppel-)Stunde, Breite nach Dauer.
class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.kid,
    required this.status,
    required this.tone,
    required this.now,
  });

  final ChildToday kid;
  final DayStatus status;
  final KidTone tone;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final l = kid.lessons;

    Color colorFor(int i) {
      final x = l[i];
      if (x.cancelled) return k.p.cancel.bar;
      if (x.change != null && !lessonDone(x, now)) return k.p.change.bar;
      if (lessonDone(x, now)) return tone.barDone;
      return tone.barRest;
    }

    final next = status.next == null ? null : l[status.next!];
    final t = context.t;
    // Ohne Uhrzeiten (DayPhase.untimed): Leiste ohne Zeitbeschriftung.
    final timed = status.phase != DayPhase.untimed;
    final center = next == null || !timed
        ? ''
        : t.barThen(next.start, next.subject);
    final lastEnd = l.lastWhere((x) => !x.cancelled, orElse: () => l.last).end;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: Sz.dayBar,
          child: Row(
            children: [
              for (var i = 0; i < l.length; i++) ...[
                if (i > 0) const SizedBox(width: Sp.xs),
                Expanded(
                  flex: lessonMinutes(l[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Rad.bar),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: colorFor(i)),
                        if (status.current == i)
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: status.progress.clamp(0, 1),
                            child: ColoredBox(color: tone.accent),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Sp.xs + Sp.xxs),
        Row(
          children: [
            Text(timed ? l.first.start : '', style: k.barLabel),
            Expanded(
              child: Text(
                center,
                style: k.barLabel,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(timed ? t.barUntil(lastEnd) : '', style: k.barLabel),
          ],
        ),
      ],
    );
  }
}

/// Aufgeklappter Tag: eine Zeile je Abschnitt, Pausen ab 30 Minuten.
class _DayList extends StatelessWidget {
  const _DayList({
    required this.kid,
    required this.status,
    required this.tone,
    required this.now,
  });

  final ChildToday kid;
  final DayStatus status;
  final KidTone tone;
  final DateTime now;

  /// Ab dieser Länge erscheint eine Pause als eigene Zeile. Kürzere
  /// (5–20 Min.) sind normale Wechsel und würden die Liste nur verlängern.
  static const pauseRowMinutes = 30;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final l = kid.lessons;
    final rows = <Widget>[];
    for (var i = 0; i < l.length; i++) {
      if (gapBefore(l, i) >= pauseRowMinutes) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.xs,
              vertical: Sp.xs,
            ),
            child: Row(
              children: [
                const SizedBox(width: Sz.slotColumn + Sp.s + Sp.xxs),
                Text(context.t.pauseUntil(l[i].start), style: k.rowPause),
              ],
            ),
          ),
        );
      }
      rows.add(_row(k, context.t, l[i], i));
    }
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.s),
      padding: const EdgeInsets.only(top: Sp.xs + Sp.xxs),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: k.p.line)),
      ),
      child: Column(children: rows),
    );
  }

  Widget _row(Kit k, ForkL10n t, DayLesson x, int i) {
    final done = lessonDone(x, now) && status.current != i;
    final running = status.current == i;
    Color ink = k.p.ink;
    Color sub = k.p.muted;
    Color? bg;
    var subject = x.subject;
    // Rechts nur die Uhrzeit (und Raum); Angaben zur Änderung stehen als
    // zweite Zeile unter dem Fach. Ursache: „11:40 · Tim Sommer, R 112“
    // rechts drückte das Fach bei Schrift ×1,15 in zwei Zeilen.
    var right = [
      if (hasTime(x)) x.start,
      if (x.change == null) ?x.room,
    ].join(' · ');
    String? second;
    var strong = false;

    if (x.cancelled) {
      bg = k.p.cancel.bg;
      ink = sub = k.p.cancel.ink;
      second = t.lessonCancelled;
      strong = true;
    } else if (running) {
      bg = tone.tint;
      ink = tone.onTint;
      sub = tone.label;
      right = t.lessonRunning;
      strong = true;
    } else if (done) {
      ink = sub = k.p.faint;
    } else if (x.change != null) {
      bg = k.p.change.bg;
      ink = sub = k.p.change.ink;
      final what = x.change == ChangeKind.substitution
          ? t.changeSubstitution
          : t.changeRoom;
      second = [what, ?x.changeDetail].join(': ');
      strong = true;
    }

    return Container(
      margin: const EdgeInsets.only(top: Sp.xxs),
      padding: const EdgeInsets.symmetric(horizontal: Sp.xs, vertical: Sp.s),
      decoration: bg == null
          ? null
          : BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(Rad.row),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: Sz.slotColumn,
            child: Text(listSlot(x.slot), style: k.rowSlot(sub)),
          ),
          const SizedBox(width: Sp.s + Sp.xxs),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: k
                      .rowSubject(ink, strong: strong)
                      .copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: ink,
                      ),
                ),
                if (second != null) Text(second, style: k.rowTime(sub)),
              ],
            ),
          ),
          const SizedBox(width: Sp.s),
          // Uhrzeit/Raum darf schrumpfen, das Fach hat Vorrang (flex 3:2).
          // Ursache: Bei „Sehr groß“ lief die Zeile 32 px über
          // (today_page_test, ×1,3 × 1,12).
          Flexible(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(right, style: k.rowTime(sub)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Material(
      color: k.p.inset,
      borderRadius: BorderRadius.circular(Rad.buttonSmall),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.buttonSmall),
        onTap: onTap,
        child: SizedBox(
          height: Sz.buttonSmall,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Verkleinern statt Überlauf: Bei Schriftstufe „Sehr groß“ plus
              // großer Systemschrift lief der Text 27 px über die Karte
              // (today_page_test, ×1,3 × 1,12).
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    expanded ? context.t.dayCollapse : context.t.dayExpand,
                    style: k.button(k.p.muted),
                  ),
                ),
              ),
              const SizedBox(width: Sp.xs + Sp.xxs),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: Sz.icon,
                color: k.p.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.strong = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final fg = strong ? k.p.onStrong : k.p.ink;
    return Material(
      color: strong ? k.p.strong : k.p.inset,
      borderRadius: BorderRadius.circular(Rad.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.button),
        onTap: onTap,
        child: Tooltip(
          message: label,
          child: SizedBox(
            height: Sz.button,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: Sz.icon, color: fg),
                const SizedBox(width: Sp.s),
                Flexible(
                  child: Text(
                    label,
                    style: k.button(fg),
                    overflow: TextOverflow.ellipsis,
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

// ---- Demnächst --------------------------------------------------------------

class UpcomingTiles extends StatelessWidget {
  const UpcomingTiles({super.key, required this.data, this.onOpenAll});

  final FamilyToday data;
  final VoidCallback? onOpenAll;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final items = [...data.week]..sort((a, b) => a.day.compareTo(b.day));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.page + Sp.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(context.t.upcoming, style: k.section)),
              if (onOpenAll != null)
                TextButton(
                  onPressed: onOpenAll,
                  child: Text(context.t.allEvents, style: k.link),
                ),
            ],
          ),
        ),
        const SizedBox(height: Sp.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Sp.page),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, w) in items.indexed) ...[
                  if (i > 0) const SizedBox(width: Sp.s + Sp.xxs),
                  _Tile(item: w, data: data),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item, required this.data});

  final WeekItem item;
  final FamilyToday data;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final ci = item.childIndex;
    final kid = ci == null ? null : data.kids[ci];
    final color = kid == null ? k.p.muted : k.kid(kid.colorIndex).accent;
    final t = context.t;
    final caption = upperFor(
      t,
      [relativeDay(t, item.day, data.now), ?item.time].join(' · '),
    );
    return Container(
      width: Sz.tileWidth,
      padding: const EdgeInsets.all(Sp.ml),
      decoration: BoxDecoration(
        color: k.p.card,
        borderRadius: BorderRadius.circular(Rad.tile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption, style: k.tileCaption),
          const SizedBox(height: Sp.xs + Sp.xxs),
          // Ganze Wörter (word_fit.dart); Breite = Kachel minus Innenrand.
          Expanded(
            child: WordFitText(
              item.title,
              style: k.tileTitle,
              width: Sz.tileWidth - 2 * Sp.ml,
            ),
          ),
          const SizedBox(height: Sp.xs + Sp.xxs),
          Row(
            children: [
              _Dot(color: color),
              const SizedBox(width: Sp.xs + Sp.xxs),
              Flexible(
                child: Text(
                  kid?.firstName ?? t.forEveryone,
                  style: k.tileKid(color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
