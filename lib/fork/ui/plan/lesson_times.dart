/// Selbst eingetragene Stundenzeiten für Schulen, die im Stundenplan keine
/// Uhrzeiten zeigen (KidPlan.timed = false) – nur Daten und Rechnung.
///
/// Ursache (Wunsch 17.10.26): Ohne Uhrzeiten fehlen „Jetzt“, „Danach“ und
/// die Zeitlinie. Die Familie trägt die Zeiten einmal ein: Beginn der
/// 1. Stunde, Länge einer Stunde und nach jeder Stunde die Pause bis zur
/// nächsten. Gespeichert je Konto auf dem Gerät (LiveDataScope,
/// lessonTimesSetting). Ohne Eintrag bleibt die Ansicht mit Stundennummern.
///
/// Warum Pause je Stunde statt Raster „Pause nach je n Stunden“: Die zweite
/// Schule der Familie hat 20, 20, 5, 10 und 5 Minuten Pause nach der 2., 4.,
/// 5., 6. und 8. Stunde (Rückmeldung 17.10.26) – kein Takt bildet das ab.
/// Grenze: Alle Stunden sind gleich lang; eine Doppelstunde mit anderer
/// Länge kennt das Modell nicht.
class LessonTimes {
  const LessonTimes({
    required this.start,
    this.length = 45,
    this.pauses = defaultPauses,
  });

  /// Raster für einen neuen Eintrag: 15 Minuten nach jeder zweiten Stunde
  /// („klassisch“, Rückmeldung 17.10.26).
  static const defaultPauses = {2: 15, 4: 15, 6: 15, 8: 15};

  /// Beginn der 1. Stunde in Minuten seit Mitternacht.
  final int start;

  /// Länge einer Stunde in Minuten.
  final int length;

  /// Pause nach Stunde n (Schlüssel) in Minuten; fehlt n, folgt die nächste
  /// Stunde direkt.
  final Map<int, int> pauses;

  /// Pause nach Stunde [n] in Minuten (0 = keine).
  int pauseAfter(int n) => pauses[n] ?? 0;

  /// Kopie mit geänderter Pause nach Stunde [n]; 0 entfernt sie.
  LessonTimes withPause(int n, int minutes) => LessonTimes(
    start: start,
    length: length,
    pauses: {
      for (final e in pauses.entries)
        if (e.key != n) e.key: e.value,
      if (minutes > 0) n: minutes,
    },
  );

  /// Gespeicherte Form (Map wie die übrigen Plan-Einstellungen); null bei
  /// fehlendem oder unbrauchbarem Eintrag.
  ///
  /// Liest auch die Form bis 4.1.0+9351 („every“/„pause“ = Pause nach je n
  /// Stunden) und rechnet sie in Einzelpausen um – sonst verlöre ein schon
  /// eingetragenes Raster mit dem Update seine Pausen.
  static LessonTimes? fromMap(Map<String, String> m) {
    final start = _hm(m['start']);
    final length = int.tryParse(m['length'] ?? '');
    if (start == null || length == null || length < 10 || length > 120) {
      return null;
    }
    final Map<int, int> pauses;
    if (m.containsKey('pauses')) {
      final p = _decodePauses(m['pauses']!);
      if (p == null) return null;
      pauses = p;
    } else {
      final every = int.tryParse(m['every'] ?? '');
      final pause = int.tryParse(m['pause'] ?? '');
      if (every == null || pause == null) return null;
      if (every < 0 || every > 10 || pause < 0 || pause > 120) return null;
      pauses = {
        if (every > 0 && pause > 0)
          for (var n = every; n < maxLessons; n += every) n: pause,
      };
    }
    return LessonTimes(start: start, length: length, pauses: pauses);
  }

  /// Höchste Stundennummer, für die Pausen gespeichert werden.
  static const maxLessons = 16;

  Map<String, String> toMap() => {
    'start': hm(start),
    'length': '$length',
    'pauses': [
      for (final n in (pauses.keys.toList()..sort()))
        if (pauses[n]! > 0) '$n:${pauses[n]}',
    ].join(','),
  };

  /// „2:20,4:20“ → {2: 20, 4: 20}; null bei kaputtem Eintrag.
  static Map<int, int>? _decodePauses(String s) {
    final out = <int, int>{};
    if (s.trim().isEmpty) return out;
    for (final part in s.split(',')) {
      final kv = part.split(':');
      if (kv.length != 2) return null;
      final n = int.tryParse(kv[0]);
      final min = int.tryParse(kv[1]);
      if (n == null || min == null) return null;
      if (n < 1 || n > maxLessons || min < 0 || min > 120) return null;
      if (min > 0) out[n] = min;
    }
    return out;
  }

  /// Beginn und Ende der Stunde [n] (1 = erste). Die 0. Stunde liegt direkt
  /// vor der ersten, ohne Pause.
  ({int start, int end}) of(int n) {
    if (n <= 0) {
      final s = start + (n - 1) * length;
      return (start: s, end: s + length);
    }
    var s = start + (n - 1) * length;
    for (var k = 1; k < n; k++) {
      s += pauseAfter(k);
    }
    return (start: s, end: s + length);
  }

  static String hm(int minutes) {
    final m = minutes.clamp(0, 24 * 60 - 1);
    return '${(m ~/ 60).toString().padLeft(2, '0')}:'
        '${(m % 60).toString().padLeft(2, '0')}';
  }

  static int? _hm(String? s) {
    final p = (s ?? '').split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }
}
