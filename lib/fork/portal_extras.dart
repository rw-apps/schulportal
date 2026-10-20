import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import 'package:liblanis/liblanis.dart';

/// Wahltool und Profilfoto (Wunsch 20.10.26, Export Schule B 20.10.26).

/// Bietet die Schule das Modul [php] an? (App-Liste der Sitzung.)
bool offersModule(List<dynamic> travelMenu, String php) =>
    travelMenu.any((e) => e is Map && e['link']?.toString() == php);

// ---- Wahltool --------------------------------------------------------------

const electionModule = 'wahl.php';

/// Ist im Wahltool eine Wahl offen?
///
/// Ursache für die Prüfung über den Leertext: Im Export war keine Wahl offen;
/// die Seite zeigte unter „Aktive Veranstaltungen“ nur „Es sind derzeit keine
/// passenden Veranstaltungen aktiv.“ Wie eine offene Wahl aussieht, ist
/// unbekannt. Grenze: Ändert das Portal den Leertext, meldet die App eine
/// Wahl, die es nicht gibt; fehlt die Überschrift (Fehlerseite, abgemeldet),
/// meldet sie nichts.
bool electionOpen(String html) {
  final text = parse(html).body?.text.replaceAll(RegExp(r'\s+'), ' ') ?? '';
  if (!text.contains('Aktive Veranstaltungen')) return false;
  return !RegExp(
    r'keine\s+(passenden\s+)?Veranstaltungen\s+aktiv',
    caseSensitive: false,
  ).hasMatch(text);
}

Future<bool> loadElectionOpen(LanisSession session) async {
  final r = await session.dio.get(
    'https://start.schulportal.hessen.de/$electionModule',
  );
  return electionOpen(r.data.toString());
}

/// Hintergrund: letzter Stand und letzter Blick (notify_task.dart).
const electionOpenSetting = 'fork/election-open';
const electionCheckedSetting = 'fork/election-checked';
const electionCheckEvery = Duration(hours: 6);

// ---- Profilfoto ------------------------------------------------------------

/// Adresse des eigenen Fotos aus benutzerverwaltung.php?a=userFoto
/// (`img.userFoto_preview`); null = keins.
String? photoUrlFrom(String html) {
  final src = parse(
    html,
  ).querySelector('img.userFoto_preview')?.attributes['src']?.trim();
  if (src == null || src.isEmpty) return null;
  return src.startsWith('http')
      ? src
      : 'https://start.schulportal.hessen.de/$src';
}

/// Ein Foto gilt so lange, bevor es neu geladen wird.
const photoMaxAge = Duration(days: 7);

const _photoFile = 'fork-profile-photo';

/// Foto des Schülerkontos, zwischengespeichert im Dateicache des Kontos.
///
/// Ursache für den Cache des Kontos (StorageManager.getDocumentCacheDirectory):
/// Er gehört zum Konto und wird beim Abmelden gelöscht (settings_page.dart,
/// _logout) – das Foto eines Kindes bleibt nicht auf einem geteilten Gerät
/// zurück. Nur für Schülerkonten: Bei Elternkonten wäre es das Foto des
/// Elternteils. Grenze: Ohne hochgeladenes Foto zeigt das Portal vielleicht
/// ein Platzhalterbild; dann erscheint dieses.
Future<Uint8List?> loadProfilePhoto(
  LanisSession session,
  Directory cache, {
  bool force = false,
  DateTime? now,
}) async {
  final file = File('${cache.path}/$_photoFile');
  final t = now ?? DateTime.now();
  // Leere Datei = „kein echtes Foto“ (Platzhalter), ebenfalls zwischen-
  // gespeichert, damit nicht jeder Start neu lädt.
  Future<Uint8List?> cached() async {
    if (!file.existsSync()) return null;
    final b = file.readAsBytesSync();
    if (b.isEmpty || await looksLikePlaceholder(b)) return null;
    return b;
  }

  if (!force &&
      file.existsSync() &&
      t.difference(file.lastModifiedSync()) < photoMaxAge) {
    return cached();
  }
  try {
    final page = await session.dio.get(
      'https://start.schulportal.hessen.de/benutzerverwaltung.php?a=userFoto',
    );
    final url = photoUrlFrom(page.data.toString());
    if (url == null) {
      file.writeAsBytesSync(const [], flush: true);
      return null;
    }
    final img = await session.dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(img.data ?? const []);
    // Nur echte Bilder (JPG/PNG) – eine Fehlerseite wäre HTML.
    final jpg = bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;
    final png = bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50;
    if (!jpg && !png) return await cached();
    if (await looksLikePlaceholder(bytes)) {
      file.writeAsBytesSync(const [], flush: true);
      return null;
    }
    file.writeAsBytesSync(bytes, flush: true);
    return bytes;
  } catch (_) {
    return cached();
  }
}

/// Ist das Bild der graue Platzhalter des Portals statt eines Fotos?
///
/// Ursache (Bildschirmfoto 20.10.26): Ohne hochgeladenes Foto liefert das
/// Portal ein graues Schattenbild; in der Karte sah das wie ein fehlendes
/// Bild aus. Prüfung: verkleinert auf 24 × 24, wie viele Bildpunkte farbig
/// sind (Abstand der Farbkanäle > 24). Unter 3 % gilt als Platzhalter.
/// Grenze: Ein echtes Schwarzweißfoto gilt ebenfalls als Platzhalter – dann
/// erscheint der Anfangsbuchstabe.
Future<bool> looksLikePlaceholder(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 24,
      targetHeight: 24,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    frame.image.dispose();
    if (data == null) return false;
    final px = data.lengthInBytes ~/ 4;
    var colored = 0;
    for (var i = 0; i < px; i++) {
      final r = data.getUint8(i * 4);
      final g = data.getUint8(i * 4 + 1);
      final b = data.getUint8(i * 4 + 2);
      final hi = [r, g, b].reduce((a, c) => a > c ? a : c);
      final lo = [r, g, b].reduce((a, c) => a < c ? a : c);
      if (hi - lo > 24) colored++;
    }
    return colored < px * 0.03;
  } catch (_) {
    return false;
  }
}
