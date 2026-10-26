import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lanis/fork/demo/demo_mode.dart';
import 'package:lanis/fork/l10n/l10n.dart' show ForkL10n;
import 'package:liblanis/liblanis.dart' show LanisClient;
import 'package:riverpod/misc.dart' show Override;
import 'package:lanis/fork/ui/font_step.dart';
import 'package:lanis/fork/ui/language.dart';
import 'package:lanis/applets/conversations/view/shared.dart';
import 'package:lanis/background_service.dart';
import 'package:lanis/bridge/lanis_bootstrap.dart';
import 'package:lanis/bridge/legacy_storage_cleanup.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/router.dart';
import 'package:lanis/themes.dart';
import 'package:lanis/utils/glitchtip.dart';
import 'package:lanis/utils/logger.dart';
import 'package:lanis/utils/mono_text_viewer.dart';
import 'package:lanis/utils/phoenix.dart';
import 'package:lanis/utils/theme_settings.dart';
import 'package:lanis/view/startup_error_view.dart';
import 'package:lanis/fork_identity.dart';

Future<void> main() async {
  // Fork: Lizenz der eingebauten Schrift Manrope (OFL 1.1 verlangt, dass der
  // Lizenztext mit der App ausgeliefert wird); erscheint unter
  // Einstellungen → Über → Lizenzen.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('fonts/manrope/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Manrope'], text);
  });
  await initGlitchTip(_startApp);
}

Future<void> _startApp() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    if (kReleaseMode) {
      ErrorWidget.builder = (FlutterErrorDetails details) {
        return errorWidget(details);
      };
    }

    await removeLegacyV3StorageArtifacts();
    final overrides = await bootstrapLanisClient();
    syncGlitchTipReportingFromConfig();
    // Fork (26.10.26): Demo starten/beenden baut die App mit anderen
    // Overrides neu auf (fork/demo/demo_mode.dart).
    restartApp = _relaunch;

    enableTransparentNavigationBar();

    try {
      await setupBackgroundService();
      await initializeNotifications();
    } catch (e, stack) {
      logger.e('Failed to initialize background service and notifications');
      logger.e(e, stackTrace: stack);
      await captureGlitchTipException(e, stackTrace: stack);
    }

    await initializeDateFormatting();

    _run(overrides);
  } catch (e, st) {
    logger.e(e, stackTrace: st);
    await captureGlitchTipException(e, stackTrace: st);

    runApp(
      MaterialApp(
        home: Scaffold(
          body: StartupErrorView(
            errorDetails: FlutterErrorDetails(exception: e, stack: st),
          ),
        ),
      ),
    );
  }
}

void _run(List<Override> overrides) => runApp(
  ProviderScope(
    key: UniqueKey(),
    overrides: overrides,
    child: Phoenix(child: const App()),
  ),
);

/// Demo starten ([demo] gesetzt) oder beenden. Ursache: liblanis hält die
/// Einstellung (Datenbank, Netzadapter) statisch (LanisClient.configure);
/// ein Wechsel braucht neue Overrides und einen neuen ProviderScope. Der
/// Hintergrunddienst bleibt unberührt.
Future<void> _relaunch({DemoChoice? demo}) async {
  LanisClient.reset();
  if (demo == null) leaveDemo();
  final overrides = demo == null
      ? await bootstrapLanisClient()
      : await bootstrapDemoClient(demo);
  _run(overrides);
}

