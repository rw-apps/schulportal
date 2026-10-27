import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/applets/conversations/background.dart';
import 'package:lanis/fork/notify/notify_task.dart';
import 'package:liblanis/liblanis.dart';

import '../background_service.dart';

/// Was von den Lanis-Bereichen im Fork bleibt: die Hintergrundaufgaben je
/// Modul (Benachrichtigungen).
///
/// Ursache (Aufräumen 17.10.26): Seit die App immer mit der neuen
/// Oberfläche startet (fork/start.dart), waren Ansichten, Routen und Leisten
/// der Lanis-Bereiche nicht mehr erreichbar – rund 14 000 Zeilen. Geblieben
/// sind nur die Felder, die background_service.dart braucht. Die Schlüssel
/// „notification-<php>“ der Einstellungen bleiben dieselben.
typedef BackgroundTaskFunction =
    Future<void> Function(
      ProviderContainer container,
      AccountType accountType,
      BackgroundTaskToolkit toolkit,
    );

class AppletDefinition {
  const AppletDefinition({
    required this.appletPhpUrl,
    required this.supportedAccountTypes,
    this.notificationTask,
  });

  final String appletPhpUrl;
  final List<AccountType> supportedAccountTypes;
  final BackgroundTaskFunction? notificationTask;
}

/// Verknüpfung nach außen (Portal im Browser).
///
/// Fork (Prüfung 27.10.26): label/icon und openMoodleDefinition entfernt –
/// die Oberfläche (preview_shell.dart) ruft nur openLanisDefinition.action
/// auf und setzt Text und Symbol selbst.
class ExternalDefinition {
  final String id;
  final Function(BuildContext?)? action;

  ExternalDefinition({required this.id, this.action});
}

class AppDefinitions {
  static const _all = [
    AccountType.student,
    AccountType.teacher,
    AccountType.parent,
  ];

  static final List<AppletDefinition> applets = [
    // Fork: nur, was die Stunden des Kindes betrifft (fork/notify).
    const AppletDefinition(
      appletPhpUrl: 'vertretungsplan.php',
      supportedAccountTypes: _all,
      notificationTask: forkSubstitutionsTask,
    ),
    const AppletDefinition(
      appletPhpUrl: 'nachrichten.php',
      supportedAccountTypes: _all,
      notificationTask: conversationsBackgroundTask,
    ),
  ];
}
