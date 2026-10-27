import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/notify/notify_keys.dart';
import 'package:liblanis/liblanis.dart';

TypedSettings _mem() {
  final m = <String, String?>{};
  return TypedSettings(
    read: (k) => m[k],
    write: (k, v) => m[k] = v,
    delete: m.remove,
  );
}

void main() {
  test('Große Termine: ohne eigenen Eintrag wie der Vertretungsplan', () {
    final a = _mem();
    expect(notifyEventsOn(a), isTrue);
    a.setBool('notification-vertretungsplan.php', false);
    expect(notifyEventsOn(a), isFalse, reason: 'bisher gemeinsam aus');
    a.setBool(notifyEventsKey, true);
    expect(notifyEventsOn(a), isTrue, reason: 'eigener Schalter gewinnt');
  });

  test('Nachrichten auch nachts: Standard aus', () {
    final s = _mem();
    expect(notifyNightMessages(s), isFalse);
    s.setBool(notifyNightMessagesKey, true);
    expect(notifyNightMessages(s), isTrue);
  });
}
