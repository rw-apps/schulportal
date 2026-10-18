import 'package:flutter/material.dart';
import 'package:liblanis/liblanis.dart';

import '../../courses_scan.dart';
import '../../error_log.dart';
import '../../l10n/l10n.dart';
import '../kit.dart';
import '../segments.dart';
import 'course_detail_page.dart' show ValueRow;
import 'courses_model.dart';
import 'grades_model.dart';

/// Woher die Übersicht ihre Kursseiten bekommt.
class GradesSource {
  const GradesSource({
    required this.account,
    required this.courses,
    required this.load,
    this.onCurrentLoaded,
  });

  /// Konto-Schlüssel für den Zwischenspeicher (LiveSnapshot.accountKey).
  final String account;
  final List<CourseItem> courses;
  final Future<DetailedLesson> Function(
    CourseItem course, {
    required bool firstHalf,
  })
  load;

  /// Nach einem Durchgang im laufenden Halbjahr mit allen bis dahin
  /// geladenen Seiten – für die gespeicherte Auswertung (courses_scan.dart),
  /// damit „Heute“ die Arbeiten kennt und der Hinweis im Hintergrund schon
  /// Gesehenes nicht noch einmal meldet.
  final void Function(Map<String, DetailedLesson> pages)? onCurrentLoaded;
}

/// „Noten“ im Bereich Unterricht (Vorschlag abgenommen 17.10.26): je
/// Halbjahr jedes Fach mit seinen Noten, darunter die Fächer ohne Note in
/// einer Zeile. Kein eigener Scroller – steht in der Liste von CoursesPage.
///
/// Lädt die Kursseiten nacheinander, nicht gleichzeitig. Ursache: Alle
/// Abrufe teilen eine Portal-Sitzung; 15 parallele Anfragen an das
/// Schulportal wären unhöflich und riskieren Abbrüche. Grenze: Bei ~15
/// Kursen dauert das erste Öffnen einige Sekunden – der Fortschritt steht
/// dabei („5 von 14“), danach kommt alles aus GradesCache.
class GradesView extends StatefulWidget {
  const GradesView({
    super.key,
    required this.source,
    this.onOpen,
    this.now,
    this.onOpenAbsences,
  });

  final GradesSource source;

  /// Zeile „Fehlstunden“ antippen → „Abwesenheiten“; null = nur Text.
  final VoidCallback? onOpenAbsences;
  final void Function(CourseItem item)? onOpen;

  /// Nur für Tests; sonst DateTime.now().
  final DateTime? now;

  @override
  State<GradesView> createState() => GradesViewState();
}

class GradesViewState extends State<GradesView> {
  static const _halfId = 'grades-first-half';

  bool _firstHalf = false;
  bool _hasFirstHalf = false;
  final _failed = <String>{};
  int _done = 0;

  /// Seiten, die dieser Durchgang laden muss (für „5 von 14“).
  int _total = 0;
  bool _loading = false;

  /// Nummer des laufenden Durchgangs; ein älterer (Halbjahr gewechselt,
  /// neu geladen) schreibt nichts mehr in die Anzeige.
  int _run = 0;

  String get _key =>
      GradesCache.key(widget.source.account, firstHalf: _firstHalf);

  @override
  void initState() {
    super.initState();
    _firstHalf =
        PageStorage.maybeOf(context)?.readState(context, identifier: _halfId)
            as bool? ??
        false;
    _hasFirstHalf =
        _firstHalf ||
        GradesCache.instance
            .pagesFor(GradesCache.key(widget.source.account, firstHalf: false))
            .values
            .any((d) => d.semester1URL != null);
    _load();
  }

  @override
  void didUpdateWidget(GradesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Kursliste kam nach (erstes Laden) oder änderte sich: fehlende holen.
    if (oldWidget.source.courses.length != widget.source.courses.length) {
      _load();
    }
  }

