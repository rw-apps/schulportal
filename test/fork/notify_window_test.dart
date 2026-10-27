import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/notify/notify_window.dart';
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
  // 31.10.2026 ist ein Samstag, 30.10.2026 ein Freitag.
  final saturdayNoon = DateTime(2026, 10, 31, 12);
  final fridayNight = DateTime(2026, 10, 30, 23);
  final fridayNoon = DateTime(2026, 10, 30, 12);

  test('ohne eigene Auswahl: alle Tage, 6–21 Uhr', () {
    final s = _mem();
    expect(notifyWindowAt(s, saturdayNoon), NotifyWindow.open);
    expect(notifyWindowAt(s, fridayNight), NotifyWindow.offHours);
  });

  test('abgewählter Tag bleibt ganz ruhig, auch tagsüber', () {
    // Ursache (Prüfung 27.10.26): „nachts“ umfasste auch abgewählte Tage –
    // mit „Nachrichten auch nachts“ kamen sie samstags den ganzen Tag.
    final s = _mem()
      ..setJsonList('notifications-allowed-days', [
        true,
        true,
        true,
        true,
        true,
        false,
        false,
      ]);
    expect(notifyWindowAt(s, saturdayNoon), NotifyWindow.offDay);
    expect(notifyWindowAt(s, fridayNoon), NotifyWindow.open);
    expect(notifyWindowAt(s, fridayNight), NotifyWindow.offHours);
  });

  test('eigene Uhrzeiten', () {
    final s = _mem()
      ..setJsonList('notifications-start-time', [8, 30])
      ..setJsonList('notifications-end-time', [18, 0]);
    expect(
      notifyWindowAt(s, DateTime(2026, 10, 30, 8, 29)),
      NotifyWindow.offHours,
    );
    expect(notifyWindowAt(s, DateTime(2026, 10, 30, 8, 30)), NotifyWindow.open);
    expect(notifyWindowAt(s, DateTime(2026, 10, 30, 18)), NotifyWindow.open);
    expect(
      notifyWindowAt(s, DateTime(2026, 10, 30, 18, 1)),
      NotifyWindow.offHours,
    );
  });
}
