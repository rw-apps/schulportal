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
  'widget_card': p.card,
  'widget_ink': p.ink,
  'widget_muted': p.muted,
  'widget_faint': p.faint,
  'widget_change_bg': p.change.bg,
  'widget_change_ink': p.change.ink,
  'widget_change_strong': p.change.strong,
  'widget_cancel_bg': p.cancel.bg,
  'widget_cancel_ink': p.cancel.ink,
  'widget_cancel_strong': p.cancel.strong,
  'widget_cancel_dot': p.cancel.dot,
  'widget_todo_dot': p.todo.dot,
  for (final (i, k) in p.kids.indexed) ...{
    'widget_kid${i}_accent': k.accent,
    'widget_kid${i}_tint': k.tint,
    'widget_kid${i}_on_tint': k.onTint,
    'widget_kid${i}_label': k.label,
    'widget_kid${i}_meta': k.meta,
  },
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
