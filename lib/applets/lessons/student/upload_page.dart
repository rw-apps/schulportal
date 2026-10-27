import 'dart:async';
import 'package:lanis/fork/demo/demo_entry.dart' show blockedInDemo;

import 'package:dart_date/dart_date.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/lessons/student/upload_dates.dart';
import 'package:lanis/applets/lessons/student/upload_multipart.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/file_picker.dart';
import 'package:lanis/utils/root_nav.dart';
import 'package:lanis/widgets/error_view.dart';

import '../../../utils/file_operations.dart';
import '../../../utils/logger.dart';

class UploadScreen extends ConsumerStatefulWidget {
  final String url;
  final String name;
  final String status;
  const UploadScreen({
    super.key,
    required this.url,
    required this.name,
    required this.status,
  });

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  late Future _future;
  final ValueNotifier<int> _addedFiles = ValueNotifier(
    0,
  ); // Could also use a stream

  final List<MultipartFile> _multipartFiles = [];
  final List<ListTile> _fileWidgets = [];

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
    _addedFiles.dispose();
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

  static const Divider indentedDivider = Divider(indent: 16, endIndent: 16);

  Container uploadStatusContainer(String text) => Container(
    padding: const EdgeInsets.all(12.0),
    margin: const EdgeInsets.only(left: 16, right: 16, top: 4.0, bottom: 4.0),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );

