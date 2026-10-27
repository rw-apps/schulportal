import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:liblanis/liblanis.dart';

final openLanisDefinition = ExternalDefinition(
  id: 'openLanis',
  action: (context) {
    if (context == null) return;
    final container = ProviderScope.containerOf(context);
    final account = container.read(activeAccountProvider);
    if (account == null) return;
    final config = container.read(lanisConfigProvider);
    LanisSession.getLoginURL(account, config)
        .then((response) {
          if (!context.mounted) return;
          safeLaunchUrl(Uri.parse(response), context: context);
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('Failed to open Lanis login URL: $error');
        });
  },
);
