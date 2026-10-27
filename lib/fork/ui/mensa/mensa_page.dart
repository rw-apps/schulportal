import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart' show sharedOverAccountSettingsProvider;
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:webview_flutter/webview_flutter.dart';

import 'package:lanis/utils/safe_launch.dart';

import '../../l10n/l10n.dart';
import '../../mensa.dart';
import '../../mensa_login.dart';
import '../kit.dart';
import '../../mensa_store.dart';
import '../../mensa_week.dart';
import 'meal_fetcher.dart' show pageHtml;
import 'mensa_unclip.dart';

/// Wer zuletzt auf welcher Bestellseite war (geräteweit, Host → Kind).
///
/// Ursache: Die eingebettete Seite teilt sich mit allen anderen in der App
/// einen Cookie-Speicher (Android-WebView). Öffnet man nach einem Kind die
/// gleiche Seite für ein anderes, wäre noch das erste angemeldet – und man
/// bestellte unbemerkt fürs falsche Kind. Deshalb erscheint dann ein Hinweis
/// mit „Abmelden“. Grenze: Teilen sich Geschwister EIN Konto beim Caterer,
/// ist der Hinweis überflüssig und lässt sich einfach schließen.
const mensaLastKey = 'fork-mensa/last';

/// Bestellseite in der App; die Anmeldung bleibt gespeichert, bis man sich
/// in der App abmeldet (Einstellungen → Abmelden löscht alle Web-Cookies).
class MensaPage extends ConsumerStatefulWidget {
  const MensaPage({
    super.key,
    required this.url,
    required this.owner,
    this.childName,
    this.open,
  });

  /// Genau diese Adresse öffnen (eine Woche aus „Essen“); null = die
  /// Bestellwoche (mensaWeekUrl). Ursache: Sonst ersetzte mensaWeekUrl die
  /// gewählte Woche wieder durch die Bestellwoche.
  final String? open;

  /// Eingetragene Adresse (normalizeMensaUrl); die Woche wird beim Öffnen
  /// ersetzt (mensaWeekUrl).
  final String url;

  /// Eindeutig je Konto und Kind (`konto:kind`).
  final String owner;

  final String? childName;

  @override
  ConsumerState<MensaPage> createState() => _MensaPageState();
}

class _MensaPageState extends ConsumerState<MensaPage> {
  late final Uri _home = Uri.parse(widget.url);
  late final WebViewController _c;
  int _progress = 0;
  bool _failed = false;
  String? _otherName;

  /// Gemerkte Anmeldung je Seite höchstens einmal einsetzen (mensa_login.dart).
  bool _triedLogin = false;
  bool _afterLogin = false;
  bool _asked = false;

