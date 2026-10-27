import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:liblanis/liblanis.dart';

import '../../absences.dart';
import '../../data/message_templates.dart';
import '../../error_log.dart';
import '../../l10n/l10n.dart';
import '../../lessons_parent.dart';
import '../kid_chips.dart';
import '../kit.dart';
import '../live/live_data.dart';
import '../messages/compose_model.dart';
import '../messages/compose_page.dart';
import '../nav.dart';
import 'courses_model.dart';
import 'grades_model.dart';

/// „Abwesenheiten“ mit echten Daten: lädt die Kursseiten des laufenden
/// Halbjahrs (GradesCache, geteilt mit „Arbeiten & Noten“) und zeigt jede
/// Fehlstunde mit Tag, Fach und Stunde.
///
/// „Entschuldigen“ öffnet „Neue Nachricht“ an die Lehrkraft des Fachs mit
/// fertigem Text (absenceExcuse) – nur im Elternkonto. Ursache: Entschuldigen
/// müssen Eltern; ein Schülerkonto zeigt die Stunden nur an. Grenze: Ob die
/// Schule Entschuldigungen per Nachricht annimmt, regelt sie selbst; der
/// Vermerk „gesendet“ steht nur auf diesem Gerät.
class LiveAbsencesPage extends ConsumerStatefulWidget {
  const LiveAbsencesPage({super.key, required this.courses, this.focus});

  final List<CourseItem> courses;

  /// Nur dieses Fach zeigen (aus „Unterricht“ bei einem Fach mit
  /// Fehlstunden); „Alle Fächer“ hebt das auf.
  final String? focus;

  @override
  ConsumerState<LiveAbsencesPage> createState() => _LiveAbsencesPageState();
}

class _LiveAbsencesPageState extends ConsumerState<LiveAbsencesPage> {
  int _done = 0;
  int _total = 0;
  bool _loading = true;
  int _failed = 0;
  String? _focus;
  Map<String, DateTime> _sent = const {};
  late final LessonsStudentParser _parser;