Future<void> enableTransparentNavigationBar() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 29) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
        ),
      );
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(themeSettingsProvider);
    final router = ref.watch(goRouterProvider);

    late ThemeMode mode;
    late Themes theme;

    mode = snapshot['theme'] == 'system'
        ? ThemeMode.system
        : snapshot['theme'] == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;

    if (snapshot['color'] == 'standard') {
      theme = Themes.standardTheme;
    } else if (snapshot['color'] != 'standard' &&
        snapshot['color'] != 'dynamic') {
      if (Themes.flutterColorThemes.containsKey(snapshot['color'])) {
        theme = Themes.flutterColorThemes[snapshot['color']!]!;
      } else {
        theme = Themes.standardTheme;
      }
    } else {
      theme = Themes.standardTheme;
    }
    if (snapshot['is-amoled'] == true) {
      theme = Themes.getAmoledThemes(theme);
    }

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        if (lightDynamic != null && darkDynamic != null) {
          Themes.dynamicTheme = Themes.getNewTheme(lightDynamic.primary);
        }
        if (snapshot['color'] == 'dynamic') {
          final dynamicTheme = Themes.dynamicTheme;
          // DynamicColorBuilder may call this before platform colors exist;
          // keep the already-selected fallback theme instead of null themes.
          if (dynamicTheme.lightTheme != null) {
            var darkTheme = dynamicTheme.darkTheme;
            if (snapshot['is-amoled'] == true) {
              darkTheme = Themes.getAmoledThemes(dynamicTheme).darkTheme;
            }
            theme = Themes(dynamicTheme.lightTheme, darkTheme);
          }
        }

        final lightTheme = theme.lightTheme ?? Themes.standardTheme.lightTheme!;
        final darkTheme = theme.darkTheme ?? Themes.standardTheme.darkTheme!;
        if (mode == ThemeMode.light ||
            (mode == ThemeMode.system &&
                MediaQuery.of(context).platformBrightness ==
                    Brightness.light)) {
          BubbleStyles.init(lightTheme);
        } else if (mode == ThemeMode.dark ||
            (mode == ThemeMode.system &&
                MediaQuery.of(context).platformBrightness == Brightness.dark)) {
          BubbleStyles.init(darkTheme);
        }

        return MaterialApp.router(
          title: forkAppName,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: mode,
          routerConfig: router,
          // Fork: Sprache aus Einstellungen → Darstellung (fork/ui/language.dart);
          // null = wie das Handy.
          locale: localeFor(ref.watch(languageProvider)),
          // Fork: Schriftgröße für alle Seiten (fork/ui/font_step.dart).
          builder: (context, child) => MediaQuery(
            data: scaledFor(
              MediaQuery.of(context),
              ref.watch(fontStepProvider),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ForkL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          // Fork: feste Liste statt der Lanis-Sprachen, damit Oberfläche und
          // Lanis-Seiten dieselben drei Sprachen haben; Englisch zuerst als
          // Ausweichsprache (fork/l10n/l10n.dart, fallbackLanguage).
          supportedLocales: appLocales,
        );
      },
    );
  }
}

Widget errorWidget(FlutterErrorDetails details, {BuildContext? context}) {
  // Hardcoded German copy: ErrorWidget can run before AppLocalizations is loaded.
  final error = details.exception.toString();

  return Container(
    color: const Color.fromARGB(255, 249, 222, 220),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_rounded,
            size: 60,
            color: Color.fromARGB(255, 179, 38, 30),
          ),
          const SizedBox(height: 24),
          const DefaultTextStyle(
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 179, 38, 30),
            ),
            child: Text(
              'Ein Fehler ist aufgetreten.',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          DefaultTextStyle(
            style: const TextStyle(
              fontSize: 16,
              color: Color.fromARGB(255, 179, 38, 30),
            ),
            child: Text('Problem: $error', textAlign: TextAlign.center),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text: '${details.exception}\n${details.stack.toString()}',
                ),
              );
              if (context != null && context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MonoTextViewer(
                      report:
                          '${details.exception}\n${details.stack.toString()}',
                      title: 'Stack Trace',
                      fileNameStart: 'stack_trace_default',
                    ),
                  ),
                );
              }
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return const Color.fromARGB(255, 198, 40, 32);
                }
                return const Color.fromARGB(255, 179, 38, 30);
              }),
            ),
            child: const Text('Fehler in die Zwischenablage kopieren'),
          ),
        ],
      ),
    ),
  );
}