  Container requirementsInfo(List<Widget> widgets, {Color? color}) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4.0),
    padding: const EdgeInsets.symmetric(vertical: 2.0),
    decoration: BoxDecoration(
      color:
          color ?? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: [...widgets]),
  );

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
              appBar: AppBar(title: Text(widget.name)),
              body: AppletErrorView(error: error),
            );
          }

          final data = snapshot.data;
          // Fork: fehlende/unlesbare Felder blenden nur ihre Zeile aus statt
          // die ganze Seite zur Fehlerseite zu machen (upload_dates.dart).
          final dates = UploadDates.tryParse(
            startRaw: data?["start"] as String?,
            deadlineRaw: data?["deadline"] as String?,
            deletionRaw: data?["automatic_deletion"] as String?,
          );
          final startDate = dates.start;
          final endDate = dates.deadline;
          final deleteDate = dates.automaticDeletion;
          final String? deletionText = data?["automatic_deletion"] as String?;
          final DateTime now = DateTime.now();

          final bool filesDeleted =
              deleteDate != null && !now.isBefore(deleteDate);

          final bool isBeforeStart =
              startDate != null && now.isBefore(startDate);

          return Scaffold(
            appBar: AppBar(title: Text(widget.name)),
            floatingActionButton: ValueListenableBuilder(
              valueListenable: _addedFiles,
              builder: (_, filesLength, __) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (filesLength != 0) ...[
                      Column(
                        children: [
                          FloatingActionButton(
                            heroTag: null,
                            // Fork: während des Hochladens gesperrt (_uploading).
                            onPressed: _uploading
                                ? null
                                : () async {
                                    // Fork: in der Demo nicht hochladen.
                                    if (blockedInDemo(context)) return;
                                    if (snapshot.data["upload_multiple_files"] ==
                                            false ||
                                        snapshot.data["upload_any_number_of_times"] ==
                                            false) {
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: Text(
                                              AppLocalizations()
                                                  .uploadNotPossible,
                                            ),
                                            content: Text(
                                              AppLocalizations()
                                                  .multipleOrUnlimitedSubmissionNotSupportedMsg,
                                            ),
                                            actions: [
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.of(context).pop(),
                                                child: Text(
                                                  AppLocalizations().back,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      return;
                                    }

                                    showSnackbar(
                                      text: AppLocalizations()
                                          .tryingToUploadFiles,
                                    );

                                    List<FileStatus> fileStatus;

                                    setState(() => _uploading = true);
                                    try {
                                      // Clone before each attempt: Dio MultipartFile
                                      // streams can only be finalized once (retry after
                                      // a failed upload would otherwise crash).
                                      final uploadFiles = cloneMultipartFiles(
                                        _multipartFiles,
                                      );
                                      fileStatus = await ref
                                          .read(lessonsStudentParserProvider)
                                          .uploadFile(
                                            course: snapshot.data["course_id"],
                                            entry: snapshot.data["entry_id"],
                                            upload: snapshot.data["upload_id"],
                                            file1: uploadFiles[0],
                                            file2: uploadFiles.elementAtOrNull(
                                              1,
                                            ),
                                            file3: uploadFiles.elementAtOrNull(
                                              2,
                                            ),
                                            file4: uploadFiles.elementAtOrNull(
                                              3,
                                            ),
                                            file5: uploadFiles.elementAtOrNull(
                                              4,
                                            ),
                                          );
                                    } on LanisException catch (ex) {
                                      // Fork: Seite verlassen → still beenden statt
                                      // rethrow (unbehandelter Fehler im Callback).
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).hideCurrentSnackBar();
                                        pushInShell(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) {
                                              return Scaffold(
                                                appBar: AppBar(),
                                                body: AppletErrorView(
                                                  error: ex,
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      }
                                      return;
                                    } finally {
                                      if (mounted) {
                                        setState(() => _uploading = false);
                                      }
                                    }

                                    // Fork: _addedFiles ist nach dispose entsorgt –
                                    // ohne diese Prüfung warf das Zurücksetzen unten.
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
                                        onPressed: () {
                                          // We render the Widgets before so we can have a dynamically sized AlertDialog.
                                          final List<ListTile>
                                          fileStatusWidgets = [];

                                          for (final status in fileStatus) {
                                            fileStatusWidgets.add(
                                              ListTile(
                                                leading:
                                                    status.status ==
                                                        "erfolgreich"
                                                    ? const Icon(Icons.done)
                                                    : const Icon(Icons.error),
                                                title: Text(status.name),
                                                subtitle:
                                                    status.message != null &&
                                                        status.message != ""
                                                    ? Text(status.message!)
                                                    : null,
                                              ),
                                            );
                                          }

                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              return AlertDialog(
                                                title: Text(
                                                  AppLocalizations()
                                                      .moreDetails,
                                                ),
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    ...fileStatusWidgets,
                                                  ],
                                                ),
                                                actions: [
                                                  FilledButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(),
                                                    child: Text(
                                                      AppLocalizations().back,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    );

                                    _addedFiles.value = 0;
                                    _multipartFiles.clear();
                                    _fileWidgets.clear();
                                    // Fork: hochgeladen → Kopien im Cache entfernen.
                                    unawaited(clearPickedUploadFiles());

                                    forceReloadPage();
                                  },
                            child: const Icon(Icons.upload),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ],
                    if (filesLength < 5 &&
                        snapshot.data["course_id"] != null) ...[
                      FloatingActionButton.extended(
                        heroTag: null,
                        label: Text(
                          "$filesLength / 5",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        icon: const Icon(Icons.add),
                        // Fork: auch Hinzufügen ist während des Hochladens
                        // gesperrt – der Erfolg leert die Liste und löscht
                        // die Cache-Kopien (clearPickedUploadFiles), eine
                        // währenddessen hinzugefügte Datei wäre verloren.
                        onPressed: _uploading
                            ? null
                            : () async {
                                final List<PickedFile> pickedFiles =
                                    await pickMultipleFiles(
                                      context,
                                      snapshot.data["allowed_file_types"],
                                    );

                                // Fork: Seite während der Auswahl verlassen →
                                // _addedFiles ist entsorgt.
                                if (pickedFiles.isEmpty || !mounted) {
                                  return;
                                }

                                if ((pickedFiles.length + filesLength) > 5) {
                                  showSnackbar(
                                    text: AppLocalizations().maxOfFiveFiles,
                                  );
                                  return;
                                }

                                // Fork: unbekannte Angabe → keine clientseitige
                                // Grenze (upload_dates.dart, parseMaxFileSizeBytes).
                                final num? maxFileSize = parseMaxFileSizeBytes(
                                  snapshot.data["max_file_size"] as String?,
                                );

                                for (final file in pickedFiles) {
                                  if (!snapshot.data["allowed_file_types"]
                                      .contains(file.extension.toUpperCase())) {
                                    showSnackbar(
                                      text:
                                          "${AppLocalizations().fileTypeNotAllowed} (${file.name})",
                                    );
                                    continue;
                                  }

                                  if (maxFileSize != null &&
                                      (file.size ?? 0) > maxFileSize) {
                                    showSnackbar(
                                      text:
                                          "${AppLocalizations().maxFileSizeExceeded} (${file.name})",
                                    );
                                    continue;
                                  }

                                  // Only check for filename like Lanis.
                                  // Fork: Ursache (Prüfung 27.10.26): Das
                                  // `continue` stand in der inneren Schleife über
                                  // _multipartFiles und übersprang nur deren
                                  // nächsten Eintrag – die doppelte Datei wurde
                                  // trotzdem angehängt (und das Entfernen per
                                  // Name traf dann die falsche Zeile).
                                  if (_multipartFiles.any(
                                    (element) => element.filename == file.name,
                                  )) {
                                    showSnackbar(
                                      text:
                                          "${AppLocalizations().fileNameAlreadyExists} (${file.name})",
                                    );
                                    continue;
                                  }

                                  final String? mimeType = file.mimeType;
                                  if (mimeType == null) {
                                    showSnackbar(
                                      text:
                                          "${AppLocalizations().failedToDetectFileType} (${file.name})",
                                    );
                                    continue;
                                  }

                                  final MultipartFile multipartFile = await file
                                      .intoMultipart();
                                  if (!mounted) return;

                                  _multipartFiles.add(multipartFile);
                                  _fileWidgets.add(
                                    ListTile(
                                      title: Text(file.name),
                                      trailing: const Icon(Icons.remove),
                                      onTap: () {
                                        // We need to calculate the index dynamically because you can remove every tile at any index.
                                        // Maybe there is a better way.
                                        int tileIndex = _fileWidgets.indexWhere(
                                          (ListTile element) {
                                            final Text textWidget =
                                                element.title as Text;
                                            final String text =
                                                textWidget.data!;

                                            return text == file.name;
                                          },
                                        );
                                        _fileWidgets.removeAt(tileIndex);
                                        _multipartFiles.removeAt(tileIndex);
                                        _addedFiles.value -= 1;
                                      },
                                    ),
                                  );
                                  _addedFiles.value += 1;
                                }
                              },
                      ),
                    ],
                  ],
                );
              },
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  // Fork: „HH:mm“ statt „hh:mm“. Ursache (Prüfung 27.10.26): „hh“
                  // ist das 12-Stunden-Format ohne AM/PM – 14:00 erschien als
                  // „02:00“. Fehlt ein Datum, entfällt nur seine Zeile.
                  if (startDate != null || endDate != null)
                    requirementsInfo([
                      if (startDate != null)
                        ListTile(
                          title: Text(AppLocalizations().start),
                          subtitle: Text(
                            AppLocalizations().dateTimeString(
                              startDate.format("EEEE"),
                              startDate.format("dd.MM.yyyy"),
                              startDate.format("HH:mm"),
                            ),
                          ),
                          leading: const Icon(Icons.hourglass_top),
                        ),
                      if (endDate != null)
                        ListTile(
                          title: Text(AppLocalizations().end),
                          subtitle: Text(
                            AppLocalizations().dateTimeString(
                              endDate.format("EEEE"),
                              endDate.format("dd.MM.yyyy"),
                              endDate.format("HH:mm"),
                            ),
                          ),
                          leading: const Icon(Icons.hourglass_bottom),
                        ),
                    ]),
                  Visibility(
                    visible:
                        isBeforeStart || snapshot.data["course_id"] != null,
                    child: requirementsInfo([
                      ListTile(
                        title: Text(AppLocalizations().uploadOfMultipleFiles),
                        subtitle: Text(
                          snapshot.data["upload_multiple_files"]
                              ? AppLocalizations().possible
                              : AppLocalizations().notPossible,
                        ),
                        leading: snapshot.data["upload_multiple_files"]
                            ? const Icon(Icons.file_upload)
                            : const Icon(Icons.file_upload_off),
                      ),
                      ListTile(
                        title: Text(AppLocalizations().uploadUnlimitedTimes),
                        subtitle: Text(
                          snapshot.data["upload_any_number_of_times"]
                              ? AppLocalizations().possible
                              : AppLocalizations().notPossible,
                        ),
                        leading: snapshot.data["upload_any_number_of_times"]
                            ? const Icon(Icons.file_upload)
                            : const Icon(Icons.file_upload_off),
                      ),
                    ]),
                  ),
                  Visibility(
                    visible:
                        isBeforeStart || snapshot.data["course_id"] != null,
                    child: requirementsInfo([
                      ListTile(
                        title: Text(
                          "${AppLocalizations().filesVisibleForX}${snapshot.data["visibility"] ?? ""}",
                        ),
                        leading: const Icon(Icons.visibility),
                      ),
                      ListTile(
                        title: Text(AppLocalizations().automaticDeletion),
                        subtitle: deletionText == null
                            ? null
                            : Text(deletionText),
                        leading: const Icon(Icons.delete_forever),
                      ),
                    ]),
                  ),
                  Visibility(
                    visible:
                        !isBeforeStart && snapshot.data["course_id"] == null,
                    child: requirementsInfo([
                      ListTile(
                        title: filesDeleted
                            ? Text(AppLocalizations().filesWereDeleted)
                            : Text(AppLocalizations().automaticDeletion),
                        subtitle: filesDeleted || deletionText == null
                            ? null
                            : Text(deletionText),
                        leading: const Icon(Icons.delete_forever),
                      ),
                    ], color: filesDeleted ? Colors.redAccent : null),
                  ),
                  Visibility(
                    visible:
                        isBeforeStart || snapshot.data["course_id"] != null,
                    child: requirementsInfo([
                      ListTile(
                        title: Text(AppLocalizations().allowedFileTypes),
                        subtitle: Text(
                          snapshot.data["allowed_file_types"]
                              .toString()
                              .substring(
                                1,
                                snapshot.data["allowed_file_types"]
                                        .toString()
                                        .length -
                                    1,
                              ),
                        ),
                        leading: const Icon(Icons.description),
                      ),
                      ListTile(
                        title: Text(AppLocalizations().maxFileSize),
                        subtitle: Text(snapshot.data["max_file_size"]),
                        leading: const Icon(Icons.description),
                      ),
                    ]),
                  ),
                  Visibility(
                    visible: snapshot.data["additional_text"] != null,
                    child: requirementsInfo([
                      if (snapshot.data["additional_text"] != null) ...[
                        ListTile(
                          title: Text(AppLocalizations().moreInformation),
                          subtitle: Text(
                            snapshot.data["additional_text"] ?? "",
                          ),
                          leading: const Icon(Icons.info),
                        ),
                      ],
                    ]),
                  ),
                  if (snapshot.data["public_files"].length != 0) ...[
                    indentedDivider,
                  ],
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: snapshot.data["public_files"].length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(
                          snapshot.data["public_files"][index].name,
                          style: !filesDeleted
                              ? Theme.of(context).textTheme.titleMedium
                              : Theme.of(context).textTheme.bodyLarge,
                        ),
                        subtitle: Text(
                          snapshot.data["public_files"][index].person,
                          style: !filesDeleted
                              ? Theme.of(context).textTheme.bodyMedium
                              : null,
                        ),
                        // Fork: derselbe Weg wie bei den eigenen Dateien
                        // (launchFile). Ursache (Prüfung 27.10.26): Der alte
                        // Weg öffnete die Datei nur im else-Zweig von
                        // context.mounted – also nie, solange die Seite offen
                        // war; ein Fehler beim Laden ließ den Ladedialog ohne
                        // catchError stehen; der Name der Mitschüler-Datei ging
                        // ungefiltert in den Speicherpfad (StorageManager,
                        // „../“). launchFile hat catchError, und
                        // DownloadableFile filtert den Namen (safeFileName).
                        onTap: !filesDeleted
                            ? () => launchFile(
                                context,
                                DownloadableFile(
                                  name:
                                      snapshot.data["public_files"][index].name,
                                  url: Uri.parse(
                                    snapshot.data["public_files"][index].url,
                                  ),
                                ),
                                () {},
                              )
                            : null,
                      );
                    },
                  ),
                  indentedDivider,
                  if (snapshot.data["own_files"].length == 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      margin: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 4.0,
                        bottom: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        AppLocalizations().noSubmissionMsg,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: snapshot.data["own_files"].length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(
                          snapshot.data["own_files"][index].name,
                          style: !filesDeleted
                              ? Theme.of(context).textTheme.titleMedium
                              : Theme.of(context).textTheme.bodyLarge,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              snapshot.data["own_files"][index].time,
                              style: !filesDeleted
                                  ? Theme.of(context).textTheme.bodyMedium
                                  : null,
                            ),
                            if (snapshot.data["own_files"][index].comment !=
                                null)
                              Text(snapshot.data["own_files"][index].comment),
                          ],
                        ),
                        trailing: !filesDeleted
                            ? IconButton(
                                onPressed: () async {
                                  final TextEditingController
                                  passwordController = TextEditingController();
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Text(
                                          AppLocalizations()
                                              .confirmWithPassword,
                                        ),
                                        content: TextField(
                                          obscureText: true,
                                          enableSuggestions: false,
                                          autocorrect: false,
                                          controller: passwordController,
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text(
                                              AppLocalizations().back,
                                            ),
                                          ),
                                          FilledButton(
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              // Fork: ab hier this.context
                                              // (Seite) statt des Dialog-
                                              // Kontexts. Ursache (Prüfung
                                              // 27.10.26): Der Dialog ist nach
                                              // pop entsorgt – context.mounted
                                              // war im Fehlerzweig falsch, der
                                              // Fehler wurde per rethrow
                                              // unbehandelt statt angezeigt.
                                              final pageContext = this.context;
                                              // Fork: in der Demo nicht löschen.
                                              if (blockedInDemo(pageContext)) {
                                                return;
                                              }

                                              showSnackbar(
                                                text: AppLocalizations()
                                                    .tryingToDeleteFiles,
                                              );
                                              String response;
                                              try {
                                                response = await ref
                                                    .read(
                                                      lessonsStudentParserProvider,
                                                    )
                                                    .deleteUploadedFile(
                                                      course: snapshot
                                                          .data["course_id"],
                                                      entry: snapshot
                                                          .data["entry_id"],
                                                      upload: snapshot
                                                          .data["upload_id"],
                                                      file: snapshot
                                                          .data["own_files"][index]
                                                          .index,
                                                      userPasswordEncrypted: () {
                                                        final session = ref
                                                            .read(
                                                              sessionProvider,
                                                            )
                                                            .asData
                                                            ?.value;
                                                        if (session == null) {
                                                          throw ConfigurationException(
                                                            'No active session',
                                                          );
                                                        }
                                                        return session.cryptor
                                                            .encryptString(
                                                              passwordController
                                                                  .text,
                                                            );
                                                      }(),
                                                    );
                                              } on LanisException catch (ex) {
                                                if (pageContext.mounted) {
                                                  ScaffoldMessenger.of(
                                                    pageContext,
                                                  ).hideCurrentSnackBar();
                                                  pushInShell(
                                                    pageContext,
                                                    MaterialPageRoute(
                                                      builder: (context) {
                                                        return Scaffold(
                                                          appBar: AppBar(),
                                                          body: AppletErrorView(
                                                            error: ex,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  );
                                                }
                                                return;
                                              }

                                              String
                                              message = AppLocalizations()
                                                  .unknownErrorWhileDeletingFile;

                                              if (response == "-1") {
                                                message = AppLocalizations()
                                                    .wrongPassword;
                                              } else if (response == "-2") {
                                                message = AppLocalizations()
                                                    .failedToDeleteFile;
                                              } else if (response == "1") {
                                                message = AppLocalizations()
                                                    .fileDeletedSuccessfully;
                                              }

                                              if (!mounted) return;
                                              showSnackbar(
                                                text: "$message ($response)",
                                              );

                                              forceReloadPage();
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Padding(
                                                  padding: EdgeInsets.only(
                                                    right: 4.0,
                                                  ),
                                                  child: Icon(Icons.warning),
                                                ),
                                                Text(
                                                  AppLocalizations()
                                                      .deletePermanently,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                icon: const Icon(Icons.delete),
                              )
                            : null,
                        onLongPress: !filesDeleted
                            ? () {
                                showFileModal(
                                  context,
                                  DownloadableFile(
                                    name:
                                        snapshot.data["own_files"][index].name,
                                    url: Uri.parse(
                                      snapshot.data["own_files"][index].url,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        onTap: !filesDeleted
                            ? () {
                                logger.d(snapshot.data["own_files"][index]);
                                launchFile(
                                  context,
                                  DownloadableFile(
                                    name:
                                        snapshot.data["own_files"][index].name,
                                    url: Uri.parse(
                                      snapshot.data["own_files"][index].url,
                                    ),
                                  ),
                                  () {},
                                );
                              }
                            : null,
                      );
                    },
                  ),
                  indentedDivider,
                  ValueListenableBuilder(
                    valueListenable: _addedFiles,
                    builder: (context, value, _) {
                      if (value == 0 && snapshot.data["course_id"] == null) {
                        if (startDate != null && now.isBefore(startDate)) {
                          // Fork: positive Wartezeit (upload_dates.dart,
                          // uploadWaitingTime) statt now.difference(start).
                          final (amount, unit) = uploadWaitingTime(
                            startDate,
                            now,
                          );
                          final l = AppLocalizations();
                          final String waitingTime =
                              "$amount ${switch (unit) {
                                UploadWaitUnit.day => amount == 1 ? l.day : l.days,
                                UploadWaitUnit.hour => amount == 1 ? l.hour : l.hours,
                                UploadWaitUnit.minute => amount == 1 ? l.minute : l.minutes,
                              }}";

                          return uploadStatusContainer(
                            AppLocalizations().submissionPossibleInX(
                              waitingTime,
                            ),
                          );
                        }

                        return uploadStatusContainer(
                          AppLocalizations().submissionNoLongerPossible,
                        );
                      } else if (value == 0) {
                        return uploadStatusContainer(
                          AppLocalizations().addFilesToUpload,
                        );
                      } else {
                        return Container(
                          margin: const EdgeInsets.only(
                            top: 8,
                            bottom: 8,
                            left: 20,
                            right: 20,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(children: [..._fileWidgets]),
                        );
                      }
                    },
                  ),
                  SizedBox.fromSize(size: const Size(0, 104)),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(widget.name)),
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
