import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart' show sharedOverAccountSettingsProvider;

import 'kit.dart';

/// Geräteweite Schriftgröße (Normal / Groß / Sehr groß), gespeichert unter
/// [fontStepKey].
///
/// Ursache: Bisher wirkte die Stufe nur innerhalb der neuen Oberfläche
/// (MediaQuery in PreviewShell). Darüber geöffnete Seiten – Einstellungen,
/// Kursseite, Unterhaltung, Krankmeldung – liegen im Navigator NEBEN der
/// Oberfläche und blieben klein. Jetzt setzt sie die App ganz oben
/// (main.dart, MaterialApp.router builder). Grenze: Die Stufe kommt zur
/// Schriftgröße des Handys hinzu, ersetzt sie nicht.
const fontStepKey = 'fork-ui/font-step';

class FontStepNotifier extends Notifier<KitFontStep> {
  @override
  KitFontStep build() {
    try {
      return KitFontStep.parse(
        ref.watch(sharedOverAccountSettingsProvider).getString(fontStepKey),
      );
    } catch (_) {
      return KitFontStep.normal;
    }
  }

  void set(KitFontStep step) {
    state = step;
    try {
      ref
          .read(sharedOverAccountSettingsProvider)
          .setString(fontStepKey, step.name);
    } catch (_) {}
  }
}

final fontStepProvider = NotifierProvider<FontStepNotifier, KitFontStep>(
  FontStepNotifier.new,
);

/// Schriftgröße der Handy-Einstellung mal [step].
MediaQueryData scaledFor(MediaQueryData mq, KitFontStep step) {
  final system = mq.textScaler.scale(14) / 14;
  return mq.copyWith(textScaler: TextScaler.linear(system * step.factor));
}
