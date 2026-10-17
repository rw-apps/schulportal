import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/fork_identity.dart';
import 'package:lanis/home_page.dart' show firstSupportedHomePath;
import 'package:lanis/utils/safe_launch.dart';
import 'package:lanis/utils/theme_settings.dart';
import 'package:lanis/view/settings/subsettings/cache.dart' show CacheSettings;
import 'package:lanis/view/settings/subsettings/debug_export.dart';

import '../font_step.dart';
import '../kit.dart';
import '../today/today_from_lanis.dart' show shortSchoolName;

/// Einstellungen im Stil der neuen Oberfläche (Entscheidung 17.10.26).
///
/// Ursache: Die Lanis-Einstellungen sahen anders aus als der Rest und
/// enthielten für Eltern Überflüssiges (Farbschemata, Moodle, Mitwirkende,
/// Stundenplan-Anpassung). Geblieben ist: Konto, Benachrichtigungen,
/// Darstellung, Daten, Über die App, Fehlersuche. Grenze: Der Debug-Export
/// öffnet weiter die bisherige Seite – er ist ein Werkzeug für Rückfragen,
/// kein Alltagsteil.
class ForkSettingsPage extends ConsumerStatefulWidget {
  const ForkSettingsPage({super.key});

  @override
  ConsumerState<ForkSettingsPage> createState() => _ForkSettingsPageState();
}

class _ForkSettingsPageState extends ConsumerState<ForkSettingsPage> {
  PermissionStatus? _permission;
  String? _version;
  int? _cacheBytes;
  bool _debugOpen = false;

  @override
  void initState() {
    super.initState();
    // Ohne Plattform (Tests) werfen beide; die Seite zeigt dann eben keine
    // Version und nimmt die Erlaubnis als erteilt an.
    Permission.notification.status
        .then((s) {
          if (mounted) setState(() => _permission = s);
        })
        .catchError((Object _) {});
    PackageInfo.fromPlatform()
        .then((i) {
          if (mounted) {
            setState(() => _version = '${i.version}+${i.buildNumber}');
          }
        })
        .catchError((Object _) {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _readCache());
  }

  void _readCache() {
    final dir = ref.read(storageManagerProvider)?.getDocumentCacheDirectory();
    if (dir == null || !mounted) return;
    setState(() => _cacheBytes = CacheSettings.dirStatSync(dir.path)['size']);
  }

  Future<void> _clearCache() async {
    final dir = ref.read(storageManagerProvider)?.getDocumentCacheDirectory();
    if (dir != null && dir.existsSync()) dir.deleteSync(recursive: true);
    _readCache();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Zwischenspeicher geleert')));
    }
  }

  // ---- Konto ---------------------------------------------------------------

  Future<void> _logout(ClearTextAccount account) async {
    final k = Kit.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Abmelden?', style: k.sheetTitle),
        content: Text(
          'Das Konto wird von diesem Gerät entfernt, auch gespeicherte '
          'Gruppenwahl und Lehrernamen. Zum Wiederkommen meldest du dich '
          'neu an.',
          style: k.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Abbrechen', style: k.link),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Abmelden', style: k.link),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // Wie die bisherige Ansicht (home_page.dart, _logout).
    final router = GoRouter.of(context);
    await ref
        .read(authControllerProvider.notifier)
        .removeAccountAndContinue(account.localId);
    if (!mounted) return;
    final phase = ref.read(authControllerProvider).phase;
    router.go(
      phase == AuthPhase.authenticated
          ? firstSupportedHomePath(ref)
          : '/welcome',
    );
  }

