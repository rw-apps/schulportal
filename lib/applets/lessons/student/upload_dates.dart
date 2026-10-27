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
