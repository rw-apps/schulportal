import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../error_log.dart';
import '../../l10n/l10n.dart';
import '../../settings_transfer.dart';
import '../kit.dart';
import '../live/live_data.dart' show settingsRevision;

/// „Eingaben übertragen“: Datei mit den Eingaben aller Konten senden bzw.
/// auf diesem Gerät übernehmen (settings_transfer.dart).
///
/// Ursache Datei statt QR-Code: Ein QR-Code braucht zum Lesen die Kamera
/// und ein weiteres Paket; die Datei geht über jeden Messenger, Mail oder
/// Quick Share und reicht, weil sich die Eingaben selten ändern.
class TransferPage extends ConsumerStatefulWidget {
  const TransferPage({super.key});

  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends ConsumerState<TransferPage> {
  bool _busy = false;

  Future<List<AccountSummary>> _accounts() => ref.read(accountsProvider.future);

  Future<void> _send() async {
    final t = context.t;
    setState(() => _busy = true);
    try {
      final values = collectTransferValues(
        ref.read(lanisDatabaseProvider),
        await _accounts(),
      );
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/schulportal-eingaben.json');
      await f.writeAsString(buildTransfer(values, now: DateTime.now()));
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(f.path, mimeType: 'application/json')],
          subject: t.transferTitle,
          text: t.transferShareText,
        ),
      );
    } catch (e, st) {
      ErrorLog.instance.record('fork/eingaben-senden', e, st);
      _snack(t.transferFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _receive() async {
    final t = context.t;
    String text;
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      final path = files.firstOrNull?.path;
      if (path == null) return;
      text = await File(path).readAsString();
    } catch (e, st) {
      ErrorLog.instance.record('fork/eingaben-lesen', e, st);
      _snack(t.transferFailed);
      return;
    }
    final data = parseTransfer(text);
    if (data == null) {
      _snack(t.transferNotOurs);
      return;
    }
    final accounts = await _accounts();
    final byKey = {
      for (final a in accounts) transferAccountKey(a.schoolID, a.username): a,
    };
    final matched = [
      for (final k in data.keys)
        if (byKey[k] != null && data[k]!.isNotEmpty) byKey[k]!,
    ];
    final skipped = data.keys.where((k) => byKey[k] == null).length;
    if (!mounted) return;
    if (matched.isEmpty) {
      _snack(t.transferNoMatch);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.transferApplyTitle),
        content: Text(
          [
            t.transferApplyText(
              matched
                  .map(
                    (a) =>
                        a.schoolName.isEmpty ? '${a.schoolID}' : a.schoolName,
                  )
                  .join(', '),
            ),
            if (skipped > 0) t.transferSkipped(skipped),
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(t.transferApply),
          ),
        ],
      ),
    );
    if (ok != true) return;
    applyTransferValues(ref.read(lanisDatabaseProvider), data, matched);
    settingsRevision.value++;
    _snack(t.transferDone);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    return Scaffold(
      backgroundColor: k.p.bg,
      appBar: AppBar(
        backgroundColor: k.p.bg,
        surfaceTintColor: k.p.bg,
        title: Text(t.transferTitle, style: k.section),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.page, Sp.s, Sp.page, Sp.xl),
        children: [
          Text(t.transferIntro, style: k.body),
          const SizedBox(height: Sp.m),
          Text(t.transferWhat, style: k.meta),
          const SizedBox(height: Sp.xl),
          FilledButton.icon(
            onPressed: _busy ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: k.p.strong,
              foregroundColor: k.p.onStrong,
              minimumSize: const Size.fromHeight(Sz.button),
            ),
            icon: const Icon(Icons.ios_share),
            label: Text(t.transferSend),
          ),
          const SizedBox(height: Sp.m),
          OutlinedButton.icon(
            onPressed: _busy ? null : _receive,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(Sz.button),
              side: BorderSide(color: k.p.line),
              foregroundColor: k.p.ink,
            ),
            icon: const Icon(Icons.file_download_outlined),
            label: Text(t.transferReceive),
          ),
          const SizedBox(height: Sp.l),
          Text(t.transferLimit, style: k.meta),
        ],
      ),
    );
  }
}
