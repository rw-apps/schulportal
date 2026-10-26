import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../mensa.dart' show mensaAllows;
import '../../mensa_login.dart';
import '../../mensa_week.dart';
import '../today/today_page.dart' show schoolWeek;

/// Quelltext der geladenen Seite aus einer eingebetteten Ansicht; null bei
/// Fehler. Android liefert Zeichenketten JSON-kodiert („"<html…"“).
Future<String?> pageHtml(WebViewController c) async {
  try {
    final r = await c.runJavaScriptReturningResult(
      'document.documentElement.outerHTML',
    );
    if (r is! String) return null;
    if (r.startsWith('"')) {
      final v = jsonDecode(r);
      return v is String ? v : null;
    }
    return r;
  } catch (_) {
    return null;
  }
}

/// Unsichtbare eingebettete Ansicht (1 × 1), die Wochenseiten des Caterers
/// lädt und liest (mensa_week.dart).
///
/// Ursache: Die Seiten sind nur mit der Anmeldung lesbar, die in der
/// eingebetteten Ansicht gespeichert ist (MensaPage, gemeinsamer
/// Cookie-Speicher von Android); ein eigener Abruf hätte sie nicht. Deshalb
/// lädt die App die Seite wie MensaPage, nur ohne sie zu zeigen.
///
/// Ablauf: [url] laden, lesen; bis [want] und [weeks] Wochen danach da
/// sind, über MealWeek.prev/next weiter. Ist eine Seite nicht lesbar (Anmeldeseite, anderer
/// Aufbau), endet der Abruf mit [onUnreadable]. Grenzen: Navigation nur zur
/// eingetragenen Seite (mensaAllows); nach [timeout] ohne Ergebnis endet
/// der Abruf still ([onDone]).
class MealFetcher extends StatefulWidget {
  const MealFetcher({
    super.key,
    required this.url,
    required this.onWeek,
    required this.onDone,
    this.onUnreadable,
    this.owner,
    this.want,
    this.weeks = 2,
    this.timeout = const Duration(seconds: 30),
  });

  final String url;

  /// Kind (MensaPage.owner): Ist dessen Anmeldung gemerkt
  /// (mensa_login.dart), meldet sich der Abruf auf einer Anmeldeseite
  /// einmal selbst an und lädt danach die gewünschte Woche neu.
  final String? owner;

  /// Gewünschte Schulwoche (Montag); null = die Woche, die [url] zeigt.
  /// Zeigt die Seite eine spätere Woche (manche Caterer öffnen gleich die
  /// nächste Bestellwoche), geht der Abruf über „vorherige Woche“ zurück.
  /// Ursache (Bildschirmfoto 27.10.26): Ohne das fehlte die laufende Woche,
  /// und Heute kannte das Essen von heute nicht.
  final DateTime? want;

  /// Anzahl Wochen ab [want]: 1 = nur diese, 2 = auch die folgende.
  final int weeks;
  final Duration timeout;
  final void Function(MealWeek week) onWeek;
  final VoidCallback? onUnreadable;
  final VoidCallback onDone;

  @override
  State<MealFetcher> createState() => _MealFetcherState();
}

class _MealFetcherState extends State<MealFetcher> {
  late final Uri _home = Uri.parse(widget.url);
  late final WebViewController _c;
  Timer? _timer;
  var _read = 0;
  var _loads = 0;
  final _seen = <DateTime>{};
  List<DateTime>? _targets;
  var _done = false;
  var _triedLogin = false;
  var _afterLogin = false;
  String? _loading;

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
          onPageFinished: (_) => _onPage(),
          onWebResourceError: (e) {
            if (e.isForMainFrame != false) _finish();
          },
        ),
      );
    _timer = Timer(widget.timeout, _finish);
    _load(widget.url);
  }

  void _load(String url) {
    _loads++;
    _loading = url;
    _c.loadRequest(Uri.parse(url));
  }

  Future<void> _onPage() async {
    if (_done) return;
    final url = await _c.currentUrl();
    final src = await pageHtml(_c);
    if (_done || !mounted) return;
    final week = src == null ? null : parseMealWeek(src);
    if (week == null && await _login()) return;
    if (week == null) {
      // Zwischenseite einer Weiterleitung? Nur die erste Seite zählt als
      // „nicht lesbar“, wenn nichts mehr nachkommt – kurz abwarten.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (_done || !mounted) return;
      if ((await _c.currentUrl()) != url) return;
      if (_read == 0) widget.onUnreadable?.call();
      _finish();
      return;
    }
    _read++;
    widget.onWeek(week);
    final ws = schoolWeek(week.start).first;
    _seen.add(ws);
    final first = widget.want ?? ws;
    final targets = _targets ??= [
      for (var i = 0; i < widget.weeks; i++)
        DateTime(first.year, first.month, first.day + 7 * i),
    ];
    final missing = [
      for (final x in targets)
        if (!_seen.contains(x)) x,
    ];
    // Höchstens vier Seiten je Abruf (zurück, dann vor).
    if (missing.isNotEmpty && _loads < 4) {
      final link = missing.first.isBefore(ws) ? week.prev : week.next;
      if (link != null) {
        final target = Uri.parse(url ?? _loading ?? widget.url).resolve(link);
        if (mensaAllows(_home, target)) {
          _load(target.toString());
          return;
        }
      }
    }
    _finish();
  }

  /// true = Anmeldung läuft bzw. Woche wird neu geladen; auf die nächste
  /// Seite warten.
  Future<bool> _login() async {
    final owner = widget.owner;
    if (owner == null) return false;
    if (_afterLogin) {
      // Nach der Anmeldung leitet der Caterer meist auf seine Startseite.
      _afterLogin = false;
      _load(_loading ?? widget.url);
      return true;
    }
    if (_triedLogin) return false;
    final l = await readMensaLogin(owner);
    final host = Uri.tryParse(await _c.currentUrl() ?? '')?.host;
    if (l == null || host != l.host || _done || !mounted) return false;
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

  void _finish() {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 1, height: 1, child: WebViewWidget(controller: _c));
}
