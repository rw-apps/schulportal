import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import 'package:lanis/fork_identity.dart';
import 'package:lanis/utils/safe_launch.dart';

import '../../error_log.dart';
import '../../l10n/l10n.dart';
import '../kit.dart';

/// Erkannte Probleme ansehen, teilen oder auf GitHub melden.
///
/// Ursache „Teilen“ zuerst: Familien und Freunde haben meist kein
/// GitHub-Konto; über Messenger oder Mail geht der Bericht an die Person, die
/// die App betreut. Der Text ist vor dem Senden vollständig sichtbar
/// (ErrorLog.report) – kein verstecktes Anhängsel. Grenze: Ein GitHub-Issue
/// ist öffentlich; der Bericht enthält deshalb nichts außer Version, Bereich,
/// Fehlerart und Code-Stellen.
class ErrorReportPage extends StatefulWidget {
  const ErrorReportPage({super.key, this.log});

  /// Nur für Tests; sonst [ErrorLog.instance].
  final ErrorLog? log;

  @override
  State<ErrorReportPage> createState() => _ErrorReportPageState();
}

class _ErrorReportPageState extends State<ErrorReportPage> {
  ErrorLog get _log => widget.log ?? ErrorLog.instance;

  String get _os {
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return '';
    }
  }

  /// GitHub nimmt Titel und Text als Parameter; lange Adressen scheitern, daher
  /// gekürzt. Grenze: Bei sehr vielen Fehlern fehlen die ältesten im Issue –
  /// „Teilen“ hat immer alles.
  Uri _issueUrl(String text) {
    final body = text.length > 6000 ? '${text.substring(0, 6000)}\n…' : text;
    final first = _log.records.first;
    return Uri.parse('$forkIssuesUrl/new').replace(
      queryParameters: {
        'title': 'Fehler ${first.version}: ${first.area} – ${first.type}',
        'body': '```\n$body\n```',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final text = _log.report(os: _os);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: k.p.bg,
      appBar: AppBar(
        backgroundColor: k.p.bg,
        surfaceTintColor: k.p.bg,
        title: Text(t.errorReportTitle, style: k.section),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Sp.page, Sp.s, Sp.page, bottom + Sp.xl),
        children: [
          Text(t.errorReportIntro, style: k.meta),
          const SizedBox(height: Sp.m),
          Container(
            padding: const EdgeInsets.all(Sp.m),
            decoration: BoxDecoration(
              color: k.p.card,
              borderRadius: BorderRadius.circular(Rad.row),
            ),
            child: SelectableText(text, style: k.planMeta(k.p.ink)),
          ),
          const SizedBox(height: Sp.l),
          FilledButton.icon(
            onPressed: _log.records.isEmpty
                ? null
                : () => SharePlus.instance.share(
                    ShareParams(text: text, subject: t.errorReportTitle),
                  ),
            icon: const Icon(Icons.share_outlined),
            label: Text(t.shareReport),
          ),
          const SizedBox(height: Sp.s),
          OutlinedButton.icon(
            onPressed: _log.records.isEmpty
                ? null
                : () => safeLaunchUrl(
                    _issueUrl(text),
                    context: context,
                    mode: LaunchMode.externalApplication,
                  ),
            icon: const Icon(Icons.open_in_new),
            label: Text(t.reportOnGithub),
          ),
          const SizedBox(height: Sp.s),
          TextButton(
            onPressed: _log.records.isEmpty
                ? null
                : () {
                    _log.clear();
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(t.errorsDeleted)));
                    Navigator.of(context).pop();
                  },
            child: Text(t.deleteErrors, style: k.link),
          ),
        ],
      ),
    );
  }
}
