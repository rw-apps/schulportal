import 'dart:convert';

import 'package:background_fetch/background_fetch.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/fork/kid_name.dart';
import 'package:lanis/fork/login_guard.dart';
import 'package:lanis/fork/notify/notify_keys.dart';
import 'package:lanis/fork/notify/notify_task.dart' show showForkSummary;
import 'package:lanis/fork/notify/notify_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/bridge/lanis_bootstrap.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:lanis/utils/logger.dart';
import 'package:lanis/utils/privacy_policy.dart';

const _oneShotTaskId = 'com.transistorsoft.notftask';

/// Android headless entry (app swiped away). iOS ignores this registration.
@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessEvent event) async {
  await _runFetchTask(event.taskId, timeout: event.timeout);
}

Future<void> _onBackgroundFetch(String taskId) async {
  await _runFetchTask(taskId, timeout: false, inApp: true);
}

Future<void> _onBackgroundFetchTimeout(String taskId) async {
  await _runFetchTask(taskId, timeout: true);
}

/// [inApp]: Lauf im Prozess der geöffneten App (BackgroundFetch.configure,
/// auch der Einmal-Lauf 10 s nach dem Start), nicht headless.
Future<void> _runFetchTask(
  String taskId, {
  required bool timeout,
  bool inApp = false,
}) async {
  debugPrint('[Lanis BG] fetch taskId=$taskId timeout=$timeout');
  if (timeout) {
    await BackgroundFetch.finish(taskId);
    return;
  }
  try {
    await callbackDispatcher(inApp: inApp);
  } finally {
    await BackgroundFetch.finish(taskId);
    debugPrint('[Lanis BG] fetch finished taskId=$taskId');
  }
}

Future<void> _stopBackgroundFetch() async {
  _configuredInterval = null;
  try {
    await BackgroundFetch.stop();
  } catch (e, s) {
    backgroundLogger.e(e, stackTrace: s);
  }
}

/// Fork: Abstand (Minuten) der zuletzt in diesem Prozess eingerichteten
/// Hintergrundabfrage; null = gestoppt oder noch nie eingerichtet.
int? _configuredInterval;
Future<void> _setupQueue = Future<void>.value();

/// Fork: Hintergrundabfrage einrichten – mehrfach aufrufbar.
/// Ursache (Prüfung 27.10.26): Auf Android 13+ zählt eine nie erfragte
/// Benachrichtigungs-Erlaubnis als `isDenied`; beim ersten Start wurde die
/// Abfrage daher gestoppt und nach dem späteren Erlauben (NotifyIntroPage,
/// StartupScreen.requestPermissions, Einstellungen) nie eingerichtet – erst
/// beim nächsten App-Start. Jetzt rufen diese Stellen und der Hauptschalter
/// (fork/ui/settings/settings_page.dart) [refreshBackgroundService] auf.
/// Aufrufe laufen nacheinander ([_setupQueue]); ist die Abfrage mit gleichem
/// Abstand schon eingerichtet ([_configuredInterval]), entfallen configure
/// und der Einmal-Lauf nach 10 s – sonst meldete jeder Aufruf alle Konten
/// erneut an. Grenze: Ein Abstand ist im Fork nicht einstellbar; geändert
/// wird er nur über die Lanis-Einstellung `notifications-target-interval-…`.
Future<void> setupBackgroundService() {
  final run = _setupQueue.then((_) => _setupBackgroundService());
  _setupQueue = run.catchError((Object _) {});
  return run;
}

/// Fork: [setupBackgroundService] für Aufrufer aus der Oberfläche – Fehler
/// werden protokolliert statt geworfen (ohne Plattform, z. B. in Tests,
/// wirft schon die Erlaubnis-Abfrage).
Future<void> refreshBackgroundService() async {
  try {
    await setupBackgroundService();
  } catch (e, s) {
    backgroundLogger.e(e, stackTrace: s);
  }
}

