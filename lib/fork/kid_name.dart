import 'package:liblanis/liblanis.dart' show TypedSettings;

/// Nur der erste Vorname („Lena Marie“ → „Lena“) – für die App
/// (LiveSnapshot.firstName) und die Hinweise (notify_task.dart) gleich.
/// Ursache (Prüfung 20.10.26): Die Hinweise nannten den vollen Vornamen.
/// Grenze: Doppelnamen mit Leerzeichen („Anna Lena“) werden gekürzt, mit
/// Bindestrich bleiben sie ganz.
String shortFirstName(String full) => full.trim().split(RegExp(r'\s+')).first;

/// Vorname des Kindes je Konto, für die Hinweise im Hintergrund.
///
/// Ursache (Wunsch 20.10.26, „Nachrichten-Hinweis nennt das Kind nicht“):
/// Die Anmeldung im Hintergrund lädt keine Benutzerdaten
/// (authenticate(withoutData: true), background_service.dart) – beim
/// Schülerkonto kannte der Hintergrund den Namen gar nicht, beim
/// Elternkonto nur, wenn „Mein Unterricht“ im selben Lauf geladen wurde.
/// Geschrieben von der App (live_data.dart) und vom Vertretungs-Hinweis
/// (notify_task.dart), sobald sie ihn kennen. Grenze: Vor dem ersten Öffnen
/// der App bleibt er bei Schülerkonten leer.
const kidNameSetting = 'fork/kid-name';

String storedKidName(TypedSettings s) => s.getString(kidNameSetting) ?? '';

void rememberKidName(TypedSettings s, String name) {
  if (name.isEmpty || s.getString(kidNameSetting) == name) return;
  s.setString(kidNameSetting, name);
}
