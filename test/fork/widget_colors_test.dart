import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/kit.dart';

/// Farben des Startbildschirm-Widgets (android/app/src/main/res/values*/
/// widget_colors.xml) müssen genau die des Design-Kits sein. Ursache
/// (Abnahme 28.10.26): Das native Widget kann KitPalette nicht lesen; ohne
/// diese Prüfung liefe eine Farbänderung im Kit am Widget vorbei. Das Kit
/// bleibt die einzige Quelle – bei Abweichung die XML-Datei anpassen.

Map<String, Color> _expected(KitPalette p) => {
  // Entwurf 10 (Abnahme 30.10.26): Karte, Schrift, blasse Symbole.
  'widget_card': p.card,
  'widget_ink': p.ink,
  'widget_muted': p.muted,
  'widget_faint': p.faint,
  'widget_faint_off': p.faint.withValues(alpha: 0.45),
  'widget_faint_label': p.faint.withValues(alpha: 0.6),
  'widget_inset': p.inset,
  'widget_line': p.line,
  // Arbeit blau, Essen/Vertretung/Raum gelb, Ausfall rot.
  'widget_on_nav_selected': p.onNavSelected,
  'widget_exam_bg': p.onNavSelected.withValues(alpha: 0.22),
  'widget_change_bg': p.change.bg,
  'widget_change_strong': p.change.strong,
  'widget_cancel_strong': p.cancel.strong,
  for (final (i, k) in p.kids.indexed) 'widget_kid${i}_label': k.label,
};

Map<String, Color> _parse(String path) {
  final xml = File(path).readAsStringSync();
  return {
    for (final m in RegExp(
      r'<color name="([^"]+)">#([0-9A-Fa-f]{8})</color>',
    ).allMatches(xml))
      m[1]!: Color(int.parse(m[2]!, radix: 16)),
  };
}

void main() {
  for (final (folder, palette) in [
    ('values', KitPalette.light),
    ('values-night', KitPalette.dark),
  ]) {
    test('widget_colors.xml in $folder = KitPalette', () {
      final xml = _parse('android/app/src/main/res/$folder/widget_colors.xml');
      final want = _expected(palette);
      expect(xml.keys.toSet(), want.keys.toSet());
      for (final e in want.entries) {
        expect(
          xml[e.key]!.toARGB32(),
          e.value.toARGB32(),
          reason: '${e.key} in $folder',
        );
      }
    });
  }
}
