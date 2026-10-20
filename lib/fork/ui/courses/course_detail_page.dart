import 'package:flutter/material.dart';
import 'package:liblanis/liblanis.dart';

import '../../courses_scan.dart' show examsOfPage;
import '../../exams.dart';
import '../../l10n/l10n.dart';
import '../kit.dart';
import '../segments.dart';
import '../today/today_model.dart' show WeekItem;
import '../today/today_page.dart' show dayDiff, relativeDay;
import 'course_detail_model.dart';

/// Was die Kursseite außer der Kursmappe braucht – aus „Heute“/„Kalender“
/// schon geladen (LiveSnapshot), damit die Seite nichts doppelt abfragt.
class CourseContext {
  const CourseContext({
    required this.title,
    required this.fullName,
    required this.teachers,
    this.colorSlot = 0,
    this.nextLesson,
    this.calendarExams = const [],
    this.openHomework,
    this.lastMessages = const {},
    this.extraOffer = false,
  });

  /// „Englisch“ und „Englisch 07 b“.
  final String title;
  final String fullName;

  /// Kürzel → ausgeschriebener Name, in der Reihenfolge des Portals.
  final List<(String kuerzel, String name)> teachers;

  /// Fachfarbe wie im Wochenraster (subjectColorSlots).
  final int colorSlot;
  final ({DateTime day, String slot, String start, String end, String? room})?
  nextLesson;

  /// Arbeiten aus dem Schulkalender (weekItemsFromCalendar); welche zu
  /// diesem Fach gehören, entscheidet nextExamOfSubject (exams.dart).
  final List<WeekItem> calendarExams;

  /// Einträge (CurrentEntry.entryID) mit offener Hausaufgabe nach
  /// homeworkLists (homework_ledger.dart) – dieselbe Einteilung wie die
  /// Hausaufgabenliste, das Zeichen am Reiter und Heute. Null (Tests,
  /// Vorschau): nur die Marke des Portals.
  ///
  /// Ursache (Prüfung 20.10.26): Die Kursseite las nur die Marke des
  /// Portals. In der App Abgehaktes (bei Elternkonten immer so) blieb hier
  /// offen, und ältere Einträge zählten als offen, obwohl die Liste nur den
  /// neuesten je Kurs führt.
  final Set<String>? openHomework;

  bool homeworkOpen(CurrentEntry e) {
    final h = e.homework;
    if (h == null) return false;
    return openHomework?.contains(e.entryID) ?? !h.homeWorkDone;
  }

  /// Kürzel → neueste Unterhaltung mit dieser Lehrkraft (Datum wie im
  /// Portal, Öffnen).
  final Map<String, (String date, VoidCallback open)> lastMessages;
  final bool extraOffer;
}

/// Kursseite der neuen Oberfläche (Entwurf 3, abgenommen 17.10.26).
///
/// Ursache: Die übernommene Lanis-Seite (CourseOverviewAnsicht) war für
/// Eltern unübersichtlich – drei Reiter, alle Stunden offen untereinander.
/// Jetzt: getrennte Bereiche mit eigenem Kopf, Verlauf zugeklappt und nach
/// Themen gegliedert (groupHistory), dazu „Als Nächstes“ aus Plan und
/// Kalender. Grenze: Hausaufgaben abhaken und Abgaben hochladen bleiben
/// Schülerkonten vorbehalten und laufen über die bisherigen Seiten
/// ([onOpenUpload]); Elternkonten sehen nur den Stand.
class CourseDetailPage extends StatefulWidget {
  const CourseDetailPage({
    super.key,
    required this.course,
    required this.load,
    this.onWrite,
    this.onOpenFile,
    this.onOpenUpload,
    this.onOpenAbsences,
  });

  /// Seite „Abwesenheiten“ für dieses Fach (Entschuldigen); null = ohne.
  final VoidCallback? onOpenAbsences;

  final CourseContext course;