Future<void> _setupBackgroundService() async {
  await BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);

  if ((await Permission.notification.isDenied)) {
    logger.d('User disallowed notifications');
    await _stopBackgroundFetch();
    return;
  }

  // Fork: removeLegacyV3StorageArtifacts nur noch einmal je App-Start in
  // main.dart. Ursache (Prüfung 27.10.26): lief dreimal je Start (main, hier,
  // im Einmal-Lauf nach 10 s) und las jedes Mal den sicheren Speicher.
  // Grenze: Headless-Läufe räumen nicht mehr auf; die Reste (v3-Dateien,
  // `encryption_key`) stören dort nicht und gehen beim nächsten Öffnen.
  final overrides = await bootstrapLanisClient(forApp: false);
  final container = ProviderContainer(overrides: overrides);
  try {
    final accounts = await container.read(accountsProvider.future);
    var disabledCount = 0;
    for (final account in accounts) {
      final settings = TypedSettings.account(
        container.read(lanisDatabaseProvider),
        account.localId,
      );
      if (settings.getBool('notifications-allow') == false) {
        disabledCount++;
      }
    }
    // Fork: Erlaubte Konten/Themen der Sammelmeldung merken und still
    // aufräumen – auch wenn gleich alles abgeschaltet wird und kein
    // Hintergrundlauf mehr kommt (Prüfung 27.10.26).
    await showForkSummary(
      container,
      [for (final a in accounts) a.localId],
      alert: false,
      parents: _parentIds(accounts),
    );
    if (accounts.isNotEmpty && disabledCount == accounts.length) {
      await _stopBackgroundFetch();
      return;
    }

    final shared = container.read(sharedOverAccountSettingsProvider);
    final targetIntervalMinutes =
        shared.getInt('notifications-target-interval-minutes') ?? 60;
    // Fork: siehe _configuredInterval.
    if (_configuredInterval == targetIntervalMinutes) return;
    logger.i(
      'Setting up background task with interval of $targetIntervalMinutes minutes',
    );

    try {
      await BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: targetIntervalMinutes,
          stopOnTerminate: false,
          startOnBoot: true,
          enableHeadless: true,
          requiresBatteryNotLow: true,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        _onBackgroundFetch,
        _onBackgroundFetchTimeout,
      );

      // Fork: Einmal-Lauf nach 10 s nur, wenn der letzte vollständige Lauf
      // fehlt oder einen Abstand zurückliegt (startRunDue, notify_keys.dart).
      // Ursache (Prüfung 27.10.26, Befund 9): Er kam nach JEDEM App-Start
      // und meldete alle Konten ein zweites Mal an. Grenze: Zeitfenster und
      // Nachtregel prüft weiter der Lauf selbst (callbackDispatcher); die
      // regelmäßige Abfrage richtet configure oben unverändert ein.
      if (startRunDue(
        lastFullRun(shared),
        DateTime.now(),
        Duration(minutes: targetIntervalMinutes),
      )) {
        await BackgroundFetch.scheduleTask(
          TaskConfig(
            taskId: _oneShotTaskId,
            delay: 10000,
            enableHeadless: true,
            stopOnTerminate: false,
          ),
        );
      } else {
        logger.i('Skipping start-up fetch: last full run is recent');
      }
      _configuredInterval = targetIntervalMinutes; // Fork: siehe oben.
    } catch (e, s) {
      backgroundLogger.e(e, stackTrace: s);
    }
  } finally {
    container.dispose();
  }
}

Future<void> initializeNotifications() async {
  try {
    // Fork: abgewartet – sonst fing der catch asynchrone Fehler nie, und
    // ein Aufrufer zeigte womöglich vor Ende der Initialisierung eine Meldung
    // (Prüfung 27.10.26).
    await FlutterLocalNotificationsPlugin().initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
    );
  } catch (e, s) {
    backgroundLogger.e(e, stackTrace: s);
  }
}