  void _openUserData(LanisSession session) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _UserDataPage(data: session.userData),
      ),
    );
  }

  // ---- Benachrichtigungen ---------------------------------------------------

  Future<void> _askPermission() async {
    final s = await Permission.notification.request();
    if (s.isPermanentlyDenied) await openAppSettings();
    final now = await Permission.notification.status;
    if (mounted) setState(() => _permission = now);
  }

  Future<void> _pickTime(
    TypedSettings shared,
    String key,
    List<int> cur,
  ) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur[0], minute: cur[1]),
    );
    if (t == null) return;
    shared.setJsonList(key, [t.hour, t.minute]);
    setState(() {});
  }

  // ---- Termine abonnieren -----------------------------------------------------

  Future<void> _calendarLink() async {
    final k = Kit.of(context);
    final parser = ref.read(calendarParserProvider);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Termine abonnieren', style: k.sheetTitle),
        content: FutureBuilder(
          future: parser.getExports(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text(
                'Die Abo-Adresse ließ sich nicht laden.',
                style: k.body,
              );
            }
            final link = snap.data?.subscriptionLink;
            if (link == null) {
              return const SizedBox(
                height: Sz.button,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mit dieser Adresse übernimmt dein Kalender (z. B. Google '
                  'Kalender: „Weitere Kalender“ → „Per URL“) die Schultermine '
                  'und hält sie aktuell.',
                  style: k.meta,
                ),
                const SizedBox(height: Sp.m),
                SelectableText(link, style: k.body),
                const SizedBox(height: Sp.m),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.copy),
                  label: Text('Adresse kopieren', style: k.link),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Schließen', style: k.link),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final session = ref.watch(sessionProvider).asData?.value;
    final account = ref.watch(activeAccountProvider);
    final accountSettings = ref.watch(accountSpecificSettingsProvider);
    final shared = ref.watch(sharedOverAccountSettingsProvider);
    final supported = ref.watch(supportedAppletPhpUrlsProvider);
    final theme = ref.watch(themeSettingsProvider)['theme'] as String;
    final font = ref.watch(fontStepProvider);

    final name = [
      session?.userData['vorname'],
      session?.userData['nachname'],
    ].nonNulls.where((s) => s.isNotEmpty).join(' ');
    final type = switch (account?.accountType ?? session?.accountTypeOrNull) {
      AccountType.parent => 'Elternkonto',
      AccountType.student => 'Schülerkonto',
      AccountType.teacher => 'Lehrkraft',
      _ => null,
    };
    final allow = accountSettings?.getBool('notifications-allow') ?? true;
    final granted = _permission?.isGranted ?? true;
    final start = [
      for (final v in shared.getJsonList('notifications-start-time') ?? [6, 0])
        v as int,
    ];
    final end = [
      for (final v in shared.getJsonList('notifications-end-time') ?? [21, 0])
        v as int,
    ];
    String hm(List<int> t) => '${t[0]}:${t[1].toString().padLeft(2, '0')}';
    bool area(String php) =>
        accountSettings?.getBool('notification-$php') ?? true;
    void setArea(String php, bool v) {
      accountSettings?.setBool('notification-$php', v);
      setState(() {});
    }

    return Scaffold(
      backgroundColor: k.p.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(Sp.page, Sp.m, Sp.page, bottom + Sp.xl),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.arrow_back, color: k.p.ink),
                  tooltip: 'Zurück',
                ),
                const SizedBox(width: Sp.xs),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('Einstellungen', style: k.pageTitle),
                  ),
                ),
              ],
            ),

            _Section('Konto', [
              if (account != null)
                _Item(
                  icon: Icons.person_outline,
                  label: name.isEmpty ? account.username : name,
                  detail: [
                    ?type,
                    shortSchoolName(account.schoolName),
                  ].join(' · '),
                ),
              if (session != null && session.userData.isNotEmpty)
                _Item(
                  icon: Icons.badge_outlined,
                  label: 'Benutzerdaten',
                  detail: 'Was das Portal über dieses Konto führt',
                  onTap: () => _openUserData(session),
                ),
              _Item(
                icon: Icons.switch_account_outlined,
                label: 'Konto wechseln oder hinzufügen',
                onTap: () => GoRouter.of(context).push('/accounts'),
              ),
              if (account != null)
                _Item(
                  icon: Icons.logout,
                  label: 'Abmelden',
                  detail: 'Entfernt das Konto von diesem Gerät',
                  onTap: () => _logout(account),
                ),
            ]),

            _Section('Benachrichtigungen', [
              if (!granted)
                _Item(
                  icon: Icons.notifications_off_outlined,
                  label: 'Benachrichtigungen erlauben',
                  detail: 'Das Handy blockiert sie gerade für diese App',
                  onTap: _askPermission,
                ),
              _Switch(
                label: 'Benachrichtigungen',
                detail: 'Für dieses Konto',
                value: allow && granted,
                onChanged: granted
                    ? (v) {
                        accountSettings?.setBool('notifications-allow', v);
                        setState(() {});
                      }
                    : null,
              ),
              if (supported.contains('vertretungsplan.php'))
                _Switch(
                  label: 'Ausfall, Vertretung, große Termine',
                  detail: 'Heute sofort, für morgen ab 19 Uhr',
                  value: area('vertretungsplan.php'),
                  onChanged: allow && granted
                      ? (v) => setArea('vertretungsplan.php', v)
                      : null,
                ),
              if (supported.contains('nachrichten.php'))
                _Switch(
                  label: 'Neue Nachrichten',
                  value: area('nachrichten.php'),
                  onChanged: allow && granted
                      ? (v) => setArea('nachrichten.php', v)
                      : null,
                ),
              _Item(
                icon: Icons.schedule,
                label: 'Zeitfenster',
                detail: 'Außerhalb ist Ruhe',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () =>
                          _pickTime(shared, 'notifications-start-time', start),
                      child: Text(hm(start), style: k.link),
                    ),
                    Text('–', style: k.meta),
                    TextButton(
                      onPressed: () =>
                          _pickTime(shared, 'notifications-end-time', end),
                      child: Text(hm(end), style: k.link),
                    ),
                  ],
                ),
              ),
            ]),

            _Section('Darstellung', [
              for (final (v, l) in const [
                ('system', 'Wie das Handy'),
                ('light', 'Hell'),
                ('dark', 'Dunkel'),
              ])
                _Choice(
                  label: l,
                  selected: theme == v,
                  onTap: () {
                    shared.setString('theme', v);
                    notifyThemeChanged(ref);
                  },
                ),
              const SizedBox(height: Sp.s),
              Padding(
                padding: const EdgeInsets.only(left: Sp.xs, bottom: Sp.xs),
                child: Text('Schriftgröße', style: k.planMeta(k.p.muted)),
              ),
              for (final step in KitFontStep.values)
                _Choice(
                  label: step.label,
                  selected: step == font,
                  onTap: () => ref.read(fontStepProvider.notifier).set(step),
                ),
            ]),

            _Section('Daten', [
              if (supported.contains('kalender.php'))
                _Item(
                  icon: Icons.event_available_outlined,
                  label: 'Termine abonnieren',
                  detail: 'Schultermine im eigenen Kalender',
                  onTap: _calendarLink,
                ),
              _Item(
                icon: Icons.cleaning_services_outlined,
                label: 'Zwischenspeicher leeren',
                detail: _cacheBytes == null
                    ? 'Geladene Dateien aus Kursen und Nachrichten'
                    : '${(_cacheBytes! / (1024 * 1024)).toStringAsFixed(1)} MB',
                onTap: _clearCache,
              ),
            ]),

            _Section('Über die App', [
              _Item(
                icon: Icons.info_outline,
                label: forkAppName,
                detail: [
                  if (_version != null) 'Version $_version',
                  'inoffiziell, nicht vom Land Hessen',
                ].join(' · '),
              ),
              _Item(
                icon: Icons.new_releases_outlined,
                label: 'Neu in dieser Version',
                onTap: () => _open(forkLatestReleaseUrl),
              ),
              _Item(
                icon: Icons.privacy_tip_outlined,
                label: 'Datenschutz',
                detail: 'Kein eigener Server – alles bleibt auf dem Handy',
                onTap: () => _open(forkPrivacyPolicyUrl),
              ),
              _Item(
                icon: Icons.code,
                label: 'Quellcode und Lizenz',
                detail: 'Freie Software (GPL-3.0), Grundlage $upstreamName',
                onTap: () => _open(forkRepoUrl),
              ),
              _Item(
                icon: Icons.article_outlined,
                label: 'Verwendete Bibliotheken',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: forkAppName,
                  applicationVersion: _version,
                ),
              ),
            ]),

            _Section('Fehlersuche', [
              _Item(
                icon: _debugOpen ? Icons.expand_less : Icons.expand_more,
                label: 'Für Rückfragen bei Problemen',
                onTap: () => setState(() => _debugOpen = !_debugOpen),
              ),
              if (_debugOpen)
                _Item(
                  icon: Icons.bug_report_outlined,
                  label: 'Debug-Export',
                  detail: 'Protokoll zum Weitergeben, Passwörter geschwärzt',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DebugExport(),
                    ),
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _open(String url) => safeLaunchUrl(
    Uri.parse(url),
    context: context,
    mode: LaunchMode.externalApplication,
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Sp.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Sp.xs, bottom: Sp.s),
            child: Text(title, style: k.section),
          ),
          for (final c in children)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: c,
            ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    this.detail,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Material(
      color: k.p.card,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.signal),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.m),
          child: Row(
            children: [
              Icon(icon, size: Sz.navIcon, color: k.p.ink),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: k.planSubject(k.p.ink)),
                    if (detail != null && detail!.isNotEmpty)
                      Text(detail!, style: k.planMeta(k.p.muted)),
                  ],
                ),
              ),
              ?trailing,
              if (trailing == null && onTap != null)
                Icon(Icons.chevron_right, size: Sz.icon, color: k.p.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.label,
    required this.value,
    required this.onChanged,
    this.detail,
  });

  final String label;
  final String? detail;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Material(
      color: k.p.card,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rad.signal),
        ),
        title: Text(
          label,
          style: k.planSubject(onChanged == null ? k.p.muted : k.p.ink),
        ),
        subtitle: detail == null
            ? null
            : Text(detail!, style: k.planMeta(k.p.muted)),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Material(
      color: selected ? k.kid(0).tint : k.p.card,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.signal),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.m),
          child: Row(
            children: [
              Expanded(child: Text(label, style: k.planSubject(k.p.ink))),
              if (selected)
                Icon(Icons.check, size: Sz.icon, color: k.kid(0).label),
            ],
          ),
        ),
      ),
    );
  }
}

/// Benutzerdaten des Portals, so wie es sie führt (nur lesen).
class _UserDataPage extends StatelessWidget {
  const _UserDataPage({required this.data});

  final Map<String, String> data;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    String label(String key) => key.isEmpty
        ? key
        : '${key[0].toUpperCase()}${key.substring(1)}'.replaceAll('_', ' ');
    return Scaffold(
      backgroundColor: k.p.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(Sp.page, Sp.m, Sp.page, bottom + Sp.xl),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.arrow_back, color: k.p.ink),
                  tooltip: 'Zurück',
                ),
                const SizedBox(width: Sp.xs),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('Benutzerdaten', style: k.pageTitle),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.s),
            Text(
              'Was das Schulportal über dieses Konto führt. Ändern lässt es '
              'sich nur im Portal selbst.',
              style: k.meta,
            ),
            const SizedBox(height: Sp.l),
            for (final e in data.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Sp.l,
                    vertical: Sp.m,
                  ),
                  decoration: BoxDecoration(
                    color: k.p.card,
                    borderRadius: BorderRadius.circular(Rad.signal),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label(e.key), style: k.planMeta(k.p.muted)),
                      SelectableText(e.value, style: k.body),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