  /// Lädt die Kursmappe; [firstHalf] = 1. Halbjahr (Portal „&halb=1“).
  final Future<DetailedLesson> Function({required bool firstHalf}) load;
  final void Function(String kuerzel)? onWrite;
  final void Function(FileInfo file)? onOpenFile;
  final void Function(LessonUpload upload)? onOpenUpload;

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  DetailedLesson? _data;
  bool _failed = false;
  bool _firstHalf = false;

  /// Halbjahr-Umschalter nur, wenn das Portal ein 1. Halbjahr anbietet
  /// (semester1URL beim Laden des laufenden Halbjahrs).
  bool _hasFirstHalf = false;
  final _open = <int>{};

  /// Nummer der jüngsten Anfrage. Ursache (Prüfbefund 17.10.26): Wechselte
  /// man schnell zwischen den Halbjahren, konnte die langsamere, ältere
  /// Antwort zuletzt eintreffen und unter dem falschen Halbjahr stehen.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _fetch(clear: true);
  }

  /// [clear]: Inhalt sofort leeren (Halbjahr gewechselt). Beim Ziehen zum
  /// Aktualisieren bleibt der alte Stand stehen, bis der neue da ist – und
  /// auch, wenn das Laden scheitert.
  Future<void> _fetch({bool clear = false}) async {
    final id = ++_request;
    final firstHalf = _firstHalf;
    setState(() {
      _failed = false;
      if (clear) _data = null;
    });
    try {
      final d = await widget.load(firstHalf: firstHalf);
      if (!mounted || id != _request) return;
      setState(() {
        _data = d;
        if (clear) _open.clear();
        if (!firstHalf) _hasFirstHalf = d.semester1URL != null;
      });
    } catch (_) {
      if (!mounted || id != _request) return;
      setState(() => _failed = _data == null);
    }
  }

  void _half(bool first) {
    if (first == _firstHalf) return;
    _firstHalf = first;
    _fetch(clear: true);
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final c = widget.course;
    final f = k.subjectAt(c.colorSlot);
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final d = _data;

    final children = <Widget>[
      Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back, color: k.p.ink),
            tooltip: t.back,
          ),
        ],
      ),
      const SizedBox(height: Sp.xs),
      _Header(course: c, tone: f),
      if (_hasFirstHalf) ...[
        const SizedBox(height: Sp.m),
        PillSegments(
          labels: [t.semester1, t.semester2],
          selected: _firstHalf ? 0 : 1,
          onChanged: (i) => _half(i == 0),
          bg: f.bg,
          ink: f.ink,
        ),
      ],
    ];

    if (d == null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: Sp.xl),
          child: _failed
              ? Column(
                  children: [
                    Text(t.courseLoadFailed, style: k.meta),
                    TextButton(
                      onPressed: () => _fetch(clear: true),
                      child: Text(t.retry, style: k.link),
                    ),
                  ],
                )
              : const Center(child: CircularProgressIndicator()),
        ),
      );
    } else {
      children.addAll(_blocks(context, k, t, d, f));
    }

    return Scaffold(
      backgroundColor: k.p.bg,
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            Sp.page,
            top + Sp.s,
            Sp.page,
            bottom + Sp.xl,
          ),
          children: children,
        ),
      ),
    );
  }

  List<Widget> _blocks(
    BuildContext context,
    Kit k,
    ForkL10n t,
    DetailedLesson d,
    FachTone f,
  ) {
    final c = widget.course;
    final now = DateTime.now();
    final out = <Widget>[];

    // ---- Als Nächstes (nur im laufenden Halbjahr) -----------------------
    if (!_firstHalf && !c.extraOffer) {
      final lines = <Widget>[];
      final n = c.nextLesson;
      if (n != null) {
        lines.add(
          _Line(
            icon: Icons.schedule,
            color: k.kid(0).accent,
            title: '${relativeDay(t, n.day, now)} · ${n.slot}',
            meta: [
              if (n.start.isNotEmpty) '${n.start}–${n.end}',
              if (n.room != null) n.room!,
            ].join(' · '),
          ),
        );
      }
      // Nächste Arbeit nach der gemeinsamen Regel (exams.dart): Kursmappe
      // dieser Seite zuerst, sonst der Schulkalender.
      final e = nextExamOfSubject(
        subject: c.title,
        folder: examsOfPage('', c.title, d, now),
        calendar: c.calendarExams,
        now: now,
      );
      if (e != null) {
        lines.add(
          _Line(
            icon: Icons.edit_note,
            color: k.p.cancel.ink,
            title: e.title,
            titleColor: k.p.cancel.ink,
            meta: [
              formatDate(t, t.dateShort, e.day),
              t.inDays(dayDiff(now, e.day)),
              ?e.detail,
              e.fromCalendar ? t.fromSchoolCalendar : t.fromCourseFolder,
            ].join(' · '),
          ),
        );
      }
      for (final u in openUploads(d.history)) {
        lines.add(
          _Line(
            icon: Icons.upload_file,
            color: k.p.change.ink,
            title: t.uploadTitle(u.name),
            meta: [
              if (u.date != null && u.date!.isNotEmpty) t.uploadUntil(u.date!),
              u.uploaded == null || u.uploaded!.isEmpty
                  ? t.uploadNotYet
                  : t.uploadDone(u.uploaded!),
            ].join(' · '),
            metaColor: k.p.change.ink,
            onTap: widget.onOpenUpload == null
                ? null
                : () => widget.onOpenUpload!(u),
          ),
        );
      }
      out.add(
        _Block(
          icon: Icons.upcoming_outlined,
          tint: k.kid(0).tint,
          ink: k.kid(0).onTint,
          title: t.blockNext,
          children: lines.isEmpty
              ? [Text(t.nothingNext, style: k.meta)]
              : _divided(k, lines),
        ),
      );
    }

    // ---- Lehrkraft ------------------------------------------------------
    if (c.teachers.isNotEmpty) {
      final shown = c.teachers.take(3).toList();
      final teach = k.subjectAt(1);
      out.add(
        _Block(
          icon: Icons.person_outline,
          tint: teach.bg,
          ink: teach.ink,
          title: c.teachers.length == 1 ? t.blockTeacher : t.blockTeachers,
          children: [
            for (final (i, (kz, name)) in shown.indexed) ...[
              if (i > 0) const SizedBox(height: Sp.m),
              _TeacherRow(
                name: name,
                tone: teach,
                last: c.lastMessages[kz],
                onWrite: widget.onWrite == null
                    ? null
                    : () => widget.onWrite!(kz),
              ),
            ],
            if (c.teachers.length > shown.length) ...[
              const SizedBox(height: Sp.s),
              Text(
                t.moreTeachers(c.teachers.length - shown.length),
                style: k.planMeta(k.p.muted),
              ),
            ],
          ],
        ),
      );
    }

    // ---- Anwesenheit ----------------------------------------------------
    final counts = attendanceCounts(d.attendances);
    final absent = absentEntries(d.history);
    if (counts != null || absent.isNotEmpty) {
      final pres = k.subjectAt(3);
      out.add(
        _Block(
          icon: Icons.fact_check_outlined,
          tint: pres.bg,
          ink: pres.ink,
          title: t.blockAttendance,
          trailing: counts != null && counts.missing > 0
              ? t.missingShort(counts.missing)
              : null,
          children: [
            if (counts != null) ...[
              _AttendanceBar(counts: counts),
              const SizedBox(height: Sp.s),
              Text(
                t.attendanceLine(
                  counts.present,
                  counts.excused,
                  counts.missing,
                ),
                style: k.planMeta(k.p.ink),
              ),
            ],
            if (absent.isNotEmpty)
              Text(
                t.absentOn(
                  [
                    for (final e in absent.take(6))
                      [
                        if (e.topicDate != null)
                          formatDate(t, t.dateShort, e.topicDate!),
                        if (e.presence != null) e.presence!.trim(),
                      ].join(' '),
                  ].join(', '),
                ),
                style: k.planMeta(k.p.cancel.ink),
              ),
            if (absent.isNotEmpty && widget.onOpenAbsences != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onOpenAbsences,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  icon: Icon(
                    Icons.chevron_right,
                    size: Sz.icon,
                    color: k.p.onNavSelected,
                  ),
                  label: Text(t.absenceOpenLink, style: k.link),
                ),
              ),
          ],
        ),
      );
    }

    // ---- Verlauf --------------------------------------------------------
    final groups = groupHistory(d.history, noTopic: t.noTopic);
    out.add(
      _Block(
        icon: Icons.timeline,
        tint: f.bg,
        ink: f.ink,
        title: t.blockHistory,
        trailing: d.history.isEmpty
            ? null
            : '${t.lessonsCount(d.history.length)} · '
                  '${t.topicsCount(groups.length)}',
        children: d.history.isEmpty
            ? [_Empty(text: t.historyEmptyText, title: t.historyEmptyTitle)]
            : [
                for (final (i, g) in groups.indexed)
                  _TopicGroupView(
                    group: g,
                    isOpen: widget.course.homeworkOpen,
                    tone: f,
                    first: i == 0,
                    open: _open.contains(i),
                    onToggle: () => setState(
                      () => _open.contains(i) ? _open.remove(i) : _open.add(i),
                    ),
                    onOpenFile: widget.onOpenFile,
                  ),
              ],
      ),
    );

    // ---- Material -------------------------------------------------------
    final files = allFiles(d.history);
    if (files.isNotEmpty) {
      final mat = k.subjectAt(5);
      out.add(
        _Block(
          icon: Icons.folder_open_outlined,
          tint: mat.bg,
          ink: mat.ink,
          title: t.blockMaterial,
          trailing: t.filesCount(files.length),
          children: [
            for (final (file, day) in files)
              InkWell(
                onTap: widget.onOpenFile == null
                    ? null
                    : () => widget.onOpenFile!(file),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Sp.xs + Sp.xxs),
                  child: Row(
                    children: [
                      Icon(
                        fileIcon(file.name),
                        size: Sz.navIcon,
                        color: mat.ink,
                      ),
                      const SizedBox(width: Sp.m),
                      Expanded(
                        child: Text(
                          file.name ?? '…',
                          style: k.body,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (day != null)
                        Text(
                          formatDate(t, t.dateShort, day),
                          style: k.planMeta(k.p.muted),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // ---- Leistungen / Leistungskontrollen -------------------------------
    final marks = k.subjectAt(4);
    if (d.marks.isNotEmpty) {
      out.add(
        _Block(
          icon: Icons.grading_outlined,
          tint: marks.bg,
          ink: marks.ink,
          title: t.blockMarks,
          children: [
            for (final m in d.marks)
              ValueRow(
                name: m.name,
                note: [
                  m.date,
                  ?m.comment,
                ].where((s) => s.isNotEmpty).join(' · '),
                value: m.mark,
              ),
          ],
        ),
      );
    }
    if (examSections(d.exams).isNotEmpty) {
      out.add(
        _Block(
          icon: Icons.event_note_outlined,
          tint: marks.bg,
          ink: marks.ink,
          title: t.blockExams,
          children: [
            for (final (i, s) in examSections(d.exams).indexed) ...[
              if (s.title.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    top: i == 0 ? 0 : Sp.m,
                    bottom: Sp.xs,
                  ),
                  child: Text(upperFor(t, s.title), style: k.dateCaps),
                ),
              for (final l in s.lines)
                _ExamRow(
                  // Ohne Wochentag, mit kurzem Jahr, wenn es nicht das laufende
                  // ist („2.11.“, „8.3.27“) – passt in die schmale Spalte.
                  date: l.date == null
                      ? null
                      : formatDate(t, t.dateDayMonth, l.date!) +
                            (l.date!.year == now.year
                                ? ''
                                : (l.date!.year % 100).toString().padLeft(
                                    2,
                                    '0',
                                  )),
                  text: l.text,
                  past: l.date != null && dayDiff(now, l.date!) < 0,
                ),
            ],
          ],
        ),
      );
    }
    return out;
  }

  List<Widget> _divided(Kit k, List<Widget> lines) => [
    for (final (i, l) in lines.indexed) ...[
      if (i > 0) Divider(color: k.p.line, height: Sp.xl),
      l,
    ],
  ];
}

/// Symbol nach Dateiendung.
IconData fileIcon(String? name) {
  final ext = (name ?? '').split('.').last.toLowerCase();
  return switch (ext) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'jpg' ||
    'jpeg' ||
    'png' ||
    'gif' ||
    'heic' ||
    'webp' => Icons.image_outlined,
    'mp3' || 'm4a' || 'wav' => Icons.audio_file_outlined,
    'mp4' || 'mov' => Icons.video_file_outlined,
    _ => Icons.description_outlined,
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.course, required this.tone});

  final CourseContext course;
  final FachTone tone;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final c = course;
    final sub = [c.fullName, if (c.extraOffer) t.withoutGrades].join(' · ');
    return Container(
      padding: const EdgeInsets.all(Sp.lx),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(Rad.card),
      ),
      child: Row(
        children: [
          Container(
            width: Sz.avatar + Sp.xs,
            height: Sz.avatar + Sp.xs,
            decoration: BoxDecoration(
              color: k.p.card,
              borderRadius: BorderRadius.circular(Rad.row + Sp.xs),
            ),
            child: Icon(subjectIconFor(c.title), color: tone.ink),
          ),
          const SizedBox(width: Sp.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    c.title,
                    maxLines: 1,
                    style: k.pageTitle.copyWith(color: tone.ink),
                  ),
                ),
                Text(sub, style: k.planMeta(tone.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bereich als eigene Karte mit Schatten und farbigem Kopf (Entwurf 3).
class _Block extends StatelessWidget {
  const _Block({
    required this.icon,
    required this.tint,
    required this.ink,
    required this.title,
    required this.children,
    this.trailing,
  });

  final IconData icon;
  final Color tint;
  final Color ink;
  final String title;
  final String? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Container(
      margin: const EdgeInsets.only(top: Sp.l),
      decoration: BoxDecoration(
        color: k.p.card,
        borderRadius: BorderRadius.circular(Rad.box),
        boxShadow: k.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
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
                Icon(icon, size: Sz.navIcon, color: ink),
                const SizedBox(width: Sp.s),
                Expanded(child: Text(title, style: k.planSubject(ink))),
                // Einzeilig, notfalls verkleinert („5 Stunden · 3 Themen“
                // brach sonst unter den Titel, Bildschirmfoto 17.10.26).
                if (trailing != null)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        trailing!,
                        maxLines: 1,
                        style: k.planMeta(ink),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.l, Sp.m, Sp.l, Sp.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.color,
    required this.title,
    required this.meta,
    this.titleColor,
    this.metaColor,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String meta;
  final Color? titleColor;
  final Color? metaColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: Sz.navIcon, color: color),
          const SizedBox(width: Sp.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: k.planSubject(titleColor ?? k.p.ink)),
                if (meta.isNotEmpty)
                  Text(meta, style: k.planMeta(metaColor ?? k.p.muted)),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, size: Sz.icon, color: k.p.muted),
        ],
      ),
    );
  }
}

class _TeacherRow extends StatelessWidget {
  const _TeacherRow({
    required this.name,
    required this.tone,
    this.last,
    this.onWrite,
  });

  final String name;
  final FachTone tone;
  final (String, VoidCallback)? last;
  final VoidCallback? onWrite;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.characters.first.toUpperCase())
        .take(2)
        .join();
    return Row(
      children: [
        Container(
          width: Sz.avatar - Sp.xs,
          height: Sz.avatar - Sp.xs,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
          child: Text(initials, style: k.planTeacher(tone.ink)),
        ),
        const SizedBox(width: Sp.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: k.planSubject(k.p.ink)),
              if (last != null)
                InkWell(
                  onTap: last!.$2,
                  child: Text(t.lastMessageOn(last!.$1), style: k.link),
                ),
            ],
          ),
        ),
        if (onWrite != null)
          Material(
            color: k.p.strong,
            borderRadius: BorderRadius.circular(Rad.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.pill),
              onTap: onWrite,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Sp.m,
                  vertical: Sp.s,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mail_outline,
                      size: Sz.icon,
                      color: k.p.onStrong,
                    ),
                    const SizedBox(width: Sp.xs),
                    Text(t.write, style: k.button(k.p.onStrong)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AttendanceBar extends StatelessWidget {
  const _AttendanceBar({required this.counts});

  final AttendanceCounts counts;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final parts = [
      (counts.present, k.kid(0).accent),
      (counts.excused, k.p.change.dot),
      (counts.missing, k.p.cancel.dot),
    ].where((p) => p.$1 > 0).toList();
    if (parts.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(Rad.bar),
      child: SizedBox(
        height: Sz.dayBar,
        child: Row(
          children: [
            for (final (i, (n, color)) in parts.indexed) ...[
              if (i > 0) const SizedBox(width: Sp.xxs),
              // Container statt ColoredBox: ohne Kind wäre ColoredBox 0 breit.
              Expanded(
                flex: n,
                child: Container(color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopicGroupView extends StatelessWidget {
  const _TopicGroupView({
    required this.group,
    required this.isOpen,
    required this.tone,
    required this.first,
    required this.open,
    required this.onToggle,
    this.onOpenFile,
  });

  final TopicGroup group;
  final bool Function(CurrentEntry e) isOpen;
  final FachTone tone;
  final bool first;
  final bool open;
  final VoidCallback onToggle;
  final void Function(FileInfo)? onOpenFile;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final from = group.from;
    final to = group.to;
    final openCount = group.entries.where(isOpen).length;
    // Zeitraum kurz ohne Wochentag („13.10.–15.10.“), sonst brach die Zeile.
    final range = from == null
        ? null
        : (to == null || dayDiff(from, to) == 0
              ? formatDate(t, t.dateShort, from)
              : '${formatDate(t, t.dateDayMonth, from)}–'
                    '${formatDate(t, t.dateDayMonth, to)}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!first) Divider(color: k.p.line, height: Sp.l),
        InkWell(
          onTap: onToggle,
          child: Row(
            children: [
              Container(
                width: Sp.xs,
                height: Sz.buttonSmall - Sp.s,
                decoration: BoxDecoration(
                  color: tone.ink,
                  borderRadius: BorderRadius.circular(Rad.bar),
                ),
              ),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.title, style: k.planSubject(k.p.ink)),
                    Text(
                      [
                        ?range,
                        t.lessonsCount(group.entries.length),
                      ].join(' · '),
                      style: k.planMeta(k.p.muted),
                    ),
                  ],
                ),
              ),
              if (openCount > 0) ...[
                _Chip(
                  icon: Icons.menu_book_outlined,
                  text: t.openCount(openCount),
                  tone: k.p.change,
                ),
                const SizedBox(width: Sp.xs),
              ],
              Icon(
                open ? Icons.expand_less : Icons.expand_more,
                size: Sz.navIcon,
                color: k.p.muted,
              ),
            ],
          ),
        ),
        if (open) ...[
          const SizedBox(height: Sp.m),
          for (final e in group.entries)
            _EntryCard(
              entry: e,
              homeworkOpen: isOpen(e),
              onOpenFile: onOpenFile,
            ),
        ],
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.homeworkOpen,
    this.onOpenFile,
  });

  final CurrentEntry entry;

  /// Offen nach CourseContext.homeworkOpen; sonst als erledigt gezeigt.
  final bool homeworkOpen;
  final void Function(FileInfo)? onOpenFile;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final e = entry;
    final when = [
      if (e.topicDate != null) formatDate(t, t.dateShort, e.topicDate!),
      if (e.schoolHours != null && e.schoolHours!.trim().isNotEmpty)
        e.schoolHours!.trim(),
    ].join(' · ');
    final title = topicRest(e.topicTitle);
    final hw = e.homework;
    final presence = (e.presence ?? '').trim();
    final absent = absentEntries([e]).isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.s, left: Sp.l),
      padding: const EdgeInsets.all(Sp.m),
      decoration: BoxDecoration(
        color: k.p.inset,
        borderRadius: BorderRadius.circular(Rad.row),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (when.isNotEmpty) Text(upperFor(t, when), style: k.dateCaps),
          if (title != null)
            Text(title, style: k.rowSubject(k.p.ink, strong: true)),
          if (e.description != null && e.description!.trim().isNotEmpty)
            Text(e.description!.trim(), style: k.planMeta(k.p.muted)),
          if (hw != null) ...[
            const SizedBox(height: Sp.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  homeworkOpen ? Icons.menu_book_outlined : Icons.check_circle,
                  size: Sz.icon,
                  color: homeworkOpen ? k.p.change.ink : k.p.faint,
                ),
                const SizedBox(width: Sp.s),
                Expanded(
                  child: Text(
                    hw.description.trim().isEmpty
                        ? t.homeworkEntered
                        : hw.description.trim(),
                    style: homeworkOpen
                        ? k.boxStrong(k.p.change)
                        : k.planMeta(k.p.faint),
                  ),
                ),
              ],
            ),
          ],
          if (e.files.isNotEmpty || absent) ...[
            const SizedBox(height: Sp.xs),
            Wrap(
              spacing: Sp.xs,
              runSpacing: Sp.xs,
              children: [
                for (final f in e.files)
                  _Chip(
                    icon: fileIcon(f.name),
                    text: f.name ?? '…',
                    onTap: onOpenFile == null ? null : () => onOpenFile!(f),
                  ),
                if (absent)
                  _Chip(
                    icon: Icons.event_busy,
                    text: presence,
                    tone: k.p.cancel,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, this.tone, this.onTap});

  final IconData icon;
  final String text;
  final SignalTone? tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final ink = tone?.ink ?? k.p.muted;
    return Material(
      color: tone?.bg ?? k.p.card,
      borderRadius: BorderRadius.circular(Rad.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.s,
            vertical: Sp.xxs + 1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: Sz.icon - Sp.xs, color: ink),
              const SizedBox(width: Sp.xs),
              Flexible(
                child: Text(
                  text,
                  style: k.planMeta(ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zeile „Name / Notiz … Wert“ (Leistungen, Leistungskontrollen); auch in
/// der Notenübersicht (grades_view.dart), damit beide gleich aussehen.
class ValueRow extends StatelessWidget {
  const ValueRow({
    super.key,
    required this.name,
    required this.note,
    required this.value,
  });

  final String name;
  final String note;
  final String value;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: k.body),
                if (note.isNotEmpty) Text(note, style: k.planMeta(k.p.muted)),
              ],
            ),
          ),
          const SizedBox(width: Sp.m),
          // Begrenzt, damit ein langer Wert den Namen nicht auf eine Spalte
          // zusammendrückt (Bildschirmfoto 17.10.26, Leistungskontrollen).
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sz.tileWidth),
            child: Text(
              value,
              style: k.planSubject(k.p.ink),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.m),
      child: Column(
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: Sz.avatar - Sp.xs,
            color: k.p.faint,
          ),
          const SizedBox(height: Sp.s),
          Text(title, style: k.planSubject(k.p.ink)),
          const SizedBox(height: Sp.xs),
          Text(text, style: k.meta, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Eine Leistungskontrolle: Datum vorn, Text daneben (umbrechend).
class _ExamRow extends StatelessWidget {
  const _ExamRow({required this.text, this.date, this.past = false});

  final String? date;
  final String text;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final ink = past ? k.p.faint : k.p.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (date != null) ...[
            SizedBox(
              width: Sz.slotColumn + Sp.xl,
              child: Text(date!, style: k.planSubject(ink)),
            ),
            const SizedBox(width: Sp.s),
          ],
          Expanded(
            child: Text(text, style: k.body.copyWith(color: ink)),
          ),
        ],
      ),
    );
  }
}
