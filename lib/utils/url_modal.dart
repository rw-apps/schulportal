import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/view/moodle_sso.dart' show isHostMatch;

import 'logger.dart';
import 'safe_launch.dart';

enum UrlModalResponse {
  /// The user opened the URL.
  opened,

  /// The user dismissed the modal.
  dismissed,

  /// The user opened the URL, but the URL could not be opened.
  rejected,
}

/// List of trusted domain endings. If a URL ends with one of these, it will be opened without asking the user.
///
/// As a school, you may make a pull request and add your domain to this list after verification.
const trustedDomains = [
  'hessen.de',
  'bund.de',
  'wikipedia.org',
  'gesetze-im-internet.de',
];

/// Fork: Öffnet sich [uri] ohne Rückfrage? Nur https und nur der Host selbst
/// oder eine Subdomain eines [trustedDomains]-Eintrags (isHostMatch,
/// view/moodle_sso.dart). Ursache (Prüfung 27.10.26): vorher
/// `uri.host.endsWith(domain)` ohne Punktgrenze und ohne Schema – etwa
/// `evilhessen.de` oder `http://…` öffneten ohne Nachfrage. Grenze: prüft
/// nur den Host; Weiterleitungen der Zielseite sieht die App nicht.
bool isTrustedUrl(Uri uri) =>
    uri.scheme.toLowerCase() == 'https' &&
    trustedDomains.any((domain) => isHostMatch(uri, domain));

Future<UrlModalResponse> openUrlModal(BuildContext context, Uri uri) async {
  bool? open;

  if (isTrustedUrl(uri)) {
    open = true;
  } else {
    logger.w('Untrusted URL: $uri');
  }

  if (open == null || !open) {
    open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).openExternalUrl),
        content: Column(
          mainAxisSize: .min,
          spacing: 8,
          children: [
            Text(AppLocalizations.of(context).openExternalUrlDescription),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Padding(
                padding: EdgeInsetsGeometry.all(4.0),
                child: Text(
                  uri.toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: uri.toString()));
              Navigator.of(context).pop(false);
            },
            icon: Icon(Icons.copy),
            label: Text(AppLocalizations.of(context).copy),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  if (open == null || !open) {
    return UrlModalResponse.dismissed;
  }
  final opened = await safeLaunchUrl(
    uri,
    context: context.mounted ? context : null,
  );
  return opened ? UrlModalResponse.opened : UrlModalResponse.rejected;
}
