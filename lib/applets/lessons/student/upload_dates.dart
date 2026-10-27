import 'package:intl/intl.dart';

/// Parses Lanis upload deadline strings shown in the student upload UI.
///
/// Fork: jedes Feld einzeln und nullbar. Ursache (Prüfung 27.10.26): Fehlte
/// eines der drei Felder (liblanis StudentParser.getUploadInfo liefert
/// start/deadline/automatic_deletion als `String?`, Selektor „span.editable“
/// bzw. „label-info“), wurde die ganze Abgabeseite zur Fehlerseite – ohne
/// Dateien, ohne Abgabe. Jetzt zeigt die Seite das fehlende Feld nur nicht an.
/// Grenze: Ohne Start gilt die Abgabe als „schon begonnen“, ohne Löschdatum
/// als „nicht gelöscht“ – die Entscheidung trifft ohnehin der Server.
class UploadDates {
  final DateTime? start;
  final DateTime? deadline;
  final DateTime? automaticDeletion;

  const UploadDates({this.start, this.deadline, this.automaticDeletion});

  static String _normalizeDateTime(String raw) =>
      raw.replaceAll(",", "").replaceAll(" den", "").replaceAll(" Uhr", "");

  static DateTime? _tryParse(String? raw, String pattern, bool normalize) {
    if (raw == null) return null;
    try {
      return DateFormat(
        pattern,
        "de",
      ).parse(normalize ? _normalizeDateTime(raw) : raw);
    } catch (_) {
      return null;
    }
  }

  /// Fork: liefert immer ein Objekt; ein fehlendes oder unlesbares Feld ist
  /// null (siehe Klassenkommentar).
  static UploadDates tryParse({
    required String? startRaw,
    required String? deadlineRaw,
    required String? deletionRaw,
  }) {
    return UploadDates(
      start: _tryParse(startRaw, "EEEE d.M.yy H:mm", true),
      deadline: _tryParse(deadlineRaw, "EEEE d.M.yy H:mm", true),
      automaticDeletion: _tryParse(deletionRaw, "d.M.yyyy", false),
    );
  }
}

/// Fork: Größenangabe des Portals („10 MB“, „2,5 MB“, „500 KB“) in Bytes;
/// null = unbekannt, dann prüft die App clientseitig keine Größe.
/// Ursache (Prüfung 27.10.26): upload_page.dart rechnete mit
/// `num.parse(raw.replaceAll("MB", ""))` – jede andere Einheit warf eine
/// FormatException im Knopf-Callback, die Dateiauswahl tat danach nichts.
/// Grenze: Dezimal wie bisher (1 MB = 1 000 000 Bytes); eine zu kleine
/// Grenze lehnt der Server ohnehin selbst ab.
num? parseMaxFileSizeBytes(String? raw) {
  if (raw == null) return null;
  final m = RegExp(
    r'^\s*(\d+(?:[.,]\d+)?)\s*(KB|MB|GB)\s*$',
    caseSensitive: false,
  ).firstMatch(raw);
  if (m == null) return null;
  final value = num.tryParse(m.group(1)!.replaceAll(",", "."));
  if (value == null) return null;
  return switch (m.group(2)!.toUpperCase()) {
    "KB" => value * 1000,
    "MB" => value * 1000000,
    _ => value * 1000000000,
  };
}

enum UploadWaitUnit { minute, hour, day }

/// Fork: Wartezeit bis zum Abgabestart als (Anzahl, Einheit).
/// Ursache (Prüfung 27.10.26): upload_page.dart rechnete
/// `now.difference(startDate)` – vor dem Start negativ, angezeigt wurde
/// „Abgabe möglich in -4320 Minuten“ (negative Stunden fielen immer in den
/// Minutenzweig `inHours <= 1`). Grenze: Schwellen wie in der Vorlage
/// (ab 24 h Tage, unter 2 h Minuten, sonst Stunden).
(int, UploadWaitUnit) uploadWaitingTime(DateTime start, DateTime now) {
  final Duration difference = start.difference(now);
  if (difference.inHours >= 24) {
    return (difference.inDays, UploadWaitUnit.day);
  } else if (difference.inHours <= 1) {
    return (difference.inMinutes, UploadWaitUnit.minute);
  }
  return (difference.inHours, UploadWaitUnit.hour);
}

/// Fork: Zeitpunkt einer eigenen Abgabe aus dem Text des Portals
/// (liblanis OwnFile.time, Selektor „small“), z. B. „26.10.2026 19:42“ oder
/// „(hochgeladen am 26.10.26 um 19:42 Uhr)“. Ursache (Abnahme 27.10.26):
/// Die neue Abgabeseite zeigt im Kopf „ABGEGEBEN Mo, 26. Oktober · 19:42“.
/// Grenze: Das genaue Muster des Portals ist nicht festgeschrieben – gesucht
/// wird das erste Datum „T.M.JJ(JJ)“ und eine Uhrzeit dahinter; ohne Datum
/// null, dann zeigt die Seite den Text roh ([cleanOwnFileTime]).
DateTime? parseOwnFileTime(String raw) {
  final m = RegExp(
    r'(\d{1,2})\.(\d{1,2})\.(\d{2,4})(?:\D{1,12}?(\d{1,2}):(\d{2}))?',
  ).firstMatch(raw);
  if (m == null) return null;
  final day = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  var year = int.parse(m.group(3)!);
  if (year < 100) year += 2000;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(
    year,
    month,
    day,
    int.tryParse(m.group(4) ?? '') ?? 0,
    int.tryParse(m.group(5) ?? '') ?? 0,
  );
}

/// Fork: Zeittext ohne Klammern und Leerraum am Rand (Anzeige, wenn
/// [parseOwnFileTime] nichts erkennt).
String cleanOwnFileTime(String raw) =>
    raw.trim().replaceAll(RegExp(r'^\(+|\)+$'), '').trim();

/// Fork: Dateigröße für die Abgabeliste („1,2 MB“, „350 KB“). Dezimal wie
/// [parseMaxFileSizeBytes], damit „bis 10 MB“ und „10,2 MB“ dieselbe
/// Einheit meinen. Grenze: unter 1 KB in Bytes.
String formatUploadSize(num bytes, String locale) {
  final f = NumberFormat('#,##0.#', locale);
  if (bytes >= 1000000000) return '${f.format(bytes / 1000000000)} GB';
  if (bytes >= 1000000) return '${f.format(bytes / 1000000)} MB';
  if (bytes >= 1000) {
    return '${NumberFormat('#,##0', locale).format(bytes / 1000)} KB';
  }
  return '${bytes.round()} B';
}
