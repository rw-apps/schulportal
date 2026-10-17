import 'package:flutter/material.dart';

import 'kit.dart';

/// Umschalter mit zwei oder mehr gleich breiten Feldern in einer Pille
/// („1. Halbjahr | 2. Halbjahr“, „Kurse | Noten“).
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
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final Color bg;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Container(
      padding: const EdgeInsets.all(Sp.xxs + 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Rad.pill),
      ),
      child: Row(
        children: [
          for (final (i, label) in labels.indexed)
            Expanded(
              child: Material(
                color: i == selected ? k.p.card : Colors.transparent,
                borderRadius: BorderRadius.circular(Rad.pill),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.pill),
                  onTap: () => onChanged(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Sp.s),
                    child: Center(
                      child: Text(
                        label,
                        style: k.chipLabel(i == selected, ink),
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
