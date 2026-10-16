import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Hält den Sitzungsschlüssel `sid` des Schulportals eindeutig, wenn das
/// Portal ihn mitten in der Sitzung austauscht.
///
/// Ursache (Debug-Export Schule A, Elternkonto, 16.10.26 09:54):
/// Die Antwort auf `dateispeicher.php?a=view&folder=0` setzte einen NEUEN
/// `sid` mit `domain=schulportal.hessen.de`; ab der nächsten Anfrage war die
/// App abgemeldet („Login nötig“, alle weiteren Presets). Der Cookie-Speicher
/// (cookie_jar 4.0.9, DefaultCookieJar) legt Cookies MIT domain-Attribut in
/// `domainCookies`, Cookies OHNE in `hostCookies` ab — der neue `sid`
/// überschreibt den alten aus der Anmeldung also nicht, sondern steht daneben.
/// `loadForRequest` liefert Host-Cookies zuerst, der Cookie-Kopf lautet dann
/// `sid=ALT; sid=NEU`, und PHP wertet bei doppelten Namen den ersten aus.
///
/// Abhilfe: Für Antworten von start.schulportal.hessen.de wird beim `sid` das
/// domain-Attribut entfernt. Der neue Schlüssel landet so als Host-Cookie
/// genau auf dem Platz des alten und ersetzt ihn. Läge doch einmal ein
/// domain-weiter `sid` im Speicher, gewinnt der neue trotzdem, weil
/// Host-Cookies zuerst gesendet werden.
///
/// Grenze: Nur `sid`, nur Host start.schulportal.hessen.de. Die Anmeldung über
/// login./connect.schulportal.hessen.de (LanisSession.getLoginURL in liblanis)
/// braucht domainweite Cookies und bleibt unberührt. Die Sitzungs-Dio spricht
/// sonst nur mit start.* — dass der `sid` dort jetzt hostgebunden ist, ändert
/// für sie nichts.
class SidRotationAdapter implements HttpClientAdapter {
  SidRotationAdapter(this.inner);

  final HttpClientAdapter inner;

  static const portalHost = 'start.schulportal.hessen.de';

  /// Gleiche Trennregel wie dio_cookie_manager 3.5.0 (`_setCookieReg`), damit
  /// zusammengefasste Set-Cookie-Werte („i=…; secure,sid=…“) genauso
  /// zerlegt werden wie später im CookieManager.
  static final _setCookieSplit = RegExp('(?<=)(,)(?=[^;]+?=)');
  static final _domainAttr = RegExp(r';\s*domain=[^;]*', caseSensitive: false);

  /// Entfernt das domain-Attribut aus jedem `sid`-Cookie in [value].
  static String normalizeSetCookie(String value) {
    return value
        .split(_setCookieSplit)
        .map((part) {
          if (!part.trimLeft().toLowerCase().startsWith('sid=')) return part;
          return part.replaceAll(_domainAttr, '');
        })
        .join(',');
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = await inner.fetch(options, requestStream, cancelFuture);
    if (options.uri.host != portalHost) return response;
    for (final key in response.headers.keys.toList()) {
      if (key.toLowerCase() != 'set-cookie') continue;
      response.headers[key] =
          response.headers[key]!.map(normalizeSetCookie).toList();
    }
    return response;
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
}
