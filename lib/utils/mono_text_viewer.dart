import 'dart:io';

import 'package:flutter/material.dart';

import 'file_operations.dart';

class MonoTextViewer extends StatelessWidget {
  const MonoTextViewer({
    super.key,
    required this.report,
    required this.title,
    required this.fileNameStart,
  });

  final String report;
  final String title;
  final String fileNameStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 8.0,
          right: 8.0,
          top: 8.0,
          bottom: 100.0,
        ),
        child: SelectableText(
          report,
          style: TextStyle(fontFamily: 'monospace', fontSize: 10),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        label: Text('Export Report File'),
        icon: Icon(Icons.save_alt),
        onPressed: () {
          final fileName =
              '${fileNameStart}_${DateTime.now().toIso8601String()}.txt';
          // Fork (Sicherheitsprüfung 17.10.26): Frühere Berichte entfernen –
          // sie enthalten Portal-Antworten mit persönlichen Daten und
          // blieben sonst unbegrenzt im App-Speicher liegen.
          removeOldReports(Directory.systemTemp, fileNameStart);
          final file = File('${Directory.systemTemp.path}/$fileName');
          file
              .writeAsString(report)
              .then((_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Report saved to ${file.path}')),
                  );
                }
              })
              .catchError((e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save report: $e')),
                  );
                }
              });
          showFileModal(
            context,
            DownloadableFile.local(
              filePath: file.path,
              name: fileName,
              size: "",
            ),
          );
        },
      ),
    );
  }
}

/// Löscht ältere Berichtsdateien `<prefix>_*.txt` in [dir]. Fehler werden
/// ignoriert (der neue Bericht ist wichtiger als das Aufräumen).
void removeOldReports(Directory dir, String prefix) {
  try {
    for (final f in dir.listSync()) {
      final name = f.path.split('/').last;
      if (f is File && name.startsWith('${prefix}_') && name.endsWith('.txt')) {
        f.deleteSync();
      }
    }
  } catch (_) {}
}
