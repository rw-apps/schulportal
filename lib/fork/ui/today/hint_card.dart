import 'package:flutter/material.dart';

import '../kit.dart';

/// Gelber Hinweis oben auf „Heute“ mit einer Aktion (neues Schuljahr,
/// offene Wahl). Ursache: Beide Hinweise sahen gleich aus; ein Baustein hält
/// sie einheitlich (Entwurf 20.10.26 k4).
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
      padding: const EdgeInsets.fromLTRB(Sp.l, Sp.m, Sp.s, Sp.s),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(Rad.signal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: Sz.navIcon, color: tone.ink),
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
            ],
          ),
          if (action != null && onAction != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onAction,
                child: Text(action!, style: k.link),
              ),
            ),
        ],
      ),
    );
  }
}
