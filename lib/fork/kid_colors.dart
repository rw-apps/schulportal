import 'package:liblanis/liblanis.dart';

/// Feste Farbe je Kind (Konto), Wunsch 20.10.26.
///
/// Ursache: Vorher galt die Reihenfolge der Kontoanlage (localId). Auf einem
/// zweiten Gerät mit anderer Reihenfolge hatte dasselbe Kind eine andere
/// Farbe, und nach dem Entfernen eines Kontos rückten die übrigen nach.
/// Jetzt wird die Farbe beim ersten Anzeigen am Konto gespeichert, mit den
/// Eingaben übertragen (settings_transfer.dart) und lässt sich in den
/// Einstellungen wählen. Grenze: Bei mehr Kindern als Farben (4) teilen
/// sich zwei eine Farbe.
const kidColorSetting = 'fork/kid-color';

/// Anzahl der Kinderfarben in der Palette (KitPalette.kids).
const kidColorCount = 4;

int? storedKidColor(TypedSettings s) {
  final v = int.tryParse(s.getString(kidColorSetting) ?? '');
  return v != null && v >= 0 && v < kidColorCount ? v : null;
}

void storeKidColor(TypedSettings s, int color) =>
    s.setString(kidColorSetting, '$color');

/// Farbe je Konto: gespeicherte gelten, die übrigen bekommen in
/// Anlage-Reihenfolge die erste noch freie Farbe. [stored] null = keine.
/// Rückgabe: alle Farben und die neu vergebenen (zum Speichern).
({Map<int, int> colors, Map<int, int> fresh}) assignKidColors(
  List<int> accountIds,
  Map<int, int?> stored,
) {
  final ids = [...accountIds]..sort();
  final colors = <int, int>{};
  for (final id in ids) {
    final c = stored[id];
    if (c != null) colors[id] = c;
  }
  final fresh = <int, int>{};
  for (final id in ids) {
    if (colors.containsKey(id)) continue;
    final used = colors.values.toSet();
    final free = [
      for (var c = 0; c < kidColorCount; c++)
        if (!used.contains(c)) c,
    ];
    final c = free.isNotEmpty ? free.first : colors.length % kidColorCount;
    colors[id] = c;
    fresh[id] = c;
  }
  return (colors: colors, fresh: fresh);
}
