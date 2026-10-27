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
  ///
  /// „frei“ nur am Wortende („frei“, „Klasse frei“, „unterrichtsfrei“) oder
  /// als „Freistunde“/„Freisetzung“/„freigesetzt“. Ursache (Prüfung
  /// 27.10.26): Als bloße Teilzeichenkette traf „frei“ auch „Freiarbeit“ –
  /// ein sicherer Ausfall für eine Stunde, die stattfindet. Buchstaben mit
  /// Umlaut zählen mit, weil \b in Dart nur ASCII kennt.
  static final cancelKind = RegExp(
    r'entfall|ausfall|fällt aus|entfällt|frei(?![a-zäöüß])|'
    r'freistunde|freisetzung|freigesetzt',
  );

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

  /// Art-Wort einer Arbeit im Kalendertitel, für die Anzeige als „Fach:
  /// Art“ (exams.dart, examFromCalendar). Längere Wörter zuerst, damit
  /// „Klassenarbeit“ nicht als „Arbeit“ zählt.
  static final examKind = RegExp(
    r'\b(klassenarbeit|lernzielkontrolle|lernkontrolle|vergleichsarbeit|'
    r'klausur|test|arbeit)\b',
    caseSensitive: false,
  );

  /// Kategorie bzw. Titel: Ferien, unterrichtsfreie Tage.
  static const freeCategories = ['ferien', 'frei'];
  static final freeTitle = RegExp(r'ferien|unterrichtsfrei');

  /// Titel, die NUR einen freien Tag benennen – für das Leeren des
  /// Stundenplans (today_from_lanis.dart, freeDaysFrom), strenger als
  /// [freeTitle]. Ursache: „Ferienbetreuung“ oder „Ferienspiele“ träfen
  /// [freeTitle], sind aber kein schulfreier Tag. Real gesehen (Exporte
  /// 16./17.10.26): „Ferien“, „Schöne Ferien“.
  static final freeDayTitle = RegExp(
    r'^\s*(schöne\s+)?([a-zäöü]*ferien|beweglicher ferientag|brückentag|'
    r'unterrichtsfrei(er tag)?|schulfrei(er tag)?)\s*[!.]*\s*(\(.*\))?\s*$',
    caseSensitive: false,
  );

  /// Nur ein Teil des Tages frei („Unterrichtsfrei ab 11:30 Uhr“, „nach
  /// der 4. Stunde“): Der Stundenplan bleibt.
  static final partialDay = RegExp(
    r'\bab\s+\d|\bnach der\b|\bstunde\b|\buhr\b',
    caseSensitive: false,
  );

  /// Allgemeine Feier- und Gedenktage, die viele Schulkalender eintragen
  /// („Reformationstag“, „Allerheiligen“, „1. Advent“). Unter „Demnächst“
  /// ausgeblendet, im Kalender bleiben sie.
  ///
  /// Ursache (Rückmeldung 18.10.26): Sie sagen Eltern nichts Neues und
  /// verdrängten echte Termine aus den Kacheln. Das Portal kennzeichnet sie
  /// nicht – an Schule B stehen sie in derselben Kategorie wie
  /// „Unterrichtsende nach der 3. Stunde“ (Export 17.10.26) –, daher die
  /// Namensliste. Nur der GANZE Titel zählt: „Weihnachtskonzert“ oder
  /// „Unterrichtsfrei (Fronleichnam)“ bleiben. Ferien und schulfreie Tage
  /// sind kein Feiertag in diesem Sinn und bleiben ebenfalls.
  static final plainHoliday = RegExp(
    r'^(neujahr|heilige drei könige|valentinstag|weiberfastnacht|'
    r'rosenmontag|fastnacht|faschingsdienstag|aschermittwoch|'
    r'gründonnerstag|karfreitag|karsamstag|ostern|ostersonntag|ostermontag|'
    r'tag der arbeit|maifeiertag|muttertag|vatertag|christi himmelfahrt|'
    r'pfingsten|pfingstsonntag|pfingstmontag|fronleichnam|'
    r'tag der deutschen einheit|erntedank(fest)?|reformationstag|halloween|'
    r'allerheiligen|allerseelen|st\.? ?martin|martinstag|volkstrauertag|'
    r'buß- und bettag|totensonntag|ewigkeitssonntag|\d\.\s*advent|'
    r'nikolaus|nikolaustag|heiligabend|heiliger abend|weihnachten|'
    r'\d\.\s*weihnachtstag|\d\.\s*weihnachtsfeiertag|silvester)$',
  );

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

  /// Einzelne Klasse im Titel: „9D“, „09A“ (ohne Leerzeichen) oder „06 xy“
  /// (zweistellig mit Leerzeichen, Schreibweise Schule A). Ursache der
  /// Strenge: Mit Leerzeichen und einstelliger Zahl wären „6 und“ (aus „5, 6
  /// und 7 Jg.“) oder „9 in der Aula“ Klassen. Ziffern direkt nach „.“, „:“,
  /// „,“ oder „/“ zählen nicht (Uhrzeit „19:00 Uhr“, „Str.60“).
  static final classToken = RegExp(
    r'(?<![\d.:,/])\b(?:0?(\d{1,2})([a-zA-Z]{1,3})|(\d{2}) ([a-zA-Z]{1,3}))'
    r'\b(?![.:\d])',
  );

  /// Kein Klassenbuchstabe: „10 Uhr“, „6 Std“, „5 km“ …
  static const notClassWords = {
    'uhr',
    'std',
    'st',
    'h',
    'min',
    'km',
    'm',
    'x',
    'mal',
    'ag',
    'ags',
    'jg',
    'kl',
    'tag',
    'nr',
    'pkt',
    'kg',
    'g',
    'l',
    'ct',
    'eur',
  };

  /// Davor stehend kein Klassen-, sondern ein Raum-/Ortsbezug
  /// („Raum 9a“, „Haus 2b“, „Bus 7A“).
  static final placeBefore = RegExp(
    r'(?:raum|r\.|zi\.|zimmer|haus|gebäude|geb\.|bus|linie|gleis|tor|'
    r'halle|platz|nr\.?)\s*$',
    caseSensitive: false,
  );

  /// Oberstufe („Q1“–„Q4“, „E1“/„E2“, „E-Phase“, „Einführungsphase“,
  /// „Oberstufe“) – in Hessen frühestens ab Jahrgang 10 (G8: E-Phase in 10).
  static final upperSchool = RegExp(
    r'\b(?:q[1-4]|e[12]|e-?phase|einführungsphase|oberstufe)\b',
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
    'GEO': 'Geographie',
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
    'ETHI': 'Ethik',
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
    'Geographie': 'Geo',
    'Ev. Religion': 'ev. Reli',
    'Kath. Religion': 'kath. Reli',
    'Informatik': 'Info',
    'Französisch': 'Franz.',
    'Spanisch': 'Span.',
    'Darstellendes Spiel': 'DS',
    'Politik und Wirtschaft': 'PoWi',
  };
}
