import 'courses_scan.dart' show ScanExam;
import 'data/portal_rules.dart';
import 'ui/courses/grades_model.dart' show currentIsFirstHalf;
import 'ui/today/today_model.dart' show WeekItem, WeekKind;

/// Anstehende Arbeiten eines Kindes – EINE Quelle für „Demnächst“ (Heute),
/// Unterricht „Alle“ und Unterricht eines Kindes („Nächste Arbeiten“).
///
/// Ursache (Rückfrage 20.10.26, „Warum zeigt Alle andere Informationen als
/// ein einzelnes Kind?“): Bisher las das einzelne Kind nur die Kursmappen
/// (upcomingExams, bis Halbjahresende), „Alle“ und Heute dagegen zuerst den
/// Schulkalender (withCourseExams, 60 bzw. 14 Tage), die Kursmappe nur als
/// Ergänzung. Dieselbe Arbeit stand so einmal als „Englisch – Arbeit, 5./6.
/// Std. (60 Min.)“ und einmal als „Englisch 09C Arbeit · 11:40“; was nur im
/// Kalender stand, fehlte beim Kind.
///
/// Regel jetzt:
/// - Kursmappe zuerst: Sie nennt Fach, Art, Stunden und Dauer.
/// - Dazu Arbeiten aus dem Kalender, die in keiner Kursmappe stehen –
///   Titel bereinigt ([examFromCalendar]): ohne Klassenangabe, als
///   „Fach: Art“, Uhrzeit als Angabe.
/// - Gleicher Zeitraum für Unterricht (Alle und Kind): bis Halbjahresende
///   ([halfYearEnd]); Heute zeigt davon die nächsten 14 Tage.
///
/// Grenze: Die Kursmappen-Arbeiten in „Alle“ und Heute stammen aus der
/// gespeicherten Auswertung (courses_scan.dart), beim einzelnen Kind aus
/// den gerade geladenen Seiten. Bis zur nächsten Auswertung (Öffnen von
/// „Arbeiten & Noten“ oder täglicher Abruf) kann „Alle“ daher einen Tag
/// hinterher sein.
class UpcomingExam {
  const UpcomingExam({
    required this.day,
    required this.subject,
    required this.kind,
    this.detail,
    this.fromCalendar = false,
  });

  final DateTime day;

  /// „Mathematik“.
  final String subject;

  /// „Arbeit“, „Lernkontrolle“; leer, wenn der Kalendertitel keine Art
  /// nennt (Arbeit nur an der Kategorie erkannt).
  final String kind;

  /// Stunden und Dauer („3., 4. Std. (90 Min.)“) oder Uhrzeit („11:40“).
  final String? detail;
  final bool fromCalendar;

  /// „Mathematik: Arbeit“.
  String get title => kind.isEmpty ? subject : '$subject: $kind';

  factory UpcomingExam.fromScan(ScanExam e) => UpcomingExam(
    day: e.day,
    subject: e.subject,
    kind: e.kind,
    detail: e.hours,
  );
}

/// Letzter Tag des laufenden Schulhalbjahrs: 31. Januar bzw. 31. Juli –
/// abgeleitet aus currentIsFirstHalf (grades_model.dart), damit „Arbeiten
/// & Noten“ und diese Liste dasselbe Halbjahr meinen. Grenze wie dort: Der
/// Wechsel liegt in Hessen um den 1. Februar; ein paar Tage Unterschied
/// verschieben nur, ab wann die Arbeiten des neuen Halbjahrs erscheinen.
DateTime halfYearEnd(DateTime now) => currentIsFirstHalf(now)
    ? DateTime(now.month >= 8 ? now.year + 1 : now.year, 1, 31)
    : DateTime(now.year, 7, 31);

/// Tage von heute bis [until] einschließlich – für weekItemsFromCalendar.
int daysUntil(DateTime now, DateTime until) {
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(until.year, until.month, until.day).difference(today).inDays +
      1;
}

/// Kalender-Arbeit als [UpcomingExam]: „Naturwissenschaften 06 xy
/// Lernkontrolle“ → Fach „Naturwissenschaften“, Art „Lernkontrolle“.
///
/// Klassenangaben fallen weg (PortalRules.classToken, dieselbe Erkennung
/// wie forClass in today_from_lanis.dart): Der Kalender ist schon nach der
/// Klasse gefiltert, die Angabe ist dort nur Rauschen. Grenze: Nennt der
/// Titel kein Art-Wort (PortalRules.examKind), bleibt der bereinigte Titel
/// das Fach und die Art leer.
UpcomingExam examFromCalendar(WeekItem w) {
  var rest = w.title.replaceAllMapped(PortalRules.classToken, (m) {
    final g = int.parse(m[1] ?? m[3]!);
    final l = (m[2] ?? m[4]!).toLowerCase();
    final isClass = g >= 5 && g <= 13 && !PortalRules.notClassWords.contains(l);
    return isClass ? ' ' : m[0]!;
  });
  var kind = '';
  final k = PortalRules.examKind.firstMatch(rest);
  if (k != null) {
    final word = k[0]!;
    kind = word[0].toUpperCase() + word.substring(1).toLowerCase();
    rest = rest.replaceRange(k.start, k.end, ' ');
  }
  var subject = rest
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s:,;–-]+|[\s:,;–-]+$'), '')
      .trim();
  if (subject.isEmpty) {
    // Nur Art und Klasse im Titel („09C Arbeit“): Art als Titel.
    subject = kind.isEmpty ? w.title.trim() : kind;
    kind = '';
  }
  return UpcomingExam(
    day: w.day,
    subject: subject,
    kind: kind,
    detail: w.time,
    fromCalendar: true,
  );
}

