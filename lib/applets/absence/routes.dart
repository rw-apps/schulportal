import 'package:go_router/go_router.dart';
import 'package:lanis/applets/absence/definition.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/fork/absence/absence_view.dart';
import 'package:lanis/l10n/account_type_ui.dart';

List<RouteBase> buildAbsenceRoutes(AppletRouteContext ctx) {
  return [
    GoRoute(
      path: '/parent/absence',
      redirect: (context, state) {
        if (state.uri.path == '/parent/absence') {
          return absenceDefinition.homePath(AccountType.parent);
        }
        return null;
      },
      routes: [
        GoRoute(path: 'home', builder: (context, state) => const AbsencePage()),
      ],
    ),
  ];
}
