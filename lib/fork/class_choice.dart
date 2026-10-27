import 'dart:convert';

import 'package:liblanis/liblanis.dart';

/// Von Hand eingetragene Klasse eines Kindes (Wunsch 20.10.26: „bei der
/// Anmeldung und in den Einstellungen abfragen und hinterlegen“).
///
/// Ursache für den Ablauf: Die App erkennt die Klasse selbst (Benutzerdaten
/// bzw. Kursnamen, liveClassName). Eine Eingabe korrigiert das – bliebe sie
/// über den Sommer stehen, hielte der Filter (forClass) aus der 9C die 10C
/// für eine andere Klasse und blendete die eigenen Termine aus. Deshalb gilt
/// ein Eintrag nur bis zum Ende des Schuljahres (31. Juli, Hessen).
///
/// Grenze: Wiederholt ein Kind das Jahr oder wechselt die Klasse mitten im
/// Jahr, muss der Eintrag von Hand geändert werden.
const classSetting = 'fork/class';

class ClassChoice {
  const ClassChoice(this.name, this.until);

  final String name;

  /// Letzter Tag, an dem der Eintrag gilt.
  final DateTime until;

  bool validAt(DateTime now) => !now.isAfter(until);

  String encode() =>
      jsonEncode({'name': name, 'until': until.toIso8601String()});

  static ClassChoice? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final v = jsonDecode(raw);
      final name = (v['name'] as String?)?.trim() ?? '';
      final until = DateTime.tryParse(v['until'] as String? ?? '');
      if (name.isEmpty || until == null) return null;
      return ClassChoice(name, until);
    } catch (_) {
      return null;
    }
  }
}

/// Ende des Schuljahres, für das ein Eintrag gilt: 31. Juli, ab Juli das des
/// Folgejahres.
///
/// Ursache für Juli (Prüfung 27.10.26): In Hessen ist der Juli (fast) ganz
/// Sommerferien. Wer die Klasse dann einträgt, meint die neue – vorher lief
/// der Eintrag schon am 31.07. wieder ab.
/// Grenze: Wer in den ersten Julitagen vor Ferienbeginn noch die alte
/// Klasse einträgt, behält sie bis zum Juli darauf (dann von Hand ändern).
DateTime schoolYearEnd(DateTime now) =>
    DateTime(now.month >= 7 ? now.year + 1 : now.year, 7, 31, 23, 59, 59);

/// Gültiger Eintrag des Kontos, sonst null.
ClassChoice? storedClass(TypedSettings s, {DateTime? now}) {
  final c = ClassChoice.decode(s.getString(classSetting));
  return c != null && c.validAt(now ?? DateTime.now()) ? c : null;
}

/// Gab es einen Eintrag, der abgelaufen ist (neues Schuljahr)?
bool classExpired(TypedSettings s, {DateTime? now}) {
  final c = ClassChoice.decode(s.getString(classSetting));
  return c != null && !c.validAt(now ?? DateTime.now());
}

/// Eintrag speichern (bis Schuljahresende) oder mit null entfernen.
ClassChoice? storeClass(TypedSettings s, String? name, {DateTime? now}) {
  final n = name?.trim() ?? '';
  if (n.isEmpty) {
    s.setString(classSetting, null);
    return null;
  }
  final c = ClassChoice(n, schoolYearEnd(now ?? DateTime.now()));
  s.setString(classSetting, c.encode());
  return c;
}

/// Anzeige ohne führende Null: „09C“ → „9C“, „06 AH“ → „6 AH“.
String classLabel(String c) => c.trim().replaceFirst(RegExp(r'^0(?=\d)'), '');

/// Jahrgang und Rest: „9C“ → (9, „C“), „6 Ahorn“ → (6, „Ahorn“).
({int? grade, String rest}) splitClass(String c) {
  final m = RegExp(r'^\s*0?(\d{1,2})\s*(.*)$').firstMatch(c);
  if (m == null) return (grade: null, rest: c.trim());
  return (grade: int.parse(m[1]!), rest: m[2]!.trim());
}

/// Datum als „31.07.2027“.
String classUntilLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