/// Nennen Kursmappe und Kalender am selben Tag dasselbe Fach?
bool sameExam(ScanExam scan, UpcomingExam cal) =>
    scan.day.year == cal.day.year &&
    scan.day.month == cal.day.month &&
    scan.day.day == cal.day.day &&
    sameSubject(scan.subject, cal);

/// Gehört die Kalender-Arbeit [cal] zum Fach [subject]?
///
/// Gleich, wenn der Kalendertitel das Fach enthält („Englisch 09C Arbeit“ ↔
/// „Englisch“) oder das Kalenderfach eine bekannte Kurzform ist („Mathe“,
/// „NaWi“, „M“ – SubjectNames) bzw. der Anfang des Fachs („Mathe“ ↔
/// „Mathematik“, mindestens 4 Buchstaben). Ein vorangestellter Kindname
/// („Lena: Mathematik“, Elternkonto mit zwei Kindern an einer Schule,
/// lessons_parent.dart) zählt nicht mit. Grenze: Ganz andere Namen („Bio“ ↔
/// „Naturwissenschaften“) gelten als verschieden; dann stehen beide da.
bool sameSubject(String subject, UpcomingExam cal) {
  final colon = subject.lastIndexOf(': ');
  final s = (colon < 0 ? subject : subject.substring(colon + 2))
      .toLowerCase()
      .trim();
  if (s.length < 3) return false;
  final c = cal.subject.toLowerCase().trim();
  if (c.contains(s)) return true;
  if (c.length >= 4 && s.startsWith(c)) return true;
  final full = _longName(cal.subject);
  return full != null && full.toLowerCase() == s;
}

String? _longName(String short) {
  final s = short.trim();
  final byCode = SubjectNames.known[s.toUpperCase()];
  if (byCode != null) return byCode;
  for (final e in SubjectNames.gridShort.entries) {
    if (e.value.toLowerCase() == s.toLowerCase()) return e.key;
  }
  return null;
}

/// Die Arbeiten eines Kindes von heute bis [until], nach Tag (bei gleichem
/// Tag nach Fach). [calendar]: Einträge aus weekItemsFromCalendar – nur die
/// Arbeiten (WeekKind.exam) zählen.
List<UpcomingExam> upcomingExamsOf({
  required Iterable<ScanExam> scan,
  required Iterable<WeekItem> calendar,
  required DateTime now,
  required DateTime until,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final last = DateTime(until.year, until.month, until.day);
  bool inRange(DateTime d) => !d.isBefore(today) && !d.isAfter(last);
  final fromScan = [
    for (final e in scan)
      if (inRange(e.day)) e,
  ];
  final out = [for (final e in fromScan) UpcomingExam.fromScan(e)];
  for (final w in calendar) {
    if (w.kind != WeekKind.exam || !inRange(w.day)) continue;
    final c = examFromCalendar(w);
    if (fromScan.any((s) => sameExam(s, c))) continue;
    out.add(c);
  }
  out.sort((a, b) {
    final d = a.day.compareTo(b.day);
    return d != 0 ? d : a.subject.compareTo(b.subject);
  });
  return out;
}

/// Nächste Arbeit EINES Fachs nach derselben Regel („Als Nächstes“ auf der
/// Kursseite): Kursmappe [folder] zuerst, sonst die früheste Kalender-Arbeit
/// dieses Fachs bis Halbjahresende.
///
/// Ursache (Prüfung 20.10.26): Bisher gewann dort der Kalender, auch wenn
/// die Kursmappe eine frühere Arbeit nannte; die Kursmappe kam nur ohne
/// Kalendereintrag zum Zug.
UpcomingExam? nextExamOfSubject({
  required String subject,
  required Iterable<ScanExam> folder,
  required Iterable<WeekItem> calendar,
  required DateTime now,
}) {
  final mine = [
    for (final w in calendar)
      if (w.kind == WeekKind.exam && sameSubject(subject, examFromCalendar(w)))
        w,
  ];
  final all = upcomingExamsOf(
    scan: folder,
    calendar: mine,
    now: now,
    until: halfYearEnd(now),
  );
  if (all.isEmpty) return null;
  final e = all.first;
  if (!e.fromCalendar) return e;
  // Kalender-Kurzform („Mathe“) durch das Fach der Kursseite ersetzen –
  // die Zugehörigkeit steht ja fest (sameSubject).
  final colon = subject.lastIndexOf(': ');
  return UpcomingExam(
    day: e.day,
    subject: colon < 0 ? subject : subject.substring(colon + 2),
    kind: e.kind,
    detail: e.detail,
    fromCalendar: true,
  );
}
