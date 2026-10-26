import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../mensa.dart' show mensaAllows;
import '../../mensa_week.dart';

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
/// Ablauf: [url] laden, lesen; mit [weeks] > 1 auch die Folgewoche
/// (MealWeek.next). Ist eine Seite nicht lesbar (Anmeldeseite, anderer
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
    this.weeks = 2,
    this.timeout = const Duration(seconds: 30),
  });

  final String url;
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
  var _done = false;
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
    _loading = url;
    _c.loadRequest(Uri.parse(url));
  }

  Future<void> _onPage() async {
    if (_done) return;
    final url = await _c.currentUrl();
    final src = await pageHtml(_c);
    if (_done || !mounted) return;
    final week = src == null ? null : parseMealWeek(src);
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
    final next = week.next;
    if (_read < widget.weeks && next != null) {
      final target = Uri.parse(url ?? _loading ?? widget.url).resolve(next);
      if (mensaAllows(_home, target)) {
        _load(target.toString());
        return;
      }
    }
    _finish();
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
