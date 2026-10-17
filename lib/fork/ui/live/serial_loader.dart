/// Führt Ladedurchgänge strikt nacheinander aus und verwirft keinen Wunsch.
///
/// Ursache: Alle Parser teilen eine Sitzung; gleichzeitige Durchgänge hätten
/// sich bei der Neuanmeldung überholt (AppletParser.fetchData, secondTry).
/// Ein Wunsch während eines laufenden Durchgangs wird gesammelt und danach
/// erledigt; alle Aufrufer bekommen dieselbe Zukunft, die erst endet, wenn
/// nichts mehr aussteht („Ziehen zum Aktualisieren“ wartet darauf).
///
/// Vorgänger-Fehler (Prüfbefund 17.10.26, live_data.dart 4.1.0+9328): Lief
/// ein Durchgang ohne ein einziges await durch (keine Quelle angeboten,
/// z. B. vor der Anmeldung), setzte er „läuft“ zurück, BEVOR es gesetzt
/// war – danach blieb das Laden für immer gesperrt. Hier sorgt das erste
/// `await` in [_drain] dafür, dass [_running] vor jedem Zurücksetzen steht.
class SerialLoader {
  SerialLoader(this._body);

  /// [only] = null: alle Quellen; sonst nur diese (phpUrl).
  final Future<void> Function(bool force, Set<String>? only) _body;

  Future<void>? _running;
  bool _pending = false;
  bool _force = false;
  bool _all = false;
  final Set<String> _only = {};

  bool get busy => _running != null;

  Future<void> run({bool force = false, Set<String>? only}) {
    _pending = true;
    _force |= force;
    if (only == null) {
      _all = true;
    } else {
      _only.addAll(only);
    }
    return _running ??= _drain();
  }

  Future<void> _drain() async {
    await null;
    try {
      while (_pending) {
        final force = _force;
        final only = _all ? null : {..._only};
        _pending = false;
        _force = false;
        _all = false;
        _only.clear();
        try {
          await _body(force, only);
        } catch (_) {
          // Fehler meldet der Körper je Quelle selbst (Feed.error).
        }
      }
    } finally {
      _running = null;
    }
  }
}
