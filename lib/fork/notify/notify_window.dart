import 'package:liblanis/liblanis.dart';

/// Wo ein Hintergrundlauf im Zeitfenster der Hinweise liegt.
enum NotifyWindow {
  /// Erlaubter Tag, innerhalb der Uhrzeiten: alles abrufen.
  open,

  /// Erlaubter Tag, aber außerhalb der Uhrzeiten („nachts“): nur die
  /// Nachrichten, still – wenn „Nachrichten auch nachts“ an ist.
  offHours,

  /// Abgewählter Wochentag: nichts, auch keine Nachrichten.
  offDay,
}

/// Zeitfenster aus den Einstellungen (Tage, Beginn, Ende) für [now].
///
/// Ursache für die Trennung von Tag und Uhrzeit (Prüfung 27.10.26): Vorher
/// hieß „nachts“ einfach „außerhalb des Fensters“ (isTaskWithinConstraints,
/// background_service.dart) – dazu zählte auch ein abgewählter Wochentag.
/// Mit „Nachrichten auch nachts“ kamen Nachrichten dann an einem
/// abgewählten Samstag den ganzen Tag (still). Ein abgewählter Tag bleibt
/// jetzt ganz ruhig.
///
/// Ohne eigene Auswahl alle Tage. Ursache: Die Sammelmeldung für Montag
/// kommt Sonntagabend (fork/notify/notices.dart); mit dem Lanis-Standard
/// Mo–Fr wäre sie nie gelaufen.
///
/// Grenze: Der Tag ist der Kalendertag von [now]. Nach Mitternacht zählt
/// schon der neue Tag – Freitag 23 Uhr ist „nachts“ (Freitag erlaubt),
/// Samstag 1 Uhr bei abgewähltem Samstag ruhig.
NotifyWindow notifyWindowAt(TypedSettings shared, DateTime now) {
  final days =
      shared.getJsonList('notifications-allowed-days') ??
      [true, true, true, true, true, true, true];
  final start = shared.getJsonList('notifications-start-time') ?? [6, 0];
  final end = shared.getJsonList('notifications-end-time') ?? [21, 0];
  final day = now.weekday - 1;
  if (day >= days.length || days[day] != true) return NotifyWindow.offDay;
  final startMinutes = (start[0] as int) * 60 + (start[1] as int);
  final endMinutes = (end[0] as int) * 60 + (end[1] as int);
  final nowMinutes = now.hour * 60 + now.minute;
  if (nowMinutes < startMinutes || nowMinutes > endMinutes) {
    return NotifyWindow.offHours;
  }
  return NotifyWindow.open;
}
