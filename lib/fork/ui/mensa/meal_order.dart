import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../meal_order_js.dart';
import '../../mensa.dart' show mensaAllows;
import '../../mensa_login.dart';
import '../../mensa_week.dart';
import '../today/today_page.dart' show dayDiff;
import 'meal_fetcher.dart' show hiddenWebView, pageHtml;

/// ok = die neu gelesene Seite zeigt den gewünschten Stand; notDone = vor
/// dem Klick abgebrochen, nichts geändert; unclear = geklickt, aber die
/// Seite bestätigt es nicht (bitte auf der Seite prüfen).
enum MealOrderOutcome { ok, notDone, unclear }

/// Ergebnis eines Bestell- bzw. Abbestellvorgangs.
class MealOrderResult {
  const MealOrderResult(this.outcome, {this.week, this.message});

  final MealOrderOutcome outcome;
  bool get ok => outcome == MealOrderOutcome.ok;

  /// Neu gelesene Woche (auch bei Misserfolg, wenn lesbar).
  final MealWeek? week;

  /// Text eines Fensters der Seite (z. B. „Guthaben reicht nicht“).
  final String? message;
}

/// Bestellt bzw. bestellt ab – unsichtbar auf der Seite des Caterers
/// (1 × 1, wie MealFetcher) – und prüft danach durch neues Lesen.
///
/// Ablauf: Woche [url] laden (bei Anmeldeseite einmal gemerkte Anmeldung,
/// mensa_login.dart) → prüfen, dass der Tag noch im erwarteten Zustand ist
/// (sonst nichts tun) → Skript (meal_order_js.dart), genau einmal → neue
/// Fenster der Seite bestätigen → wenn die Seite ruht (keine Navigation,
/// keine laufende Anfrage, kein Fenster) neu laden → Ergebnis.
///
/// Absicherung (unabhängige Prüfung 27.10.26):
/// - Seitenzähler ([_page], onPageStarted) und Phase nach jedem await
///   prüfen; das Skript läuft höchstens einmal ([_acted], ohne await
///   zwischen Prüfung und Setzen) – kein Doppelklick bei doppeltem
///   onPageFinished.
/// - Prüfung nur auf einer Seite, die nach dem Neuladen begonnen hat und
///   die Marke [mealStaleMarkJs] nicht mehr trägt – kein „Erfolg“ aus dem
///   alten DOM.
/// - Abfragen nicht überlappend ([_polling]); nach dispose nichts mehr.
/// Grenze: Ob der Caterer eine angezeigte Bestellung später verwirft,
/// sieht die App erst beim nächsten Lesen.
class MealOrderRunner extends StatefulWidget {
  const MealOrderRunner({
    super.key,
    required this.url,
    required this.owner,
    required this.day,
    required this.onResult,
    this.option,
    this.timeout = const Duration(seconds: 45),
  });

  final String url;
  final String owner;
  final DateTime day;

  /// Zu bestellendes Gericht; null = abbestellen.
  final MealOption? option;
  final Duration timeout;
  final void Function(MealOrderResult r) onResult;

  @override
  State<MealOrderRunner> createState() => _MealOrderRunnerState();
}

enum _Phase { load, act, verify, done }

class _MealOrderRunnerState extends State<MealOrderRunner> {
  late final Uri _home = Uri.parse(widget.url);
  late final WebViewController _c;
  var _phase = _Phase.load;
  var _page = 0;
  var _loading = false;
  var _acted = false;
  var _polling = false;
  var _triedLogin = false;
  var _afterLogin = false;

  /// Seitenzähler beim Ausfüllen der Anmeldung (siehe _onPage).
  var _fillPage = 0;
  var _verifies = 0;
  var _verifyFrom = 0;
  var _verifyErrors = 0;
  String? _message;
  DateTime _lastActivity = DateTime.now();
  DateTime? _actedAt;
  Timer? _tick;
  Timer? _timeout;

