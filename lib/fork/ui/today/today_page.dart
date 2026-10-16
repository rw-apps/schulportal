import 'package:flutter/material.dart';

import '../kit.dart';
import 'today_model.dart';

const _weekdaysLong = [
  'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag',
  'Sonntag',
];
const _weekdaysShort = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const _months = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August',
  'September', 'Oktober', 'November', 'Dezember',
];

String _longDate(DateTime d) =>
    '${_weekdaysLong[d.weekday - 1]}, ${d.day}. ${_months[d.month - 1]}';

/// „Heute“, „Morgen“ oder „Do 22.10.“ relativ zu [now].
String relativeDay(DateTime day, DateTime now) {
  final a = DateTime(day.year, day.month, day.day);
  final b = DateTime(now.year, now.month, now.day);
  final diff = a.difference(b).inDays;
  if (diff == 0) return 'Heute';
  if (diff == 1) return 'Morgen';
  return '${_weekdaysShort[day.weekday - 1]} ${day.day}.${day.month}.';
}

/// Seite „Heute“: je Kind eine Karte, darunter die gemeinsame Woche.
class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.data,
    this.onReportAbsence,
    this.onOpenHomework,
    this.onOpenMessages,
  });

  final FamilyToday data;
  final void Function(ChildToday child)? onReportAbsence;
  final void Function(ChildToday child)? onOpenHomework;
  final void Function(ChildToday child)? onOpenMessages;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(Sp.page, Sp.l, Sp.page, Sp.s),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Heute', style: k.pageTitle),
                  const SizedBox(height: Sp.xs),
                  Text(_longDate(data.now), style: k.pageSub),
                  if (data.isDemo) ...[
                    const SizedBox(height: Sp.m),
                    _DemoNote(),
                  ],
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.page),
          sliver: SliverList.separated(
            itemCount: data.kids.length,
            separatorBuilder: (_, _) => const SizedBox(height: Sp.m),
            itemBuilder: (context, i) => ChildCard(
              child: data.kids[i],
              now: data.now,
              onReportAbsence: onReportAbsence,
              onOpenHomework: onOpenHomework,
              onOpenMessages: onOpenMessages,
            ),
          ),
        ),
        if (data.week.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              Sp.page,
              Sp.xl,
              Sp.page,
              Sp.xxl + bottom,
            ),
            sliver: SliverToBoxAdapter(
              child: WeekList(data: data),
            ),
          ),
      ],
    );
  }
}

class _DemoNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.s),
      decoration: BoxDecoration(
        color: k.insetBg,
        borderRadius: BorderRadius.circular(Rad.chip),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: Sz.icon, color: k.cs.onSurfaceVariant),
          const SizedBox(width: Sp.s),
          Expanded(
            child: Text(
              'Entwurf mit erfundenen Beispieldaten',
              style: k.meta,
            ),
          ),
        ],
      ),
    );
  }
}

/// Karte eines Kindes.
class ChildCard extends StatelessWidget {
  const ChildCard({
    super.key,
    required this.child,
    required this.now,
    this.onReportAbsence,
    this.onOpenHomework,
    this.onOpenMessages,
  });

  final ChildToday child;
  final DateTime now;
  final void Function(ChildToday child)? onReportAbsence;
  final void Function(ChildToday child)? onOpenHomework;
  final void Function(ChildToday child)? onOpenMessages;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final tone = k.child(child.colorIndex);
    final c = child;

