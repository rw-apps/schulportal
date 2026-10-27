import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../meal_order_js.dart';
import '../../mensa.dart' show mensaAllows;
import '../../mensa_login.dart';
import '../../mensa_week.dart';
import '../today/today_page.dart' show dayDiff;
import 'meal_fetcher.dart' show pageHtml;

/// Ergebnis eines Bestell- bzw. Abbestellvorgangs.
class MealOrderResult {
  const MealOrderResult({required this.ok, this.week, this.message});

  /// true nur, wenn die neu gelesene Seite den gewünschten Stand zeigt.
  final bool ok;

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
/// (sonst nichts tun) → Skript (meal_order_js.dart) → Fenster der Seite
/// bestätigen und ihren Text merken → nach Ruhe Woche neu laden → Ergebnis.
///
/// Grenzen: höchstens [timeout]; die App behauptet keinen Erfolg, den die
/// Seite nicht zeigt. Ob der Caterer eine Bestellung trotz Anzeige später
/// verwirft (z. B. Guthaben), sieht die App erst beim nächsten Lesen.
class MealOrderRunner extends StatefulWidget {
  const MealOrderRunner({
    super.key,
    required this.url,
    required this.owner,
    required this.day,
    required this.onResult,
    this.option,
    this.timeout = const Duration(seconds: 40),
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
  var _triedLogin = false;
  var _afterLogin = false;
  var _verifies = 0;
  String? _message;
  DateTime _lastActivity = DateTime.now();
  DateTime? _actedAt;
  Timer? _tick;
  Timer? _timeout;

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
          onPageStarted: (_) => _lastActivity = DateTime.now(),
          onPageFinished: (_) => _onPage(),
          onWebResourceError: (e) {
            if (e.isForMainFrame != false && _phase != _Phase.act) {
              _finish(const MealOrderResult(ok: false));
            }
          },
        ),
      );
    _timeout = Timer(
      widget.timeout,
      () => _finish(MealOrderResult(ok: false, message: _message)),
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
    return src == null ? null : parseMealWeek(src);
  }

  Future<void> _onPage() async {
    _lastActivity = DateTime.now();
    if (_phase == _Phase.done || !mounted) return;
    if (_phase == _Phase.act) return; // Seite lädt nach dem Klick neu.
    final week = await _read();
    if (_phase == _Phase.done || !mounted) return;
    if (week == null) {
      // Zwischenseite einer Weiterleitung? Kurz warten.
      final at = await _c.currentUrl();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (_phase == _Phase.done || !mounted) return;
      if ((await _c.currentUrl()) != at) return;
      if (_afterLogin) {
        _afterLogin = false;
        await _c.loadRequest(Uri.parse(widget.url));
        return;
      }
      if (!_triedLogin && await _login()) return;
      return _finish(MealOrderResult(ok: false, message: _message));
    }
    if (_phase == _Phase.verify) return _check(week);
    // Laden: Ausgangszustand prüfen, dann handeln.
    final d = _dayOf(week);
    final o = widget.option;
    final ready =
        d != null &&
        (o == null
            ? d.state == MealState.ordered && d.canCancel
            : d.state == MealState.open &&
                  d.options.any((x) => x.id == o.id && x.orderable));
    if (!ready) return _finish(MealOrderResult(ok: false, week: week));
    final js = o == null
        ? mealCancelJs(week.kind, widget.day, d.ordered)
        : mealOrderJs(week.kind, widget.day, o);
    final Object r;
    try {
      r = await _c.runJavaScriptReturningResult(js);
    } catch (_) {
      return _finish(MealOrderResult(ok: false, week: week));
    }
    if (!'$r'.contains('ok')) {
      return _finish(MealOrderResult(ok: false, week: week));
    }
    _phase = _Phase.act;
    _actedAt = DateTime.now();
    _lastActivity = DateTime.now();
    _tick = Timer.periodic(const Duration(milliseconds: 700), (_) => _poll());
  }

  /// Nach dem Klick: Fenster der Seite bestätigen; nach 2,5 s Ruhe (keine
  /// Navigation, kein Fenster) die Woche neu laden und prüfen.
  Future<void> _poll() async {
    if (_phase != _Phase.act || !mounted) return;
    try {
      final r = await _c.runJavaScriptReturningResult(mealModalJs);
      var s = '$r';
      if (s.startsWith('"')) s = jsonDecode(s) as String;
      final m = jsonDecode(s);
      if (m is Map && m['s'] != 'none') {
        final t = '${m['t'] ?? ''}'.trim();
        if (t.isNotEmpty) _message = t;
        _lastActivity = DateTime.now();
        return;
      }
    } catch (_) {}
    final now = DateTime.now();
    if (now.difference(_lastActivity) > const Duration(milliseconds: 2500) &&
        now.difference(_actedAt!) > const Duration(milliseconds: 2500)) {
      _tick?.cancel();
      _phase = _Phase.verify;
      await _c.loadRequest(Uri.parse(widget.url));
    }
  }

  Future<void> _check(MealWeek week) async {
    final d = _dayOf(week);
    final o = widget.option;
    final ok =
        d != null &&
        (o == null
            ? d.state != MealState.ordered
            : d.state == MealState.ordered &&
                  (d.ordered?.id == o.id || d.ordered?.name == o.name));
    if (!ok && _verifies == 0) {
      // Langsamer Caterer: einmal kurz warten und erneut lesen.
      _verifies++;
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted && _phase == _Phase.verify) {
        await _c.loadRequest(Uri.parse(widget.url));
      }
      return;
    }
    _finish(MealOrderResult(ok: ok, week: week, message: ok ? null : _message));
  }

  Future<bool> _login() async {
    final l = await readMensaLogin(widget.owner);
    final host = Uri.tryParse(await _c.currentUrl() ?? '')?.host;
    if (l == null || host != l.host || !mounted) return false;
    try {
      final r = await _c.runJavaScriptReturningResult(mensaLoginFillJs(l));
      if ('$r'.contains('filled')) {
        _triedLogin = true;
        _afterLogin = true;
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
    widget.onResult(r);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 1, height: 1, child: WebViewWidget(controller: _c));
}
