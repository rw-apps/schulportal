import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../anon/anon_export.dart';
import '../../error_log.dart';
import '../../l10n/l10n.dart';
import '../kit.dart';

/// Anonymer Export: Aufbau der Portalseiten ohne Namen, Noten und freie
/// Texte (anon_export.dart, anonymizer.dart).
///
/// Ursache (Entscheidung 25.10.26): Damit die App Lehrerkonten und weitere
/// Schulen lesen lernt, braucht sie deren Seitenaufbau; der Debug-Export
/// enthält echte Schülerdaten und darf nicht weitergegeben werden.
///
/// Vor dem Teilen stehen die unveränderten Wörter oben und der Anfang der
/// Datei darunter: So sieht die Person, die exportiert, ob ein Name stehen
/// geblieben ist. Grenze: Die Vorschau zeigt nur den Anfang (große Dateien
/// würden die Seite lähmen); geteilt wird die ganze Datei, die sich in jeder
/// Text-App ansehen lässt.
class AnonExportPage extends ConsumerStatefulWidget {
  const AnonExportPage({super.key, this.version = '', this.initialResult});

  final String version;

  /// Nur für Tests und Bildschirmfotos: Ergebnis ohne Portal.
  @visibleForTesting
  final AnonExport? initialResult;

  @override
  ConsumerState<AnonExportPage> createState() => _AnonExportPageState();
}

class _AnonExportPageState extends ConsumerState<AnonExportPage> {
  static const previewChars = 4000;

  late AnonExport? _result = widget.initialResult;
  (int, int)? _progress;
  File? _file;

  @override
  void dispose() {
    // Die Datei liegt nur für das Teilen im Zwischenspeicher.
    try {
      _file?.deleteSync();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _run() async {
    final t = context.t;
    final messenger = ScaffoldMessenger.of(context);
    final session = ref.read(sessionProvider).asData?.value;
    if (session == null) {
      messenger.showSnackBar(SnackBar(content: Text(t.anonExportNoSession)));
      return;
    }
    setState(() => _progress = (0, 1));
    try {
      final r = await runAnonExport(
        dio: session.dio,
        type: session.accountTypeOrNull,
        schoolId: session.account.schoolID,
        travelMenu: session.travelMenu,
        version: widget.version,
        onProgress: (d, n) {
          if (mounted) setState(() => _progress = (d, n));
        },
      );
      final dir = await getTemporaryDirectory();
      final day = DateTime.now().toIso8601String().substring(0, 10);
      final f = File('${dir.path}/schulportal-anonym-$day.txt');
      await f.writeAsString(r.text);
      if (!mounted) return;
      setState(() {
        _result = r;
        _file = f;
      });
    } catch (e, st) {
      ErrorLog.instance.record('fork/anonym-export', e, st);
      messenger.showSnackBar(SnackBar(content: Text(t.anonExportFailed)));
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _share() async {
    final f = _file;
    if (f == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(f.path, mimeType: 'text/plain')],
        subject: context.t.anonExportTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final r = _result;
    final p = _progress;
    final bottom = MediaQuery.paddingOf(context).bottom;
    Widget box(Widget child) => Container(
      padding: const EdgeInsets.all(Sp.m),
      decoration: BoxDecoration(
        color: k.p.card,
        borderRadius: BorderRadius.circular(Rad.row),
      ),
      child: child,
    );
    return Scaffold(
      backgroundColor: k.p.bg,
      appBar: AppBar(
        backgroundColor: k.p.bg,
        surfaceTintColor: k.p.bg,
        title: Text(t.anonExportTitle, style: k.section),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Sp.page, Sp.s, Sp.page, bottom + Sp.xl),
        children: [
          Text(t.anonExportIntro, style: k.body),
          const SizedBox(height: Sp.s),
          Text(t.anonExportRules, style: k.meta),
          const SizedBox(height: Sp.l),
          if (r == null)
            FilledButton.icon(
              onPressed: p == null ? _run : null,
              icon: p == null
                  ? const Icon(Icons.shield_outlined)
                  : const SizedBox.square(
                      dimension: Sz.navIcon,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
              label: Text(
                p == null ? t.anonExportRun : t.anonExportProgress(p.$1, p.$2),
              ),
            )
          else ...[
            Text(t.anonExportKeptTitle, style: k.section),
            const SizedBox(height: Sp.xs),
            Text(t.anonExportKeptHint, style: k.meta),
            const SizedBox(height: Sp.s),
            box(SelectableText(r.kept.join(', '), style: k.body)),
            const SizedBox(height: Sp.l),
            Text(t.anonExportPreviewTitle, style: k.section),
            const SizedBox(height: Sp.xs),
            Text(
              t.anonExportSize((r.text.length / 1024).ceil()),
              style: k.meta,
            ),
            const SizedBox(height: Sp.s),
            box(
              SelectableText(
                r.text.length > previewChars
                    ? '${r.text.substring(0, previewChars)}\n…'
                    : r.text,
                style: k.planMeta(k.p.ink),
              ),
            ),
            const SizedBox(height: Sp.l),
            FilledButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.share_outlined),
              label: Text(t.shareReport),
            ),
          ],
        ],
      ),
    );
  }
}
