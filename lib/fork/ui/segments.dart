import 'package:flutter/material.dart';

import 'kit.dart';

/// Umschalter mit zwei oder mehr gleich breiten Feldern in einer Pille
/// („1. Halbjahr | 2. Halbjahr“, „Fächer & Hausaufgaben | Arbeiten & Noten“).
///
/// [PillSegments.strong]: weiße Spur, gewähltes Feld dunkel – wie „Tag |
/// Woche | Termine“ im Kalender (plan_page.dart, _ViewToggle). Ursache
/// (Rückmeldung 18.10.26): Grau auf Grau mit weißem Feld hatte in
/// „Unterricht“ zu wenig Kontur. Die übrigen Umschalter bekommen einen Rand.
///
/// Ursache: Kursseite und Unterricht brauchen denselben Umschalter; vorher
/// lag er nur privat in course_detail_page.dart (_HalfSwitch). [bg] ist die
/// Fläche, [ink] die Schrift des gewählten Felds – Fachfarbe auf der
/// Kursseite, neutral (inset/ink) in der Übersicht.
class PillSegments extends StatelessWidget {
  const PillSegments({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    required this.bg,
    required this.ink,
  }) : strong = false;

  const PillSegments.strong({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  }) : strong = true,
       bg = null,
       ink = null;

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final Color? bg;
  final Color? ink;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final track = strong ? k.p.card : bg!;
    final selBg = strong ? k.p.strong : k.p.card;
    final selInk = strong ? k.p.onStrong : ink!;
    return Container(
      padding: EdgeInsets.all(strong ? Sp.xs : Sp.xxs + 1),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(Rad.pill + (strong ? Sp.xs : 0)),
        border: strong ? null : Border.all(color: k.p.line),
        boxShadow: strong ? k.cardShadow : null,
      ),
      child: Row(
        children: [
          for (final (i, label) in labels.indexed)
            Expanded(
              child: Material(
                color: i == selected ? selBg : Colors.transparent,
                borderRadius: BorderRadius.circular(Rad.pill),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.pill),
                  onTap: () => onChanged(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: Sp.s,
                      horizontal: Sp.s,
                    ),
                    // Einzeilig, notfalls kleiner („Fächer & Hausaufgaben“
                    // bei großer Schrift).
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: k.chipLabel(i == selected, selInk),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
