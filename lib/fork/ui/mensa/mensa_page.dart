import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart' show sharedOverAccountSettingsProvider;
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:webview_flutter/webview_flutter.dart';

import 'package:lanis/utils/safe_launch.dart';

import '../../l10n/l10n.dart';
import '../../mensa.dart';
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
  });

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

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
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
    _c.loadRequest(Uri.parse(mensaWeekUrl(widget.url, DateTime.now())));
  }

  /// Gelesene Woche für „Essen“ und Heute merken (mensa_store.dart): Nach
  /// einer Bestellung hier stimmt die Anzeige ohne weiteren Abruf.
  Future<void> _remember() async {
    final src = await pageHtml(_c);
    final w = src == null ? null : parseMealWeek(src);
    if (w == null || !mounted) return;
    try {
      MealCache.instance
        ..attach(ref.read(sharedOverAccountSettingsProvider))
        ..put(widget.owner, [w]);
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
    await _c.loadRequest(Uri.parse(mensaWeekUrl(widget.url, DateTime.now())));
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
