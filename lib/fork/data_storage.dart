import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;
import 'package:liblanis/liblanis.dart';

/// Dateispeicher der Schule (dateispeicher.php), Wunsch 20.10.26.
///
/// Ursache für einen eigenen Leser: liblanis (DataStorageParser.getNode)
/// liest nur `table#files`. Der Startordner hat keine solche Tabelle, sondern
/// Ordnerkacheln und den Kasten „Neue Dateien“ (Export Schule B 17.10.26:
/// zwei Ordner, zwei neue Dateien) – den gab liblanis gar nicht zurück.
/// Grenze: Wie ein Ordner MIT Dateien aussieht, war nur aus liblanis bekannt
/// (Spalten „Name“, „Änderung“, „Größe“); fehlt eine Spalte, bleibt das Feld
/// leer statt abzustürzen.
const storageModule = 'dateispeicher.php';

class StorageFolder {
  const StorageFolder({
    required this.id,
    required this.name,
    this.desc = '',
    this.files,
  });

  final int id;
  final String name;
  final String desc;

  /// Anzahl Dateien laut Kachel; null = unbekannt, 0 = „Keine Dateien“.
  final int? files;
}

class StorageFile {
  const StorageFile({
    required this.id,
    required this.name,
    this.changed = '',
    this.size = '',
    this.note = '',
  });

  final int id;
  final String name;
  final String changed;
  final String size;
  final String note;

  String get extension =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';

  String get url =>
      'https://start.schulportal.hessen.de/dateispeicher.php?a=download&f=$id';
}

class StorageView {
  const StorageView({
    this.folders = const [],
    this.files = const [],
    this.newFiles = const [],
  });

  final List<StorageFolder> folders;

  /// Dateien dieses Ordners (table#files).
  final List<StorageFile> files;

  /// Kasten „Neue Dateien“ (nur im Startordner).
  final List<StorageFile> newFiles;

  bool get isEmpty => folders.isEmpty && files.isEmpty && newFiles.isEmpty;
}

String _text(Element? e) =>
    (e?.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Ordner [folder] auslesen (0 = Start).
StorageView parseStorage(String html) {
  final doc = parse(html);
  final folders = <StorageFolder>[];
  for (final f in doc.querySelectorAll('.folder')) {
    final id = int.tryParse(f.attributes['data-id'] ?? '');
    if (id == null) continue;
    final name =
        (f.attributes['data-name'] ?? _text(f.querySelector('.caption')))
            .trim();
    final label = f.querySelector('.label-info');
    final hidden = (label?.attributes['style'] ?? '').contains('hidden');
    final count = label == null
        ? null
        : hidden
        ? 0
        : int.tryParse(RegExp(r'\d+').stringMatch(label.text) ?? '');
    folders.add(
      StorageFolder(
        id: id,
        name: name,
        desc: _text(f.querySelector('.desc')),
        files: count,
      ),
    );
  }

  final files = <StorageFile>[];
  final headers = [
    for (final th in doc.querySelectorAll('table#files thead th')) _text(th),
  ];
  String cell(List<Element> tds, String header) {
    final i = headers.indexOf(header);
    return i < 0 || i >= tds.length ? '' : _text(tds[i]);
  }

  for (final tr in doc.querySelectorAll('table#files tbody tr')) {
    final id = int.tryParse(tr.attributes['data-id'] ?? '');
    if (id == null) continue;
    final tds = tr.querySelectorAll('td');
    final nameCell = headers.indexOf('Name');
    final small = nameCell >= 0 && nameCell < tds.length
        ? tds[nameCell].querySelector('small')
        : null;
    final note = _text(small);
    small?.remove();
    final name = tr.attributes['data-name'] ?? cell(tds, 'Name');
    files.add(
      StorageFile(
        id: id,
        name: name.trim(),
        changed: cell(tds, 'Änderung'),
        size: cell(tds, 'Größe'),
        note: note,
      ),
    );
  }

  final newFiles = <StorageFile>[];
  for (final tr in doc.querySelectorAll('tr')) {
    if (tr.querySelector('td.new_download') == null) continue;
    final id = int.tryParse(tr.attributes['data-id'] ?? '');
    final name = tr.attributes['data-name'];
    if (id == null || name == null || name.trim().isEmpty) continue;
    newFiles.add(
      StorageFile(
        id: id,
        name: name.trim(),
        note: _text(tr.querySelector('small')),
      ),
    );
  }
  return StorageView(folders: folders, files: files, newFiles: newFiles);
}

/// Bietet die Schule den Dateispeicher an? (App-Liste der Sitzung.)
bool offersStorage(List<dynamic> travelMenu) =>
    travelMenu.any((e) => e is Map && e['link']?.toString() == storageModule);

/// Ordner vom Portal holen.
Future<StorageView> loadStorage(LanisSession session, int folder) async {
  final r = await session.dio.get(
    'https://start.schulportal.hessen.de/dateispeicher.php?a=view&folder=$folder',
  );
  return parseStorage(r.data.toString());
}

// ---- Meldung bei neuen Dateien ---------------------------------------------

/// Schon gemeldete bzw. bekannte neue Dateien (Kennungen) und letzter Blick.
const storageSeenSetting = 'fork/storage-seen';
const storageCheckedSetting = 'fork/storage-checked';

/// Höchstens so oft sieht der Hintergrund nach. Ursache: Die Schule stellt
/// selten Dateien ein; jeder Blick ist eine Anfrage beim Portal.
const storageCheckEvery = Duration(hours: 3);

Set<int> decodeSeen(String? raw) {
  try {
    return {
      for (final v in (jsonDecode(raw ?? '[]') as List)) (v as num).toInt(),
    };
  } catch (_) {
    return {};
  }
}

String encodeSeen(Set<int> ids) => jsonEncode((ids.toList()..sort()));

/// Neue Dateien, die noch nicht gemeldet wurden. [seen] null = erster Blick:
/// dann nichts melden, nur merken (sonst käme beim ersten Lauf eine Meldung
/// über längst bekannte Dateien).
List<StorageFile> unseenFiles(StorageView home, Set<int>? seen) => seen == null
    ? const []
    : [
        for (final f in home.newFiles)
          if (!seen.contains(f.id)) f,
      ];
