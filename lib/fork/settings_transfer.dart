import 'dart:convert';

import 'package:liblanis/liblanis.dart';

import 'class_choice.dart' show classSetting;
import 'kid_colors.dart' show kidColorSetting;
import 'absences.dart' show absenceSentSetting, decodeSent, encodeSent;
import 'homework_ledger.dart';
import 'ui/live/live_data.dart'
    show
        groupChoiceSetting,
        lessonTimesSetting,
        mensaUrlSetting,
        mensaUrlsSetting,
        teacherNamesSetting;

/// Eingaben der Familie von einem Gerät aufs andere übertragen (Wunsch
/// 18.10.26: „die Daten ändern sich ja nur selten“).
///
/// Ursache für Datei statt Abgleich: Die App hat bewusst keinen eigenen
/// Server; ein laufender Abgleich bräuchte einen. Grenze: Was danach auf
/// einem Gerät geändert wird, kommt erst mit der nächsten Übertragung mit.
///
/// Was übertragen wird – je Konto, nur Eingaben der Familie, keine
/// Zugangsdaten und nichts aus dem Portal:
const transferKeys = [
  'stundenplan.php/$groupChoiceSetting', // Gruppenwahl im Stundenplan
  'stundenplan.php/$teacherNamesSetting', // selbst benannte Lehrkräfte
  'stundenplan.php/$lessonTimesSetting', // Stundenzeiten
  'fork/$mensaUrlsSetting', // Mensa je Kind
  'fork/$mensaUrlSetting', // Mensa (alte Form)
  homeworkLedgerSetting, // abgehakte Hausaufgaben
  absenceSentSetting, // gesendete Entschuldigungen
  classSetting, // eingetragene Klasse
  kidColorSetting, // Farbe des Kindes
];

/// Konto über Geräte hinweg: Schulnummer und Benutzername. Ursache: Die
/// lokale Kontonummer (localId) vergibt jedes Gerät selbst.
String transferAccountKey(int schoolId, String username) =>
    '$schoolId:${username.trim().toLowerCase()}';

const _format = 'schulportal-eingaben';

/// Datei-Inhalt aus den rohen gespeicherten Werten je Konto.
/// [values]: Kontoschlüssel → (Einstellung → roher Wert, null = fehlt).
String buildTransfer(
  Map<String, Map<String, String?>> values, {
  required DateTime now,
}) => const JsonEncoder.withIndent(' ').convert({
  'format': _format,
  'version': 1,
  'created': now.toIso8601String(),
  'accounts': {
    for (final a in values.entries)
      a.key: {
        for (final e in a.value.entries)
          if (e.value != null && transferKeys.contains(e.key)) e.key: e.value,
      },
  },
});

/// Gelesene Datei: Kontoschlüssel → (Einstellung → roher Wert); null, wenn
/// es keine Übertragungsdatei dieser App ist.
Map<String, Map<String, String>>? parseTransfer(String text) {
  try {
    final v = jsonDecode(text);
    if (v is! Map || v['format'] != _format) return null;
    final acc = v['accounts'];
    if (acc is! Map) return null;
    return {
      for (final a in acc.entries)
        if (a.value is Map)
          '${a.key}': {
            for (final e in (a.value as Map).entries)
              // Nur bekannte Schlüssel – eine fremde Datei schreibt nichts
              // anderes in die Einstellungen.
              if (transferKeys.contains('${e.key}') && e.value is String)
                '${e.key}': e.value as String,
          },
    };
  } catch (_) {
    return null;
  }
}

/// Wert, der nach dem Übernehmen gilt.
///
/// Abgehakte Hausaufgaben und gesendete Entschuldigungen werden
/// zusammengeführt (je Eintrag der neuere Stand), damit auf beiden Geräten
/// Abgehaktes nicht verloren geht; alles andere übernimmt die Datei.
/// [incoming] und [current] sind gespeicherte Rohwerte (LanisDatabase.
/// encodeValue); [decode]/[encode] wandeln in den Text dahinter.
String mergeValue(
  String key,
  String incoming,
  String? current, {
  required String? Function(String raw) decode,
  required String Function(String text) encode,
}) {
  if (current == null) return incoming;
  if (key == homeworkLedgerSetting) {
    final a = HomeworkLedger.decode(decode(current));
    final b = HomeworkLedger.decode(decode(incoming));
    final merged = {...a.byKey};
    for (final r in b.byKey.values) {
      final old = merged[r.key];
      if (old == null || r.changed.isAfter(old.changed)) merged[r.key] = r;
    }
    return encode(HomeworkLedger(merged).encode());
  }
  if (key == absenceSentSetting) {
    final a = decodeSent(decode(current));
    final b = decodeSent(decode(incoming));
    final merged = {...a};
    for (final e in b.entries) {
      final old = merged[e.key];
      if (old == null || e.value.isAfter(old)) merged[e.key] = e.value;
    }
    return encode(encodeSent(merged));
  }
  return incoming;
}

/// Übernommene Eingaben in die Konten dieses Geräts schreiben (Zuordnung
/// über Schulnummer und Benutzername, nur [transferKeys]). Rückgabe: Konten,
/// für die etwas übernommen wurde. Gemeinsam für Datei (transfer_page.dart)
/// und QR-Code (device_transfer_page.dart).
List<AccountSummary> applyTransferValues(
  LanisDatabase db,
  Map<String, Map<String, String>> data,
  List<AccountSummary> accounts,
) {
  final out = <AccountSummary>[];
  for (final a in accounts) {
    final incoming = data[transferAccountKey(a.schoolID, a.username)];
    if (incoming == null || incoming.isEmpty) continue;
    for (final e in incoming.entries) {
      if (!transferKeys.contains(e.key)) continue;
      db.setAccountSetting(
        a.localId,
        e.key,
        mergeValue(
          e.key,
          e.value,
          db.getAccountSetting(a.localId, e.key),
          decode: (raw) => LanisDatabase.decodeValue(raw)?.toString(),
          encode: LanisDatabase.encodeValue,
        ),
      );
    }
    out.add(a);
  }
  return out;
}

/// Rohwerte der übertragbaren Eingaben aller [accounts].
Map<String, Map<String, String?>> collectTransferValues(
  LanisDatabase db,
  List<AccountSummary> accounts,
) => {
  for (final a in accounts)
    transferAccountKey(a.schoolID, a.username): {
      for (final k in transferKeys) k: db.getAccountSetting(a.localId, k),
    },
};
