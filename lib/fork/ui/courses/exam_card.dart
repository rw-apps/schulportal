import 'package:flutter/material.dart';

import '../../exams.dart';
import '../../l10n/l10n.dart';
import '../kit.dart';
import '../today/kind_icons.dart';
import '../today/today_model.dart' show WeekKind;
import '../today/today_page.dart' show relativeDay;

/// Kind an einem Eintrag der Ansicht „Alle“ (Name, Farbplatz).
typedef KidTag = ({String name, int color});

/// Punkt und Name in der Farbe des Kindes (wie bei Nachrichten).
class KidLine extends StatelessWidget {
  const KidLine({super.key, required this.kid});

  final KidTag kid;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final c = k.kid(kid.color).accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: Sz.dot,
          height: Sz.dot,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: Sp.xs + Sp.xxs),
        Text(kid.name, style: k.tileKid(c)),
      ],
    );
  }
}

/// Eine Arbeit in der Liste; [kid] nur in „Alle“.
class AllExam {
  const AllExam({required this.exam, this.kid});

  final UpcomingExam exam;
  final KidTag? kid;
}

/// Anstehende Arbeiten als Karte – gemeinsam für Unterricht „Alle“ und
/// „Nächste Arbeiten“ eines Kindes (grades_view.dart).
///
/// Ursache (Rückfrage 20.10.26): Bisher zeigte das Kind eine eigene Zeile
/// (Fach, Text, Datum rechts), „Alle“ eine andere – dieselbe Arbeit sah
/// verschieden aus. Jetzt eine Zeile wie in „Demnächst“ (today_page.dart,
/// _UpcomingRow): Tag, Symbol, „Fach: Art“, Stunden; rechts das Kind.
class ExamCard extends StatelessWidget {
  const ExamCard({super.key, required this.exams, required this.now});

  final List<AllExam> exams;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.xs),
      decoration: BoxDecoration(
        color: k.p.card,
        borderRadius: BorderRadius.circular(Rad.box),
        boxShadow: k.cardShadow,
      ),
      child: Column(
        children: [
          for (final (i, e) in exams.indexed) ...[
            if (i > 0) Divider(height: 1, color: k.p.line),
            _ExamRow(exam: e, now: now),
          ],
        ],
      ),
    );
  }
}

class _ExamRow extends StatelessWidget {
  const _ExamRow({required this.exam, required this.now});

  final AllExam exam;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final e = exam.exam;
    final kid = exam.kid;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.s + Sp.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: Sz.slotColumn + Sp.l,
            child: Text(relativeDay(t, e.day, now), style: k.tileCaption),
          ),
          Padding(
            padding: const EdgeInsets.only(top: Sp.xxs, right: Sp.s),
            child: Icon(
              weekIcon(WeekKind.exam),
              size: Sz.icon,
              color: k.p.cancel.ink,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: k.tileTitle),
                if (e.detail != null && e.detail!.isNotEmpty)
                  Text(e.detail!, style: k.planMeta(k.p.cancel.ink)),
              ],
            ),
          ),
          if (kid != null) ...[
            const SizedBox(width: Sp.s),
            Padding(
              padding: const EdgeInsets.only(top: Sp.xxs),
              child: KidLine(kid: kid),
            ),
          ],
        ],
      ),
    );
  }
}
