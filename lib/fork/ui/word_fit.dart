import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Mehrzeiliger Text, der lieber kleiner wird als ein Wort zu trennen.
///
/// Ursache (Bildschirmfoto 18.10.26): In den schmalen Kacheln unter
/// „Demnächst“ brach „Reformationstag“ als „Reformationst/ag“ um – Flutter
/// trennt ein Wort, das nicht in die Zeile passt, an beliebiger Stelle. Jetzt
/// wird die Schrift so weit verkleinert, dass das längste Wort in [width]
/// passt, höchstens auf [minScale]; erst darunter wird getrennt.
///
/// [width] wird übergeben statt gemessen. Ursache: Die Kacheln stehen in
/// einer IntrinsicHeight-Zeile, und LayoutBuilder liefert dort keine
/// Eigenmaße (Laufzeitfehler). Grenze: Stimmt [width] nicht mit der echten
/// Breite überein, passt die Rechnung nicht genau.
class WordFitText extends StatelessWidget {
  const WordFitText(
    this.text, {
    super.key,
    required this.style,
    required this.width,
    this.minScale = 0.7,
  });

  final String text;
  final TextStyle style;
  final double width;
  final double minScale;

  /// Faktor für die Schriftgröße, damit das längste Wort in [width] passt.
  static double scaleFor(
    String text,
    TextStyle style,
    double width,
    TextScaler scaler, {
    double minScale = 0.7,
  }) {
    var widest = 0.0;
    for (final w in text.split(RegExp(r'\s+'))) {
      if (w.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(text: w, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, tp.width);
      tp.dispose();
    }
    if (widest <= width || widest == 0) return 1;
    // Etwas Luft, damit Rundung den Umbruch nicht doch auslöst.
    return math.max(minScale, width / widest * 0.98);
  }

  @override
  Widget build(BuildContext context) {
    final f = scaleFor(
      text,
      style,
      width,
      MediaQuery.textScalerOf(context),
      minScale: minScale,
    );
    final s = f == 1
        ? style
        : style.copyWith(fontSize: (style.fontSize ?? 14) * f);
    return Text(text, style: s);
  }
}