  bool get _over => _phase == _Phase.done || !mounted;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (r) {
            final t = Uri.tryParse(r.url);
            return t != null && mensaAllows(_home, t)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageStarted: (_) {
            _page++;
            _loading = true;
            _lastActivity = DateTime.now();
          },
          onPageFinished: (_) {
            _loading = false;
            _lastActivity = DateTime.now();
            _onPage(_page);
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame == false || _over) return;
            _loading = false;
            switch (_phase) {
              case _Phase.load:
                // Nur ohne Verbindung; abgebrochenes Laden (Weiterleitung
                // der Seite) führt über Seitenende bzw. timeout weiter.
                if (e.errorType
                    case WebResourceErrorType.hostLookup ||
                        WebResourceErrorType.connect ||
                        WebResourceErrorType.timeout) {
                  _finish(const MealOrderResult(MealOrderOutcome.notDone));
                }
              case _Phase.verify:
                // Kurzer Netzfehler beim Prüfen: einmal neu laden.
                if (_verifyErrors++ == 0) {
                  _reloadForVerify();
                } else {
                  _finish(
                    MealOrderResult(
                      MealOrderOutcome.unclear,
                      message: _message,
                    ),
                  );
                }
              case _Phase.act || _Phase.done:
                break;
            }
          },
        ),
      );
    _timeout = Timer(
      widget.timeout,
      () => _finish(
        MealOrderResult(
          _acted ? MealOrderOutcome.unclear : MealOrderOutcome.notDone,
          message: _message,
        ),
      ),
    );
    _c.loadRequest(Uri.parse(widget.url));
  }

  MealDay? _dayOf(MealWeek w) {
    for (final d in w.days) {
      if (dayDiff(d.day, widget.day) == 0) return d;
    }
    return null;
  }

  Future<MealWeek?> _read() async {
    final src = await pageHtml(_c);
    return (src == null ? null : parseMealWeek(src))?.withUrl(widget.url);
  }

  Future<void> _onPage(int page) async {
    if (_over) return;
    if (_phase == _Phase.act) return; // Seite lädt nach dem Klick neu.
    bool stale() => _over || page != _page;

    if (_phase == _Phase.verify) {
      if (page <= _verifyFrom) return; // noch die alte Seite
      try {
        final r = await _c.runJavaScriptReturningResult(mealIsStaleJs);
        if ('$r'.contains('stale')) return;
      } catch (_) {}
      if (stale() || _phase != _Phase.verify) return;
      final week = await _read();
      if (stale() || _phase != _Phase.verify) return;
      return _check(week);
    }

    // Laden.
    final week = await _read();
    if (stale() || _phase != _Phase.load) return;
    if (week == null) {
      // Zwischenseite einer Weiterleitung? Kurz warten.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (stale() || _phase != _Phase.load) return;
      if (_afterLogin) {
        // Doppelt gemeldetes Seitenende der Anmeldeseite (Abrufverlauf
        // 27.10.26, MealFetcher._login): nur eine neu begonnene Seite ist
        // das Ergebnis der Anmeldung; sonst brach das Neuladen die
        // laufende Anmeldung ab.
        if (page <= _fillPage) return;
        _afterLogin = false;
        await _c.loadRequest(Uri.parse(widget.url));
        return;
      }
      if (!_triedLogin && await _login()) return;
      if (stale() || _phase != _Phase.load) return;
      return _finish(
        MealOrderResult(MealOrderOutcome.notDone, message: _message),
      );
    }
    final d = _dayOf(week);
    final o = widget.option;
    final ready =
        d != null &&
        (o == null
            ? d.state == MealState.ordered && d.canCancel
            : d.state == MealState.open &&
                  d.options.any((x) => x.id == o.id && x.orderable));
    if (!ready) {
      return _finish(MealOrderResult(MealOrderOutcome.notDone, week: week));
    }
    // Genau einmal: zwischen Prüfung und Setzen kein await.
    if (_acted) return;
    _acted = true;
    _phase = _Phase.act;
    final js = o == null
        ? mealCancelJs(week.kind, widget.day, d.ordered)
        : mealOrderJs(week.kind, widget.day, o);
    Object r;
    try {
      r = await _c.runJavaScriptReturningResult(js);
    } catch (_) {
      r = '';
    }
    if (_over) return;
    var s = '$r';
    if (s.startsWith('"')) s = s.substring(1, s.length - 1);
    if (s != 'ok') {
      // Nichts gedrückt (Element fehlt, gesperrt) – sicher nichts geändert.
      return _finish(MealOrderResult(MealOrderOutcome.notDone, week: week));
    }
    _actedAt = DateTime.now();
    _lastActivity = DateTime.now();
    _tick = Timer.periodic(const Duration(milliseconds: 700), (_) => _poll());
  }

  /// Nach dem Klick: neue Fenster der Seite bestätigen; wenn die Seite
  /// 2,5 s ruht (keine Navigation, keine Anfrage, kein Fenster), neu laden.
  Future<void> _poll() async {
    if (_phase != _Phase.act || _over || _polling) return;
    _polling = true;
    try {
      var pending = 0;
      try {
        final r = await _c.runJavaScriptReturningResult(mealModalJs);
        var s = '$r';
        if (s.startsWith('"')) s = jsonDecode(s) as String;
        final m = jsonDecode(s);
        if (m is Map) {
          pending = (m['p'] as num?)?.toInt() ?? 0;
          if (m['s'] != 'none') {
            final t = '${m['t'] ?? ''}'.trim();
            if (t.isNotEmpty) _message = t;
            if (m['s'] == 'clicked') _lastActivity = DateTime.now();
          }
        }
      } catch (_) {}
      if (_phase != _Phase.act || _over) return;
      final now = DateTime.now();
      if (!_loading &&
          pending <= 0 &&
          now.difference(_lastActivity) > const Duration(milliseconds: 2500) &&
          now.difference(_actedAt!) > const Duration(milliseconds: 2500)) {
        _tick?.cancel();
        _phase = _Phase.verify;
        await _reloadForVerify();
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _reloadForVerify() async {
    try {
      await _c.runJavaScript(mealStaleMarkJs);
    } catch (_) {}
    _verifyFrom = _page;
    if (_over) return;
    await _c.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _check(MealWeek? week) async {
    final d = week == null ? null : _dayOf(week);
    final o = widget.option;
    bool sameDish(MealOption? x) =>
        x != null &&
        o != null &&
        (x.id != null && o.id != null ? x.id == o.id : x.name == o.name);
    final ok =
        d != null &&
        (o == null
            ? d.state != MealState.ordered
            : d.state == MealState.ordered && sameDish(d.ordered));
    if (!ok && _verifies == 0) {
      // Langsamer Caterer: einmal kurz warten und erneut lesen.
      _verifies++;
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!_over && _phase == _Phase.verify) await _reloadForVerify();
      return;
    }
    _finish(
      MealOrderResult(
        ok ? MealOrderOutcome.ok : MealOrderOutcome.unclear,
        week: week,
        message: ok ? null : _message,
      ),
    );
  }

  Future<bool> _login() async {
    final l = await readMensaLogin(widget.owner);
    final host = Uri.tryParse(await _c.currentUrl() ?? '')?.host;
    if (l == null || host != l.host || _over || _triedLogin) return false;
    _triedLogin = true;
    try {
      final r = await _c.runJavaScriptReturningResult(mensaLoginFillJs(l));
      if ('$r'.contains('filled')) {
        _afterLogin = true;
        _fillPage = _page;
        return true;
      }
    } catch (_) {}
    return false;
  }

  void _finish(MealOrderResult r) {
    if (_phase == _Phase.done) return;
    _phase = _Phase.done;
    _tick?.cancel();
    _timeout?.cancel();
    if (mounted) widget.onResult(r);
  }

  @override
  void dispose() {
    _phase = _Phase.done;
    _tick?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  /// Volle Größe hinter einer deckenden Fläche (hiddenWebView,
  /// MealFetcher: 1 × 1 arbeitete auf dem Pixel nicht).
  @override
  Widget build(BuildContext context) =>
      hiddenWebView(WebViewWidget(controller: _c));
}
