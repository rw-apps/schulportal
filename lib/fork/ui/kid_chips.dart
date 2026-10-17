import 'package:flutter/material.dart';

import 'kit.dart';

/// Auswahl der Kinder als Pillen (Kalender, Bereiche mit [FamilySwitch]).
class KidChips extends StatelessWidget {
  const KidChips({
    super.key,
    required this.kids,
    required this.selected,
    required this.onSelect,
  });

  final List<({String name, int color})> kids;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Wrap(
      spacing: Sp.s,
      runSpacing: Sp.s,
      children: [
        for (final (i, kid) in kids.indexed)
          Builder(
            builder: (context) {
              final tone = k.kid(kid.color);
              final sel = i == selected;
              return Semantics(
                selected: sel,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.pill),
                  onTap: () => onSelect(i),
                  child: Container(
                    height: Sz.buttonSmall,
                    padding: const EdgeInsets.symmetric(horizontal: Sp.l),
                    decoration: BoxDecoration(
                      color: sel ? tone.tint : k.p.card,
                      borderRadius: BorderRadius.circular(Rad.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: Sz.dot + Sp.xxs,
                          height: Sz.dot + Sp.xxs,
                          decoration: BoxDecoration(
                            color: tone.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: Sp.s),
                        Text(kid.name, style: k.chipLabel(sel, tone.onTint)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
