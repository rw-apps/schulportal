import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/applets/definitions.dart';

/// Seit dem Aufräumen 17.10.26 tragen die Definitionen nur noch die
/// Hintergrundaufgaben (Benachrichtigungen).
void main() {
  test('Benachrichtigungen für Vertretungen und Nachrichten', () {
    final urls = {
      for (final a in AppDefinitions.applets)
        if (a.notificationTask != null) a.appletPhpUrl,
    };
    expect(urls, {'vertretungsplan.php', 'nachrichten.php'});
  });
}
