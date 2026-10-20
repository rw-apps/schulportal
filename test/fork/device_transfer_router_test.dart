import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/fork/device_transfer.dart';
import 'package:lanis/fork/kid_colors.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/settings_transfer.dart';
import 'package:lanis/fork/ui/settings/device_transfer_page.dart';
import 'package:lanis/utils/auth_redirect.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/view/login/screen.dart';

import '../helpers/test_app.dart';

/// Ersteinrichtung per QR-Code mit zwei Konten unter der echten
/// Umleitungslogik (resolveAuthRedirect, ausgelöst wie in router.dart bei
/// jeder Änderung von Anmeldung und Konten).
///
/// Ursache (Prüfung 20.10.26): Die Zustimmung zum Datenschutz kam erst nach
/// dem Anlegen der Konten; der Router leitete dabei nach /privacy-policy um,
/// die Übernahme brach mittendrin ab. Der Abnahme-Test lief ohne Router und
/// tippte nicht auf „Übernehmen“ – daher dieser Test.
void main() {
  tearDown(() {
    LanisClient.reset();
    AuthController.resetDebugAuth();
    debugTransferScanner = null;
  });

  testWidgets('Ersteinrichtung mit zwei Konten endet angemeldet', (t) async {
    installFakeSessionAuth();
    t.view.physicalSize = const Size(1080, 2424);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    void Function(String)? scan;
    debugTransferScanner = (onCode) {
      scan = onCode;
      return const SizedBox();
    };

    late ProviderContainer c;
    await t.pumpWidget(
      ProviderScope(
        overrides: testLanisOverrides(),
        child: Consumer(
          builder: (context, ref, _) {
            c = ProviderScope.containerOf(context);
            return MaterialApp.router(
              locale: const Locale('de'),
              localizationsDelegates: testLocalizationsDelegates,
              supportedLocales: ForkL10n.supportedLocales,
              routerConfig: _router(c),
            );
          },
        ),
      ),
    );
    Future<void> tap(String text) async {
      await t.ensureVisible(find.text(text));
      await t.pump();
      await t.tap(find.text(text));
    }

    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await t.runAsync(() => Future<void>.delayed(Duration.zero));
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    // Wie StartupScreen beim Kaltstart: ohne Konten → /welcome.
    await t.runAsync(
      () => c.read(authControllerProvider.notifier).bootstrapIfNeeded(),
    );
    await settle();
    expect(find.text('startup-marker'), findsNothing);
    final de = forkL10nFor('de');
    await tap(de.devFromOther);
    await settle();

    // Das alte Gerät (hier der Test) verschlüsselt für den gezeigten Code.
    final offer = t.widget<TransferQr>(find.byType(TransferQr)).data;
    final codes = (await t.runAsync(
      () => sealPayload(
        buildDevicePayload(
          const [
            TransferAccount(
              schoolId: 1234,
              schoolName: 'Muster-Gymnasium',
              username: 'eltern.muster',
              password: 'geheim-1',
              accountType: AccountType.parent,
            ),
            TransferAccount(
              schoolId: 1234,
              schoolName: 'Muster-Gymnasium',
              username: 'lena.muster',
              password: 'geheim-2',
              accountType: AccountType.student,
            ),
          ],
          {
            transferAccountKey(1234, 'lena.muster'): {
              kidColorSetting: LanisDatabase.encodeValue('3'),
            },
          },
        ),
        parseOffer(offer)!,
      ),
    ))!;
    await tap(de.devScanData);
    await settle();
    for (final code in codes) {
      scan!(code);
    }
    await settle();
    await tap(de.devPrivacy);
    await t.pump();
    await tap(de.devApply);
    await settle();

    expect(find.text('home-marker'), findsOneWidget);
    expect(c.read(authControllerProvider).phase, AuthPhase.authenticated);
    expect(
      isPrivacyPolicyAccepted(c.read(sharedOverAccountSettingsProvider)),
      isTrue,
    );
    final db = c.read(lanisDatabaseProvider);
    final accounts = await db.listAccounts();
    expect(accounts.map((a) => a.username).toSet(), {
      'eltern.muster',
      'lena.muster',
    });
    final parent = accounts.firstWhere((a) => a.username == 'eltern.muster');
    final lena = accounts.firstWhere((a) => a.username == 'lena.muster');
    expect(
      (await db.getAccount(parent.localId))!.accountType,
      AccountType.parent,
    );
    expect((await db.getAccount(lena.localId))!.password, 'geheim-2');
    expect(
      LanisDatabase.decodeValue(
        db.getAccountSetting(lena.localId, kidColorSetting),
      ),
      '3',
    );
  });
}

GoRouter _router(ProviderContainer c) {
  final refresh = ValueNotifier(0);
  c.listen(authControllerProvider, (_, _) => refresh.value++);
  c.listen(accountsProvider, (_, _) => refresh.value++);
  return GoRouter(
    initialLocation: '/startup',
    refreshListenable: refresh,
    redirect: (context, state) => resolveAuthRedirect(
      phase: c.read(authControllerProvider).phase,
      loc: state.matchedLocation,
      privacyAccepted: isPrivacyPolicyAccepted(
        c.read(sharedOverAccountSettingsProvider),
      ),
      hasAccounts: c.read(accountsProvider).asData?.value.isNotEmpty ?? false,
      isShellPath: false,
      shellSupported: true,
      deepLinkErrorPath: null,
      homePath: () => '/home',
    ),
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeLoginScreen()),
      for (final p in ['/startup', '/privacy-policy', '/login', '/home'])
        GoRoute(
          path: p,
          builder: (_, _) => Scaffold(body: Text('${p.substring(1)}-marker')),
        ),
    ],
  );
}
