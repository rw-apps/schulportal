import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:liblanis/liblanis.dart'
    show StorageManager, storageManagerProvider;
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';

import 'file_icons.dart';
import 'root_nav.dart';
import 'package:lanis/fork_identity.dart';

Future<String> _downloadRemote(
  BuildContext context,
  String url,
  String filename,
) async {
  final storage = ProviderScope.containerOf(
    context,
  ).read(storageManagerProvider);
  if (storage == null) return '';
  return downloadRevalidated(storage, url, filename);
}

/// Wie lange eine gespeicherte Datei ohne neuen Abruf geöffnet wird.
const cachedFileMaxAge = Duration(hours: 1);

/// StorageManager.downloadFile, aber eine gespeicherte Kopie älter als
/// [maxAge] wird neu geladen.
///
/// Ursache (Prüfung 27.10.26, liblanis storage/storage_manager.dart:107–109):
/// Die Bibliothek liefert eine einmal geladene Datei für immer aus dem
/// Speicher (Schlüssel: Adresse + Name). Ersetzt eine Lehrkraft die Datei
/// unter derselben Adresse und demselben Namen, sah man weiter die alte –
/// bis zur Bereinigung nach 30 Tagen (pruneOldFiles, lanis_bootstrap.dart).
/// Jetzt: Ist die Kopie älter als [maxAge], wird sie beiseitegelegt und neu
/// geladen; scheitert das (offline, Sitzung weg), kommt die alte Kopie
/// zurück und wird geöffnet.
///
/// Grenze: Innerhalb von [maxAge] nach dem letzten Laden bleibt es bei der
/// gespeicherten Kopie. Das Portal nennt kein Änderungsdatum je Datei, das
/// sich vergleichen ließe.
Future<String> downloadRevalidated(
  StorageManager storage,
  String url,
  String filename, {
  Duration maxAge = cachedFileMaxAge,
  DateTime? now,
}) async {
  final File cached;
  try {
    cached = File(storage.resolvePath(url, filename));
  } catch (_) {
    return storage.downloadFile(url, filename);
  }
  if (!cached.existsSync() ||
      (now ?? DateTime.now()).difference(cached.lastModifiedSync()) <= maxAge) {
    return storage.downloadFile(url, filename);
  }
  final aside = File('${cached.path}.old');
  try {
    if (aside.existsSync()) aside.deleteSync();
    cached.renameSync(aside.path);
  } catch (_) {
    return storage.downloadFile(url, filename);
  }
  try {
    final path = await storage.downloadFile(url, filename);
    try {
      aside.deleteSync();
    } catch (_) {}
    return path;
  } catch (_) {
    try {
      if (cached.existsSync()) cached.deleteSync();
      aside.renameSync(cached.path);
      return cached.path;
    } catch (_) {}
    rethrow;
  }
}

class DownloadableFile {
  String? name;

  /// The size + the unit. Often enclosed with parentheses.
  String? size;

  /// Remote file URL - null if this is a local file
  Uri? url;

  /// Local file path - null if this is a remote file
  String? localPath;

  /// Gets the file extension from either name or local path
  String get extension {
    if (name != null && name!.contains('.')) {
      return name!.split('.').last;
    } else if (localPath != null && localPath!.contains('.')) {
      return localPath!.split('/').last.split('.').last;
    }
    return "";
  }

  /// Create a file info for a remote file.
  ///
  /// Fork (Sicherheitsprüfung 17.10.26): Der Name kommt vom Server (Portal,
  /// Moodle) und wird Teil des Speicherpfads (StorageManager.resolvePath);
  /// [safeFileName] entfernt Pfadanteile wie „../“.
  DownloadableFile({String? name, this.size, this.url})
    : name = name == null ? null : safeFileName(name, 'datei'),
      localPath = null;

  /// Create a file info for a local file
  DownloadableFile.local({String? name, String? size, required String filePath})
    : this.name = name ?? filePath.split('/').last,
      this.size = size,
      this.localPath = filePath,
      this.url = null;

  /// Returns true if this represents a local file
  bool get isLocal => localPath != null;
}

