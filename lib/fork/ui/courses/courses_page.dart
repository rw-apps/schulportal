import 'package:flutter/material.dart';

import '../../homework_ledger.dart';
import '../../l10n/l10n.dart';
import '../kit.dart';
import '../segments.dart';
import 'courses_model.dart';
import 'grades_view.dart';

/// Höchstens drei Namen, sonst zwei und „+n“. Ursache: Das Ganztagsangebot
/// von Schule A nennt sechs Lehrkräfte; die Zeile lief über vier Zeilen.
String teacherSummary(List<String> t) =>
    t.length <= 3 ? t.join(', ') : '${t.take(2).join(', ')} +${t.length - 2}';

/// Nachname aus „Vorname Nachname“ (letztes Wort) – für die schmale Spalte
/// rechts in der Kurszeile (Entwurf 17.10.26).
String lastNameOf(String display) {
  final w = display.trim().split(RegExp(r'\s+'));
  return w.isEmpty ? display : w.last;
}

/// Hausaufgaben für „Unterricht“: offen, Zahl der erledigten und Aktionen.
/// Ohne (Vorschau) zeigt die Seite die offenen aus [CoursesPage.items].
class HomeworkBoard {
  const HomeworkBoard({
    required this.open,
    required this.doneCount,
    required this.onDone,
    required this.onReopen,
    this.onOpenArchive,
  });

  final List<HomeworkItem> open;
  final int doneCount;
  final void Function(HomeworkItem item) onDone;
  final void Function(HomeworkItem item) onReopen;
  final VoidCallback? onOpenArchive;
}

/// Bereich „Unterricht“ (Entwurf 1, abgenommen 17.10.26): oben die offenen
/// Hausaufgaben, darunter die Fächer in der Reihenfolge und Farbe des
/// Wochenplans, unten eingeklappt die weiteren Angebote (Ganztag, Training).
///
/// Grenze: Das Portal zeigt in der Übersicht nur den neuesten Eintrag je
/// Kurs; ältere Hausaufgaben stehen auf der Kursseite (Antippen).
///
/// Mit [grades] oben der Umschalter „Fächer & Hausaufgaben | Arbeiten &
/// Noten“ (Namen nach Rückmeldung 18.10.26: „Kurse | Noten“ passte nicht,
/// seit oben die anstehenden Arbeiten stehen; „gewählte Kurse“ wäre für die
/// Pflichtfächer der Sekundarstufe I falsch). Rechts zeigt GradesView in
/// derselben Liste unter Titel und Kind.
class CoursesPage extends StatefulWidget {
  const CoursesPage({
    super.key,
    required this.items,
    this.firstName,
    this.className,
    this.onOpen,
    this.onRefresh,
    this.loading = false,
    this.grades,
    this.homework,
  });

  /// Abhaken und Archiv (Wunsch 18.10.26); null = nur Anzeige.
  final HomeworkBoard? homework;

  final List<CourseItem> items;
  final String? firstName;
  final String? className;
  final void Function(CourseItem item)? onOpen;
  final Future<void> Function()? onRefresh;
  final bool loading;

  /// Quelle der Notenübersicht; null = kein Umschalter (Vorschau, kein
  /// „Mein Unterricht“).
  final GradesSource? grades;

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  bool _showExtra = false;

  /// „Noten“ gewählt. In PageStorage, damit die Wahl beim Wechsel des Kindes
  /// bleibt – FamilySwitch baut die Seite je Konto neu (KeyedSubtree), der
  /// Speicher hängt aber am Reiter.
  static const _modeId = 'courses-grades';
  late bool _grades =
      PageStorage.maybeOf(context)?.readState(context, identifier: _modeId)
          as bool? ??
      false;
  final _gradesKey = GlobalKey<GradesViewState>();

