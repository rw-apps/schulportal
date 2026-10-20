import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../kit.dart';

/// Hinweis auf „Heute“: Der eingetragene Eintrag ist mit dem Schuljahr
/// abgelaufen und die App erkennt die Klasse nicht selbst
/// (class_choice.dart, Entwurf 20.10.26 k4). Ursache: Ohne Klasse blendet
/// forClass keine Termine anderer Klassen aus – das soll nicht still
/// passieren. Grenze: Wer nie eine Klasse eingetragen hat, wird hier nicht
/// gefragt (das übernimmt die Einrichtung).
class ClassPromptCard extends StatelessWidget {
  const ClassPromptCard({super.key, required this.kidName, this.onEnter});

  final String kidName;
  final VoidCallback? onEnter;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
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
              Icon(Icons.school_outlined, size: Sz.navIcon, color: tone.ink),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.classPromptTitle(kidName), style: k.boxStrong(tone)),
                    Text(t.classPromptText, style: k.boxText(tone)),
                  ],
                ),
              ),
            ],
          ),
          if (onEnter != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onEnter,
                child: Text(t.classPromptAction, style: k.link),
              ),
            ),
        ],
      ),
    );
  }
}
