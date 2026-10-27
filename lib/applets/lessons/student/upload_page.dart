import 'dart:async';
import 'package:lanis/fork/demo/demo_entry.dart' show blockedInDemo;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/lessons/student/upload_dates.dart';
import 'package:lanis/applets/lessons/student/upload_multipart.dart';
import 'package:lanis/fork/ui/courses/upload_view.dart';
import 'package:lanis/fork/ui/kit.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/utils/file_picker.dart';
import 'package:lanis/utils/root_nav.dart';
import 'package:lanis/widgets/error_view.dart';

import '../../../utils/file_operations.dart';
import '../../../utils/logger.dart';

/// Fork: Abgabeseite im Aufbau nach Entwurf 3 (Abnahme 27.10.26). Die
/// Anzeige steht in lib/fork/ui/courses/upload_view.dart (UploadView, reine
/// Daten); hier bleiben Laden, Auswahl, Prüfung, Hochladen und Löschen.
class UploadScreen extends ConsumerStatefulWidget {
  final String url;
  final String name;
  final String status;

  /// Fork: Fach/Kurs unter dem Titel (null → „Abgabe“).
  final String? subject;

  /// Fork: Farbe des Kindes (KitPalette.kids) für „erledigt“.
  final int colorIndex;

  const UploadScreen({
    super.key,
    required this.url,
    required this.name,
    required this.status,
    this.subject,
    this.colorIndex = 0,
  });

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

/// Fork: gewählte Datei samt hochladbarer Fassung. Ursache (Abnahme
/// 27.10.26): Vorher zwei parallele Listen (_multipartFiles und ListTiles),
/// das Entfernen suchte die Zeile über den Text des Titels. Jetzt eine
/// Liste, entfernt wird per Index.
class _Picked {
  _Picked(this.view, this.multipart);
  final UploadPick view;
  final MultipartFile multipart;
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  late Future _future;

  final List<_Picked> _picked = [];

  /// Fork: läuft gerade ein Hochladen? Ursache (Prüfung 27.10.26): Der
  /// Hochlade-Knopf blieb während uploadFile aktiv – ein zweites Tippen
  /// schickte dieselben Dateien noch einmal (Portal benennt sie dann um,
  /// „Datei mit gleichem Namen schon vorhanden“). Grenze: schützt nur
  /// innerhalb dieser Seite, nicht gegen eine zweite offene Abgabeseite.
  bool _uploading = false;

  void forceReloadPage() {
    // Fork: nach await aufgerufen (Hochladen, Löschen) – setState auf einer
    // verlassenen Seite warf „setState() called after dispose()“.
    if (!mounted) return;
    setState(() {
      _future = ref
          .read(lessonsStudentParserProvider)
          .getUploadInfo(widget.url);
    });
  }

  @override
  void initState() {
    _future = ref.read(lessonsStudentParserProvider).getUploadInfo(widget.url);
    super.initState();
  }

  @override
  void dispose() {
    // Fork: Kopien der Auswahl beim Verlassen entfernen
    // (file_picker.dart, clearPickedUploadFiles).
    unawaited(clearPickedUploadFiles());
    super.dispose();
  }

