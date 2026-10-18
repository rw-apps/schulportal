import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../kit.dart';
import '../today/today_model.dart';
import '../today/today_page.dart' show dayDiff;

/// „HEUTE · MONTAG, 19. OKTOBER“ bzw. „DONNERSTAG, 22. OKTOBER“.
String eventDayHeader(ForkL10n t, DateTime day, DateTime now) {
  final date = formatDate(t, t.dateLong, day);
  final diff = dayDiff(now, day);
  final rel = diff == 0
      ? '${t.dayToday} · '
      : (diff == 1 ? '${t.dayTomorrow} · ' : '');
  return upperFor(t, '$rel$date');
}

/// Art als kurzes Wort für die Metazeile; normale Termine ohne Wort.
String? eventKindLabel(ForkL10n t, WeekKind k) => switch (k) {
  WeekKind.exam => t.kindExam,
  WeekKind.free => t.kindFree,
  WeekKind.deadline => t.kindDeadline,
  WeekKind.meal => t.kindMeal,
  WeekKind.event => null,
};

/// Alle Termine, nach Tag gruppiert – die Heimat der Termine im Bereich
/// „Kalender“ (Konzept 17.10.26: jedes Ding hat genau einen Ort; „Heute“
/// zeigt nur Auszüge).
class EventList extends StatelessWidget {
  const EventList({
    super.key,
    required this.items,
    required this.now,
    this.kidColor = 0,
    this.kids = const [],
    this.showKid = false,
  });

  final List<WeekItem> items;
  final DateTime now;

  /// Farbplatz des Kindes (KitPalette.kids) für normale Termine ohne
  /// [WeekItem.childIndex] bzw. ohne [kids].
  final int kidColor;

  /// Kinder in der Reihenfolge von [WeekItem.childIndex]: Name und
  /// Farbplatz. Ursache (Rückmeldung 18.10.26): Vorher trug jeder Termin die
  /// Farbe des gerade gewählten Kindes – auch die des anderen.
  final List<({String name, int color})> kids;

  /// Unter jedem Termin „● Name“ (bei mehreren Kindern und Filter „Alle“).
  final bool showKid;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.xl),
        child: Text(
          context.t.eventsNone,
          style: k.meta,
          textAlign: TextAlign.center,
        ),
      );
    }
    final children = <Widget>[];
    DateTime? last;
    for (final it in items) {
      if (last == null || dayDiff(last, it.day) != 0) {
        children.add(
          Padding(
            padding: EdgeInsets.only(
              top: last == null ? 0 : Sp.l,
              bottom: Sp.s,
              left: Sp.xs,
            ),
            child: Text(
              eventDayHeader(context.t, it.day, now),
              style: k.dateCaps,
            ),
          ),
        );
        last = it.day;
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.s),
          child: _EventRow(
            item: it,
            now: now,
            kid: _kidOf(it),
            fallbackColor: kidColor,
            showKid: showKid,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  ({String name, int color})? _kidOf(WeekItem it) {
    final ci = it.childIndex;
    return ci != null && ci >= 0 && ci < kids.length ? kids[ci] : null;
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.item,
    required this.now,
    required this.kid,
    required this.fallbackColor,
    required this.showKid,
  });

  final WeekItem item;
  final DateTime now;
  final ({String name, int color})? kid;
  final int fallbackColor;
  final bool showKid;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final accent = switch (item.kind) {
      WeekKind.exam => k.p.cancel.dot,
      WeekKind.free => k.p.change.dot,
      WeekKind.meal => k.p.faint,
      WeekKind.deadline ||
      WeekKind.event => k.kid(kid?.color ?? fallbackColor).accent,
    };
    final kidInk = kid == null ? null : k.kid(kid!.color).accent;
    final t = context.t;
    final until = item.until;
    final meta = [
      ?eventKindLabel(t, item.kind),
      if (until != null) t.barUntil(formatDate(t, t.dateShort, until)),
      ?item.place,
    ].join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: k.p.card,
        borderRadius: BorderRadius.circular(Rad.row),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: Sp.xs, color: accent),
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.m, Sp.m, 0, Sp.m),
              // Einzeilig, notfalls kleiner: „ganztags“ brach in der schmalen
              // Spalte als „ganzta/gs“ um (Bildschirmfoto 18.10.26).
              child: SizedBox(
                width: Sz.slotColumn,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: Text(
                    item.time ?? t.allDay,
                    maxLines: 1,
                    softWrap: false,
                    style: item.time == null ? k.timeEnd : k.timeStart,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Sp.s, Sp.m, Sp.m, Sp.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: k.planSubject(k.p.ink)),
                    if (meta.isNotEmpty)
                      Text(meta, style: k.planMeta(k.p.muted)),
                    if (showKid && kid != null && kidInk != null) ...[
                      const SizedBox(height: Sp.xxs),
                      Row(
                        children: [
                          Container(
                            width: Sz.dot,
                            height: Sz.dot,
                            decoration: BoxDecoration(
                              color: kidInk,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: Sp.xs + Sp.xxs),
                          Flexible(
                            child: Text(
                              kid!.name,
                              style: k.tileKid(kidInk),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
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
