import 'dart:io';

import 'package:flutter/material.dart';
import 'package:liblanis/liblanis.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:lanis/view/settings/subsettings/debug_export_presets.dart';

import '../../anon/anon_export.dart';
import '../../error_log.dart';
import '../../l10n/l10n.dart';
import '../../onboarding/onboarding_kit.dart';
import '../../portal_fault.dart';
import '../../report_relay.dart';
import '../kit.dart';

/// Portalseite zu einer Quelle, die die App nicht lesen konnte; null =
/// keine (Nachrichten bewusst nicht: zu persönlich, Aufbau bekannt).
DebugExportHttpRequest? pageRequestFor(String phpUrl, AccountType? type) {
  DebugExportHttpRequest get(String p) =>
      DebugExportHttpRequest(method: 'GET', url: '$sphBase/$p');
  return switch (phpUrl) {
    'stundenplan.php' => get('stundenplan.php'),
    'vertretungsplan.php' => get('vertretungsplan.php'),
    'kalender.php' => get('kalender.php'),
    'meinunterricht.php' => get(
      type == AccountType.teacher
          ? 'meinunterricht.php?jump=no'
          : 'meinunterricht.php',
    ),
    _ => null,
  };
}

String _label(ForkL10n t, String phpUrl) => switch (phpUrl) {
  'stundenplan.php' => t.timetableTitle,
  'vertretungsplan.php' => t.pageSubstitutions,
  'kalender.php' => t.pageCalendar,
  _ => t.pageLessons,
};

/// „Anonym senden“ unter „… ließ sich nicht laden“, nur wenn die App die
/// Seite nicht lesen konnte (FaultKind.other). Ursache (Entwurf 26.10.26):
/// Bei Lehrerkonten und neuen Schulen scheitern die Parser an unbekanntem
/// Aufbau; ein Tipp soll genau diese Seite anonym zur Person bringen, die
/// die App betreut. Bei Störung des Portals oder ohne Verbindung hilft die
/// Seite nicht – dann kein Knopf.
Widget? pageReportButton(
  BuildContext context, {
  required LanisSession session,
  required String phpUrl,
  required Object? error,
}) {
  if (error == null || portalFault(error).kind != FaultKind.other) return null;
  final request = pageRequestFor(phpUrl, session.accountTypeOrNull);
  if (request == null) return null;
  return TextButton(
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Kit.of(context).p.card,
      builder: (_) =>
          PageReportSheet(session: session, phpUrl: phpUrl, request: request),
    ),
    child: Text(context.t.pageReportButton, style: Kit.of(context).link),
  );
}

/// Blatt „Seite anonym senden?“: holt die Seite, zeigt die stehen
/// gebliebenen Wörter (Prüfung auf Namen), dann Senden. Ohne
/// Weiterleitungsdienst (relayConfigured) öffnet Senden das Teilen-Menü.
class PageReportSheet extends StatefulWidget {
  const PageReportSheet({
    super.key,
    required this.session,
    required this.phpUrl,
    required this.request,
    this.initial,
  });

  final LanisSession? session;
  final String phpUrl;
  final DebugExportHttpRequest request;

  /// Nur für Tests: Ergebnis ohne Portal.
  @visibleForTesting
  final AnonExport? initial;

  @override
  State<PageReportSheet> createState() => _PageReportSheetState();
}

class _PageReportSheetState extends State<PageReportSheet> {
  late AnonExport? _result = widget.initial;
  bool _failed = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (_result == null) _load();
  }

  Future<void> _load() async {
    final s = widget.session;
    if (s == null) return;
    try {
      final r = await anonPage(
        dio: s.dio,
        request: widget.request,
        schoolId: s.account.schoolID,
        version: ErrorLog.instance.version,
        label: widget.phpUrl,
      );
      if (mounted) setState(() => _result = r);
    } catch (e, st) {
      ErrorLog.instance.record('fork/anonym-seite', e, st);
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _send() async {
    final r = _result;
    if (r == null) return;
    final t = context.t;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _sending = true);
    if (relayConfigured) {
      final ok = await sendReport(
        kind: 'seite',
        version: ErrorLog.instance.version,
        area: widget.phpUrl,
        text: r.text,
      );
      if (!mounted) return;
      setState(() => _sending = false);
      messenger?.showSnackBar(
        SnackBar(content: Text(ok ? t.pageReportSent : t.pageReportFailed)),
      );
      if (ok) nav.pop();
      return;
    }
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/schulportal-seite.txt');
    await f.writeAsString(r.text);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path, mimeType: 'text/plain')]),
    );
    if (mounted) nav.pop();
  }

  void _preview() {
    final r = _result;
    if (r == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (c) {
          final k = Kit.of(c);
          return Scaffold(
            backgroundColor: k.p.bg,
            appBar: AppBar(
              backgroundColor: k.p.bg,
              title: Text(c.t.anonExportPreviewTitle, style: k.section),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(Sp.page),
              child: SelectableText(r.text, style: k.planMeta(k.p.ink)),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final r = _result;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.pageReportTitle, style: k.sheetTitle),
            const SizedBox(height: Sp.s),
            Text(t.pageReportText(_label(t, widget.phpUrl)), style: k.body),
            const SizedBox(height: Sp.m),
            Container(
              padding: const EdgeInsets.all(Sp.m),
              decoration: BoxDecoration(
                color: k.p.bg,
                borderRadius: BorderRadius.circular(Rad.row),
              ),
              child: _failed
                  ? Text(t.anonExportFailed, style: k.meta)
                  : r == null
                  ? Text(t.pageReportLoading, style: k.meta)
                  : Text(
                      r.kept.isEmpty ? '–' : r.kept.join(', '),
                      style: k.body,
                    ),
            ),
            TextButton(
              onPressed: r == null ? null : _preview,
              child: Text(t.pageReportPreview, style: k.link),
            ),
            const SizedBox(height: Sp.s),
            OnbButton(
              label: t.pageReportSend,
              icon: Icons.send_outlined,
              strong: true,
              onPressed: r == null || _sending ? null : _send,
            ),
            const SizedBox(height: Sp.s),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.cancel, style: k.link),
            ),
          ],
        ),
      ),
    );
  }
}
