/// Erkennungswörter für Vertretungsplan, Schulkalender und Meldungen – nur
/// Daten, keine Logik.
///
/// Ursache für eigene Datei (Vorgabe 17.10.26: „Code soll von Daten immer
/// getrennt sein“): Die Wörter stammen aus den Einträgen der Schulen und
/// ändern sich unabhängig vom Code. Neue Schreibweisen hier ergänzen, ohne
/// die Auswertung (today_from_lanis.dart, notices.dart) anzufassen. Alle
/// Muster sind deutsch, weil die Schulen deutsch schreiben – unabhängig von
/// der App-Sprache.
abstract final class PortalRules {
  /// Vertretungsplan, Spalte „Art“ (klein geschrieben): Stunde fällt aus.
  static final cancelKind = RegExp(r'entfall|ausfall|fällt aus|entfällt|frei');

  /// Vertretungsplan, Spalte „Hinweis“: Stunde fällt aus.
  static final cancelHint = RegExp(r'entfällt|fällt aus');

  /// Kalender: Essensnotiz (nur ganzes Wort, „Interessen“ nicht).
  static final meal = RegExp(
    r'\b(mittag)?essen\b|\bmensa\b',
    caseSensitive: false,
  );

  /// Kalender-Kategorien, die für Eltern nur Rauschen sind (Lehrerdienst,
  /// A/B-Wochen).
  static const skipCategories = ['pausenaufsicht', 'schulwoche'];

  /// Kategorie bzw. Titel: Arbeit/Leistungskontrolle.
  static const examCategories = ['arbeit'];
  static final examTitle = RegExp(
    r'lernkontrolle|klassenarbeit|klausur|\btest\b',
  );

  /// Kategorie bzw. Titel: Ferien, unterrichtsfreie Tage.
  static const freeCategories = ['ferien', 'frei'];
  static final freeTitle = RegExp(r'ferien|unterrichtsfrei');

  /// Titel: Abgabetermin.
  static const deadlineWord = 'abgabe';

  /// Titel: Termin, der als Meldung kommt (Elternabend, Ausflug …).
  static final bigEvent = RegExp(
    r'eltern|sprechtag|ausflug|wandertag|klassenfahrt|fest\b|feier|'
    r'zeugnis|projekttag|sportfest|unterrichtsfrei|schulfrei',
    caseSensitive: false,
  );

  /// Eintrag der App-Liste der Schule (Session.travelMenu), der zur
  /// Essensbestellung führt – Name oder Link (school_links.dart,
  /// mensaSuggestion). Ganze Wörter, damit „Interessen“ nicht trifft.
  static final mensaLink = RegExp(
    r'\b(mittag)?essen\b|\bmensa\b|\bspeise|\bkantine\b|\bcafeteria\b|'
    r'catering|essensbestell|menübestell|schulverpflegung',
    caseSensitive: false,
  );

  /// Jahrgangsangaben im Titel: Bereich „5-7 Klassen“ / „Jg. 8–10“ und
  /// Aufzählung „nur für 5, 6 und 7 Jg.“.
  static final gradeRangeBefore = RegExp(
    r'(\d{1,2})\s*[-–]\s*(\d{1,2})\s*\.?\s*(?:klass|jg|jahrg)',
    caseSensitive: false,
  );
  static final gradeRangeAfter = RegExp(
    r'(?:klassen?|jg\.?|jahrgang|jahrgänge)\s*(\d{1,2})\s*[-–]\s*(\d{1,2})',
    caseSensitive: false,
  );
  static final gradeList = RegExp(
    r'((?:\d{1,2}\s*(?:,|und|u\.|/)\s*)+\d{1,2})\.?\s*(?:klass|jg|jahrg)',
    caseSensitive: false,
  );
}

/// Fachnamen im Stundenplan – nur Daten.
abstract final class SubjectNames {
  /// Eindeutige Fachkürzel → Fachname. Doppeldeutige (TXT, WPU …) bewusst
  /// nicht.
  static const known = <String, String>{
    'D': 'Deutsch',
    'DE': 'Deutsch',
    'E': 'Englisch',
    'EN': 'Englisch',
    'M': 'Mathematik',
    'MA': 'Mathematik',
    'NAWI': 'Naturwissenschaften',
    'NW': 'Naturwissenschaften',
    'GL': 'Gesellschaftslehre',
    'SP': 'Sport',
    'SPO': 'Sport',
    'KU': 'Kunst',
    'MU': 'Musik',
    'BIO': 'Biologie',
    'BI': 'Biologie',
    'CH': 'Chemie',
    'PH': 'Physik',
    'EK': 'Erdkunde',
    'G': 'Geschichte',
    'GE': 'Geschichte',
    'POWI': 'Politik und Wirtschaft',
    'F': 'Französisch',
    'FR': 'Französisch',
    'SPA': 'Spanisch',
    'L': 'Latein',
    'LA': 'Latein',
    'INF': 'Informatik',
    'IF': 'Informatik',
    'ETH': 'Ethik',
    'ET': 'Ethik',
    'REV': 'Ev. Religion',
    'ER': 'Ev. Religion',
    'RKA': 'Kath. Religion',
    'KR': 'Kath. Religion',
    'AL': 'Arbeitslehre',
    'DS': 'Darstellendes Spiel',
    'KL': 'Klassenstunde',
    'ÄSTH': 'Ästhetik',
  };

  /// Kurzform im Wochenraster (plan_model.dart, gridName).
  static const gridShort = <String, String>{
    'Mathematik': 'Mathe',
    'Gesellschaftslehre': 'GL',
    'Naturwissenschaften': 'NaWi',
    'Geschichte': 'Gesch.',
    'Biologie': 'Bio',
    'Erdkunde': 'Erdk.',
    'Ev. Religion': 'ev. Reli',
    'Kath. Religion': 'kath. Reli',
    'Informatik': 'Info',
    'Französisch': 'Franz.',
    'Spanisch': 'Span.',
    'Darstellendes Spiel': 'DS',
    'Politik und Wirtschaft': 'PoWi',
  };
}
