import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Stellt die liblanis-Datenbank unter [path] auf WAL um; gibt den Modus
/// danach zurück (`wal`), null bei Fehler oder fehlender Datei.
///
/// Ursache (Prüfung 27.10.26, liblanis database/database.dart:28): Die
/// Bibliothek öffnet die Datei im Standardmodus (Rollback-Journal, kein
/// busy_timeout). Der Hintergrundlauf öffnet im Prozess der geöffneten App
/// eine ZWEITE Verbindung auf dieselbe Datei (background_service.dart,
/// bootstrapLanisClient(forApp: false)). Im Rollback-Modus sperrt jeder
/// Schreiber auch alle Leser; ohne busy_timeout scheitert die andere Seite
/// sofort mit „database is locked“. Im WAL-Modus lesen beide weiter,
/// während einer schreibt.
///
/// Grenze: Der Modus wird in der Datei gespeichert und gilt damit auch für
/// die Verbindungen von liblanis – eine Wartezeit auf Sperren dagegen gilt
/// je Verbindung und lässt sich von außen nicht setzen; seit der
/// eingebetteten liblanis (packages/liblanis/FORK.md, Befund 12) wartet
/// jede liblanis-Verbindung selbst bis zu 5 s, zwei GLEICHZEITIGE Schreiber
/// kollidieren erst danach. Die
/// Zusatzdateien `-wal`/`-shm` liegen neben lanis.db; keine Funktion der
/// App kopiert die Datenbankdatei einzeln (geprüft 27.10.26: Übertragung
/// aufs neue Gerät nur Einstellungen, settings_transfer.dart). Backups sind
/// abgeschaltet (data_extraction_rules.xml). Ist die Datei gerade von einer
/// anderen Verbindung gesperrt oder noch gar nicht angelegt (allererster
/// Start), bleibt der Modus, wie er ist; der nächste Start versucht es
/// erneut.
String? enableWalJournal(String path) {
  if (!File(path).existsSync()) return null;
  Database? db;
  try {
    db = sqlite3.open(path);
    final current = db.select('PRAGMA journal_mode;').first.values.first;
    if (current == 'wal') return 'wal';
    return db.select('PRAGMA journal_mode=WAL;').first.values.first as String?;
  } catch (_) {
    return null;
  } finally {
    try {
      db?.close();
    } catch (_) {}
  }
}