    return Material(
      color: k.cardBg,
      borderRadius: BorderRadius.circular(Rad.card),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(Sp.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kopf: Kind, Schule, Krankmeldung
            Row(
              children: [
                CircleAvatar(
                  radius: Sz.avatar,
                  backgroundColor: tone.container,
                  child: Text(
                    c.firstName.characters.first,
                    style: k.cardTitle.copyWith(color: tone.onContainer),
                  ),
                ),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.firstName, style: k.cardTitle),
                      Text(
                        '${c.school} · ${c.className}',
                        style: k.meta,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.m),

            // Jetzt / Danach
            _NowNext(child: c, tone: tone),

            // Änderungen
            for (final ch in c.changes) ...[
              const SizedBox(height: Sp.s),
              _ChangeRow(item: ch, now: now),
            ],

            // Zähler
            // Krankmeldung als beschrifteter Chip statt Symbolknopf im Kopf:
            // Das Symbol allein war im ersten Entwurf nicht verständlich.
            if (c.openHomework > 0 ||
                c.unreadMessages > 0 ||
                c.canReportAbsence) ...[
              const SizedBox(height: Sp.m),
              Wrap(
                spacing: Sp.s,
                runSpacing: Sp.s,
                children: [
                  if (c.openHomework > 0)
                    ActionChip(
                      avatar: const Icon(Icons.menu_book_outlined, size: Sz.icon),
                      label: Text(
                        c.openHomework == 1
                            ? '1 Hausaufgabe offen'
                            : '${c.openHomework} Hausaufgaben offen',
                        style: k.chip,
                      ),
                      onPressed: onOpenHomework == null
                          ? null
                          : () => onOpenHomework!(c),
                    ),
                  if (c.unreadMessages > 0)
                    ActionChip(
                      avatar: const Icon(Icons.mark_email_unread_outlined,
                          size: Sz.icon),
                      label: Text(
                        c.unreadMessages == 1
                            ? '1 neue Nachricht'
                            : '${c.unreadMessages} neue Nachrichten',
                        style: k.chip,
                      ),
                      onPressed: onOpenMessages == null
                          ? null
                          : () => onOpenMessages!(c),
                    ),
                  if (c.canReportAbsence)
                    ActionChip(
                      avatar: const Icon(Icons.sick_outlined, size: Sz.icon),
                      label: Text('Krank melden', style: k.chip),
                      tooltip: 'Krank melden',
                      onPressed: onReportAbsence == null
                          ? null
                          : () => onReportAbsence!(c),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Laufende und nächste Stunde mit Farbbalken des Kindes.
class _NowNext extends StatelessWidget {
  const _NowNext({required this.child, required this.tone});

  final ChildToday child;
  final KitTone tone;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final rows = <Widget>[];

    Widget row(String tag, LessonRef l, {required bool strong}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(width: Sz.tagColumn, child: Text(tag, style: k.tag)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.subject, style: strong ? k.bodyStrong : k.body),
                Text(
                  [
                    '${l.start}–${l.end}',
                    ?l.room,
                    ?l.teacher,
                  ].join(' · '),
                  style: k.meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (child.now != null) rows.add(row('JETZT', child.now!, strong: true));
    if (child.next != null) {
      rows.add(row(child.now == null ? 'GLEICH' : 'DANACH', child.next!,
          strong: child.now == null));
    }
    if (rows.isEmpty) {
      rows.add(
        Text(child.dayEnd ?? 'Heute kein Unterricht', style: k.meta),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: Sz.bar,
            decoration: BoxDecoration(
              color: tone.accent,
              borderRadius: BorderRadius.circular(Sz.bar / 2),
            ),
          ),
          const SizedBox(width: Sp.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            ),
          ),
        ],
      ),
    );
  }
}

/// Eine Abweichung als farbige Zeile.
class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.item, required this.now});

  final ChangeItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final cancelled = item.kind == ChangeKind.cancelled;
    final tone = cancelled ? k.cancel : k.change;
    final icon = switch (item.kind) {
      ChangeKind.cancelled => Icons.event_busy_outlined,
      ChangeKind.roomChange => Icons.meeting_room_outlined,
      ChangeKind.substitution => Icons.swap_horiz,
    };
    // Zeile 1: wann und welches Fach; Zeile 2: was sich ändert. Vorher stand
    // „Vertretung“ doppelt („Deutsch Vertretung / Vertretung Hr. …“).
    final what = switch (item.kind) {
      ChangeKind.cancelled => 'Fällt aus',
      ChangeKind.roomChange => 'Raumwechsel',
      ChangeKind.substitution => 'Vertretung',
    };
    final second = item.detail == null ? what : '$what: ${item.detail}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.s),
      decoration: BoxDecoration(
        color: tone.container,
        borderRadius: BorderRadius.circular(Rad.tile),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: Sz.icon, color: tone.onContainer),
          ),
          const SizedBox(width: Sp.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${relativeDay(item.day, now)} · ${item.slot} · ${item.subject}',
                  style: k.signalStrong(tone),
                ),
                Text(second, style: k.signal(tone)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gemeinsame Wochenübersicht, nach Tagen gruppiert.
class WeekList extends StatelessWidget {
  const WeekList({super.key, required this.data});

  final FamilyToday data;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final byDay = <DateTime, List<WeekItem>>{};
    for (final w in data.week) {
      final day = DateTime(w.day.year, w.day.month, w.day.day);
      byDay.putIfAbsent(day, () => []).add(w);
    }
    final days = byDay.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DEMNÄCHST', style: k.section),
        const SizedBox(height: Sp.s),
        Material(
          color: k.cardBg,
          borderRadius: BorderRadius.circular(Rad.card),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, day) in days.indexed) ...[
                if (i > 0) Divider(height: 1, color: k.divider),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Sp.l,
                    vertical: Sp.m,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: Sz.tagColumn,
                        child: Text(
                          relativeDay(day, data.now),
                          style: k.tag,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            for (final w in byDay[day]!)
                              _WeekRow(item: w, data: data),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.item, required this.data});

  final WeekItem item;
  final FamilyToday data;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final childIdx = item.childIndex;
    final kid = childIdx == null ? null : data.kids[childIdx];
    final dot = kid == null
        ? k.cs.onSurfaceVariant
        : k.child(kid.colorIndex).accent;
    final icon = switch (item.kind) {
      WeekKind.exam => Icons.edit_note,
      WeekKind.event => Icons.event_outlined,
      WeekKind.deadline => Icons.flag_outlined,
      WeekKind.free => Icons.beach_access_outlined,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: Sz.icon, color: dot),
          ),
          const SizedBox(width: Sp.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: item.kind == WeekKind.exam ? k.bodyStrong : k.body,
                ),
                Text(
                  [
                    kid?.firstName ?? 'Alle',
                    ?item.time,
                  ].join(' · '),
                  style: k.meta.copyWith(color: dot),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