/// [inApp]: Lauf im Prozess der geöffneten App (siehe _runFetchTask).
@pragma('vm:entry-point')
Future<void> callbackDispatcher({bool inApp = false}) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    backgroundLogger.i('Background fetch triggered');
    debugPrint('[Lanis BG] callbackDispatcher started');
    // Fork: Datumsformate wie main.dart. Ursache (Prüfung 27.10.26): Der
    // headless Lauf (App geschlossen) startet nicht über main(); ohne
    // initializeDateFormatting warf DateFormat('E', 'de') in weekDayGer
    // (applets/substitutions/background.dart) eine LocaleDataException und
    // die Vertretungsmeldung entfiel. Grenze: lädt alle eingebauten
    // Sprachen; im Prozess der geöffneten App ist der Aufruf wirkungslos.
    await initializeDateFormatting();
    await initializeNotifications();

    // Fork: kein removeLegacyV3StorageArtifacts mehr (siehe
    // setupBackgroundService).
    // Fork: forApp: false – siehe bootstrapLanisClient (Demo-Modus der
    // geöffneten App bleibt unberührt).
    final overrides = await bootstrapLanisClient(forApp: false);
    final container = ProviderContainer(overrides: overrides);
    try {
      // Fork: Außerhalb der Uhrzeiten nur Nachrichten, still, wenn
      // „Nachrichten auch nachts“ an ist (notify_keys.dart, Abnahme
      // 27.10.26); an einem abgewählten Tag gar nichts (notify_window.dart,
      // Prüfung 27.10.26). Sonst wie bisher: nichts abrufen, still aufräumen.
      final window = notifyWindowAt(
        container.read(sharedOverAccountSettingsProvider),
        DateTime.now(),
      );
      final inWindow = window == NotifyWindow.open;
      final night =
          window == NotifyWindow.offHours &&
          notifyNightMessages(
            container.read(sharedOverAccountSettingsProvider),
          );
      if (!inWindow && !night) {
        backgroundLogger.w('Task not within constraints... aborting');
        // Fork: still aufräumen (vergangene Tage, abgeschaltete Konten).
        await _quietSummary(container);
        return;
      }

      if (!await container.read(connectionCheckerProvider).connected) {
        backgroundLogger.w('No network connection, aborting background fetch');
        await _quietSummary(container);
        return;
      }

      final sharedPolicy = container.read(sharedOverAccountSettingsProvider);
      if (!shouldRunBackgroundFetch(sharedPolicy)) {
        backgroundLogger.w(
          'Privacy policy not accepted, aborting background fetch',
        );
        return;
      }

      final accounts = await container.read(accountsProvider.future);

      // One shared activeAccount/session — must run accounts sequentially.
      //
      // Fork: jedes Konto für sich abgesichert. Ursache (Prüfbefund
      // 17.10.26): Schlug die Anmeldung oder eine Aufgabe eines Kontos fehl,
      // brach die Schleife ab – alle folgenden Konten blieben ohne Meldung,
      // und das Abmelden (deAuthenticate) entfiel. Jetzt: Fehler protokollieren,
      // dieses Konto abmelden, mit dem nächsten weitermachen. Ein Konto mit
      // abgelehntem Passwort überspringt guardedLogin (login_guard.dart).
      //
      // Fork: je Konto ein eigener Container (gleiche Datenbank). Ursache
      // (Prüfung 27.10.26): Im Prozess der geöffneten App ([inApp]) meldete
      // der Lauf jedes Konto am Ende ab (Session.deAuthenticate,
      // `index.php?logout=all`) – auch beim Wechsel zum nächsten Konto
      // (ActiveAccount.select meldet das vorige ab). Ob das Portal damit
      // auch die Sitzung der App für dasselbe Konto beendet, ist nicht
      // belegt; „all“ legt es nahe. Mit eigenem Container entfällt das
      // Abmelden beim Wechsel, und [inApp] meldet gar nicht ab – die
      // Sitzung des Laufs verfällt im Portal von selbst. Grenze: headless
      // (App geschlossen) wird wie bisher abgemeldet.
      final db = container.read(lanisDatabaseProvider);
      for (final summary in accounts) {
        final settings = TypedSettings.account(db, summary.localId);
        if (settings.getBool('notifications-allow') == false) {
          continue;
        }

        final c = ProviderContainer(
          overrides: [
            ...overrides,
            lanisDatabaseProvider.overrideWithValue(db),
          ],
        );
        var authenticated = false;
        try {
          await c.read(activeAccountProvider.notifier).select(summary.localId);
          final account = c.read(activeAccountProvider);
          if (account == null) continue;

          for (final applet in AppDefinitions.applets.where(
            (a) => a.notificationTask != null,
          )) {
            final accountType = account.accountType ?? AccountType.student;
            // Nachts nur die Nachrichten (siehe oben).
            if (night && applet.appletPhpUrl != 'nachrichten.php') continue;
            // Fork: Der Vertretungsplan-Abruf liefert auch die großen
            // Termine am Vorabend – er läuft, wenn einer der beiden
            // Schalter an ist (notify_keys.dart).
            final enabled =
                (settings.getBool('notification-${applet.appletPhpUrl}') ??
                    true) ||
                (applet.appletPhpUrl == 'vertretungsplan.php' &&
                    notifyEventsOn(settings));
            if (!applet.supportedAccountTypes.contains(accountType) ||
                !enabled) {
              continue;
            }

            if (!authenticated) {
              // Fork: nie mit einem schon abgelehnten Passwort und nie
              // während einer Sperre des Portals (login_guard.dart) – sonst
              // verlängerte jeder Lauf die Sperre, auch für die Webseite.
              // Fork: last_login wie vorher. Ursache (Prüfung 27.10.26):
              // Session.authenticate setzt ihn für jedes Konto; nach jedem
              // Lauf startete die App mit dem zuletzt geprüften Konto (bei
              // zwei Konten abwechselnd). Gleiche Lösung wie family.dart
              // (_start, restoreLastLogin).
              final before = (await db.getAccount(account.localId))?.lastLogin;
              await guardedLogin(
                settings,
                account.password,
                () => c
                    .read(sessionProvider.notifier)
                    .authenticate(withoutData: true),
              );
              authenticated = true;
              await restoreLastLogin(db, account.localId, before);
            }

            final session = c.read(sessionProvider).asData?.value;
            if (session == null) continue;
            if (!session.doesSupportFeature(
              Applets.byPhpUrl(applet.appletPhpUrl),
              overrideAccountType: accountType,
            )) {
              continue;
            }

            // One shared session/Dio — run applet tasks sequentially.
            // Fork: eine fehlerhafte Aufgabe stoppt die übrigen nicht.
            try {
              await applet.notificationTask!(
                c,
                accountType,
                BackgroundTaskToolkit(
                  accountId: account.localId,
                  username: account.username,
                  schoolName: account.schoolName,
                  settings: settings,
                  appletId: applet.appletPhpUrl,
                  multiAccount: accounts.length > 1,
                ),
              );
            } catch (e, s) {
              backgroundLogger.e('Task ${applet.appletPhpUrl} failed');
              backgroundLogger.e(e, stackTrace: s);
            }
          }
        } catch (e, s) {
          backgroundLogger.e('Account ${summary.localId} skipped');
          backgroundLogger.e(e, stackTrace: s);
        } finally {
          if (authenticated && !inApp) {
            try {
              await c.read(sessionProvider.notifier).deAuthenticate();
            } catch (_) {}
          }
          c.dispose();
        }
      }

      // Fork: Ende eines vollständigen Laufs im Zeitfenster merken – der
      // Einmal-Lauf nach dem App-Start entfällt dann (startRunDue,
      // Prüfung 27.10.26, Befund 9). Grenze: Nachts (nur Nachrichten) nicht,
      // sonst fehlte morgens der Vertretungsplan bis zum nächsten Takt;
      // gescheiterte Anmeldungen einzelner Konten zählen mit – der Lauf hat
      // sie versucht, der nächste Takt versucht es wieder.
      if (inWindow) {
        noteFullRun(sharedPolicy, DateTime.now());
      }

      // Fork: Sammel-Benachrichtigung aus allen Konten (summary.dart).
      await showForkSummary(
        container,
        [for (final a in accounts) a.localId],
        alert: !night,
        parents: _parentIds(accounts),
      );

      backgroundLogger.i('Background fetch completed');
    } finally {
      container.dispose();
    }
  } catch (e, s) {
    backgroundLogger.e('Error in background fetch');
    backgroundLogger.e(e, stackTrace: s);
  }
}

