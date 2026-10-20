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

/// Farbe für Konto [id] wählen; hat ein anderes Konto sie schon, bekommt
/// es die bisherige Farbe von [id] (Tausch). Rückgabe: zu speichernde
/// Farben je Konto. Ursache (Rückfrage 20.10.26): Ohne Tausch hätten zwei
/// Kinder dieselbe Farbe wählen können.
Map<int, int> pickKidColor(Map<int, int> current, int id, int color) {
  final old = current[id];
  final out = <int, int>{id: color};
  for (final e in current.entries) {
    if (e.key != id && e.value == color && old != null) out[e.key] = old;
  }
  return out;
}

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
    // Doppelte Farbe (z. B. aus einer Übertragung von einem anderen Gerät,
    // settings_transfer.dart): das zuerst angelegte Konto behält sie, das
    // spätere bekommt unten eine freie. Nur solange Farben frei sind.
    final taken = colors.values.contains(c);
    if (c != null && (!taken || colors.length >= kidColorCount)) {
      colors[id] = c;
    }
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