  void _mode(bool grades) {
    if (grades == _grades) return;
    setState(() => _grades = grades);
    PageStorage.maybeOf(
      context,
    )?.writeState(context, grades, identifier: _modeId);
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final items = widget.items;
    final open =
        widget.homework?.open ??
        [
          for (final i in items)
            if (i.hasOpenHomework)
              HomeworkItem(
                course: i.id,
                entry: i.entry ?? '',
                subject: i.title,
                text: i.homework ?? '',
                given: i.date,
              ),
        ];
    // Fächer nach Platz im Wochenplan (= Fachfarbe), ohne Platz ans Ende.
    final subjects = items.where((i) => !i.extra).toList()
      ..sort((a, b) {
        final c = (a.colorSlot ?? 999).compareTo(b.colorSlot ?? 999);
        return c != 0 ? c : a.title.compareTo(b.title);
      });
    final extra = items.where((i) => i.extra).toList();
    final meta = [
      ?widget.firstName,
      if (widget.className != null && widget.className!.isNotEmpty)
        widget.className!,
      if (subjects.isNotEmpty) t.subjectsCount(subjects.length),
    ].join(' · ');

    final grades = widget.grades;
    final showGrades = grades != null && _grades;
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(left: Sp.xs),
        child: Text(t.navCourses, style: k.pageTitle),
      ),
      if (meta.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: Sp.xs),
          child: Text(meta, style: k.meta),
        ),
      if (grades != null)
        Padding(
          padding: const EdgeInsets.only(top: Sp.l),
          child: PillSegments.strong(
            labels: [t.coursesTab, t.examsGradesTab],
            selected: showGrades ? 1 : 0,
            onChanged: (i) => _mode(i == 1),
          ),
        ),
      if (showGrades)
        GradesView(key: _gradesKey, source: grades, onOpen: widget.onOpen)
      else
        ..._courseList(k, t, items, open, subjects, extra),
    ];

    final view = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        Sp.page,
        MediaQuery.paddingOf(context).top + Sp.xl,
        Sp.page,
        bottom + Sp.xl,
      ),
      children: children,
    );
    final r = showGrades
        ? () async => _gradesKey.currentState?.reload()
        : widget.onRefresh;
    return r == null ? view : RefreshIndicator(onRefresh: r, child: view);
  }

  /// Abhaken mit „Rückgängig“ – ein Fehlgriff auf dem kleinen Kreis soll
  /// nicht erst über das Archiv zu reparieren sein.
  void _done(HomeworkBoard hw, HomeworkItem i) {
    hw.onDone(i);
    final t = context.t;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(t.homeworkMarkedDone),
          action: SnackBarAction(
            label: t.undo,
            onPressed: () => hw.onReopen(i),
          ),
        ),
      );
  }

  List<Widget> _courseList(
    Kit k,
    ForkL10n t,
    List<CourseItem> items,
    List<HomeworkItem> open,
    List<CourseItem> subjects,
    List<CourseItem> extra,
  ) {
    final hw = widget.homework;
    CourseItem? courseOf(HomeworkItem h) =>
        items.where((i) => i.id == h.course).firstOrNull;
    return [
      _Section(
        title: t.openHomeworkTitle,
        trailing: hw != null && hw.doneCount > 0 && hw.onOpenArchive != null
            ? t.homeworkArchive(hw.doneCount)
            : null,
        onTap: hw != null && hw.doneCount > 0 ? hw.onOpenArchive : null,
      ),
      if (open.isEmpty)
        Padding(
          padding: const EdgeInsets.only(left: Sp.xs),
          child: Text(
            widget.loading && items.isEmpty ? t.loading : t.noOpenHomework,
            style: k.meta,
          ),
        ),
      for (final i in open)
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.s),
          child: _HomeworkCard(
            item: i,
            onTap: widget.onOpen == null || courseOf(i) == null
                ? null
                : () => widget.onOpen!(courseOf(i)!),
            onDone: hw == null ? null : () => _done(hw, i),
          ),
        ),
      _Section(title: t.subjectsTitle),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.only(left: Sp.xs),
          child: Text(widget.loading ? t.loading : t.noCourses, style: k.meta),
        ),
      for (final i in subjects)
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.s),
          child: _CourseRow(item: i, onTap: widget.onOpen),
        ),
      if (extra.isNotEmpty) ...[
        _Section(
          title: t.extraOffers,
          trailing: '${extra.length} ${_showExtra ? t.hide : t.show}',
          onTap: () => setState(() => _showExtra = !_showExtra),
        ),
        if (!_showExtra)
          Padding(
            padding: const EdgeInsets.only(left: Sp.xs),
            child: Text(
              extra.map((i) => i.title).toSet().join(', '),
              style: k.meta,
            ),
          )
        else
          for (final i in extra)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: _CourseRow(item: i, onTap: widget.onOpen),
            ),
      ],
    ];
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.trailing, this.onTap});

  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: Sp.xs, bottom: Sp.s, top: Sp.xl),
        child: Row(
          children: [
            Expanded(child: Text(title, style: k.section)),
            if (trailing != null) Text(trailing!, style: k.link),
          ],
        ),
      ),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  const _HomeworkCard({required this.item, this.onTap, this.onDone});

  final HomeworkItem item;
  final VoidCallback? onTap;

  /// Kreis links hakt ab; null = nur Anzeige.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final tone = k.p.change;
    final text = item.text.isEmpty ? t.homeworkEntered : item.text;
    final meta = item.given == null
        ? item.subject
        : t.givenOn(item.subject, formatDate(t, t.dateShort, item.given!));
    final circle = Icon(
      Icons.radio_button_unchecked,
      size: Sz.navIcon,
      color: tone.ink,
    );
    return Material(
      color: tone.bg,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.signal),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.xs, Sp.l, Sp.xs),
          child: Row(
            children: [
              // Eigene Trefferfläche (48 dp), getrennt vom Öffnen des Kurses.
              if (onDone != null)
                IconButton(
                  onPressed: onDone,
                  tooltip: t.homeworkMarkDone,
                  icon: circle,
                )
              else
                Padding(padding: const EdgeInsets.all(Sp.m), child: circle),
              const SizedBox(width: Sp.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Sp.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text, style: k.boxStrong(tone)),
                      Text(meta, style: k.planMeta(tone.ink)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kurszeile: Fachfarbe links (wie im Wochenraster), Fach, Nachnamen der
/// Lehrkräfte, letzter Eintrag; offene Hausaufgabe und Fehlstunden als
/// Marken.
class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.item, this.onTap});

  final CourseItem item;
  final void Function(CourseItem)? onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final stripe = item.colorSlot == null
        ? k.p.line
        : k.subjectAt(item.colorSlot!).ink;
    final latest = [
      if (item.date != null) formatDate(t, t.dateShort, item.date!),
      ?item.topic,
    ].join('  ');
    final chips = [
      if (item.hasOpenHomework)
        _Chip(
          icon: Icons.menu_book_outlined,
          text: t.chipHomeworkOpen,
          tone: k.p.change,
        ),
      if (item.missing > 0)
        _Chip(
          icon: Icons.event_busy,
          text: t.absentCount(item.missing),
          tone: k.p.cancel,
        ),
    ];
    return Material(
      color: k.p.card,
      borderRadius: BorderRadius.circular(Rad.signal),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(item),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: Sp.xs + Sp.xxs, color: stripe),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.m, Sp.m, Sp.s, Sp.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          // Fach vor Lehrkräften (3:2), lange Fachnamen werden
                          // verkleinert statt getrennt. Ursache: „Naturwissen-
                          // schaften“ brach mitten im Wort um (Bildschirmfoto
                          // echte Daten, 17.10.26).
                          Expanded(
                            flex: 3,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                item.title,
                                maxLines: 1,
                                style: k.planSubject(k.p.ink),
                              ),
                            ),
                          ),
                          if (item.teachers.isNotEmpty) ...[
                            const SizedBox(width: Sp.s),
                            Flexible(
                              flex: 2,
                              child: Text(
                                teacherSummary([
                                  for (final n in item.teachers) lastNameOf(n),
                                ]),
                                style: k.planMeta(k.p.muted),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (latest.isNotEmpty)
                        Text(
                          latest,
                          style: k.planMeta(k.p.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: Sp.xs),
                        Wrap(
                          spacing: Sp.xs,
                          runSpacing: Sp.xs,
                          children: chips,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(right: Sp.s),
                  child: Icon(
                    Icons.chevron_right,
                    size: Sz.icon,
                    color: k.p.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, required this.tone});

  final IconData icon;
  final String text;
  final SignalTone tone;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Sp.s,
        vertical: Sp.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(Rad.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Sz.icon - Sp.xs, color: tone.ink),
          const SizedBox(width: Sp.xs),
          Flexible(child: Text(text, style: k.planMeta(tone.ink))),
        ],
      ),
    );
  }
}