  /// Neu laden (Ziehen zum Aktualisieren): Zwischenspeicher dieses
  /// Halbjahrs verwerfen.
  Future<void> reload() {
    GradesCache.instance.drop(_key);
    return _load();
  }

  Future<void> _load() async {
    final run = ++_run;
    final key = _key;
    final firstHalf = _firstHalf;
    final pages = GradesCache.instance.pagesFor(key);
    final todo = [
      for (final c in widget.source.courses)
        if (!pages.containsKey(c.id)) c,
    ];
    setState(() {
      _failed.clear();
      _done = 0;
      _total = todo.length;
      _loading = todo.isNotEmpty;
    });
    for (final c in todo) {
      try {
        final d = await widget.source.load(c, firstHalf: firstHalf);
        pages[c.id] = d;
        if (!firstHalf && d.semester1URL != null) _hasFirstHalf = true;
      } catch (e, st) {
        ErrorLog.instance.record('meinunterricht.php/noten', e, st);
        if (mounted && run == _run) _failed.add(c.id);
      }
      if (!mounted || run != _run) return;
      setState(() => _done++);
    }
    if (mounted && run == _run) setState(() => _loading = false);
    if (!firstHalf && todo.isNotEmpty) {
      widget.source.onCurrentLoaded?.call(Map.of(pages));
    }
  }

  void _half(bool first) {
    if (first == _firstHalf) return;
    _firstHalf = first;
    PageStorage.maybeOf(
      context,
    )?.writeState(context, first, identifier: _halfId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final courses = widget.source.courses;
    final o = gradesOverview(
      courses,
      GradesCache.instance.pagesFor(_key),
      _failed,
    );
    final hasFirst = _hasFirstHalf || o.hasFirstHalf;
    final out = <Widget>[];

    if (hasFirst) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: Sp.l),
          child: PillSegments(
            labels: [t.semester1, t.semester2],
            selected: _firstHalf ? 0 : 1,
            onChanged: (i) => _half(i == 0),
            bg: k.p.inset,
            ink: k.p.ink,
          ),
        ),
      );
    } else {
      final first = currentIsFirstHalf(widget.now ?? DateTime.now());
      out.add(_Section(title: first ? t.semester1 : t.semester2));
    }

    final pages = GradesCache.instance.pagesFor(_key);
    final absent = absenceTotals([for (final c in courses) ?pages[c.id]]);
    if (absent != null) {
      final line = Text(
        absent.excused + absent.missing == 0
            ? t.absenceNone
            : t.absenceTotals(absent.excused, absent.missing),
        style: k.meta,
      );
      final open = widget.onOpenAbsences;
      out.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.s, Sp.xs, 0),
          child: open == null || absent.excused + absent.missing == 0
              ? line
              : InkWell(
                  onTap: open,
                  child: Row(
                    children: [
                      Expanded(child: line),
                      Text(t.absenceOpenLink, style: k.link),
                      Icon(
                        Icons.chevron_right,
                        size: Sz.icon,
                        color: k.p.onNavSelected,
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    // Arbeiten nur im laufenden Halbjahr; die des 1. sind vorbei.
    final now = widget.now ?? DateTime.now();
    final exams = _firstHalf
        ? const <ScanExam>[]
        : upcomingExams(courses, pages, now);
    if (exams.isNotEmpty) {
      out
        ..add(_Section(title: t.gradesExamsTitle))
        ..add(_ExamCard(exams: exams));
    }

    if (_loading) {
      out.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.m, Sp.xs, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.gradesLoading(_done, _total), style: k.meta),
              const SizedBox(height: Sp.s),
              LinearProgressIndicator(
                value: _total == 0 ? null : _done / _total,
                color: k.p.ink,
                backgroundColor: k.p.inset,
                borderRadius: BorderRadius.circular(Rad.pill),
              ),
            ],
          ),
        ),
      );
    }

    if (exams.isNotEmpty && o.withMarks.isNotEmpty) {
      out.add(_Section(title: t.gradesTab));
    }
    for (final s in o.withMarks) {
      out.add(_SubjectCard(item: s, onTap: widget.onOpen));
    }

    if (!_loading && courses.isNotEmpty && o.withMarks.isEmpty) {
      out.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.m, Sp.xs, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.gradesNone, style: k.body),
              const SizedBox(height: Sp.xs),
              Text(t.gradesNoneHint, style: k.meta),
            ],
          ),
        ),
      );
    } else if (courses.isEmpty) {
      out.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.m, Sp.xs, 0),
          child: Text(t.loading, style: k.meta),
        ),
      );
    }

    if (o.failed.isNotEmpty && !_loading) {
      out.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.m, Sp.xs, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(t.gradesFailed(o.failed.length), style: k.meta),
              ),
              TextButton(
                onPressed: _load,
                child: Text(t.retry, style: k.link),
              ),
            ],
          ),
        ),
      );
    }

    // Fächer ohne Note nur, wenn es überhaupt Noten gibt – sonst sagt der
    // Hinweis oben schon alles und die Liste wäre die ganze Fächerliste.
    if (o.withMarks.isNotEmpty && o.without.isNotEmpty) {
      out
        ..add(_Section(title: t.gradesWithout))
        ..add(
          Padding(
            padding: const EdgeInsets.only(left: Sp.xs),
            child: Text(
              o.without.map((c) => c.title).toSet().join(', '),
              style: k.meta,
            ),
          ),
        );
    }
    if (o.withMarks.isNotEmpty) {
      out.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.l, Sp.xs, 0),
          child: Text(t.gradesNoAverage, style: k.meta),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: out,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: Sp.xs, bottom: Sp.xs, top: Sp.xl),
      child: Text(title, style: k.section),
    );
  }
}

