import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'hint_card.dart';

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
    final t = context.t;
    return HintCard(
      icon: Icons.school_outlined,
      title: t.classPromptTitle(kidName),
      text: t.classPromptText,
      action: t.classPromptAction,
      onAction: onEnter,
    );
  }
}
