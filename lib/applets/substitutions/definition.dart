import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/substitutions/routes.dart';
import 'package:lanis/applets/substitutions/substitutions_view.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/fork/notify/notify_task.dart';

final substitutionDefinition = AppletDefinition(
  appletPhpUrl: 'vertretungsplan.php',
  pathSegment: 'substitutions',
  deepLinkScope: DeepLinkScope.common,
  buildRoutes: buildSubstitutionRoutes,
  icon: Icon(Icons.people),
  selectedIcon: Icon(Icons.people_outline),
  appletType: AppletType.nested,
  addDivider: false,
  allowOffline: true,
  label: (context) => AppLocalizations.of(context).substitutions,
  supportedAccountTypes: [
    AccountType.student,
    AccountType.teacher,
    AccountType.parent,
  ],
  refreshInterval: Duration(minutes: 10),
  settingsDefaults: {},
  // Fork: nur, was die Stunden des Kindes betrifft (fork/notify).
  notificationTask: forkSubstitutionsTask,
  bodyBuilder: (context, accountType, openDrawerCb) {
    return SubstitutionsView(openDrawerCb: openDrawerCb);
  },
);