  void showSnackbar({required String text, SnackBarAction? action}) {
    if (mounted) {
      // Hide the current SnackBar if one is already visible.
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 6),
          action: action,
        ),
      );
    }
  }

  void _showError(BuildContext pageContext, LanisException ex) {
    if (!pageContext.mounted) return;
    ScaffoldMessenger.of(pageContext).hideCurrentSnackBar();
    pushInShell(
      pageContext,
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(),
            body: AppletErrorView(error: ex),
          );
        },
      ),
    );
  }

  /// Auswahl und Prüfung (Typ, Größe, Anzahl, Name, MIME) wie bisher.
  Future<void> _add(UploadInfo info) async {
    // Fork: auch Hinzufügen ist während des Hochladens gesperrt – der
    // Erfolg leert die Liste und löscht die Cache-Kopien
    // (clearPickedUploadFiles), eine währenddessen hinzugefügte Datei wäre
    // verloren.
    if (_uploading) return;
    final List<PickedFile> pickedFiles = await pickMultipleFiles(
      context,
      info.allowedTypes,
    );

    // Fork: Seite während der Auswahl verlassen.
    if (pickedFiles.isEmpty || !mounted) {
      return;
    }

    // Fork: Grenze je Abgabe 1 bzw. 5 (UploadInfo.maxFiles) statt immer 5.
    if ((pickedFiles.length + _picked.length) > info.maxFiles) {
      showSnackbar(
        text: info.maxFiles == 1
            ? context.t.uploadOnlyOneFile
            : AppLocalizations().maxOfFiveFiles,
      );
      return;
    }

    // Fork: unbekannte Angabe → keine clientseitige Grenze
    // (upload_dates.dart, parseMaxFileSizeBytes).
    final num? maxFileSize = parseMaxFileSizeBytes(info.maxFileSize);

    for (final file in pickedFiles) {
      if (!info.allowedTypes.contains(file.extension.toUpperCase())) {
        showSnackbar(
          text: "${AppLocalizations().fileTypeNotAllowed} (${file.name})",
        );
        continue;
      }

      if (maxFileSize != null && (file.size ?? 0) > maxFileSize) {
        showSnackbar(
          text: "${AppLocalizations().maxFileSizeExceeded} (${file.name})",
        );
        continue;
      }

      // Only check for filename like Lanis.
      // Fork: Ursache (Prüfung 27.10.26): Das `continue` stand in der
      // inneren Schleife über _multipartFiles und übersprang nur deren
      // nächsten Eintrag – die doppelte Datei wurde trotzdem angehängt (und
      // das Entfernen per Name traf dann die falsche Zeile).
      if (_picked.any((p) => p.multipart.filename == file.name)) {
        showSnackbar(
          text: "${AppLocalizations().fileNameAlreadyExists} (${file.name})",
        );
        continue;
      }

      final String? mimeType = file.mimeType;
      if (mimeType == null) {
        showSnackbar(
          text: "${AppLocalizations().failedToDetectFileType} (${file.name})",
        );
        continue;
      }

      final MultipartFile multipartFile = await file.intoMultipart();
      if (!mounted) return;

      setState(
        () => _picked.add(
          _Picked(UploadPick(name: file.name, size: file.size), multipartFile),
        ),
      );
    }
  }

  void _remove(int index) {
    if (_uploading || index < 0 || index >= _picked.length) return;
    setState(() => _picked.removeAt(index));
  }

  Future<void> _submit(Map data, UploadInfo info) async {
    // Fork: während des Hochladens gesperrt (_uploading).
    if (_uploading || _picked.isEmpty) return;
    // Fork: in der Demo nicht hochladen.
    if (blockedInDemo(context)) return;
    // Fork: Ursache (Abnahme 27.10.26, Ein-Datei-Regel): Hier stand ein
    // Hinweisfenster „multipleOrUnlimitedSubmissionNotSupportedMsg“, das
    // JEDE Abgabe mit „mehrere Dateien: nicht erlaubt“ oder „beliebig oft:
    // nicht erlaubt“ ablehnte – auch die erste mit genau einer Datei. Jetzt
    // begrenzt UploadInfo.maxFiles die Auswahl, und nach der einzigen
    // Abgabe zeigt die Seite „erledigt“ statt des Knopfs (UploadInfo.done).
    // Grenze: Ob das Portal eine zweite Abgabe annimmt, entscheidet der
    // Server; ohne Formular (course_id) gibt es den Knopf gar nicht.
    if (_picked.length > info.maxFiles || !info.canSubmit(DateTime.now())) {
      return;
    }

    showSnackbar(text: AppLocalizations().tryingToUploadFiles);

    List<FileStatus> fileStatus;

    setState(() => _uploading = true);
    try {
      // Clone before each attempt: Dio MultipartFile
      // streams can only be finalized once (retry after
      // a failed upload would otherwise crash).
      final uploadFiles = cloneMultipartFiles([
        for (final p in _picked) p.multipart,
      ]);
      fileStatus = await ref
          .read(lessonsStudentParserProvider)
          .uploadFile(
            course: data["course_id"],
            entry: data["entry_id"],
            upload: data["upload_id"],
            file1: uploadFiles[0],
            file2: uploadFiles.elementAtOrNull(1),
            file3: uploadFiles.elementAtOrNull(2),
            file4: uploadFiles.elementAtOrNull(3),
            file5: uploadFiles.elementAtOrNull(4),
          );
    } on LanisException catch (ex) {
      // Fork: Seite verlassen → still beenden statt rethrow (unbehandelter
      // Fehler im Callback).
      if (mounted) _showError(context, ex);
      return;
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }

    // Fork: Seite verlassen → nichts mehr anzeigen oder zurücksetzen.
    if (!mounted) return;

    int successfulUploads = 0;
    bool renamed = false;
    for (final status in fileStatus) {
      if (status.status == "erfolgreich") {
        successfulUploads++;
        if (status.message?.contains(
              "Datei mit gleichem Namen schon vorhanden.",
            ) ==
            true) {
          renamed = true;
        }
      }
    }

    showSnackbar(
      text:
          "$successfulUploads/${fileStatus.length} ${AppLocalizations().xWasUploadedSuccessfully} ${renamed == true ? AppLocalizations().howeverSomeFilesWereRenamed : ''}",
      action: SnackBarAction(
        label: AppLocalizations().seeMore,
        onPressed: () => _showStatus(fileStatus),
      ),
    );

    setState(_picked.clear);
    // Fork: hochgeladen → Kopien im Cache entfernen.
    unawaited(clearPickedUploadFiles());

    forceReloadPage();
  }

  void _showStatus(List<FileStatus> fileStatus) {
    if (!mounted) return;
    final k = Kit.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations().moreDetails),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final status in fileStatus)
                ListTile(
                  leading: Icon(
                    status.status == "erfolgreich" ? Icons.done : Icons.error,
                    color: k.p.muted,
                  ),
                  title: Text(status.name),
                  subtitle: status.message != null && status.message != ""
                      ? Text(status.message!)
                      : null,
                ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations().back),
            ),
          ],
        );
      },
    );
  }

  void _delete(Map data, OwnFile file) {
    final TextEditingController passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations().confirmWithPassword),
          content: TextField(
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            controller: passwordController,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations().back),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                // Fork: ab hier this.context (Seite) statt des Dialog-
                // Kontexts. Ursache (Prüfung 27.10.26): Der Dialog ist nach
                // pop entsorgt – context.mounted war im Fehlerzweig falsch,
                // der Fehler wurde per rethrow unbehandelt statt angezeigt.
                final pageContext = this.context;
                // Fork: in der Demo nicht löschen.
                if (blockedInDemo(pageContext)) {
                  return;
                }

                showSnackbar(text: AppLocalizations().tryingToDeleteFiles);
                String response;
                try {
                  response = await ref
                      .read(lessonsStudentParserProvider)
                      .deleteUploadedFile(
                        course: data["course_id"],
                        entry: data["entry_id"],
                        upload: data["upload_id"],
                        file: file.index,
                        userPasswordEncrypted: () {
                          final session = ref
                              .read(sessionProvider)
                              .asData
                              ?.value;
                          if (session == null) {
                            throw ConfigurationException('No active session');
                          }
                          return session.cryptor.encryptString(
                            passwordController.text,
                          );
                        }(),
                      );
                } on LanisException catch (ex) {
                  if (pageContext.mounted) _showError(pageContext, ex);
                  return;
                }

                String message =
                    AppLocalizations().unknownErrorWhileDeletingFile;

                if (response == "-1") {
                  message = AppLocalizations().wrongPassword;
                } else if (response == "-2") {
                  message = AppLocalizations().failedToDeleteFile;
                } else if (response == "1") {
                  message = AppLocalizations().fileDeletedSuccessfully;
                }

                if (!mounted) return;
                showSnackbar(text: "$message ($response)");

                forceReloadPage();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: Sp.xs),
                    child: Icon(Icons.warning),
                  ),
                  Text(AppLocalizations().deletePermanently),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  DownloadableFile _downloadable(UploadFile f) =>
      DownloadableFile(name: f.name, url: Uri.parse(f.url));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            final error = snapshot.error is LanisException
                ? snapshot.error as LanisException
                : UnknownException(snapshot.error.toString());
            return Scaffold(
              backgroundColor: Kit.of(context).p.bg,
              appBar: uploadAppBar(
                context,
                title: widget.name,
                subtitle: widget.subject,
              ),
              body: AppletErrorView(error: error),
            );
          }

          final Map data = snapshot.data as Map;
          // Fork: fehlende/unlesbare Felder blenden nur ihren Teil aus statt
          // die ganze Seite zur Fehlerseite zu machen (upload_dates.dart,
          // UploadInfo.fromPortal).
          final info = UploadInfo.fromPortal(data);

          return UploadView(
            title: widget.name,
            subtitle: widget.subject,
            info: info,
            now: DateTime.now(),
            colorIndex: widget.colorIndex,
            uploading: _uploading,
            picked: [for (final p in _picked) p.view],
            onAdd: () => _add(info),
            onRemovePicked: _remove,
            onSubmit: () => _submit(data, info),
            onDeleteOwn: (f) => _delete(data, f),
            onLongPressOwn: (f) => showFileModal(context, _downloadable(f)),
            onOpenOwn: (f) {
              logger.d(f);
              launchFile(context, _downloadable(f), () {});
            },
            // Fork: derselbe Weg wie bei den eigenen Dateien (launchFile).
            // Ursache (Prüfung 27.10.26): Der alte Weg öffnete die Datei nur
            // im else-Zweig von context.mounted – also nie, solange die Seite
            // offen war; ein Fehler beim Laden ließ den Ladedialog ohne
            // catchError stehen; der Name der Mitschüler-Datei ging
            // ungefiltert in den Speicherpfad (StorageManager, „../“).
            // launchFile hat catchError, und DownloadableFile filtert den
            // Namen (safeFileName).
            onOpenPublic: (f) => launchFile(context, _downloadable(f), () {}),
          );
        }
        return Scaffold(
          backgroundColor: Kit.of(context).p.bg,
          appBar: uploadAppBar(
            context,
            title: widget.name,
            subtitle: widget.subject,
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

/// Abgabe-URL aus „Mein Unterricht“: relativ („meinunterricht.php?…“) oder
/// https auf start.schulportal.hessen.de mit Pfad meinunterricht.php.
bool isLessonsUploadUrl(String raw) {
  final u = Uri.tryParse(raw.trim());
  if (u == null) return false;
  final path = u.path.replaceFirst(RegExp(r'^/+'), '');
  if (path != 'meinunterricht.php') return false;
  if (!u.hasScheme && u.host.isEmpty) return true;
  return u.scheme == 'https' && u.host == 'start.schulportal.hessen.de';
}
