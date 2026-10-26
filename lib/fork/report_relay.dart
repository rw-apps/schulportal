import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:liblanis/liblanis.dart';

import 'error_log.dart';

/// Adresse des Weiterleitungsdiensts (Cloudflare Worker, Entwurf
/// tools/report-relay/worker.js, abgenommen 26.10.26). Leer, solange der
/// Dienst nicht eingerichtet ist: Dann bietet die App kein automatisches
/// Melden an, und „Anonym senden“ öffnet das Teilen-Menü.
///
/// Ursache: Die App hat bewusst keinen eigenen Server (Entscheidung
/// 17.10.26), und ein GitHub-Schlüssel in der offenen App wäre öffentlich;
/// der Dienst hält den Schlüssel und legt ein Issue im privaten
/// Berichte-Repo an.
const reportRelayUrl = '';

bool get relayConfigured => reportRelayUrl.isNotEmpty;

/// Zustimmung zum automatischen Melden: true/false, null = noch nicht
/// gefragt (Karte auf Heute, AutoReportPrompt).
const autoReportKey = 'fork/auto-report';

/// Schon gemeldete Einträge des Fehlerprotokolls: {ErrorRecord.key: count}.
const autoReportSentKey = 'fork/auto-report-sent';

/// Einen Bericht an den Dienst senden. true = angenommen.
///
/// [kind] „fehler“ (ErrorLog.report, ohne Inhalte) oder „seite“ (eine
/// anonymisierte Portalseite, Anonymizer). Grenze: Der Dienst begrenzt
/// Größe (400 KB) und Anzahl je Tag; abgelehnt heißt hier nur false, die
/// App versucht es beim nächsten Start erneut.
Future<bool> sendReport({
  required String kind,
  required String version,
  required String area,
  required String text,
  Dio? dio,
}) async {
  if (!relayConfigured) return false;
  final d = dio ?? Dio();
  try {
    final r = await d.post<String>(
      reportRelayUrl,
      data: jsonEncode({
        'kind': kind,
        'version': version,
        'area': area,
        'text': text,
      }),
      options: Options(
        contentType: Headers.jsonContentType,
        validateStatus: (_) => true,
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    return r.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    if (dio == null) d.close();
  }
}

/// Neue Einträge des Fehlerprotokolls melden, wenn zugestimmt wurde.
/// Neu = Schlüssel unbekannt oder Anzahl gestiegen. Gemeldet wird der
/// ganze Bericht (ErrorLog.report) – derselbe Text, den „Teilen“ zeigt.
///
/// Aufgerufen beim Start (PreviewShell) und gleich nach der Zustimmung.
Future<bool> flushErrorReports(
  TypedSettings settings, {
  required String os,
  ErrorLog? log,
  Dio? dio,
  Future<bool> Function({
    required String kind,
    required String version,
    required String area,
    required String text,
  })?
  send,
}) async {
  final l = log ?? ErrorLog.instance;
  if (!relayConfigured && send == null) return false;
  if (settings.getBool(autoReportKey) != true || l.records.isEmpty) {
    return false;
  }
  Map<String, dynamic> sent;
  try {
    sent =
        jsonDecode(settings.getString(autoReportSentKey) ?? '{}')
            as Map<String, dynamic>;
  } catch (_) {
    sent = {};
  }
  final fresh = [
    for (final r in l.records)
      if (sent[r.key] != r.count) r,
  ];
  if (fresh.isEmpty) return false;
  final ok =
      await (send ??
          ({required kind, required version, required area, required text}) =>
              sendReport(
                kind: kind,
                version: version,
                area: area,
                text: text,
                dio: dio,
              ))(
        kind: 'fehler',
        version: fresh.first.version,
        area: '${fresh.first.area} · ${fresh.first.type}',
        text: l.report(os: os),
      );
  if (ok) {
    settings.setString(
      autoReportSentKey,
      jsonEncode({for (final r in l.records) r.key: r.count}),
    );
  }
  return ok;
}
