import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../mensa.dart' show mensaAllows;
import '../../mensa_login.dart';
import '../../mensa_store.dart' show mealNavJs;
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

/// Eingebettete Ansicht, die Wochenseiten des Caterers lädt und liest
/// (mensa_week.dart), ohne sie zu zeigen.
///
/// Ursache: Die Seiten sind nur mit der Anmeldung lesbar, die in der
/// eingebetteten Ansicht gespeichert ist (MensaPage, gemeinsamer
/// Cookie-Speicher von Android); ein eigener Abruf hätte sie nicht. Deshalb
/// lädt die App die Seite wie MensaPage, nur ohne sie zu zeigen.
///
/// Platzierung (9420): in voller Größe HINTER einer deckenden Fläche
/// (Positioned.fill als unterstes Kind eines Stack), nicht mehr 1 × 1
/// bzw. durchsichtig. Ursache (Bildschirmfotos 27.10.26): Auf dem Pixel
/// lasen beide Caterer nie neu, während dieselbe Adresse in MensaPage
/// (sichtbar, volle Größe) lesbar war – gespeicherte Wochen stammten nur aus
/// MensaPage, und nach dem Formatwechsel (MealWeek.format) blieb „Essen“
/// leer. Grenze: Ursache auf dem Gerät nicht nachgestellt; [MealTrace]
/// zeichnet jeden Abruf auf, die Ansicht „Essen“ zeigt ihn bei Fehlschlag.
///
/// Ablauf: [url] laden, lesen; bis [want] und [weeks] Wochen danach da
/// sind, über MealWeek.prev/next weiter. Ist eine Seite nicht lesbar (Anmeldeseite, anderer
/// Aufbau), endet der Abruf mit [onUnreadable]. Grenzen: Navigation nur zur
/// eingetragenen Seite (mensaAllows); nach [timeout] ohne Ergebnis endet
/// der Abruf still ([onDone]). Meldet die Ansicht das Seitenende nicht
/// binnen [_watch], liest der Abruf trotzdem.
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
    this.timeout = const Duration(seconds: 45),
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

/// Verlauf des letzten Abrufs je Kind, nur im Speicher (nicht gesichert):
/// Pfade ohne Abfrage, Zeitpunkte, Ergebnis je Seite. Für die Fehlersuche
/// auf dem Gerät (Ansicht „Essen“ → „Details“); Seiteninhalt und
/// Anmeldedaten stehen nie darin.
class MealTrace {
  static final _byOwner = <String, List<String>>{};

  static List<String> of(String owner) => _byOwner[owner] ?? const [];

  static String path(String? url) {
    final u = Uri.tryParse(url ?? '');
    return u == null ? '?' : '${u.host}${u.path}';
  }
}

class _MealFetcherState extends State<MealFetcher> {
  late final Uri _home = Uri.parse(widget.url);
  final _sw = Stopwatch()..start();
  final _log = <String>[];

  /// Seitenende nicht gemeldet: nach dieser Zeit trotzdem lesen.
  static const _watch = Duration(seconds: 10);
  Timer? _watchdog;

  /// Zählt Ladevorgänge; ein Lesen, das während eines neuen Ladens endet,
  /// verwirft sein Ergebnis.
  var _gen = 0;

  void _trace(String line) {
    final s = (_sw.elapsedMilliseconds / 1000).toStringAsFixed(1);
    _log.add('+${s}s $line');
    if (widget.owner case final o?) MealTrace._byOwner[o] = List.of(_log);
  }

