import 'package:flutter/material.dart';

import '../kit.dart';

/// Gelber Hinweis oben auf „Heute“ mit einer Aktion (neues Schuljahr,
/// offene Wahl). Ursache: Beide Hinweise sahen gleich aus; ein Baustein hält
/// sie einheitlich (Entwurf 20.10.26 k4).
///
/// Kompakt in einer Zeile: Symbol im runden Feld, Titel und kurze Zeile,
/// Aktion als Pille rechts. Ursache (Rückmeldung 20.10.26: „Platz besser
/// nutzen und optisch aufwerten“): Die erste Fassung brauchte mit Textblock
/// und eigener Knopfzeile so viel Höhe wie eine halbe Kinderkarte.
class HintCard extends StatelessWidget {
  const HintCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final tone = k.p.change;
    return Container(
      padding: const EdgeInsets.all(Sp.m),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(Rad.signal),
      ),
      child: Row(
        children: [
          Container(
            width: Sz.buttonSmall,
            height: Sz.buttonSmall,
            decoration: BoxDecoration(color: k.p.card, shape: BoxShape.circle),
            child: Icon(icon, size: Sz.navIcon, color: tone.ink),
          ),
          const SizedBox(width: Sp.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: k.boxStrong(tone)),
                Text(text, style: k.boxText(tone)),
              ],
            ),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(width: Sp.s),
            Material(
              color: k.p.strong,
              borderRadius: BorderRadius.circular(Rad.pill),
              child: InkWell(
                borderRadius: BorderRadius.circular(Rad.pill),
                onTap: onAction,
                child: Container(
                  height: Sz.buttonSmall,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: Sp.l),
                  child: Text(action!, style: k.button(k.p.onStrong)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
