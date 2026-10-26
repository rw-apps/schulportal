import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import '../../demo/demo_mode.dart' show demoActive;
import '../../error_log.dart';
import '../../homework_ledger.dart';
import '../../l10n/l10n.dart';
import '../kid_chips.dart';
import '../kit.dart';
import '../live/live_data.dart';
import 'courses_model.dart' show courseTitle;

/// Hausaufgabe abhaken oder wieder öffnen.
///
/// Immer im Protokoll der App (homework_ledger.dart, sofort sichtbar); beim
/// Schülerkonto zusätzlich im Portal („erledigt“ wie auf der Webseite,
/// setHomework, liblanis). Ursache für beides: Elternkonten bietet das
/// Portal kein Abhaken an, und ohne Netz soll der Haken trotzdem gelten.
/// Grenze: Schlägt das Portal fehl, gilt der Haken nur in der App – die
/// Meldung sagt das.
///
/// [parser] wird vor dem Warten gelesen, nicht danach: Die Seite kann bis
/// zur Antwort abgebaut sein (ref nach dem Abbau = Absturz 9349).
Future<void> setHomeworkDone({
  required LiveSnapshot s,
  required LessonsStudentParser parser,
  required HomeworkItem item,
  required bool done,
  required ForkL10n t,
  ScaffoldMessengerState? messenger,
}) async {
  final save = s.setHomework;
  if (save == null) return;
  final now = DateTime.now();
  save((l) => l.put(item.record(done: done ? now : null, now: now), now));
  if (s.session.account.accountType != AccountType.student) return;
  if (item.entry.isEmpty) return;
  // Demo: nur in der App abhaken, nicht ans (erfundene) Portal.
  if (demoActive) return;
  try {
    final r = await parser.setHomework(item.course, item.entry, done);
    // Das Portal antwortet mit „1“ bei Erfolg.
    if (r.trim() != '1') throw StateError('setHomework: unerwartete Antwort');
  } catch (e, st) {
    ErrorLog.instance.record('meinunterricht.php/erledigt', e, st);
    messenger?.showSnackBar(SnackBar(content: Text(t.homeworkPortalFailed)));
  }
}

/// Archiv: erledigte Hausaufgaben, neueste zuerst, mit „Wieder offen“.
/// Liest den Stand bei jedem Aufbau aus [LiveData] – nach „Wieder offen“
/// verschwindet die Zeile sofort.
class LiveHomeworkArchive extends ConsumerWidget {
  const LiveHomeworkArchive({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = LiveData.of(context);
    if (s == null) return const Scaffold(body: SizedBox.shrink());
    final lists = homeworkLists(
      s.lessons.content ?? const <Lesson>[],
      s.homework,
      subjectOf: (l) => courseTitle(l.name),
    );
    final parser = ref.read(lessonsStudentParserProvider);
    return HomeworkArchivePage(
      items: lists.done,
      firstName: s.firstName,
      onReopen: (i) {
        final t = context.t;
        final m = ScaffoldMessenger.maybeOf(context);
        setHomeworkDone(
          s: s,
          parser: parser,
          item: i,
          done: false,
          t: t,
          messenger: m,
        );
        m
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(t.homeworkReopened)));
      },
    );
  }
}

class HomeworkArchivePage extends StatelessWidget {
  const HomeworkArchivePage({
    super.key,
    required this.items,
    required this.onReopen,
    this.firstName = '',
  });

  final List<HomeworkItem> items;
  final void Function(HomeworkItem item) onReopen;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: k.p.bg,
      appBar: AppBar(
        backgroundColor: k.p.bg,
        surfaceTintColor: k.p.bg,
        // Pfeil schon in der Pillenzeile (BackInChips).
        automaticallyImplyLeading: !BackInChips.of(context),
        title: Text(t.homeworkArchiveTitle, style: k.section),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Sp.page, Sp.s, Sp.page, bottom + Sp.xl),
        children: [
          if (firstName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: Sp.xs, bottom: Sp.m),
              child: Text(firstName, style: k.meta),
            ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Sp.xs),
              child: Text(t.homeworkArchiveEmpty, style: k.meta),
            ),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: _DoneCard(item: i, onReopen: () => onReopen(i)),
            ),
        ],
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.item, required this.onReopen});

  final HomeworkItem item;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final meta = [
      item.subject,
      if (item.given != null)
        t.givenDate(formatDate(t, t.dateShort, item.given!)),
      if (item.done != null)
        t.homeworkDoneOn(formatDate(t, t.dateShort, item.done!)),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.l, Sp.m, Sp.s, Sp.s),
      decoration: BoxDecoration(
        color: k.p.card,
        borderRadius: BorderRadius.circular(Rad.signal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: Sp.xxs),
                child: Icon(
                  Icons.check_circle,
                  size: Sz.navIcon,
                  color: k.p.faint,
                ),
              ),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.text.isEmpty ? t.homeworkEntered : item.text,
                      style: k.body,
                    ),
                    const SizedBox(height: Sp.xxs),
                    Text(meta, style: k.meta),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onReopen,
              icon: Icon(Icons.undo, size: Sz.icon, color: k.p.onNavSelected),
              label: Text(t.homeworkReopen, style: k.link),
            ),
          ),
        ],
      ),
    );
  }
}