void showFileModal(BuildContext context, DownloadableFile file) {
  showRootModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 22.0),
                    Icon(getIconByFileExtension(file.extension)),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Text(
                        file.name ?? AppLocalizations.of(context).unknownFile,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      file.size ?? "",
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(width: 22.0),
                  ],
                ),
                SizedBox(height: 8),
                Divider(),
                MenuItemButton(
                  onPressed: () => {launchFile(context, file, () {})},
                  child: Row(
                    children: [
                      Padding(padding: EdgeInsets.only(left: 10.0)),
                      Icon(Icons.open_in_new),
                      Padding(padding: EdgeInsets.only(right: 8.0)),
                      Text(AppLocalizations.of(context).openFile),
                    ],
                  ),
                ),
                if (!Platform.isIOS && !file.isLocal)
                  (MenuItemButton(
                    onPressed: () => {saveFile(context, file, () {})},
                    child: Row(
                      children: [
                        Padding(padding: EdgeInsets.only(left: 10.0)),
                        Icon(Icons.save_alt_rounded),
                        Padding(padding: EdgeInsets.only(right: 8.0)),
                        Text(AppLocalizations.of(context).saveFile),
                      ],
                    ),
                  )),
                if (!Platform.isLinux)
                  (MenuItemButton(
                    onPressed: () => {shareFile(context, file, () {})},
                    child: Row(
                      children: [
                        Padding(padding: EdgeInsets.only(left: 10.0)),
                        Icon(Icons.share_rounded),
                        Padding(padding: EdgeInsets.only(right: 8.0)),
                        Text(AppLocalizations.of(context).shareFile),
                      ],
                    ),
                  )),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void launchFile(
  BuildContext context,
  DownloadableFile file,
  Function callback,
) {
  final String filename = file.name ?? AppLocalizations.of(context).unknownFile;

  if (file.isLocal) {
    // For local files, open directly
    OpenFile.open(file.localPath).then((result) {
      //sketchy, but "open_file" left us no other choice
      if (result.message.contains("No APP found to open this file") &&
          context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("${AppLocalizations.of(context).error}!"),
            icon: const Icon(Icons.error),
            content: Text(AppLocalizations.of(context).noAppToOpen),
            actions: [
              FilledButton(
                child: const Text('Ok'),
                onPressed: () {
                  popRootDialog(context);
                },
              ),
            ],
          ),
        );
      }
      callback();
    });
    return;
  }

  // For remote files, download then open
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => downloadDialog(context, file.size),
  );

  _downloadRemote(context, file.url.toString(), filename)
      .then((filepath) async {
        if (context.mounted) popRootDialog(context);

        if (filepath == "" && context.mounted) {
          showDialog(
            context: context,
            builder: (context) => errorDialog(context),
          );
        } else {
          final result = await OpenFile.open(filepath);
          //sketchy, but "open_file" left us no other choice
          if (result.message.contains("No APP found to open this file") &&
              context.mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text("${AppLocalizations.of(context).error}!"),
                icon: const Icon(Icons.error),
                content: Text(AppLocalizations.of(context).noAppToOpen),
                actions: [
                  FilledButton(
                    child: const Text('Ok'),
                    onPressed: () {
                      popRootDialog(context);
                    },
                  ),
                ],
              ),
            );
          }
          callback();
        }
      })
      .catchError((Object _) {
        if (context.mounted) {
          popRootDialog(context);
          showDialog(
            context: context,
            builder: (context) => errorDialog(context),
          );
        }
      });
}

void saveFile(BuildContext context, DownloadableFile file, Function callback) {
  const platform = MethodChannel('io.github.lanis-mobile/storage');
  final String filename = file.name ?? AppLocalizations.of(context).unknownFile;

  if (file.isLocal) {
    // For local files, just save directly
    platform
        .invokeMethod('saveFile', {
          'fileName': filename,
          'mimeType': lookupMimeType(file.localPath!) ?? "*/*",
          'filePath': file.localPath,
        })
        .then((_) {
          callback();
        });
    return;
  }

  // For remote files, download then save
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => downloadDialog(context, file.size),
  );

  _downloadRemote(context, file.url.toString(), filename)
      .then((filepath) async {
        if (context.mounted) popRootDialog(context);

        if (filepath == "" && context.mounted) {
          showDialog(
            context: context,
            builder: (context) => errorDialog(context),
          );
        } else {
          await platform.invokeMethod('saveFile', {
            'fileName': filename,
            'mimeType': lookupMimeType(filepath) ?? "*/*",
            'filePath': filepath,
          });
          callback();
        }
      })
      .catchError((Object _) {
        if (context.mounted) {
          popRootDialog(context);
          showDialog(
            context: context,
            builder: (context) => errorDialog(context),
          );
        }
      });
}

void shareFile(BuildContext context, DownloadableFile file, Function callback) {
  final String filename = file.name ?? AppLocalizations.of(context).unknownFile;

  if (file.isLocal) {
    // For local files, share directly
    Share.shareXFiles([XFile(file.localPath!)]).then((_) {
      callback();
    });
    return;
  }

  // For remote files, download then share
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => downloadDialog(context, file.size),
  );

  _downloadRemote(context, file.url.toString(), filename)
      .then((filepath) async {
        if (context.mounted) popRootDialog(context);

        if (filepath == "" && context.mounted) {
          showDialog(
            context: context,
            builder: (context) => errorDialog(context),
          );
        } else {
          await Share.shareXFiles([XFile(filepath)]);
          callback();
        }
      })
      .catchError((Object _) {
        if (context.mounted) {
          popRootDialog(context);
          showDialog(
            context: context,
            builder: (context) => errorDialog(context),
          );
        }
      });
}

AlertDialog errorDialog(BuildContext context) => AlertDialog(
  title: Text("${AppLocalizations.of(context).error}!"),
  icon: const Icon(Icons.error),
  content: Text(AppLocalizations.of(context).reportError),
  actions: [
    TextButton(
      onPressed: () {
        safeLaunchUrl(Uri.parse(forkIssuesUrl), context: context);
      },
      child: const Text("GitHub"),
    ),
    FilledButton(
      child: const Text('Ok'),
      onPressed: () {
        popRootDialog(context);
      },
    ),
  ],
);

AlertDialog downloadDialog(BuildContext context, String? fileSize) =>
    AlertDialog(
      title: Text("Download... ${fileSize ?? ""}"),
      content: const Center(
        heightFactor: 1.1,
        child: CircularProgressIndicator(),
      ),
    );

Future<File> moveFile(String originPath, String targetPath) async {
  final originFile = File.fromUri(Uri.file(originPath));
  try {
    return await originFile.rename(targetPath);
  } on FileSystemException catch (_) {
    final newFile = await originFile.copy(targetPath);
    await originFile.delete();
    return newFile;
  }
}

/// Dateiname ohne Pfadanteile und Steuerzeichen; leer, „.“ oder „..“ →
/// [fallback]. Siehe [DownloadableFile] (Fork, Sicherheitsprüfung 17.10.26).
String safeFileName(String raw, String fallback) {
  var n = raw.replaceAll('\\', '/').split('/').last;
  n = n.replaceAll(RegExp(r'[\x00-\x1f]'), '').trim();
  if (n.isEmpty || n == '.' || n == '..') return fallback;
  return n;
}