/// Karte je Fach: Kopf in Fachfarbe mit Anzahl, darunter jede Note.
/// Antippen öffnet die Kursseite (Leistungskontrollen, Kommentare).
class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.item, this.onTap});

  final SubjectMarks item;
  final void Function(CourseItem)? onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final c = item.course;
    final tone = c.colorSlot == null ? null : k.subjectAt(c.colorSlot!);
    final tint = tone?.bg ?? k.p.inset;
    final ink = tone?.ink ?? k.p.ink;
    return Container(
      margin: const EdgeInsets.only(top: Sp.m),
      decoration: BoxDecoration(
        color: k.p.card,
        borderRadius: BorderRadius.circular(Rad.box),
        boxShadow: k.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap == null ? null : () => onTap!(c),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Sp.l,
                  vertical: Sp.m,
                ),
                color: tint,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: k.planSubject(ink),
                      ),
                    ),
                    const SizedBox(width: Sp.s),
                    Text(
                      t.marksCount(item.marks.length),
                      style: k.planMeta(ink),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.l, Sp.s, Sp.l, Sp.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final m in item.marks)
                      ValueRow(
                        name: m.name,
                        note: [
                          m.date,
                          ?m.comment,
                        ].where((s) => s.trim().isNotEmpty).join(' · '),
                        value: m.mark,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Anstehende Arbeiten aller Fächer in einer Karte: Fach, Art und Stunden,
/// rechts das Datum. Ursache: Auf der Kursseite steht jede nur im eigenen
/// Fach – für die Wochenplanung zählt die Reihenfolge über alle Fächer.
class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exams});

  final List<ScanExam> exams;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.l, Sp.s, Sp.l, Sp.s),
      decoration: BoxDecoration(
        color: k.p.card,
        borderRadius: BorderRadius.circular(Rad.box),
        boxShadow: k.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in exams)
            ValueRow(
              name: e.subject,
              note: e.text,
              value: formatDate(t, t.dateShort, e.day),
            ),
        ],
      ),
    );
  }
}
