import 'package:flutter/material.dart';

import '../kit.dart';
import 'courses_model.dart';

const _wd = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

String _date(DateTime d) => '${_wd[d.weekday - 1]} ${d.day}.${d.month}.';

/// Höchstens drei Namen, sonst zwei und „+n“. Ursache: Das Ganztagsangebot
/// von Schule A nennt sechs Lehrkräfte; die Zeile lief über vier Zeilen.
String teacherSummary(List<String> t) =>
    t.length <= 3 ? t.join(', ') : '${t.take(2).join(', ')} +${t.length - 2}';

/// Bereich „Unterricht“: alles, was an einem Kurs hängt (Konzept 17.10.26).
/// Oben die Hausaufgaben (offene zuerst), darunter alle Kurse mit dem
/// neuesten Eintrag der Kursmappe und der Anwesenheit.
///
/// Grenze: Das Portal zeigt in der Übersicht nur den neuesten Eintrag je
/// Kurs; ältere Hausaufgaben stehen auf der Kursseite (Antippen).
class CoursesPage extends StatelessWidget {
  const CoursesPage({
    super.key,
    required this.items,
    this.firstName,
    this.onOpen,
    this.onRefresh,
    this.loading = false,
  });

  final List<CourseItem> items;
  final String? firstName;
  final void Function(CourseItem item)? onOpen;
  final Future<void> Function()? onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final homework = [
      ...items.where((i) => i.hasOpenHomework),
      ...items.where((i) => i.homework != null && i.homeworkDone),
    ];
    final view = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Sp.page + Sp.xs,
              Sp.xl,
              Sp.page,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unterricht', style: k.pageTitle),
                  if (firstName != null) Text(firstName!, style: k.meta),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Sp.page, Sp.xl, Sp.page, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: Sp.xs, bottom: Sp.s),
                  child: Text('Hausaufgaben', style: k.section),
                ),
                if (homework.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: Sp.xs),
                    child: Text(
                      loading && items.isEmpty
                          ? 'Wird geladen …'
                          : 'Keine Hausaufgaben eingetragen.',
                      style: k.meta,
                    ),
                  ),
                for (final i in homework)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Sp.s),
                    child: _HomeworkCard(item: i, onTap: onOpen),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(Sp.page, Sp.xl, Sp.page, bottom + Sp.xl),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: Sp.xs, bottom: Sp.s),
                  child: Text('Kurse', style: k.section),
                ),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: Sp.xs),
                    child: Text(
                      loading ? 'Wird geladen …' : 'Keine Kurse gefunden.',
                      style: k.meta,
                    ),
                  ),
                for (final i in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Sp.s),
                    child: _CourseRow(item: i, onTap: onOpen),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    final r = onRefresh;
    return r == null ? view : RefreshIndicator(onRefresh: r, child: view);
  }
}

class _HomeworkCard extends StatelessWidget {
  const _HomeworkCard({required this.item, this.onTap});

  final CourseItem item;
  final void Function(CourseItem)? onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final open = item.hasOpenHomework;
    final tone = k.p.change;
    final meta = [
      if (item.date != null) 'vom ${_date(item.date!)}',
      open ? 'offen' : 'erledigt',
    ].join(' · ');
    return Material(
      color: open ? tone.bg : k.p.card,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.signal),
        onTap: onTap == null ? null : () => onTap!(item),
        child: Padding(
          padding: const EdgeInsets.all(Sp.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: k.planSubject(open ? tone.ink : k.p.ink)),
              const SizedBox(height: Sp.xs),
              Text(item.homework!, style: open ? k.boxText(tone) : k.body),
              const SizedBox(height: Sp.xs),
              Text(meta, style: k.planMeta(open ? tone.ink : k.p.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.item, this.onTap});

  final CourseItem item;
  final void Function(CourseItem)? onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final latest = [
      if (item.date != null) _date(item.date!),
      ?item.topic,
    ].join(' · ');
    return Material(
      color: k.p.card,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.signal),
        onTap: onTap == null ? null : () => onTap!(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.m),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: k.planSubject(k.p.ink)),
                    if (item.teachers.isNotEmpty)
                      Text(
                        teacherSummary(item.teachers),
                        style: k.planTeacher(k.p.ink),
                      ),
                    if (latest.isNotEmpty)
                      Text(latest, style: k.planMeta(k.p.muted)),
                    if (item.attendance != null)
                      Text(item.attendance!, style: k.planMeta(k.p.muted)),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, size: Sz.icon, color: k.p.muted),
            ],
          ),
        ),
      ),
    );
  }
}
