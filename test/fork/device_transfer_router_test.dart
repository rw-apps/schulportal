import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  for (final granted in [true, false]) {
    testWidgets(
      'Ersteinrichtung mit zwei Konten endet angemeldet '
      '(Benachrichtigungen ${granted ? 'erlaubt' : 'noch nicht erlaubt'})',
      (t) => _firstSetup(t, notificationsGranted: granted),
    );
  }
}

Future<void> _firstSetup(
  WidgetTester t, {
  required bool notificationsGranted,
}) async {
  // Kanal von permission_handler beantworten. Ursache (CI 9379 rot, hier
  // grün): Ohne Antwort ging die Frage an die Test-Engine und kam in
  // echter Zeit zurück – mal rechtzeitig, mal nicht.
  final permissions = const MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    permissions,
    (call) async => switch (call.method) {
      'checkPermissionStatus' => notificationsGranted ? 1 : 0,
      _ => null,
    },
  );
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      permissions,
      null,
    ),
  );
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

  // Warten, bis [f] etwas findet – höchstens ~10 s echte Zeit. Ursache
  // (CI 9379 rot, hier grün): Eine feste Zahl Takte reichte auf dem
  // langsameren CI-Rechner nicht für Schlüssel, sicheren Speicher und
  // Anmeldung. Echte Zeit über runAsync, weil die Kryptografie und der
  // Speicher außerhalb der Testuhr warten.
  Future<void> until(Finder f) async {
    for (var i = 0; i < 500 && f.evaluate().isEmpty; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  // Wie StartupScreen beim Kaltstart: ohne Konten → /welcome.
  await t.runAsync(
    () => c.read(authControllerProvider.notifier).bootstrapIfNeeded(),
  );
  final de = forkL10nFor('de');
  await until(find.text(de.devFromOther));
  await tap(de.devFromOther);
  await until(find.byType(TransferQr));

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
  await until(find.text(de.devScanning));
  for (final code in codes) {
    scan!(code);
  }
  await until(find.text(de.devPrivacy));
  await tap(de.devPrivacy);
  await t.pump();
  await tap(de.devApply);
  if (!notificationsGranted) {
    // Wie nach dem Anmeldeformular: erst erklären (NotifyIntroPage).
    await until(find.text(de.onbNotifyAllow));
    expect(find.text(de.onbNotifyAllow), findsOneWidget);
    await tap(de.later);
  }
  await until(find.text('home-marker'));

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
