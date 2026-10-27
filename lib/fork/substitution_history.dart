/// Vertretungen vergangener Tage, je Konto gespeichert.
///
/// Ursache (Rückmeldung 21.10.26): Der Vertretungsplan des Portals enthält
/// nur heute und die nächsten Schultage. Sobald ein Tag herausfiel, zeigte
/// der Kalender ihn ohne Vertretung und Ausfall – als wäre alles normal
/// gelaufen. Jetzt merkt sich die App jeden gelieferten Tag und zeigt ihn
/// weiter, wenn das Portal ihn nicht mehr liefert.
///
/// Grenzen:
/// - Gespeichert ist der LETZTE gesehene Stand eines Tages. Hat die Schule
///   danach noch etwas geändert, ohne dass die App geladen hat, fehlt das.
/// - Die App erfährt nicht, wenn ALLE Einträge eines Tages gelöscht werden
///   (liblanis entfernt leere Tage, SubstitutionPlan.removeEmptyDays). Für
///   künftige Tage gilt das Fehlen deshalb als „leer“ (Eintrag gelöscht);
///   heute und früher gilt der gespeicherte Stand.
/// - Nur [keepDays] Tage zurück (Kalender zeigt die laufende und die
///   vergangenen Wochen; älter wäre selten gebraucht und wüchse unbegrenzt).
library;

import 'dart:convert';

import 'package:liblanis/liblanis.dart';

/// Schlüssel im kontoeigenen Speicher (accountSpecificSettingsProvider).
const substitutionHistorySetting = 'fork/substitution-history';

class SubstitutionHistory {
  const SubstitutionHistory(this.days);

  static const empty = SubstitutionHistory({});

  /// Tage zurück, die aufbewahrt werden (drei Wochen).
  static const keepDays = 21;

  /// „2026-10-21“ → Tag.
  final Map<String, SubstitutionDay> days;

  static String keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Unlesbares (älteres Format, abgeschnitten) ergibt eine leere Ablage
  /// statt eines Absturzes.
  static SubstitutionHistory decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SubstitutionHistory({
        for (final e in map.entries)
          e.key: SubstitutionDay.fromJson(e.value as Map<String, dynamic>),
      });
    } catch (_) {
      return empty;
    }
  }

  String encode() =>
      jsonEncode({for (final e in days.entries) e.key: e.value.toJson()});

  /// Stand nach einem Abruf: Jeder gelieferte Tag ersetzt seinen Eintrag;
  /// künftige Tage, die nicht mehr geliefert werden, fallen weg (siehe
  /// Grenzen); Tage älter als [keepDays] ebenso.
  SubstitutionHistory record(List<SubstitutionDay> live, DateTime now) {
    final today = _date(now);
    final oldest = DateTime(today.year, today.month, today.day - keepDays);
    final delivered = {for (final d in live) keyOf(d.dateTime): d};
    final out = <String, SubstitutionDay>{};
    for (final e in days.entries) {
      final d = DateTime.tryParse(e.key);
      if (d == null || d.isBefore(oldest) || d.isAfter(today)) continue;
      out[e.key] = e.value;
    }
    out.addAll(delivered);
    return SubstitutionHistory(out);
  }

  /// Tage für Heute und die Sammelmeldung: wie [withPast], aber erst ab
  /// heute. Ursache (Prüfung 27.10.26): Heute und der Hintergrund nahmen nur
  /// die gelieferten Tage – nimmt das Portal den heutigen Tag nachmittags
  /// heraus, verschwand die Änderung dort, während der Kalender sie
  /// weiter zeigte. Grenze: Vergangene Tage bleiben draußen, sonst meldete
  /// die Sammelmeldung alte Änderungen erneut.
  List<SubstitutionDay> fromToday(List<SubstitutionDay> live, DateTime now) {
    final today = _date(now);
    return [
      for (final d in withPast(live, now))
        if (!_date(d.dateTime).isBefore(today)) d,
    ];
  }

  /// Tage für den Kalender: die gelieferten, dazu gespeicherte Tage bis
  /// heute, die das Portal nicht mehr liefert.
  List<SubstitutionDay> withPast(List<SubstitutionDay> live, DateTime now) {
    final today = _date(now);
    final delivered = {for (final d in live) keyOf(d.dateTime)};
    return [
      ...live,
      for (final e in days.entries)
        if (!delivered.contains(e.key) &&
            !(DateTime.tryParse(e.key)?.isAfter(today) ?? true))
          e.value,
    ];
  }
}