  late final WebViewController _c;
  Timer? _timer;
  var _read = 0;
  var _loads = 0;
  var _hops = 0;
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
          onPageFinished: (u) {
            _trace('finished ${MealTrace.path(u)}');
            _onPage();
          },
          // Nur ohne Verbindung abbrechen. Andere Fehler des Hauptrahmens
          // (z. B. abgebrochenes Laden, wenn die Seite selbst weiterleitet)
          // beendeten den Abruf bisher still – nur aufzeichnen; Seitenende,
          // Wächter oder [timeout] führen weiter.
          onWebResourceError: (e) {
            if (e.isForMainFrame != true) return;
            _trace('error ${e.errorCode} ${e.errorType?.name ?? ''}');
            if (e.errorType
                case WebResourceErrorType.hostLookup ||
                    WebResourceErrorType.connect ||
                    WebResourceErrorType.timeout) {
              _finish();
            }
          },
        ),
      );
    _timer = Timer(widget.timeout, () {
      _trace('timeout');
      _finish();
    });
    _load(widget.url);
  }

  void _load(String url) {
    _loads++;
    _gen++;
    _loading = url;
    _trace('load ${MealTrace.path(url)}');
    _watchdog?.cancel();
    _watchdog = Timer(_watch, () {
      _trace('no finish event');
      _onPage();
    });
    _c.loadRequest(Uri.parse(url)).catchError((Object e) {
      _trace('load failed ${e.runtimeType}');
    });
  }

  /// Ein Lesen zur Zeit. Meldet die Ansicht währenddessen ein weiteres
  /// Seitenende (Weiterleitung nach der Anmeldung), wird danach noch einmal
  /// gelesen – außer das laufende Lesen hat schon die nächste Seite geladen.
  var _busy = false;
  int? _pendingGen;

  Future<void> _onPage() async {
    if (_done) return;
    _watchdog?.cancel();
    if (_busy) {
      _pendingGen = _gen;
      return;
    }
    _busy = true;
    try {
      await _readPage();
    } finally {
      _busy = false;
    }
    final again = _pendingGen;
    _pendingGen = null;
    if (again != null && again == _gen && !_done && mounted) _onPage();
  }

  Future<void> _readPage() async {
    final gen = _gen;
    final url = await _c.currentUrl();
    final src = await pageHtml(_c);
    if (_done || !mounted || gen != _gen) return;
    MealWeek? week;
    try {
      week = src == null ? null : parseMealWeek(src);
    } catch (e) {
      _trace('parse error ${e.runtimeType}');
    }
    _trace(
      'read ${MealTrace.path(url)} html=${src?.length ?? '-'} '
      'week=${week == null ? 'no' : week.label}',
    );
    if (week == null && await _login()) return;
    if (week == null) {
      // Zwischenseite einer Weiterleitung? Nur die erste Seite zählt als
      // „nicht lesbar“, wenn nichts mehr nachkommt – kurz abwarten.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (_done || !mounted || gen != _gen) return;
      if ((await _c.currentUrl()) != url) {
        _trace('moved on');
        return;
      }
      // Start- oder Hinweisseite nach der Anmeldung: dem Link zur
      // Essensbestellung folgen (mealNavJs), höchstens zweimal.
      if (_hops < 2) {
        try {
          var h = '${await _c.runJavaScriptReturningResult(mealNavJs)}';
          if (h.startsWith('"')) h = jsonDecode(h) as String;
          final target = Uri.tryParse(h);
          if (h.isNotEmpty &&
              target != null &&
              mensaAllows(_home, target) &&
              h != url) {
            _hops++;
            _trace('hop');
            _load(h);
            return;
          }
        } catch (_) {}
      }
      if (_done || !mounted || gen != _gen) return;
      if (_read == 0) {
        _trace('unreadable');
        widget.onUnreadable?.call();
      }
      _finish();
      return;
    }
    _read++;
    widget.onWeek(week.withUrl(url));
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
    // Höchstens sechs Seiten je Abruf (Anmeldung, Startseite, zurück, vor).
    if (missing.isNotEmpty && _loads < 6) {
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
      _trace('reload after login');
      _load(_loading ?? widget.url);
      return true;
    }
    if (_triedLogin) return false;
    final l = await readMensaLogin(owner);
    final host = Uri.tryParse(await _c.currentUrl() ?? '')?.host;
    if (l == null || host != l.host || _done || !mounted) {
      _trace(l == null ? 'no saved login' : 'login host differs');
      return false;
    }
    try {
      final r = await _c.runJavaScriptReturningResult(mensaLoginFillJs(l));
      _trace('login fill: $r');
      if ('$r'.contains('filled')) {
        _triedLogin = true;
        _afterLogin = true;
        // Manche Anmeldeseiten melden sich per Skript an und leiten erst
        // danach weiter (React, bis zu 6 s Warten auf das Hydrieren in
        // mensaLoginFillJs); bleibt die Weiterleitung aus (falsches
        // Passwort, Fehlermeldung auf der Seite), nach 15 s trotzdem
        // weiter – sonst endete der Abruf erst am timeout, ohne Befund.
        _watchdog?.cancel();
        _watchdog = Timer(const Duration(seconds: 15), () {
          _trace('no page after login');
          _onPage();
        });
        return true;
      }
    } catch (_) {}
    return false;
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    _watchdog?.cancel();
    _trace('done, weeks read: $_read');
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  /// Füllt den vorgegebenen Platz; der Aufrufer legt eine deckende Fläche
  /// darüber (Klassenkommentar).
  @override
  Widget build(BuildContext context) =>
      hiddenWebView(WebViewWidget(controller: _c));
}

/// Eingebettete Ansicht, die arbeitet, aber nicht bedient oder vorgelesen
/// wird; in voller Größe hinter eine deckende Fläche legen (MealFetcher).
Widget hiddenWebView(Widget view) => IgnorePointer(
  child: ExcludeSemantics(child: SizedBox.expand(child: view)),
);
