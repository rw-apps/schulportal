import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/fork_identity.dart' show appVersionLabel;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/background_service.dart' show refreshBackgroundService;
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/fork/ui/offline/offline_page.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/onboarding/onboarding_kit.dart';
import 'package:lanis/fork/onboarding/onboarding_pages.dart'
    show notifyAskedDuringSetup;
import 'package:lanis/fork/ui/kit.dart';
import 'package:lanis/fork/portal_fault.dart';
import 'package:lanis/fork/ui/login_errors.dart';

/// Splash / auth progress / recoverable auth errors.
class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  bool _errorSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Fork: Bei der Erstanmeldung fragt NotifyIntroPage (erst erklären,
      // dann fragen); hier nur, wenn schon Konten da sind.
      final hasAccounts = (await ref.read(accountsProvider.future)).isNotEmpty;
      if (hasAccounts && !notifyAskedDuringSetup && mounted) {
        requestPermissions();
      }
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      // In-app login failure may land here already in error (no phase transition).
      if (auth.phase == AuthPhase.error && auth.exception != null) {
        await _showErrorSheet(auth.exception!);
        return;
      }
      final shared = ref.read(sharedOverAccountSettingsProvider);
      final accounts = await ref.read(accountsProvider.future);
      if (!mounted) return;
      // First-time installs accept privacy on the login form instead.
      if (accounts.isNotEmpty && !isPrivacyPolicyAccepted(shared)) {
        context.go('/privacy-policy');
        return;
      }
      // Skip if loginWithAccount already drives auth — must not selectPreferred.
      await ref.read(authControllerProvider.notifier).bootstrapIfNeeded();
    });
  }

  Future<void> _showErrorSheet(LanisException exception) async {
    if (_errorSheetOpen || !mounted) return;
    _errorSheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (sheetContext) => StartupAuthErrorContent(
        exception: exception,
        onRetry: () {
          Navigator.of(sheetContext).pop();
          ref.read(authControllerProvider.notifier).retry();
        },
      ),
    );
    if (mounted) _errorSheetOpen = false;
  }

  void requestPermissions() async {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      // Fork: Erlaubnis evtl. eben erst erteilt – Hintergrundabfrage
      // einrichten (setupBackgroundService, Prüfung 27.10.26); schon
      // eingerichtet, ist der Aufruf wirkungslos.
      await refreshBackgroundService();
      return;
    }
    if (status.isPermanentlyDenied && mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.notifications_outlined),
          title: Text(AppLocalizations.of(context).notifications),
          content: Text(
            AppLocalizations.of(
              context,
            ).systemPermissionForNotificationsExplained,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            TextButton(
              onPressed: () {
                AppSettings.openAppSettings();
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context).settings),
            ),
          ],
        ),
      );
    }
  }

  Widget _splashBody() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset('assets/startup.svg', height: 96, width: 96),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          FutureBuilder(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return Text(
                'v${appVersionLabel(snapshot.data!.version, snapshot.data!.buildNumber)}',
                style: Theme.of(context).textTheme.bodySmall,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.phase == AuthPhase.error && next.exception != null) {
        if (previous?.phase == AuthPhase.error &&
            previous?.exception == next.exception) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showErrorSheet(next.exception!);
        });
      }
    });

    return Scaffold(body: _splashBody());
  }
}

/// Fehler beim Anmelden – im Stil der App, verständlich statt technisch.
///
/// Ursache (Rückmeldung 19.10.26, Bildschirmfoto „Kritischer Fehler! …
/// LoginTimeoutException: Too many failed logins“): Die Vorlage zeigte den
/// englischen Fehlertyp und bat, ihn zu melden – auch bei gesperrtem Konto
/// oder falschem Passwort. Jetzt Überschrift und Erklärung aus
/// loginErrorText; der technische Text nur noch bei unbekannten Fehlern
/// (für eine Meldung), gekürzt auf eine Zeile (technicalLine). Bei
/// abgelehntem Passwort „Passwort ändern“ direkt hier.
class StartupAuthErrorContent extends ConsumerWidget {
  final LanisException exception;
  final VoidCallback onRetry;

  const StartupAuthErrorContent({
    super.key,
    required this.exception,
    required this.onRetry,
  });

  static const _statusUrl =
      'https://info.schulportal.hessen.de/status-des-schulportal-hessen/';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = Kit.of(context);
    final t = context.t;
    final e = exception;
    final msg = loginErrorText(t, e);
    final fault = portalFault(e);
    final wrong =
        fault.kind == FaultKind.wrongCredentials ||
        fault.kind == FaultKind.incomplete;
    final known = fault.kind != FaultKind.other;
    final account = ref.watch(activeAccountProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.xl, Sp.xl, Sp.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                switch (fault.kind) {
                  FaultKind.unreachable => Icons.wifi_off,
                  FaultKind.locked => Icons.lock_clock_outlined,
                  FaultKind.down ||
                  FaultKind.server => Icons.cloud_off_outlined,
                  _ => Icons.error_outline,
                },
                size: Sz.navIcon * 2,
                color: k.p.muted,
              ),
              const SizedBox(height: Sp.m),
              Text(msg.title, style: k.sheetTitle, textAlign: TextAlign.center),
              if (account != null)
                Text(
                  [
                    if (account.schoolName.isNotEmpty) account.schoolName,
                    account.username,
                  ].join(' · '),
                  style: k.meta,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: Sp.m),
              Text(msg.text, style: k.body, textAlign: TextAlign.center),
              if (!known) ...[
                const SizedBox(height: Sp.m),
                SelectableText(
                  technicalLine(e),
                  style: k.meta,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: Sp.xl),
              if (wrong && account != null) ...[
                OnbButton(
                  label: t.passwordChange,
                  icon: Icons.key_outlined,
                  onPressed: () async {
                    final ok = await changeAccountPassword(
                      context,
                      ref,
                      account.localId,
                    );
                    if (ok) onRetry();
                  },
                ),
                const SizedBox(height: Sp.s),
              ],
              OnbButton(
                label: t.loginRetry,
                icon: Icons.refresh,
                strong: !wrong,
                onPressed: onRetry,
              ),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  if (!known)
                    TextButton(
                      onPressed: () => openErrorReport(context),
                      child: Text(t.reportError, style: k.link),
                    ),
                  TextButton(
                    onPressed: () =>
                        safeLaunchUrl(Uri.parse(_statusUrl), context: context),
                    child: Text(t.loginStatusPage, style: k.link),
                  ),
                  // Fork: Link „Konto zurücksetzen“ (ResetAccountPage) entfernt.
                  // Ursache (Prüfung 27.10.26): Er bot neben „Passwort ändern“
                  // (changeAccountPassword) einen zweiten, eigenen Passwort-
                  // weg und entfernte das Konto ohne Rückfrage und ohne
                  // Aufräumen (Cookies, Dateien). Grenze: Entfernen geht
                  // weiter über Einstellungen bzw. die Kontenliste.
                ],
              ),
              // Fork (17.10.26): statt der alten Lanis-Ansichten der zuletzt
              // gespeicherte Stand in der neuen Oberfläche.
              // Portal gestört oder nicht erreichbar (auch Serverfehler,
              // 22.10.26): der zuletzt gespeicherte Stand.
              if (fault.notTheApp) const OfflineEntry(),
            ],
          ),
        ),
      ),
    );
  }
}
