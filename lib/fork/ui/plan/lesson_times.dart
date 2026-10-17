/// Selbst eingetragene Stundenzeiten für Schulen, die im Stundenplan keine
/// Uhrzeiten zeigen (KidPlan.timed = false) – nur Daten und Rechnung.
///
/// Ursache (Wunsch 17.10.26): Ohne Uhrzeiten fehlen „Jetzt“, „Danach“ und
/// die Zeitlinie. Die Familie trägt das Raster einmal ein: Beginn der
/// 1. Stunde, Länge einer Stunde, nach wie vielen Stunden eine Pause kommt
/// und wie lang sie ist („klassisch“: 45 Minuten, Pause nach je zwei
/// Stunden). Gespeichert je Konto auf dem Gerät (LiveDataScope,
/// lessonTimesSetting). Grenze: ein gleichmäßiges Raster – eine längere
/// Mittagspause oder abweichende Einzelzeiten kennt es nicht. Ohne Eintrag
/// bleibt die Ansicht wie bisher mit Stundennummern.
class LessonTimes {
  const LessonTimes({
    required this.start,
    this.length = 45,
    this.every = 2,
    this.pause = 15,
  });

  /// Beginn der 1. Stunde in Minuten seit Mitternacht.
  final int start;

  /// Länge einer Stunde in Minuten.
  final int length;

  /// Pause nach je so vielen Stunden (0 = keine Pausen).
  final int every;

  /// Länge der Pause in Minuten.
  final int pause;

  /// Gespeicherte Form (Map wie die übrigen Plan-Einstellungen); null bei
  /// fehlendem oder unbrauchbarem Eintrag.
  static LessonTimes? fromMap(Map<String, String> m) {
    final start = _hm(m['start']);
    final length = int.tryParse(m['length'] ?? '');
    final every = int.tryParse(m['every'] ?? '');
    final pause = int.tryParse(m['pause'] ?? '');
    if (start == null || length == null || every == null || pause == null) {
      return null;
    }
    if (length < 10 || length > 120 || every < 0 || every > 10) return null;
    if (pause < 0 || pause > 120) return null;
    return LessonTimes(
      start: start,
      length: length,
      every: every,
      pause: pause,
    );
  }

  Map<String, String> toMap() => {
    'start': hm(start),
    'length': '$length',
    'every': '$every',
    'pause': '$pause',
  };

  /// Beginn und Ende der Stunde [n] (1 = erste). Die 0. Stunde liegt direkt
  /// vor der ersten, ohne Pause.
  ({int start, int end}) of(int n) {
    if (n <= 0) {
      final s = start + (n - 1) * length;
      return (start: s, end: s + length);
    }
    final pauses = every <= 0 ? 0 : (n - 1) ~/ every;
    final s = start + (n - 1) * length + pauses * pause;
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
