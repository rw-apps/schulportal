import 'package:flutter/material.dart';

import 'kit.dart';

/// Auswahl der Kinder als Pillen (Kalender, Bereiche mit [FamilySwitch]).
///
/// Mit [allLabel] steht vorn eine Pille „Alle“ ohne Farbpunkt; sie meldet
/// [onSelect] mit -1 und ist bei [selected] = -1 gewählt. Ursache
/// (Rückmeldung 18.10.26): In „Termine“ fehlte ein Filter je Kind; die
/// gemeinsame Liste bleibt dort der Normalfall.
class KidChips extends StatelessWidget {
  const KidChips({
    super.key,
    required this.kids,
    required this.selected,
    required this.onSelect,
    this.allLabel,
  });

  final List<({String name, int color})> kids;
  final int selected;
  final ValueChanged<int> onSelect;
  final String? allLabel;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    Widget chip({
      required bool sel,
      required VoidCallback onTap,
      required String label,
      required Color tint,
      required Color ink,
      Color? dot,
    }) => Semantics(
      selected: sel,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.pill),
        onTap: onTap,
        child: Container(
          height: Sz.buttonSmall,
          padding: const EdgeInsets.symmetric(horizontal: Sp.l),
          decoration: BoxDecoration(
            color: sel ? tint : k.p.card,
            borderRadius: BorderRadius.circular(Rad.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                  width: Sz.dot + Sp.xxs,
                  height: Sz.dot + Sp.xxs,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: Sp.s),
              ],
              Text(label, style: k.chipLabel(sel, ink)),
            ],
          ),
        ),
      ),
    );

    return Wrap(
      spacing: Sp.s,
      runSpacing: Sp.s,
      children: [
        if (allLabel != null)
          chip(
            sel: selected < 0,
            onTap: () => onSelect(-1),
            label: allLabel!,
            tint: k.p.inset,
            ink: k.p.ink,
          ),
        for (final (i, kid) in kids.indexed)
          chip(
            sel: i == selected,
            onTap: () => onSelect(i),
            label: kid.name,
            tint: k.kid(kid.color).tint,
            ink: k.kid(kid.color).onTint,
            dot: k.kid(kid.color).accent,
          ),
      ],
    );
  }
}
