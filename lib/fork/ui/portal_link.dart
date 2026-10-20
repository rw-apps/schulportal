import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/safe_launch.dart';

/// Schulportal im Browser öffnen, angemeldet mit dem Konto von [session].
///
/// Ursache: openLanisDefinition (external_definitions.dart) nimmt immer das
/// aktive Konto; ein Hinweis zu einem weiteren Kind (Familienansicht) muss
/// dessen Konto öffnen. Grenze: Das Portal öffnet auf der Startseite, nicht
/// direkt im Modul – liblanis liefert nur die Anmeldeadresse.
void openPortalFor(BuildContext context, LanisSession session) {
  final config = ProviderScope.containerOf(context).read(lanisConfigProvider);
  LanisSession.getLoginURL(session.account, config)
      .then((url) {
        if (context.mounted) safeLaunchUrl(Uri.parse(url), context: context);
      })
      .catchError((Object _) {});
}