  String get _start => widget.open ?? mensaWeekUrl(widget.url, DateTime.now());

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(kitWebCanvas)
      ..addJavaScriptChannel(
        mensaLoginChannel,
        onMessageReceived: (m) => _onLogin(m.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _failed = false);
          },
          // Abgeschnittene Gerichte aufheben (mensa_unclip.dart). Fehler
          // (Seite schon verlassen) sind folgenlos: dann bleibt sie, wie
          // der Caterer sie liefert.
          onPageFinished: (_) {
            _c.runJavaScript(mensaUnclipJs).catchError((_) {});
            _c.runJavaScript(mensaLoginCaptureJs).catchError((_) {});
            _autoLogin();
            _remember();
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame != false && mounted) {
              setState(() => _failed = true);
            }
          },
          onNavigationRequest: (r) {
            final target = Uri.tryParse(r.url);
            if (target == null) return NavigationDecision.prevent;
            if (mensaAllows(_home, target)) return NavigationDecision.navigate;
            // Nur der Hauptrahmen öffnet extern; eingebettete Rahmen
            // (Werbung, Zähler) werden still verworfen.
            if (r.isMainFrame &&
                (target.scheme == 'https' || target.scheme == 'http')) {
              safeLaunchUrl(
                target,
                context: context,
                mode: LaunchMode.externalApplication,
              );
            }
            return NavigationDecision.prevent;
          },
        ),
      );
    _checkOwner();
    _c.loadRequest(Uri.parse(_start));
  }

  Future<bool> _hasPasswordField() async {
    try {
      final r = await _c.runJavaScriptReturningResult(
        "document.querySelector('input[type=password]') ? 1 : 0",
      );
      return '$r' == '1';
    } catch (_) {
      return false;
    }
  }

  /// Abgelaufene Sitzung: gemerkte Anmeldung einsetzen. Danach leitet der
  /// Caterer meist auf seine Startseite – dann einmal die gewünschte Woche
  /// neu laden.
  Future<void> _autoLogin() async {
    if (_afterLogin) {
      _afterLogin = false;
      if (!await _hasPasswordField() && mounted) {
        await _c.loadRequest(Uri.parse(_start));
      }
      return;
    }
    if (_triedLogin) return;
    final l = await readMensaLogin(widget.owner);
    final host = Uri.tryParse(await _c.currentUrl() ?? '')?.host;
    if (l == null || host != l.host || !mounted) return;
    try {
      final r = await _c.runJavaScriptReturningResult(mensaLoginFillJs(l));
      if ('$r'.contains('filled')) {
        _triedLogin = true;
        _afterLogin = true;
      }
    } catch (_) {}
  }

  /// Anmeldung eingegeben: einmal fragen, ob die App sie merken soll.
  Future<void> _onLogin(String message) async {
    final Object? v;
    try {
      v = jsonDecode(message);
    } catch (_) {
      return;
    }
    if (v is! Map) return;
    final h = v['h'], u = v['u'], p = v['p'];
    if (h is! String || u is! String || p is! String || u.isEmpty) return;
    if (!mensaAllows(_home, Uri(scheme: 'https', host: h))) return;
    if (_asked) return;
    final old = await readMensaLogin(widget.owner);
    if (old != null && old.user == u && old.pass == p && old.host == h) {
      return;
    }
    if (old == null && await mensaLoginDeclined(widget.owner)) return;
    if (!mounted) return;
    _asked = true;
    final t = context.t;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.mensaRememberTitle),
        content: Text(t.mensaRememberText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(t.mensaRememberNo),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(t.mensaRememberYes),
          ),
        ],
      ),
    );
    if (yes == true) {
      await saveMensaLogin(widget.owner, MensaLogin(host: h, user: u, pass: p));
    } else if (yes == false && old == null) {
      await declineMensaLogin(widget.owner);
    }
  }

  /// Gelesene Woche für „Essen“ und Heute merken (mensa_store.dart): Nach
  /// einer Bestellung hier stimmt die Anzeige ohne weiteren Abruf.
  Future<void> _remember() async {
    final src = await pageHtml(_c);
    final url = await _c.currentUrl();
    final w = (src == null ? null : parseMealWeek(src))?.withUrl(url);
    if (!mounted) return;
    if (w == null) return _hop(url);
    _hopDone = true;
    try {
      MealCache.instance
        ..attach(ref.read(sharedOverAccountSettingsProvider))
        ..put(widget.owner, [w]);
    } catch (_) {}
  }

  /// Erste Seite ohne Woche und ohne Anmeldemaske (Hinweisseite nach der
  /// Anmeldung): einmal dem Link zur Essensbestellung folgen (mealNavJs).
  /// Ursache (Bildschirmfoto 27.10.26): Sonst musste man über die Figur
  /// oben rechts und „Kundenbereich“ gehen. Grenze: nur beim Öffnen, nicht
  /// wenn man danach selbst auf die Startseite wechselt.
  bool _hopDone = false;

  Future<void> _hop(String? url) async {
    if (_hopDone || _afterLogin || await _hasPasswordField()) return;
    _hopDone = true;
    try {
      var h = '${await _c.runJavaScriptReturningResult(mealNavJs)}';
      if (h.startsWith('"')) h = jsonDecode(h) as String;
      final t = Uri.tryParse(h);
      if (h.isEmpty || t == null || h == url || !mensaAllows(_home, t)) return;
      if (mounted) await _c.loadRequest(t);
    } catch (_) {}
  }

  Map<String, dynamic> _readLast() {
    try {
      final raw = ref
          .read(sharedOverAccountSettingsProvider)
          .getString(mensaLastKey);
      final v = raw == null ? null : jsonDecode(raw);
      return v is Map<String, dynamic> ? v : {};
    } catch (_) {
      return {};
    }
  }

  void _checkOwner() {
    final last = _readLast();
    final prev = last[_home.host];
    if (prev is Map && prev['owner'] != widget.owner) {
      _otherName = '${prev['name'] ?? ''}';
    }
    last[_home.host] = {'owner': widget.owner, 'name': widget.childName ?? ''};
    try {
      ref
          .read(sharedOverAccountSettingsProvider)
          .setString(mensaLastKey, jsonEncode(last));
    } catch (_) {}
  }

  Future<void> _logout() async {
    await WebViewCookieManager().clearCookies();
    if (!mounted) return;
    setState(() => _otherName = null);
    _triedLogin = false;
    await _c.loadRequest(Uri.parse(_start));
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final other = _otherName;
    return Scaffold(
      backgroundColor: k.p.bg,
      appBar: AppBar(
        backgroundColor: k.p.bg,
        surfaceTintColor: k.p.bg,
        title: Text(
          widget.childName == null || widget.childName!.isEmpty
              ? t.orderMeal
              : t.orderMealFor(widget.childName!),
          style: k.section,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: t.reload,
            icon: const Icon(Icons.refresh),
            onPressed: () => _c.reload(),
          ),
          IconButton(
            tooltip: t.openInBrowser,
            icon: const Icon(Icons.open_in_browser),
            onPressed: () async {
              final now = await _c.currentUrl();
              if (!context.mounted) return;
              safeLaunchUrl(
                Uri.parse(now ?? mensaWeekUrl(widget.url, DateTime.now())),
                context: context,
                mode: LaunchMode.externalApplication,
              );
            },
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(Sz.progress),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: Sz.progress,
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          if (other != null)
            Material(
              color: k.p.change.bg,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Sp.l, Sp.s, Sp.s, Sp.s),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        other.isEmpty
                            ? t.mensaOtherLoggedIn
                            : t.mensaOtherLoggedInName(other),
                        style: k.boxText(k.p.change),
                      ),
                    ),
                    TextButton(
                      onPressed: _logout,
                      child: Text(t.mensaLogout, style: k.link),
                    ),
                    IconButton(
                      tooltip: t.close,
                      icon: Icon(Icons.close, color: k.p.change.ink),
                      onPressed: () => setState(() => _otherName = null),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _failed
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Sp.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.mensaLoadFailed,
                            style: k.meta,
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: () => _c.reload(),
                            child: Text(t.retry, style: k.link),
                          ),
                        ],
                      ),
                    ),
                  )
                : WebViewWidget(controller: _c),
          ),
        ],
      ),
    );
  }
}
