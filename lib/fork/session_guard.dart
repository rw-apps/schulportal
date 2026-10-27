import 'dart:async';

import 'package:dio/dio.dart';
import 'package:liblanis/liblanis.dart';

/// Höchstwartezeit auf die Antwort einer Portal-Anfrage.
///
/// Ursache (Prüfung 27.10.26, liblanis session.dart:93): prepareDio setzt nur
/// `connectTimeout` (8 s). Hängt das Portal nach dem Verbindungsaufbau,
/// wartet eine Anfrage unbegrenzt – die Ladeschleife (live_data.dart) und
/// der Hintergrundlauf (background_service.dart) kamen nie zurück. Beim
/// Android-Adapter (native_dio_adapter conversion_layer_adapter.dart:66–68)
/// zählt connect + receive gemeinsam bis zu den Antwort-Kopfzeilen, beim
/// Dart-Adapter receive je empfangenem Datenstück – lange Downloads brechen
/// also in keinem Fall nach 30 s ab, nur Stillstand.
const forkReceiveTimeout = Duration(seconds: 30);

/// Höchstdauer zum Senden des Anfrage-Inhalts (Dart-Adapter; der
/// Android-Adapter liest damit nur den Inhalt in den Speicher,
/// conversion_layer_adapter.dart:47–61).
const forkSendTimeout = Duration(seconds: 60);

/// Zeitlimit für Anfragen mit Datei-Inhalt (FormData, z. B. Abgabe-Upload
/// liblanis lessons/student_parser.dart:672).
///
/// Ursache: Beim Android-Adapter läuft das Hochladen INNERHALB von
/// `client.send` (conversion_layer_adapter.dart:74); dessen Grenze ist
/// connect + receive. Mit 30 s bräche eine größere Abgabe im Mobilnetz ab.
const forkUploadTimeout = Duration(minutes: 5);

/// Abstand der eigenen Sitzungs-Erhaltung (statt liblanis' 10 s).
const forkKeepAliveInterval = Duration(seconds: 90);

/// Eigene Sitzungs-Erhaltung statt liblanis' preventLogoutTimer.
///
/// Ursache (Prüfung 27.10.26, liblanis session.dart:144–148, :239–264): Der
/// Timer der Bibliothek ruft alle 10 s `ajax_login.php`, für immer, und
/// wirft während einer Wartung LanisDownException außerhalb jedes try
/// (:258–259) – unbehandelt, also bei jedem Takt ein Eintrag im
/// Fehlerprotokoll (glitchtip.dart initGlitchTip, PlatformDispatcher
/// .onError). Er startet direkt nach dem Login-Link, also vor travelMenu und
/// Verschlüsselung (:150–159), und läuft nach einer danach gescheiterten
/// Anmeldung weiter. Jetzt: derselbe Aufruf (LanisSession.preventLogout),
/// alle [interval], jeder Fehler abgefangen, nie zwei gleichzeitig.
///
/// Grenze: Gestartet ([arm]) und gestoppt ([disarm]) wird über die
/// Beobachtung der Anfragen ([ForkSessionGuard]); eigene Zustände der
/// Bibliothek gibt es dafür nicht.
class ForkKeepAlive {
  ForkKeepAlive(this._ping, {this.interval = forkKeepAliveInterval});

  final Future<void> Function() _ping;
  final Duration interval;
  Timer? _timer;
  bool _busy = false;
  bool _disposed = false;

  bool get armed => _timer != null;

  void arm() {
    if (_disposed || _timer != null) return;
    _timer = Timer.periodic(interval, (_) => unawaited(tick()));
  }

  void disarm() {
    _timer?.cancel();
    _timer = null;
  }

  /// Ein Takt; öffentlich für Tests.
  Future<void> tick() async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      await _ping();
    } catch (_) {
      // Wartung (LanisDownException), Netz weg, Sitzung weg: der nächste
      // Takt oder der nächste Abruf (mit Neuanmeldung) regelt das.
    } finally {
      _busy = false;
    }
  }

  void dispose() {
    _disposed = true;
    disarm();
  }
}

