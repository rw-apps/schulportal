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
    // Gewählt: volle Farbe (Kind) bzw. dunkel („Alle“) mit Haken; nicht
    // gewählt: weiß mit Rand und Farbpunkt. Ursache (Rückmeldung 20.10.26,
    // Bildschirmfoto Nachrichten: „schwer erkennbar, welches Profil
    // ausgewählt ist“): Vorher war „Alle“ gewählt grau auf grauem Grund und
    // die NICHT gewählten Kinder weiß – die Hervorhebung wirkte verkehrt.
    Widget chip({
      required bool sel,
      required VoidCallback onTap,
      required String label,
      required Color fill,
      required Color onFill,
      Color? dot,
    }) => Semantics(
      selected: sel,
      button: true,
      child: Material(
        color: sel ? fill : k.p.card,
        shape: StadiumBorder(
          side: sel ? BorderSide.none : BorderSide(color: k.p.line),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: Sz.buttonSmall,
            padding: const EdgeInsets.symmetric(horizontal: Sp.l),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sel)
                  Padding(
                    padding: const EdgeInsets.only(right: Sp.s),
                    child: Icon(Icons.check, size: Sz.icon, color: onFill),
                  )
                else if (dot != null)
                  Padding(
                    padding: const EdgeInsets.only(right: Sp.s),
                    child: Container(
                      width: Sz.dot + Sp.xxs,
                      height: Sz.dot + Sp.xxs,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Text(label, style: k.chipLabel(sel, onFill)),
              ],
            ),
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
            fill: k.p.strong,
            onFill: k.p.onStrong,
          ),
        for (final (i, kid) in kids.indexed)
          chip(
            sel: i == selected,
            onTap: () => onSelect(i),
            label: kid.name,
            fill: k.kid(kid.color).accent,
            onFill: k.p.card,
            dot: k.kid(kid.color).accent,
          ),
      ],
    );
  }
}
