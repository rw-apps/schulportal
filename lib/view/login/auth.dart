import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/onboarding/onboarding_kit.dart';
import 'package:lanis/fork/onboarding/onboarding_pages.dart';
import 'package:lanis/fork/ui/kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lanis/fork/start.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/utils/logger.dart';
import 'package:lanis/utils/glitchtip.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:lanis/view/login/school_selector.dart';

class LoginForm extends ConsumerStatefulWidget {
  final bool showBackButton;
  const LoginForm({required this.showBackButton, super.key});

  @override
  ConsumerState<LoginForm> createState() => LoginFormState();
}

class LoginFormState extends ConsumerState<LoginForm> {
  static const double padding = 10.0;

  final _formKey = GlobalKey<FormState>();

  TextEditingController schoolIDController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool dseAgree = false;
  bool errorReportingAgree = false;
  String selectedSchoolName = "";

  /// Bei der Ersteinrichtung bereits angelegte Konten (Anzeige „Schule ·
  /// Benutzer“). Ursache (Wunsch 17.10.26): Familien mit Kindern an
  /// verschiedenen Schulen sollen alle Zugänge gleich nacheinander eingeben,
  /// statt später über Einstellungen → Konten. Grenze: Nur bei der ersten
  /// Anmeldung; „Konto hinzufügen“ aus dem Kontowechsel endet wie bisher nach
  /// einem Konto.
  final _added = <String>[];

  /// Neu erzeugt den Schulwähler je Runde (ValueKey), damit er leer beginnt.
  int _round = 0;