/// Kanal aller Hinweise (bestehende Installationen behalten ihre
/// Kanal-Einstellungen); auch für die Sammelmeldung (fork/notify/summary).
const notificationChannelId = 'io.github.alessioc42.sphplan';

/// Fork: Elternkonten für den Namen in der Sammelmeldung (summaryName,
/// fork/notify/summary.dart).
Set<int> _parentIds(Iterable<AccountSummary> accounts) => {
  for (final a in accounts)
    if (a.accountType == AccountType.parent) a.localId,
};

/// Fork: Sammelmeldung ohne neuen Abruf still neu zeichnen bzw. entfernen
/// (abgebrochener Lauf: Zeitfenster, kein Netz) – sonst stünde nachts noch
/// „Morgen …“ für den heutigen Tag da (Prüfung 27.10.26).
Future<void> _quietSummary(ProviderContainer container) async {
  try {
    final accounts = await container.read(accountsProvider.future);
    await showForkSummary(
      container,
      [for (final a in accounts) a.localId],
      alert: false,
      parents: _parentIds(accounts),
    );
  } catch (_) {}
}

class BackgroundTaskToolkit {
  final int accountId;
  final String username;
  final String schoolName;
  final TypedSettings settings;
  final String appletId;
  final bool multiAccount;

  BackgroundTaskToolkit({
    required this.accountId,
    required this.username,
    required this.schoolName,
    required this.settings,
    required this.appletId,
    this.multiAccount = false,
  });

