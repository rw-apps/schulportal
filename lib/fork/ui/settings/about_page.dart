import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import 'package:lanis/fork_identity.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:lanis/view/settings/subsettings/debug_export.dart';

import '../../error_log.dart';
import '../../l10n/l10n.dart';
import '../kit.dart';
import 'anon_export_page.dart';
import 'error_report_page.dart';
import 'settings_widgets.dart';

/// „Über die App“ als eigene Seite (Entwurf 20.10.26 „verdichtet“):
/// Version, Neuigkeiten, Datenschutz, Quellcode und Lizenz, Bibliotheken,
/// Fehlersuche.
///
/// Ursache für die Unterseite statt fünf Zeilen auf der Hauptseite: Das
/// braucht man selten. Quellcode und Lizenz bleiben aber erreichbar –
/// GPL-3.0 (Grundlage: die Vorlage) verlangt in Programmen mit Oberfläche
/// einen Hinweis auf Lizenz, Gewährleistungsausschluss und Quellcode; die
/// Bibliotheken (MIT, BSD, Apache) verlangen, ihre Lizenztexte mitzuliefern
/// (showLicensePage).
class AboutSettingsPage extends StatefulWidget {
  const AboutSettingsPage({super.key});

  @override
  State<AboutSettingsPage> createState() => _AboutSettingsPageState();
}

class _AboutSettingsPageState extends State<AboutSettingsPage> {
  String? _version;

  /// Debug-Export erst nach 7× Antippen der Version (Entscheidung 17.10.26):
  /// Er enthält echte Portalseiten und ist ein Werkzeug für Rückfragen.
  /// Grenze: gilt bis zum Verlassen der Seite.
  int _versionTaps = 0;
  bool get _debugUnlocked => _versionTaps >= 7;

  @override
  void initState() {
    super.initState();
    // Ohne Plattform (Tests) wirft das; dann eben ohne Version.
    PackageInfo.fromPlatform()
        .then((i) {
          if (mounted) {
            setState(() => _version = '${i.version}+${i.buildNumber}');
          }
        })
        .catchError((Object _) {});
  }

  void _tapVersion() {
    if (_debugUnlocked) return;
    setState(() => _versionTaps++);
    if (_debugUnlocked) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t.debugUnlocked)));
    }
  }

  Future<void> _open(String url) => safeLaunchUrl(
    Uri.parse(url),
    context: context,
    mode: LaunchMode.externalApplication,
  );

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final errors = ErrorLog.instance.records.length;
    return SettingsScaffold(
      title: t.sectionAbout,
      children: [
        SettingsSection(
          title: forkAppName,
          children: [
            SettingsRow(
              icon: Icons.info_outline,
              label: forkAppName,
              detail: [
                if (_version != null) t.versionValue(_version!),
                t.unofficial,
              ].join(' · '),
              onTap: _tapVersion,
              chevron: false,
            ),
            SettingsRow(
              icon: Icons.new_releases_outlined,
              label: t.whatsNew,
              onTap: () => _open(forkLatestReleaseUrl),
            ),
            SettingsRow(
              icon: Icons.privacy_tip_outlined,
              label: t.privacy,
              detail: t.privacyDetail,
              onTap: () => _open(forkPrivacyPolicyUrl),
            ),
            SettingsRow(
              icon: Icons.code,
              label: t.sourceLicense,
              detail: t.sourceLicenseDetail(upstreamName),
              onTap: () => _open(forkRepoUrl),
            ),
            SettingsRow(
              icon: Icons.article_outlined,
              label: t.libraries,
              onTap: () => showLicensePage(
                context: context,
                applicationName: forkAppName,
                applicationVersion: _version,
              ),
            ),
          ],
        ),
        SettingsSection(
          title: t.sectionDebug,
          children: [
            if (errors > 0)
              SettingsRow(
                icon: Icons.error_outline,
                label: t.errorsFound(errors),
                detail: t.errorsFoundDetail,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ErrorReportPage(),
                    ),
                  );
                  if (mounted) setState(() {});
                },
              )
            else
              SettingsRow(
                icon: Icons.check_circle_outline,
                label: t.noErrors,
                detail: t.noErrorsDetail,
              ),
            // Fork (26.10.26): Seitenaufbau ohne Namen und Noten – damit die
            // App Lehrerkonten und weitere Schulen lesen lernt. Sichtbar für
            // alle, nicht hinter den sieben Tipps des Debug-Exports: Wer
            // exportieren soll, muss den Weg ohne Anleitung finden.
            SettingsRow(
              icon: Icons.shield_outlined,
              label: t.anonExportTitle,
              detail: t.anonExportDetail,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AnonExportPage(version: _version ?? ''),
                ),
              ),
            ),
            if (_debugUnlocked)
              SettingsRow(
                icon: Icons.bug_report_outlined,
                label: t.debugExport,
                detail: t.debugExportWarning,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const DebugExport()),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Kleiner Baustein für den Hinweis auf Fehler auf der Hauptseite.
Widget errorsRow(BuildContext context, int errors, VoidCallback onBack) {
  final k = Kit.of(context);
  final t = context.t;
  return SettingsRow(
    icon: Icons.error_outline,
    ink: k.p.cancel.ink,
    label: t.errorsFound(errors),
    detail: t.errorsFoundDetail,
    onTap: () async {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ErrorReportPage()));
      onBack();
    },
  );
}