/// Dio-Wächter einer LanisSession: Zeitlimits, Upload-Ausnahme und Ersatz
/// des preventLogoutTimer durch [keepAlive].
///
/// Wie: Die Bibliothek legt ihren Timer in _authenticate neu an, und zwar
/// genau nach dem erfolgreichen Abruf des Login-Links (session.dart:142–148);
/// die nächste Anfrage (getFastTravelMenu, :150) läuft durch diesen Wächter.
/// Er hält den Timer dort an und startet [keepAlive]. Die erste Anfrage
/// jeder Anmeldung ist `GET https://start.schulportal.hessen.de/` (:131) –
/// dort stoppt er [keepAlive], bis die Anmeldung wieder so weit ist; eine
/// gescheiterte Anmeldung lässt ihn also aus. Ebenso beim Abmelden
/// (`index.php?logout`, :165).
///
/// Grenze: Wird eine Neuanmeldung mitten im Abruf abgebrochen (Ausnahme vor
/// getFastTravelMenu), lief der Bibliotheks-Timer höchstens bis zur nächsten
/// Anfrage dieser Sitzung – auch die hält ihn an.
class ForkSessionGuard extends Interceptor {
  ForkSessionGuard(this.session, {this.keepAlive});

  final LanisSession session;
  final ForkKeepAlive? keepAlive;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final libTimer = session.preventLogoutTimer;
    if (libTimer != null) {
      libTimer.cancel();
      session.preventLogoutTimer = null;
      keepAlive?.arm();
    }
    final uri = options.uri;
    final isStart =
        uri.host == 'start.schulportal.hessen.de' &&
        (uri.path == '/' || uri.path.isEmpty) &&
        uri.query.isEmpty &&
        options.method == 'GET';
    final isLogout =
        uri.path.endsWith('/index.php') && uri.query.contains('logout');
    if (isStart || isLogout) {
      keepAlive?.disarm();
    }
    if (options.data is FormData) {
      options.receiveTimeout = forkUploadTimeout;
      options.sendTimeout = forkUploadTimeout;
    }
    handler.next(options);
  }
}

/// Zeitlimits und Wächter an eine frisch gebaute [session] hängen; gibt die
/// Sitzungs-Erhaltung zurück (null, wenn [keepAlive] aus ist).
///
/// [keepAlive] aus im Hintergrundlauf: Ein Lauf dauert Sekunden, die
/// Erhaltung brächte nichts (background_service.dart, callbackDispatcher).
/// Der Bibliotheks-Timer wird trotzdem angehalten.
ForkKeepAlive? guardForkSession(
  LanisSession session, {
  bool keepAlive = true,
  Duration interval = forkKeepAliveInterval,
}) {
  // Fest setzen statt nur ergänzen: liblanis 0.1.4 (session.dart, BaseOptions)
  // bringt selbst 8 s Empfang mit – zu knapp für große Kursmappen und
  // Dateien im Mobilnetz (Prüfung 27.10.26, Versionsfestlegung auf 0.1.4).
  final o = session.dio.options;
  o.receiveTimeout = forkReceiveTimeout;
  o.sendTimeout = forkSendTimeout;
  final ka = keepAlive
      ? ForkKeepAlive(session.preventLogout, interval: interval)
      : null;
  session.dio.interceptors.add(ForkSessionGuard(session, keepAlive: ka));
  return ka;
}

/// Session-Provider des Forks: wie liblanis' Session, nach dem Bau der
/// Sitzung mit [guardForkSession]. Eingehängt über forkProviderOverrides
/// (parent_support.dart), damit App, Familien-Container (family.dart) und
/// Hintergrundlauf dieselbe Sitzung bekommen.
class ForkSession extends Session {
  ForkSession({this.keepAlive = true});

  final bool keepAlive;

  @override
  FutureOr<LanisSession?> build() async {
    final session = await super.build();
    if (session == null) return null;
    final ka = guardForkSession(session, keepAlive: keepAlive);
    if (ka != null) ref.onDispose(ka.dispose);
    return session;
  }
}