  /// Platform notification id: account + applet + local slot (0–9999).
  int _seedId(int id) {
    final appletSlot = (appletId.hashCode & 0x7fffffff) % 100;
    return id + appletSlot * 10000 + accountId * 1000000;
  }

  Future<void> sendMessage({
    required String title,
    required String message,
    int id = 0,
    bool avoidDuplicateSending = false,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
  }) async {
    if (id > 10000 || id < 0) {
      throw ArgumentError('id must be between 0 and 10000');
    }
    id = _seedId(id);
    // Fork: Ist der Vorname des Kindes bekannt (kid_name.dart), steht er
    // schon im Titel jedes Hinweises – dann ohne die Zeile „name@Schule“.
    // Ursache (Wunsch 20.10.26): Die Zeile nannte bei Elternkonten den
    // Benutzernamen der Eltern, nicht das Kind. Grenze: Ohne bekannten
    // Namen bleibt sie, damit mehrere Konten unterscheidbar sind.
    message = multiAccount && storedKidName(settings).isEmpty
        ? '${username.toLowerCase()}@$schoolName\n$message'
        : message;
    if (avoidDuplicateSending) {
      final hash = hashString(message);
      final key = 'notif-dupe/$appletId/$id';
      if (settings.getString(key) == hash) {
        return;
      }
      settings.setString(key, hash);
    }
    try {
      final androidDetails = AndroidNotificationDetails(
        notificationChannelId,
        'Schulportal',
        channelDescription: 'Applet notifications',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(message),
        ongoing: false,
        // Fork (Sicherheitsprüfung 17.10.26): Inhalt (Namen, Fächer,
        // Betreffzeilen) gilt als vertraulich. Auf einem gesperrten Handy
        // zeigt Android dann nur „Schulportal“ ohne Text, sofern unter
        // „Sperrbildschirm“ das Ausblenden sensibler Inhalte gewählt ist.
        // Grenze: Mit „Alle Inhalte anzeigen“ entscheidet der Nutzer anders.
        visibility: NotificationVisibility.private,
      );
      const iOSDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: true,
      );
      await FlutterLocalNotificationsPlugin().show(
        id: id,
        title: title,
        body: message,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: iOSDetails,
        ),
      );
    } catch (e, s) {
      backgroundLogger.e(e, stackTrace: s);
    }
  }

  String hashString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}
