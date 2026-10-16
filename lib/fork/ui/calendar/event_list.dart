import 'package:flutter/material.dart';

import '../kit.dart';
import '../today/today_model.dart';
import '../today/today_page.dart' show dayDiff;

const _weekdays = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];
const _wdShort = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const _months = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];

/// „HEUTE · MONTAG, 19. OKTOBER“ bzw. „DONNERSTAG, 22. OKTOBER“.
String eventDayHeader(DateTime day, DateTime now) {
  final date =
      '${_weekdays[day.weekday - 1]}, ${day.day}. ${_months[day.month - 1]}';
  final diff = dayDiff(now, day);
  final rel = diff == 0 ? 'Heute · ' : (diff == 1 ? 'Morgen · ' : '');
  return '$rel$date'.toUpperCase();
}

/// Art als kurzes Wort für die Metazeile; normale Termine ohne Wort.
String? eventKindLabel(WeekKind k) => switch (k) {
  WeekKind.exam => 'Arbeit',
  WeekKind.free => 'Schulfrei',
  WeekKind.deadline => 'Frist',
  WeekKind.meal => 'Essen',
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
  });

  final List<WeekItem> items;
  final DateTime now;

  /// Farbplatz des Kindes (KitPalette.kids) für normale Termine.
  final int kidColor;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.xl),
        child: Text(
          'Keine Termine in den nächsten Wochen.',
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
            child: Text(eventDayHeader(it.day, now), style: k.dateCaps),
          ),
        );
        last = it.day;
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.s),
          child: _EventRow(item: it, now: now, kidColor: kidColor),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.item,
    required this.now,
    required this.kidColor,
  });

  final WeekItem item;
  final DateTime now;
  final int kidColor;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final accent = switch (item.kind) {
      WeekKind.exam => k.p.cancel.dot,
      WeekKind.free => k.p.change.dot,
      WeekKind.meal => k.p.faint,
      WeekKind.deadline || WeekKind.event => k.kid(kidColor).accent,
    };
    final until = item.until;
    final meta = [
      ?eventKindLabel(item.kind),
      if (until != null)
        'bis ${_wdShort[until.weekday - 1]} ${until.day}.${until.month}.',
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
              child: SizedBox(
                width: Sz.slotColumn,
                child: Text(
                  item.time ?? 'ganztags',
                  style: item.time == null ? k.timeEnd : k.timeStart,
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
