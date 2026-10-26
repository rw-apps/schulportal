import 'dart:convert';

import 'school_links.dart' show normalizeMensaUrl;

/// Mensa-Bestellseite je Kind und Bestellwoche – reine Funktionen, ohne
/// Portal testbar (test/fork/mensa_test.dart).
///
/// Ursache (Wunsch 17.10.26): Eine Adresse je Konto reichte nicht, weil jedes
/// Kind beim Caterer ein eigenes Konto haben kann. Der Name des Caterers steht
/// bewusst nirgends im Code (öffentliches Repository) – die Familie trägt die
/// Adresse selbst ein.

/// Schlüssel eines Kindes: Schüler-ID des Elternkontos, '' im Schülerkonto
/// (bzw. solange die Kinder noch nicht geladen sind).
typedef MensaKidKey = String;

/// Gespeicherte Adressen je Kind (JSON {kidKey: url}).
///
/// [legacy] ist die bisherige eine Adresse je Konto (bis 9341); sie gilt für
/// jedes Kind ohne eigene Adresse weiter, damit nach dem Update nichts fehlt.
class MensaAddresses {
  const MensaAddresses(this.byKid, {this.legacy});

  factory MensaAddresses.decode(String? json, {String? legacy}) {
    final out = <String, String>{};
    try {
      final v = json == null || json.isEmpty ? null : jsonDecode(json);
      if (v is Map) {
        for (final e in v.entries) {
          final url = normalizeMensaUrl('${e.value}');
          if (url != null) out['${e.key}'] = url;
        }
      }
    } catch (_) {
      // Unlesbar – wie leer behandeln, die Familie trägt neu ein.
    }
    return MensaAddresses(out, legacy: normalizeMensaUrl(legacy));
  }

  final Map<MensaKidKey, String> byKid;
  final String? legacy;

  /// Adresse für das Kind: eigene, sonst die ohne Kind gespeicherte, sonst
  /// die alte Kontoadresse.
  String? of(MensaKidKey kid) => byKid[kid] ?? byKid[''] ?? legacy;

  /// Hat das Kind eine eigene Adresse (nicht nur geerbt)?
  bool ownFor(MensaKidKey kid) => byKid.containsKey(kid);

  /// Neue Adresse; null/leer löscht den Eintrag des Kindes. Ungültige
  /// Adressen ändern nichts (die Oberfläche meldet sie vorher).
  MensaAddresses withUrl(MensaKidKey kid, String? raw) {
    final next = {...byKid};
    final url = normalizeMensaUrl(raw);
    if (raw == null || raw.trim().isEmpty) {
      // Geerbte Adresse löschen = die gemeinsame ('' bzw. alte Kontoadresse)
      // löschen; sonst käme sie sofort als „geerbt“ zurück. Grenze: Andere
      // Kinder, die sie ebenfalls erbten, verlieren sie mit.
      final inherited = !next.containsKey(kid);
      next.remove(kid);
      if (inherited) next.remove('');
      return MensaAddresses(
        next,
        legacy: inherited || next.isEmpty ? null : legacy,
      );
    }
    if (url == null) return this;
    next[kid] = url;
    return MensaAddresses(next, legacy: legacy);
  }

  String encode() => jsonEncode(byKid);
}

/// ISO-Kalenderwoche (Montag als Wochenbeginn, Woche 1 enthält den ersten
/// Donnerstag) samt ISO-Jahr – am Jahreswechsel weicht es vom Kalenderjahr ab
/// (29.12.2025 gehört zu 2026/1).
({int year, int week}) isoWeek(DateTime d) {
  final day = DateTime.utc(d.year, d.month, d.day);
  final thursday = day.add(Duration(days: 4 - day.weekday));
  final first = DateTime.utc(thursday.year, 1, 1);
  final week = thursday.difference(first).inDays ~/ 7 + 1;
  return (year: thursday.year, week: week);
}

/// Woche, für die man bestellt: die laufende; ab Freitag 12 Uhr und am
/// Wochenende die nächste.
///
/// Ursache: Zum Wochenende ist die laufende Woche gegessen, geplant wird die
/// kommende. Grenze: Bestellfristen des Caterers kennt die App nicht – die
/// Seite zeigt sie selbst, und man kann dort jederzeit die Woche wechseln.
({int year, int week}) mensaOrderWeek(DateTime now) {
  final next =
      now.weekday >= DateTime.saturday ||
      (now.weekday == DateTime.friday && now.hour >= 12);
  return isoWeek(next ? DateTime(now.year, now.month, now.day + 7) : now);
}

/// Ersetzt eine fest eingetragene Woche „/JJJJ/WW/“ in der Adresse durch die
/// Bestellwoche – auch im Rücksprung nach der Anmeldung („?next=/…/2025/35/“,
/// roh oder als %2F kodiert).
///
/// Ursache: Die kopierte Adresse enthielt die Woche des Kopierens; ohne
/// Ersetzen öffnete die App ewig dieselbe alte Woche. Grenze: Nur das Muster
/// Jahr/Woche mit Schrägstrichen; andere Schreibweisen bleiben unverändert.
String mensaWeekUrl(String url, DateTime now) =>
    mensaUrlForWeek(url, mensaOrderWeek(now));

/// Adresse für die Kalenderwoche [w]: „/JJJJ/WW/“ bzw. „week=JJJJ_WW“
/// ersetzt. Grenze: Ohne eines der Muster bleibt die Adresse unverändert –
/// die Seite zeigt dann ihre eigene Standardwoche.
String mensaUrlForWeek(String url, ({int year, int week}) w) {
  final param = RegExp(r'([?&]week=)(20\d{2})_(\d{1,2})');
  if (param.hasMatch(url)) {
    return url.replaceAllMapped(param, (m) => '${m[1]}${w.year}_${w.week}');
  }
  final re = RegExp(
    r'(/|%2F)(20\d{2})(/|%2F)(\d{1,2})(?=/|%2F|$|\?|&|#)',
    caseSensitive: false,
  );
  return url.replaceAllMapped(re, (m) {
    final week = int.parse(m[4]!);
    if (week < 1 || week > 53) return m[0]!;
    return '${m[1]}${w.year}${m[3]}${w.week}';
  });
}

/// Darf die eingebettete Seite zu [target] wechseln? Nur https und nur zur
/// eingetragenen Seite (gleicher Host oder dessen Unterdomain) bzw. deren
/// Hauptdomain.
///
/// Ursache: Die Seite läuft mit gespeicherter Anmeldung in der App; fremde
/// Links (Zahlungsanbieter, Hilfe, Werbung) öffnen im Browser, damit dort
/// niemand eine echt wirkende Anmeldemaske in der App zeigen kann. Grenze:
/// Leitet der Caterer zur Anmeldung auf eine fremde Domain um, öffnet sie
/// im Browser – dann dort anmelden.
bool mensaAllows(Uri home, Uri target) {
  if (target.scheme != 'https' || target.userInfo.isNotEmpty) return false;
  final base = _registrable(home.host);
  final h = target.host.toLowerCase();
  return h == base || h.endsWith('.$base');
}

/// Hauptdomain aus den letzten zwei Teilen („www.bestellung.example.de“ →
/// „example.de“). Grenze: zweiteilige Endungen (co.uk) gelten als Domain –
/// für deutsche Caterer ohne Belang, dann nur strenger.
String _registrable(String host) {
  final p = host.toLowerCase().split('.');
  return p.length <= 2 ? p.join('.') : p.sublist(p.length - 2).join('.');
}
