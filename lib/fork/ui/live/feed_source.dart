import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:liblanis/liblanis.dart';

import '../../error_log.dart';
import '../../offline_store.dart';
import 'live_data.dart' show Feed;

/// Eine Quelle (Parser) der neuen Oberfläche mit ihrem letzten Stand
/// ([feed]); speichert und stellt bei Fehlern wieder her (offline_store.dart).
/// Aus live_data.dart herausgelöst (21.10.26), damit Speichern und Rückfall
/// eigene Tests haben (feed_source_test.dart).
class FeedSource<T> {
  FeedSource(this.phpUrl, {this.store});

  final String phpUrl;

  /// Eigene Ablage für Quellen, die liblanis nicht offline speichert
  /// (offline_store.dart); null = nur die von liblanis (allowOffline).
  final OfflineCodec<T>? store;
  AppletParser<T>? parser;
  StreamSubscription<FetcherResponse<T>>? sub;
  Feed<T> feed = const Feed();

  void attach(AppletParser<T> p, VoidCallback changed) {
    if (identical(p, parser)) return;
    sub?.cancel();
    parser = p;
    feed = Feed(content: p.latestResponse?.content);
    sub = p.stream.listen((r) {
      var c = r.content ?? feed.content;
      var offline = r.contentStatus == ContentStatus.offline;
      var at = r.status == FetcherStatus.done ? r.fetchedAt : feed.fetchedAt;
      final fresh = r.status == FetcherStatus.done && r.content != null;
      if (fresh && !offline) _save(r.content as T);
      // Fehler ohne Inhalt: gespeicherten Stand zeigen. Ursache
      // (Rückmeldung 21.10.26): liblanis greift auf die Ablage nur zurück,
      // wenn das GERÄT offline ist (AppletParser.fetchData, isConnected).
      // Antwortet bei bestehendem Netz das Schulportal nicht – morgens bei
      // Überlast –, blieben Heute und Kalender nach einem Neustart leer.
      if (c == null && r.status == FetcherStatus.error) {
        final back = restore();
        if (back != null) {
          c = back.content;
          offline = true;
          at = back.at;
        }
      }
      feed = Feed(
        content: c,
        loading: r.status == FetcherStatus.fetching,
        error: r.status == FetcherStatus.error
            ? (r.error?.exception ?? 'Fehler')
            : null,
        // Gespeicherter Stand bleibt „offline“, bis ein Abruf gelingt.
        offline: offline || (feed.offline && !fresh),
        fetchedAt: at,
      );
      changed();
    });
  }

  /// Nach jedem gelungenen Abruf in die eigene Ablage (nur [store]; die
  /// Quellen mit allowOffline speichert liblanis selbst). Fehler beim
  /// Speichern stören die Anzeige nicht, landen aber im Protokoll.
  void _save(T value) {
    final p = parser;
    final codec = store;
    if (p == null || codec == null) return;
    try {
      p.ctx.database.setAppletOfflineData(
        accountId: p.ctx.accountId,
        appletId: forkOfflineId(phpUrl),
        json: codec.encode(value, p),
      );
    } catch (e, st) {
      ErrorLog.instance.record('offline/$phpUrl', e, st);
    }
  }

  /// Zuletzt gespeicherter Stand samt Zeitpunkt, sonst null.
  ({T content, DateTime at})? restore() {
    final p = parser;
    if (p == null) return null;
    try {
      final codec = store;
      final db = p.ctx.database;
      if (codec != null) {
        final d = db.getAppletOfflineData(
          accountId: p.ctx.accountId,
          appletId: forkOfflineId(phpUrl),
        );
        return d == null
            ? null
            : (content: codec.decode(d.json, p), at: d.timestamp);
      }
      if (!p.appletMeta.allowOffline) return null;
      final d = db.getAppletOfflineData(
        accountId: p.ctx.accountId,
        appletId: phpUrl,
      );
      return d == null
          ? null
          : (content: p.typeFromJson(d.json), at: d.timestamp);
    } catch (e, st) {
      ErrorLog.instance.record('offline/$phpUrl', e, st);
      return null;
    }
  }

  /// Fehler, die fetchData selbst wirft (Neuanmeldung im zweiten Versuch,
  /// AppletParser.fetchData), statt sie als Antwort zu melden.
  void fail(Object e) {
    final back = feed.content == null ? restore() : null;
    feed = Feed(
      content: back?.content ?? feed.content,
      error: e,
      offline: back != null || feed.offline,
      fetchedAt: back?.at ?? feed.fetchedAt,
    );
  }

  void dispose() => sub?.cancel();
}