  @override
  void initState() {
    super.initState();
    _focus = widget.focus;
    _parser = ref.read(lessonsStudentParserProvider);
    _sent = decodeSent(
      ref.read(accountSpecificSettingsProvider)?.getString(absenceSentSetting),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final s = LiveData.of(context);
    if (s == null) return;
    setState(() {
      _loading = true;
      _failed = 0;
    });
    await loadCoursePages(
      courses: widget.courses,
      pages: GradesCache.instance.pagesFor(
        GradesCache.key(s.accountKey, firstHalf: false),
      ),
      load: (c) => _parser.getDetailedCourseView(
        courseUrl(c.id, firstHalf: false),
        force: true,
      ),
      alive: () => mounted,
      progress: (d, t) {
        if (mounted) {
          setState(() {
            _done = d;
            _total = t;
          });
        }
      },
      failed: (c, e, st) {
        ErrorLog.instance.record('meinunterricht.php/abwesend', e, st);
        _failed++;
      },
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _excuse(LiveSnapshot s, AbsenceItem a) async {
    final when = [
      // Deutsch wie der Text (message_templates.dart), unabhängig von der
      // App-Sprache: „Montag, 21.9.2026“.
      if (a.day != null) DateFormat('EEEE, d.M.yyyy', 'de').format(a.day!),
      if (a.hours != null && a.hours!.isNotEmpty) '(${a.hours} Stunde)',
    ].join(' ');
    final who = excuseChildAndSubject(a, s.kids, s.firstName);
    final m = absenceExcuse(
      child: who.child.isEmpty ? 'Unser Kind' : who.child,
      subject: who.subject,
      when: when,
    );
    final settings = ref.read(accountSpecificSettingsProvider);
    final backend = portalBackend(ref);
    final sent = await pushFullScreen<bool>(
      context,
      (_) => ComposePage(
        candidates: candidatesFrom(s.lessons.content ?? const []),
        backend: backend,
        initialKuerzel: a.teacherCodes.where((k) => k.isNotEmpty).firstOrNull,
        initialSubject: m.subject,
        initialText: m.text,
      ),
    );
    if (sent != true || !mounted) return;
    final next = {..._sent, a.key: DateTime.now()};
    setState(() => _sent = next);
    settings?.setString(absenceSentSetting, encodeSent(next));
  }

  @override
  Widget build(BuildContext context) {
    final s = LiveData.of(context);
    if (s == null) return const Scaffold(body: SizedBox.shrink());
    final pages = GradesCache.instance.pagesFor(
      GradesCache.key(s.accountKey, firstHalf: false),
    );
    final all = absencesFrom(widget.courses, pages);
    final parent = s.session.account.accountType == AccountType.parent;
    return AbsencesView(
      items: all,
      firstName: s.firstName,
      focus: _focus,
      onClearFocus: () => setState(() => _focus = null),
      loading: _loading,
      done: _done,
      total: _total,
      failed: _failed,
      sent: _sent,
      onRetry: _load,
      onExcuse: parent ? (a) => _excuse(s, a) : null,
    );
  }
}

/// Kind und Fach für den Text der Entschuldigung zu [a].
///
/// Ursache (Prüfung 27.10.26): Der Text nannte immer LiveSnapshot.firstName,
/// also das ERSTE Kind – die Entschuldigung für das Geschwisterkind trug den
/// falschen Namen, das Fach dazu den Vorsatz „Lena: …“. Jetzt das Kind aus
/// der Kurs-ID (`&p=`, kidOfCourse) und das Fach ohne Vorsatz
/// (courseNameWithoutKid). Grenze: Ohne passendes Kind (Schülerkonto, ein
/// Kind, Kinder nicht geladen) bleibt [fallbackName].
({String child, String subject}) excuseChildAndSubject(
  AbsenceItem a,
  List<ChildLessons> kids,
  String fallbackName,
) {
  final kid = kids.length > 1 ? kidOfCourse(a.course, kids) : null;
  return (
    child: kid == null ? fallbackName : shortFirstName(kid.firstName),
    subject: courseNameWithoutKid(a.subject, a.course, kids),
  );
}

/// Anzeige ohne Datenquelle (Tests).
class AbsencesView extends StatelessWidget {
  const AbsencesView({
    super.key,
    required this.items,
    this.firstName = '',
    this.focus,
    this.onClearFocus,
    this.loading = false,
    this.done = 0,
    this.total = 0,
    this.failed = 0,
    this.sent = const {},
    this.onRetry,
    this.onExcuse,
  });

  final List<AbsenceItem> items;
  final String firstName;
  final String? focus;
  final VoidCallback? onClearFocus;
  final bool loading;
  final int done;
  final int total;
  final int failed;
  final Map<String, DateTime> sent;
  final VoidCallback? onRetry;

  /// null = Schülerkonto (kein Entschuldigen).
  final void Function(AbsenceItem a)? onExcuse;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final shown = [
      for (final a in items)
        if (focus == null || a.course == focus) a,
    ];
    final open = [
      for (final a in shown)
        if (!a.excused) a,
    ];
    final excused = [
      for (final a in shown)
        if (a.excused) a,
    ];
    final focusName = focus == null
        ? null
        : items.where((a) => a.course == focus).firstOrNull?.subject;

    final children = <Widget>[
      if (firstName.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: Sp.xs),
          child: Text(firstName, style: k.meta),
        ),
      if (!loading || shown.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.xs, Sp.xs, 0),
          child: Text(
            shown.isEmpty
                ? t.absenceNone
                : t.absencesSummary(open.length, excused.length),
            style: k.body,
          ),
        ),
      if (focus != null && onClearFocus != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onClearFocus,
            icon: Icon(
              Icons.filter_alt_off_outlined,
              size: Sz.icon,
              color: k.p.onNavSelected,
            ),
            label: Text(t.absenceAllSubjects(focusName ?? ''), style: k.link),
          ),
        ),
      if (onExcuse == null && open.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: Sp.m),
          padding: const EdgeInsets.all(Sp.m),
          decoration: BoxDecoration(
            color: k.p.inset,
            borderRadius: BorderRadius.circular(Rad.row),
          ),
          child: Text(t.absenceStudentHint, style: k.meta),
        ),
      if (loading)
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.m, Sp.xs, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.gradesLoading(done, total), style: k.meta),
              const SizedBox(height: Sp.s),
              LinearProgressIndicator(
                value: total == 0 ? null : done / total,
                color: k.p.ink,
                backgroundColor: k.p.inset,
                borderRadius: BorderRadius.circular(Rad.pill),
              ),
            ],
          ),
        ),
      if (failed > 0 && !loading)
        Row(
          children: [
            Expanded(child: Text(t.gradesFailed(failed), style: k.meta)),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(t.retry, style: k.link),
              ),
          ],
        ),
      if (open.isNotEmpty) _Head(t.absenceOpenTitle),
      for (final a in open)
        _AbsenceCard(
          item: a,
          sent: sent[a.key],
          onExcuse: onExcuse == null ? null : () => onExcuse!(a),
        ),
      if (excused.isNotEmpty) _Head(t.absenceExcusedTitle),
      for (final a in excused) _AbsenceCard(item: a),
    ];
    return Scaffold(
      backgroundColor: k.p.bg,
      appBar: AppBar(
        backgroundColor: k.p.bg,
        surfaceTintColor: k.p.bg,
        // Pfeil schon in der Pillenzeile (BackInChips).
        automaticallyImplyLeading: !BackInChips.of(context),
        title: Text(t.absencesTitle, style: k.section),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Sp.page, Sp.s, Sp.page, bottom + Sp.xl),
        children: children,
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: Sp.xs, top: Sp.xl, bottom: Sp.s),
    child: Text(title, style: Kit.of(context).section),
  );
}

