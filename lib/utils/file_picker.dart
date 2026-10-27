import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lanis/fork/ui/kit.dart';
import 'package:lanis/utils/file_operations.dart';
import 'package:lanis/utils/logger.dart';
import 'package:lanis/utils/root_nav.dart';

import '../generated/l10n.dart';

class PickedFile {
  String name;

  /// The size in bytes (is 0 if something went wrong)
  num? size;

  String? path;

  String get extension => name.split('.').last;

  /// May be null if no mimeType was found
  String? get mimeType => lookupMimeType(path!);

  DioMediaType? get mediaType => DioMediaType.parse(mimeType!);

  PickedFile({required this.name, this.size, this.path});
}

extension Actions on PickedFile {
  Future<MultipartFile> intoMultipart() async {
    return await MultipartFile.fromFile(
      path!,
      filename: name,
      contentType: mediaType,
    );
  }
}

/// Allows the user to pick multiple files using any supported method (only Gallery and File Manager support multiple files)
Future<List<PickedFile>> pickMultipleFiles(
  BuildContext context,
  List<String>? allowedExtensions,
) async {
  List<bool> allowedMethods = [true, true, true];
  return showPickerUI(context, allowedMethods, allowedExtensions);
}

/// Allowed Methods (Position in [List<bool>]):
/// ```
/// 0 = File Manager
/// 1 = Camera
/// 2 = Gallery (iOS Only)
/// ```
Future<List<PickedFile>> showPickerUI(
  BuildContext context,
  List<bool> allowedMethods,
  List<String>? allowedExtensions,
) async {
  List<PickedFile> pickedFiles = [];
  if (context.mounted) {
    // Fork: Auswahl im Kit-Stil (Abnahme 27.10.26, Abgabeseite Entwurf 3):
    // Grund k.p.bg, je Weg eine kompakte Zeile mit Symbol im runden Feld.
    // Ursache: Die MenuItemButtons mit handgesetzten Abständen passten nicht
    // zur neuen Abgabeseite. Ablauf (Wege, Schließen nach Auswahl) wie
    // vorher.
    final k = Kit.of(context);
    await showRootModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: k.p.bg,
      builder: (context) {
        Widget row(IconData icon, String label, Future<void> Function() pick) =>
            _PickerRow(
              icon: icon,
              label: label,
              onTap: () async {
                await pick();
                if (context.mounted && pickedFiles.isNotEmpty) {
                  Navigator.pop(context);
                }
              },
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, Sp.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (allowedMethods[0])
                  row(
                    Icons.folder_open_outlined,
                    AppLocalizations.of(context).fileManager,
                    () async => pickedFiles.addAll(
                      await pickFileUsingDocumentsUI(allowedExtensions),
                    ),
                  ),
                if (allowedMethods[1])
                  row(
                    Icons.photo_camera_outlined,
                    AppLocalizations.of(context).camera,
                    () async {
                      final result = await pickFileUsingCamera(context);
                      if (result != null) pickedFiles.add(result);
                    },
                  ),
                // DocumentsUI supports galleries and the photo picker is
                // horrible (from a user perspective)
                if (allowedMethods[2] && Platform.isIOS)
                  row(
                    Icons.photo_library_outlined,
                    AppLocalizations.of(context).gallery,
                    () async => pickedFiles.addAll(
                      await pickFilesUsingGallery(context),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  return pickedFiles;
}

Future<List<PickedFile>> pickFileUsingDocumentsUI(
  List<String>? allowedExtensions,
) async {
  List<PlatformFile> files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    allowMultiple: true,
  );
  List<PickedFile> returnResult = [];

  for (final file in files) {
    returnResult.add(
      PickedFile(name: file.name, path: file.path, size: await file.length()),
    );
  }

  return returnResult;
}

Future<PickedFile?> pickFileUsingCamera(BuildContext context) async {
  final ImagePicker imagePicker = ImagePicker();
  final XFile? image;
  try {
    image = await imagePicker.pickImage(source: ImageSource.camera);
  } on PlatformException catch (e) {
    logger.w('Camera pick failed: ${e.code}');
    return null;
  }
  String? path = image?.path;

  if (path == null) {
    return null;
  }

  if (context.mounted) {
    String? name = await askFileName(context);

    if (name == null) {
      return null;
    }

    // Fork: eindeutiger Ordner je Bild, Name ohne Pfadanteile. Ursache
    // (Prüfung 27.10.26): Das Foto lag als „<Cache>/<Name>.jpg“ – zwei Fotos
    // mit demselben eingegebenen Namen überschrieben einander, der erste
    // Eintrag der Abgabeliste lud dann das zweite Bild hoch; ein „/“ im
    // Namen landete im Pfad. Aufräumen: clearPickedUploadFiles().
    name = pickedPhotoName(name, path);
    String newPath = await _uniquePickPath(name);
    await moveFile(path, newPath);

    return PickedFile(
      name: newPath.split("/").last,
      path: newPath,
      size: await File(newPath).length(),
    );
  }

  return null;
}

/// This will return an empty list if called on anything other than iOS
Future<List<PickedFile>> pickFilesUsingGallery(BuildContext context) async {
  List<PickedFile> result = [];
  if (Platform.isIOS) {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images;
    try {
      images = await picker.pickMultiImage();
    } on PlatformException catch (e) {
      logger.w('Gallery pick failed: ${e.code}');
      return result;
    }

    if (context.mounted) {
      final name = await askFileName(context);

      if (name == null) {
        return result;
      }

      for (final (i, image) in images.indexed) {
        // Fork: wie bei der Kamera eindeutiger Ordner; bei mehreren Bildern
        // „Name_1“, „Name_2“ … Ursache (Prüfung 27.10.26): Alle Bilder einer
        // Auswahl landeten unter demselben „<Cache>/<Name>.<ext>“ und
        // überschrieben einander.
        final path = await _uniquePickPath(
          pickedPhotoName(
            name,
            image.path,
            index: images.length > 1 ? i + 1 : null,
          ),
        );
        await moveFile(image.path, path);
        final file = File(path);
        final size = await file.length();

        result.add(
          PickedFile(
            name: file.path.split("/").last,
            size: size,
            path: file.path,
          ),
        );
      }
    }
  }
  return result;
}

/// Fork: Dateiname eines Kamera-/Galeriebilds aus der Eingabe [entered]
/// und der Endung des Originals [originalPath]; Pfadanteile entfernt
/// (safeFileName), leere Eingabe → Name des Originals. [index] hängt bei
/// Mehrfachauswahl „_1“, „_2“ … an. Grenze: Gleiche Namen über mehrere
/// Auswahlen hinweg lehnt erst die Abgabeseite ab (fileNameAlreadyExists).
String pickedPhotoName(String entered, String originalPath, {int? index}) {
  final original = originalPath.replaceAll('\\', '/').split('/').last;
  final dot = original.lastIndexOf('.');
  final ext = dot > 0 ? original.substring(dot + 1) : '';
  final originalBase = dot > 0 ? original.substring(0, dot) : original;
  var base = safeFileName(entered, '');
  if (base.isEmpty) base = safeFileName(originalBase, 'image');
  if (index != null) base = '${base}_$index';
  return ext.isEmpty ? base : '$base.$ext';
}

/// Fork: Unterordner im App-Cache für Kamera-/Galeriebilder der Abgabe.
const String pickedUploadDirName = 'lanis_upload_picks';

int _pickSeq = 0;

/// Fork: eigener Ordner je Bild, damit gleiche Namen einander nicht
/// überschreiben (siehe pickFileUsingCamera).
Future<String> _uniquePickPath(String name) async {
  final cache = (await getApplicationCacheDirectory()).path;
  final dir = Directory(
    '$cache/$pickedUploadDirName/'
    '${DateTime.now().microsecondsSinceEpoch}_${_pickSeq++}',
  );
  await dir.create(recursive: true);
  return '${dir.path}/$name';
}

/// Fork: entfernt die Kopien der Abgabe-Auswahl – Kamera-/Galeriebilder
/// ([pickedUploadDirName]) und die Kopien des Dateimanagers
/// (FilePicker.clearTemporaryFiles, Android „cache/file_picker“).
/// Ursache (Prüfung 27.10.26): Beide blieben für immer im Cache, jede
/// Abgabe mit Fotos wuchs den App-Speicher um die Bildgröße. Aufgerufen
/// nach erfolgreichem Hochladen und beim Verlassen der Abgabeseite
/// (upload_page.dart). Grenze: clearTemporaryFiles räumt auch eine gerade
/// laufende Auswahl einer anderen Seite (transfer_page.dart liest die Datei
/// sofort nach der Auswahl, ist also nicht betroffen); Fehler werden nur
/// protokolliert.
Future<void> clearPickedUploadFiles() async {
  try {
    final cache = (await getApplicationCacheDirectory()).path;
    final dir = Directory('$cache/$pickedUploadDirName');
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (e) {
    logger.w('Clearing picked upload photos failed: $e');
  }
  try {
    await FilePicker.clearTemporaryFiles();
  } catch (e) {
    logger.w('Clearing file picker cache failed: $e');
  }
}

Future<String?> askFileName(BuildContext context) async {
  String? result;
  final TextEditingController controller = TextEditingController();

  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(AppLocalizations.of(context).filename),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            child: Text(AppLocalizations.of(context).cancel),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          FilledButton(
            child: Text(AppLocalizations.of(context).confirm),
            onPressed: () {
              Navigator.of(context).pop();
              result = controller.text;
            },
          ),
        ],
      );
    },
  );

  return result;
}

/// Fork: eine Zeile der Auswahl (showPickerUI): Karte, Symbol im runden
/// Feld, Beschriftung tileTitle – wie „Datei oder Foto hinzufügen“ auf der
/// Abgabeseite (upload_view.dart, _AddRow).
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.s),
      child: Material(
        color: k.p.card,
        borderRadius: BorderRadius.circular(Rad.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Sp.m),
            child: Row(
              children: [
                Container(
                  width: Sz.avatar,
                  height: Sz.avatar,
                  decoration: BoxDecoration(
                    color: k.p.inset,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: k.p.ink, size: Sz.navIcon),
                ),
                const SizedBox(width: Sp.m),
                Expanded(child: Text(label, style: k.tileTitle)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
