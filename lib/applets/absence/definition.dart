import 'package:flutter/material.dart';
import 'package:lanis/applets/absence/routes.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/fork/absence/absence_parser.dart';
import 'package:lanis/fork/absence/absence_view.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:lanis/utils/deep_link.dart';

/// Fork: Krankmeldung (Portal-Modul „Abwesenheiten“), nur Elternkonten.
/// Sichtbar nur, wenn die Schule das Modul in ihrer App-Liste führt
/// (fork/parent_support.dart, forkApplets).
final absenceDefinition = AppletDefinition(
  appletPhpUrl: forkAbsenceApplet.appletPhpUrl,
  pathSegment: 'absence',
  deepLinkScope: DeepLinkScope.accountTyped,
  buildRoutes: buildAbsenceRoutes,
  addDivider: false,
  appletType: AppletType.navigation,
  icon: const Icon(Icons.sick_outlined),
  selectedIcon: const Icon(Icons.sick),
  label: (context) => 'Krankmeldung',
  supportedAccountTypes: [AccountType.parent],
  allowOffline: false,
  settingsDefaults: const {},
  refreshInterval: forkAbsenceApplet.refreshInterval,
  bodyBuilder: (context, accountType, openDrawerCb) => const AbsencePage(),
);
