import 'package:flutter/material.dart' show IconData, Icons;

/// Erkennungsregeln für Kursseite und Kursliste – nur Daten, keine Logik.
///
/// Ursache für eigene Datei (Vorgabe 17.10.26: „Code soll von Daten immer
/// getrennt sein“): Die Wörter stammen aus dem Portal bzw. von den Schulen
/// und ändern sich unabhängig vom Code. Neue Schulen ergänzen hier, ohne die
/// Auswertung (course_detail_model.dart) anzufassen.
abstract final class CourseRules {
  /// Spalten der Anwesenheit (meinunterricht.php, Tabelle „Anwesenheiten“),
  /// klein geschrieben, Teilwort genügt. Reihenfolge = Prüfreihenfolge:
  /// „unentschuldigt“ vor „entschuldigt“, weil es das Wort enthält.
  static const missing = ['unentschuldigt', 'fehl'];
  static const excused = ['entschuldigt'];
  static const present = ['anwesend'];

  /// Werte der Spalte „Anwesenheit“ im Verlauf, die keine Abwesenheit sind.
  static const presenceNeutral = ['anwesend', 'nicht erfasst', ''];

  /// Kursnamen-Bestandteile für Angebote ohne Noten (Ganztag, Training).
  /// Beleg: Kurscode „061KeineNoten04-IGS“ (Schule A, Export 16.10.26).
  /// Zusätzlich gilt als weiteres Angebot jeder Kurs, der im Stundenplan
  /// nicht vorkommt (course_detail_model.dart, isExtraOffer).
  static const extraOfferMarkers = ['keinenoten'];

  /// Fachsymbol nach Wortteil des Fachnamens (klein geschrieben); erster
  /// Treffer gewinnt, sonst [fallbackIcon].
  static const subjectIcons = <(String, IconData)>[
    ('mathe', Icons.calculate_outlined),
    ('deutsch', Icons.menu_book_outlined),
    ('englisch', Icons.translate),
    ('franz', Icons.translate),
    ('spanisch', Icons.translate),
    ('latein', Icons.translate),
    ('türk', Icons.translate),
    ('natur', Icons.science_outlined),
    ('bio', Icons.eco_outlined),
    ('chemie', Icons.science_outlined),
    ('physik', Icons.bolt_outlined),
    ('sport', Icons.sports_soccer_outlined),
    ('kunst', Icons.palette_outlined),
    ('musik', Icons.music_note_outlined),
    ('ästhetik', Icons.palette_outlined),
    ('text', Icons.content_cut),
    ('geschicht', Icons.account_balance_outlined),
    ('erdkunde', Icons.public),
    ('gesellschaft', Icons.public),
    ('politik', Icons.how_to_vote_outlined),
    ('religion', Icons.self_improvement_outlined),
    ('ethik', Icons.self_improvement_outlined),
    ('informatik', Icons.computer_outlined),
    ('arbeitslehre', Icons.build_outlined),
    ('darstellend', Icons.theater_comedy_outlined),
    ('ganztag', Icons.groups_outlined),
    ('training', Icons.groups_outlined),
    ('klasse', Icons.groups_outlined),
  ];
  static const fallbackIcon = Icons.class_outlined;

  /// Trennzeichen, vor dem das Thema eines Eintrags steht („Unit 2: Tickets“
  /// → Thema „Unit 2“). Grenze: Ohne Trenner ist der ganze Titel das Thema.
  static const topicSeparators = [':', ' – ', ' - '];
}
