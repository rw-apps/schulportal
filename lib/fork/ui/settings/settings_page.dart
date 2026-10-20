import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:webview_flutter/webview_flutter.dart' show WebViewCookieManager;

import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/fork_identity.dart';
import 'package:lanis/fork/start.dart' show firstSupportedHomePath;
import 'package:lanis/utils/safe_launch.dart';
import 'package:lanis/utils/theme_settings.dart';
import 'package:lanis/view/settings/subsettings/debug_export.dart';

import '../../calendar_subscribe.dart';
import '../../class_choice.dart';
import '../../kid_colors.dart';
import '../../error_log.dart';
import '../../l10n/l10n.dart';
import '../font_step.dart';
import '../language.dart';
import '../kit.dart';
import '../live/family.dart';
import '../live/live_data.dart'
    show
        LiveData,
        LiveSnapshot,
        detectedClassName,
        settingsRevision,
        showPhotosSetting;
import 'class_sheet.dart';
import '../today/today_from_lanis.dart' show shortSchoolName;
import 'error_report_page.dart';
import 'transfer_page.dart';

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

  /// Debug-Export erst nach 7× Antippen der Version (Entscheidung 17.10.26):
  /// Er enthält echte Portalseiten und ist ein Werkzeug für Rückfragen.
  /// Grenze: gilt bis zum Verlassen der Seite.
  int _versionTaps = 0;
  bool get _debugUnlocked => _versionTaps >= 7;

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
  }

  static String _nameOf(LanisSession session) =>
      [session.userData['vorname'], session.userData['nachname']].nonNulls
          .where((s) => s.isNotEmpty)
          .join(' ')
          .ifEmpty(session.account.username);

  static String? _typeOf(ForkL10n t, AccountType? type) => switch (type) {
    AccountType.parent => t.parentAccount,
    AccountType.student => t.studentAccount,
    AccountType.teacher => t.teacherAccount,
    _ => null,
  };

  void _tapVersion() {
    if (_debugUnlocked) return;
    setState(() => _versionTaps++);
    if (_debugUnlocked) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t.debugUnlocked)));
    }
  }

  // ---- Konto ---------------------------------------------------------------

  /// „Klasse 9C · automatisch erkannt“ (class_choice.dart); null für
  /// Lehrkräfte und solange keine Daten da sind.
  static String? _classDetail(ForkL10n t, LiveSnapshot? s) {
    if (s == null || s.session.accountTypeOrNull == AccountType.teacher) {
      return null;
    }
    final own = s.classChoice;
    if (own != null) {
      return '${t.classLine(classLabel(own.name))} · '
          '${t.classManualUntil(classUntilLabel(own.until))}';
    }
    final found = detectedClassName(s);
    if (found.isEmpty) return t.classUnknown;
    return '${t.classLine(classLabel(found))} · ${t.classDetected}';
  }

  /// Klasse ändern (class_sheet.dart); null ohne Daten oder für Lehrkräfte.
  VoidCallback? _classTap(FamilyMember? m) {
    final s = m?.snapshot;
    if (m == null ||
        s == null ||
        s.setClass == null ||
        s.session.accountTypeOrNull == AccountType.teacher) {
      return null;
    }
    return () async {
      final t = context.t;
      final r = await showClassSheet(
        context,
        kidName: s.firstName.isEmpty ? t.yourChild : s.firstName,
        school: shortSchoolName(s.schoolName),
        colorIndex: m.colorIndex,
        detected: detectedClassName(s),
        current: s.classChoice?.name ?? '',
        hasEntry: s.classChoice != null,
      );
      if (r == null || !mounted) return;
      s.setClass!(r.name);
    };
  }

  Future<void> _logout(ClearTextAccount account) async {
    final k = Kit.of(context);
    final t = context.t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.logoutQuestion, style: k.sheetTitle),
        content: Text(t.logoutText, style: k.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel, style: k.link),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.logout, style: k.link),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // Wie die bisherige Ansicht (home_page.dart, _logout).
    final router = GoRouter.of(context);
    // Fork (Sicherheitsprüfung 17.10.26): Auf geteilten Familiengeräten
    // sollen nach dem Abmelden keine Dateien und keine Moodle-Anmeldung
    // dieses Kontos zurückbleiben. Grenze: Die WebView-Cookies gelten für
    // alle Konten – andere Konten melden sich in Moodle neu an.
    final cache = ref.read(storageManagerProvider)?.getDocumentCacheDirectory();
    await ref
        .read(authControllerProvider.notifier)
        .removeAccountAndContinue(account.localId);
    try {
      if (cache != null && cache.existsSync()) {
        cache.deleteSync(recursive: true);
      }
      await WebViewCookieManager().clearCookies();
    } catch (_) {}
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
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur[0], minute: cur[1]),
    );
    if (picked == null || !mounted) return;
    shared.setJsonList(key, [picked.hour, picked.minute]);
    setState(() {});
  }

  // ---- Termine abonnieren -----------------------------------------------------

  Future<void> _calendarLink() async {
    final k = Kit.of(context);
    final t = context.t;
    final parser = ref.read(calendarParserProvider);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.subscribeEvents, style: k.sheetTitle),
        content: FutureBuilder(
          future: parser.getExports(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text(t.subscribeFailed, style: k.body);
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
                Text(t.subscribeText, style: k.meta),
                const SizedBox(height: Sp.m),
                SelectableText(link, style: k.body),
                const SizedBox(height: Sp.m),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    safeLaunchUrl(
                      googleCalendarSubscribeUrl(link),
                      context: this.context,
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: Text(t.openInGoogleCalendar, style: k.link),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.copy),
                  label: Text(t.copyAddress, style: k.link),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.close, style: k.link),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final session = ref.watch(sessionProvider).asData?.value;
    final account = ref.watch(activeAccountProvider);
    final accountSettings = ref.watch(accountSpecificSettingsProvider);
    final shared = ref.watch(sharedOverAccountSettingsProvider);
    final supported = ref.watch(supportedAppletPhpUrlsProvider);
    final errors = ErrorLog.instance.records.length;
    final theme = ref.watch(themeSettingsProvider)['theme'] as String;
    final font = ref.watch(fontStepProvider);
    final language = ref.watch(languageProvider);

    final name = session == null ? '' : _nameOf(session);
    final type = _typeOf(t, account?.accountType ?? session?.accountTypeOrNull);
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
    String hm(List<int> v) => '${v[0]}:${v[1].toString().padLeft(2, '0')}';
    bool area(String php) =>
        accountSettings?.getBool('notification-$php') ?? true;
    void setArea(String php, bool v) {
      accountSettings?.setBool('notification-$php', v);
      setState(() {});
    }

    final members = FamilyData.of(context);
    FamilyMember? activeMember;
    for (final m in members) {
      if (m.active) activeMember = m;
    }
    final live = LiveData.of(context);
    if (activeMember == null && live != null) {
      activeMember = FamilyMember(
        accountId: live.session.account.localId,
        snapshot: live,
        colorIndex: 0,
      );
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
                  tooltip: t.back,
                ),
                const SizedBox(width: Sp.xs),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(t.settings, style: k.pageTitle),
                  ),
                ),
              ],
            ),

            _Section(t.sectionAccount, [
              if (account != null)
                _Item(
                  icon: Icons.person_outline,
                  label: name.isEmpty ? account.username : name,
                  detail: [
                    ?type,
                    shortSchoolName(account.schoolName),
                  ].join(' · '),
                  extra: _classDetail(t, activeMember?.snapshot),
                  onTap: _classTap(activeMember),
                ),
              // Weitere Konten der Familienansicht (family.dart) – angemeldet
              // und in Heute/Kalender sichtbar; Einstellungen hier gelten
              // aber nur für das obere, aktive Konto.
              for (final m in FamilyData.of(context))
                if (!m.active)
                  _Item(
                    icon: Icons.person_outline,
                    label: _nameOf(m.snapshot.session),
                    detail: [
                      ?_typeOf(t, m.snapshot.session.accountTypeOrNull),
                      shortSchoolName(m.snapshot.schoolName),
                    ].join(' · '),
                    extra: _classDetail(t, m.snapshot),
                    onTap: _classTap(m),
                  ),
              if (session != null && session.userData.isNotEmpty)
                _Item(
                  icon: Icons.badge_outlined,
                  label: t.userData,
                  detail: t.userDataDetail,
                  onTap: () => _openUserData(session),
                ),
              _Item(
                icon: Icons.switch_account_outlined,
                label: t.switchAccount,
                onTap: () => GoRouter.of(context).push('/accounts'),
              ),
              if (account != null)
                _Item(
                  icon: Icons.logout,
                  label: t.logout,
                  detail: t.logoutDetail,
                  onTap: () => _logout(account),
                ),
            ]),

            // Feste Farbe je Kind (kid_colors.dart, Wunsch 20.10.26); nur
            // mit mehreren Kindern sinnvoll.
            if (members.length > 1)
              _Section(t.kidColorsTitle, [
                for (final m in members)
                  KidColorRow(
                    name: kidLabel(m.snapshot),
                    selected: m.colorIndex,
                    onPick: (c) {
                      storeKidColor(
                        TypedSettings.account(
                          ref.read(lanisDatabaseProvider),
                          m.accountId,
                        ),
                        c,
                      );
                      settingsRevision.value++;
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: Sp.xs),
                  child: Text(t.kidColorsHint, style: k.planMeta(k.p.muted)),
                ),
              ]),

            _Section(t.sectionNotifications, [
              if (!granted)
                _Item(
                  icon: Icons.notifications_off_outlined,
                  label: t.allowNotifications,
                  detail: t.notificationsBlocked,
                  onTap: _askPermission,
                ),
              _Switch(
                label: t.sectionNotifications,
                detail: t.forThisAccount,
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
                  label: t.notifySubstitutions,
                  detail: t.notifySubstitutionsDetail,
                  value: area('vertretungsplan.php'),
                  onChanged: allow && granted
                      ? (v) => setArea('vertretungsplan.php', v)
                      : null,
                ),
              if (supported.contains('nachrichten.php'))
                _Switch(
                  label: t.notifyMessages,
                  value: area('nachrichten.php'),
                  onChanged: allow && granted
                      ? (v) => setArea('nachrichten.php', v)
                      : null,
                ),
              _Item(
                icon: Icons.schedule,
                label: t.timeWindow,
                detail: t.timeWindowDetail,
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

            _Section(t.sectionAppearance, [
              for (final (v, l) in [
                ('system', t.likePhone),
                ('light', t.themeLight),
                ('dark', t.themeDark),
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
                child: Text(t.fontSize, style: k.planMeta(k.p.muted)),
              ),
              for (final step in KitFontStep.values)
                _Choice(
                  label: switch (step) {
                    KitFontStep.small => t.fontSmall,
                    KitFontStep.normal => t.fontNormal,
                    KitFontStep.large => t.fontLarge,
                  },
                  selected: step == font,
                  onTap: () => ref.read(fontStepProvider.notifier).set(step),
                ),
              const SizedBox(height: Sp.s),
              Padding(
                padding: const EdgeInsets.only(left: Sp.xs, bottom: Sp.xs),
                child: Text(t.language, style: k.planMeta(k.p.muted)),
              ),
              // Sprachnamen stehen in ihrer eigenen Sprache (so findet man
              // die eigene auch in einer fremden Oberfläche); nur „Wie das
              // Handy“ wird übersetzt.
              for (final (v, l) in [
                (languageSystem, t.likePhone),
                ('de', 'Deutsch'),
                ('en', 'English'),
                ('tr', 'Türkçe'),
              ])
                _Choice(
                  label: l,
                  selected: language == v,
                  onTap: () => ref.read(languageProvider.notifier).set(v),
                ),
              Padding(
                padding: const EdgeInsets.only(left: Sp.xs, top: Sp.xs),
                child: Text(t.languageNote, style: k.planMeta(k.p.muted)),
              ),
              const SizedBox(height: Sp.s),
              // Profilfoto statt Anfangsbuchstabe (portal_extras.dart);
              // wirkt sofort über settingsRevision (live_data.dart).
              _Switch(
                label: t.showPhotos,
                detail: t.showPhotosDetail,
                value: shared.getBool(showPhotosSetting) ?? true,
                onChanged: (v) {
                  shared.setBool(showPhotosSetting, v);
                  settingsRevision.value++;
                  setState(() {});
                },
              ),
            ]),

            _Section(t.sectionData, [
              _Item(
                icon: Icons.sync_alt,
                label: t.transferTitle,
                detail: t.transferDetail,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const TransferPage()),
                ),
              ),
              if (supported.contains('kalender.php'))
                _Item(
                  icon: Icons.event_available_outlined,
                  label: t.subscribeEvents,
                  detail: t.subscribeEventsDetail,
                  onTap: _calendarLink,
                ),
            ]),

            _Section(t.sectionAbout, [
              _Item(
                icon: Icons.info_outline,
                label: forkAppName,
                detail: [
                  if (_version != null) t.versionValue(_version!),
                  t.unofficial,
                ].join(' · '),
                onTap: _tapVersion,
                trailing: const SizedBox.shrink(),
              ),
              _Item(
                icon: Icons.new_releases_outlined,
                label: t.whatsNew,
                onTap: () => _open(forkLatestReleaseUrl),
              ),
              _Item(
                icon: Icons.privacy_tip_outlined,
                label: t.privacy,
                detail: t.privacyDetail,
                onTap: () => _open(forkPrivacyPolicyUrl),
              ),
              _Item(
                icon: Icons.code,
                label: t.sourceLicense,
                detail: t.sourceLicenseDetail(upstreamName),
                onTap: () => _open(forkRepoUrl),
              ),
              _Item(
                icon: Icons.article_outlined,
                label: t.libraries,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: forkAppName,
                  applicationVersion: _version,
                ),
              ),
            ]),

            _Section(t.sectionDebug, [
              if (errors > 0)
                _Item(
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
                _Item(
                  icon: Icons.check_circle_outline,
                  label: t.noErrors,
                  detail: t.noErrorsDetail,
                ),
              if (_debugUnlocked)
                _Item(
                  icon: Icons.bug_report_outlined,
                  label: t.debugExport,
                  detail: t.debugExportWarning,
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
    this.extra,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? detail;

  /// Dritte Zeile (Klasse des Kindes).
  final String? extra;
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
                    if (extra != null && extra!.isNotEmpty)
                      Text(extra!, style: k.planMeta(k.p.muted)),
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
                  tooltip: context.t.back,
                ),
                const SizedBox(width: Sp.xs),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(context.t.userData, style: k.pageTitle),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.s),
            Text(context.t.userDataNote, style: k.meta),
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

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// Kind mit den vier Farben zum Antippen; die gewählte mit Haken.
class KidColorRow extends StatelessWidget {
  const KidColorRow({
    required this.name,
    required this.selected,
    required this.onPick,
  });

  final String name;
  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    return Material(
      color: k.p.card,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.s),
        child: Row(
          children: [
            Expanded(child: Text(name, style: k.planSubject(k.p.ink))),
            for (var c = 0; c < kidColorCount; c++)
              Semantics(
                selected: c == selected,
                button: true,
                label: t.kidColorPick('${c + 1}'),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onPick(c),
                  child: Padding(
                    padding: const EdgeInsets.all(Sp.xs),
                    child: Container(
                      width: Sz.avatarSmall,
                      height: Sz.avatarSmall,
                      decoration: BoxDecoration(
                        color: k.kid(c).accent,
                        shape: BoxShape.circle,
                      ),
                      child: c == selected
                          ? Icon(Icons.check, size: Sz.icon, color: k.p.card)
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