  @override
  void initState() {
    super.initState();
    // Mirror the device-wide GlitchTip choice when adding another account.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shared = ref.read(sharedOverAccountSettingsProvider);
      setState(() {
        errorReportingAgree = isGlitchTipEnabled(shared);
      });
    });
  }

  void login(String username, String password, String schoolID) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).logInTitle),
        content: const Center(
          heightFactor: 1.2,
          child: CircularProgressIndicator(),
        ),
      ),
    );
    try {
      final schoolId = int.parse(schoolID);
      final accounts = await ref.read(accountsProvider.future);
      final firstSetup = accounts.isEmpty || _added.isNotEmpty;
      if (accounts.any(
        (a) => a.schoolID == schoolId && a.username == username,
      )) {
        throw AccountAlreadyExistsException();
      }

      // Login checkbox is the first-time privacy acceptance for new accounts.
      final shared = ref.read(sharedOverAccountSettingsProvider);
      acceptPrivacyPolicy(shared);
      setGlitchTipEnabled(shared, errorReportingAgree);

      final config = ref.read(lanisConfigProvider);
      await LanisSession.getLoginURL(
        ClearTextAccount(
          localId: -1,
          schoolID: schoolId,
          username: username,
          password: password,
          schoolName: "",
        ),
        config,
      );

      final newID = await ref
          .read(accountsProvider.notifier)
          .add(
            schoolId: schoolId,
            username: username,
            password: password,
            schoolName: selectedSchoolName,
          );
      final ok = await ref
          .read(authControllerProvider.notifier)
          .loginWithAccount(newID, removeAccountOnFailure: true);
      if (!mounted) return;
      Navigator.pop(context); // pop dialog
      if (ok) {
        if (!firstSetup) {
          context.go(firstSupportedHomePath(ref));
          return;
        }
        _added.add(
          '${selectedSchoolName.isEmpty ? schoolID : selectedSchoolName} · $username',
        );
        final more = await _askForAnother();
        if (!mounted) return;
        if (more == true) {
          setState(() {
            _round++;
            schoolIDController.clear();
            usernameController.clear();
            passwordController.clear();
            selectedSchoolName = '';
          });
          return;
        }
        // Schritt 2: Benachrichtigungen erklären, dann fragen – nur wenn
        // Android sie noch nicht erlaubt hat (NotifyIntroPage).
        final home = firstSupportedHomePath(ref);
        if (await Permission.notification.isGranted) {
          if (mounted) context.go(home);
          return;
        }
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (page) =>
                NotifyIntroPage(onDone: () => Navigator.of(page).pop()),
          ),
        );
        if (mounted) context.go(home);
        return;
      }
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      final cause =
          auth.exception?.cause ?? AppLocalizations.of(context).unknownError;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context).error),
          content: Text(cause),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (ex, s) {
      logger.e(ex, stackTrace: s);

      String cause = "";
      if (ex is LanisException) {
        cause = ex.cause;
      } else {
        if (mounted) {
          cause = AppLocalizations.of(context).unknownError;
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // pop dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context).error),
          content: Text(cause),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  /// „Konto eingerichtet“ als eigene Seite (Entwurf 18.10.26) statt des
  /// Dialogs; true = weiteres Konto.
  Future<bool?> _askForAnother() => Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => AccountAddedPage(accounts: List.of(_added)),
    ),
  );

  @override
  void dispose() {
    schoolIDController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fork (Entwurf 18.10.26): Formular im Stil der App (onboarding_kit.dart)
    // statt Lanis-Standard; Logik (login, Prüfung, Schulwahl) unverändert.
    final k = Kit.of(context);
    final t = context.t;
    final l = AppLocalizations.of(context);
    final firstSetup =
        ref.watch(accountsProvider).value?.isEmpty == true || _added.isNotEmpty;
    final ready = schoolIDController.text.isNotEmpty;
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: OnbPage(
          step: firstSetup ? t.onbStep(1, 2) : null,
          onBack: widget.showBackButton && _added.isEmpty
              ? () {
                  // Welcome uses go('/login') (no stack); account switcher uses push.
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/welcome');
                  }
                }
              : null,
          top: [
            const SizedBox(height: Sp.m),
            if (firstSetup)
              Text(
                OnbPage.upper(t.onbAccountNumber(_added.length + 1)),
                style: k.dateCaps,
              ),
            const SizedBox(height: Sp.xs),
            Text(
              _added.isEmpty ? t.onbLoginTitle : t.anotherAccountTitle,
              style: k.pageTitle,
            ),
            const SizedBox(height: Sp.s),
            Text(t.onbLoginText, style: k.meta),
            const SizedBox(height: Sp.xl),
            SchoolSelector(
              key: ValueKey(_round),
              controller: schoolIDController,
              outContext: context,
              onSchoolSelected: (name) {
                selectedSchoolName = name;
                setState(() {});
              },
            ),
            const SizedBox(height: Sp.m),
            TextFormField(
              controller: usernameController,
              enabled: ready,
              autofillHints: const [AutofillHints.username],
              autocorrect: false,
              style: k.body,
              decoration: onbInput(
                k,
                label: l.authUsernameHint,
                icon: Icons.person_outline,
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? l.authValidationError : null,
            ),
            const SizedBox(height: Sp.m),
            TextFormField(
              controller: passwordController,
              enabled: ready,
              autofillHints: const [AutofillHints.password],
              autocorrect: false,
              obscureText: true,
              style: k.body,
              decoration: onbInput(
                k,
                label: l.authPasswordHint,
                icon: Icons.lock_outline,
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? l.authValidationError : null,
            ),
            const SizedBox(height: Sp.m),
            InkWell(
              onTap: ready ? () => setState(() => dseAgree = !dseAgree) : null,
              child: Row(
                children: [
                  Checkbox(
                    value: dseAgree,
                    onChanged: ready
                        ? (v) => setState(() => dseAgree = v ?? false)
                        : null,
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: k.meta,
                        children: [
                          TextSpan(text: l.authIAccept),
                          TextSpan(
                            text: l.authTermsOfService,
                            style: k.link,
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => safeLaunchUrl(
                                Uri.parse(privacyPolicyUrl),
                                context: context,
                              ),
                          ),
                          TextSpan(text: l.authOfLanisMobile),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          bottom: [
            Row(
              children: [
                Icon(Icons.shield_outlined, size: Sz.icon, color: k.p.muted),
                const SizedBox(width: Sp.s),
                Expanded(child: Text(t.onbStoredHint, style: k.meta)),
              ],
            ),
            const SizedBox(height: Sp.l),
            OnbButton(
              label: l.logIn,
              onPressed: dseAgree && ready
                  ? () {
                      if (_formKey.currentState!.validate()) {
                        login(
                          usernameController.text.toLowerCase(),
                          passwordController.text,
                          schoolIDController.text,
                        );
                      }
                    }
                  : null,
            ),
            const SizedBox(height: Sp.s),
            Center(
              child: TextButton(
                onPressed: ready
                    ? () => safeLaunchUrl(
                        Uri.parse(
                          "https://start.schulportal.hessen.de/benutzerverwaltung.php?a=userPWreminder&i=${schoolIDController.text}",
                        ),
                        context: context,
                      )
                    : null,
                child: Text(l.authResetPassword, style: k.link),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