/// Eine Fehlstunde: Tag und Stunde links, Fach und Wortlaut des Portals,
/// bei offenen rechts „Entschuldigen“ bzw. der Vermerk „gesendet“.
class _AbsenceCard extends StatelessWidget {
  const _AbsenceCard({required this.item, this.sent, this.onExcuse});

  final AbsenceItem item;
  final DateTime? sent;
  final VoidCallback? onExcuse;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final tone = item.excused ? null : k.p.cancel;
    final day = item.day == null ? '' : formatDate(t, t.dateShort, item.day!);
    final meta = [
      if (item.hours != null && item.hours!.isNotEmpty)
        t.absenceHours(item.hours!),
      item.status,
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.s),
      padding: const EdgeInsets.fromLTRB(Sp.l, Sp.m, Sp.s, Sp.m),
      decoration: BoxDecoration(
        color: tone?.bg ?? k.p.card,
        borderRadius: BorderRadius.circular(Rad.signal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: Sz.slotColumn + Sp.l,
                child: Text(day, style: k.timeStart),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.subject,
                      style: k.planSubject(tone?.ink ?? k.p.ink),
                    ),
                    Text(meta, style: k.planMeta(tone?.ink ?? k.p.muted)),
                    if (sent != null)
                      Text(
                        t.absenceSent(formatDate(t, t.dateShort, sent!)),
                        style: k.planMeta(k.p.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (onExcuse != null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: Sp.s),
                child: FilledButton.icon(
                  onPressed: onExcuse,
                  style: FilledButton.styleFrom(
                    backgroundColor: k.p.strong,
                    foregroundColor: k.p.onStrong,
                  ),
                  icon: const Icon(Icons.mail_outline, size: Sz.icon),
                  label: Text(
                    sent == null ? t.absenceExcuse : t.absenceExcuseAgain,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
