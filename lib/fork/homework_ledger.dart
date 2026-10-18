import 'dart:convert';

import 'package:liblanis/liblanis.dart';

/// Gespeicherte Hausaufgaben-Stände je Konto (TypedSettings, roher
/// Schlüssel wie fork-courses/scan).
const homeworkLedgerSetting = 'fork-homework/ledger';

/// Eine Hausaufgabe, die die Familie abgehakt oder wieder geöffnet hat.
class HomeworkRecord {
  const HomeworkRecord({
    required this.course,
    required this.entry,
    required this.subject,
    required this.text,
    this.given,
    this.done,
    required this.changed,
  });

  /// Kurs-ID (Lesson.courseID, bei Eltern mit „&p=Kind“) und Eintrag
  /// (CurrentEntry.entryID) – zusammen eindeutig.
  final String course;
  final String entry;

  /// Fach („Englisch“) und Aufgabentext zum Zeitpunkt des Abhakens –
  /// damit das Archiv sie auch dann zeigt, wenn der Kurs längst neuere
  /// Einträge hat (die Übersicht des Portals nennt nur den neuesten).
  final String subject;
  final String text;

  /// Tag der Stunde, in der sie aufgegeben wurde.
  final DateTime? given;

  /// Wann abgehakt; null = (wieder) offen.
  final DateTime? done;

  /// Letzte Änderung (zum Aufräumen und Sortieren).
  final DateTime changed;

  bool get isDone => done != null;
  String get key => homeworkKey(course, entry);

  HomeworkRecord withDone(DateTime? when, DateTime now) => HomeworkRecord(
    course: course,
    entry: entry,
    subject: subject,
    text: text,
    given: given,
    done: when,
    changed: now,
  );

  Map<String, dynamic> toJson() => {
    'c': course,
    'e': entry,
    's': subject,
    't': text,
    if (given != null) 'g': given!.toIso8601String(),
    if (done != null) 'd': done!.toIso8601String(),
    'x': changed.toIso8601String(),
  };

  static HomeworkRecord? fromJson(Object? j) {
    if (j is! Map) return null;
    final changed = DateTime.tryParse('${j['x']}');
    final course = '${j['c'] ?? ''}';
    final entry = '${j['e'] ?? ''}';
    if (changed == null || course.isEmpty || entry.isEmpty) return null;
    return HomeworkRecord(
      course: course,
      entry: entry,
      subject: '${j['s'] ?? ''}',
      text: '${j['t'] ?? ''}',
      given: j['g'] == null ? null : DateTime.tryParse('${j['g']}'),
      done: j['d'] == null ? null : DateTime.tryParse('${j['d']}'),
      changed: changed,
    );
  }
}

String homeworkKey(String course, String entry) => '$course|$entry';

/// Alle Stände eines Kontos.
///
/// Ein Eintrag hier geht dem Portal vor. Ursache: Elternkonten können im
/// Portal nichts abhaken (nur Schülerkonten, sus_homeworkDone), und auch
/// beim Schülerkonto soll „Wieder offen“ sofort gelten, nicht erst nach dem
/// nächsten Laden. Grenze: Hakt das Kind dieselbe Aufgabe später auf der
/// Webseite ab, gilt hier weiter der Stand aus der App.
///
/// Aufbewahrt werden höchstens [maxRecords] Einträge und erledigte nur
/// [keepDays] Tage – ein Schuljahr Archiv reicht, und der Speicher wächst
/// nicht unbegrenzt.
class HomeworkLedger {
  const HomeworkLedger(this.byKey);

  static const empty = HomeworkLedger({});
  static const maxRecords = 400;
  static const keepDays = 400;

  final Map<String, HomeworkRecord> byKey;

  HomeworkRecord? operator [](String key) => byKey[key];

  List<HomeworkRecord> get done => [
    for (final r in byKey.values)
      if (r.isDone) r,
  ]..sort((a, b) => b.done!.compareTo(a.done!));

  /// Wieder geöffnete Aufgaben (über „Wieder offen“).
  List<HomeworkRecord> get reopened => [
    for (final r in byKey.values)
      if (!r.isDone) r,
  ];

  HomeworkLedger put(HomeworkRecord r, DateTime now) {
    final next = {...byKey, r.key: r};
    return HomeworkLedger(_pruned(next, now));
  }

  static Map<String, HomeworkRecord> _pruned(
    Map<String, HomeworkRecord> m,
    DateTime now,
  ) {
    final limit = now.subtract(const Duration(days: keepDays));
    final kept = [
      for (final r in m.values)
        if (r.changed.isAfter(limit)) r,
    ]..sort((a, b) => b.changed.compareTo(a.changed));
    return {for (final r in kept.take(maxRecords)) r.key: r};
  }

  String encode() => jsonEncode([for (final r in byKey.values) r.toJson()]);

  static HomeworkLedger decode(String? s) {
    if (s == null || s.isEmpty) return empty;
    try {
      final v = jsonDecode(s);
      if (v is! List) return empty;
      return HomeworkLedger({
        for (final j in v)
          if (HomeworkRecord.fromJson(j) case final r?) r.key: r,
      });
    } catch (_) {
      return empty;
    }
  }
}

/// Eine Hausaufgabe für die Anzeige: offen oder erledigt, aus dem neuesten
/// Eintrag eines Kurses oder aus dem Protokoll.
class HomeworkItem {
  const HomeworkItem({
    required this.course,
    required this.entry,
    required this.subject,
    required this.text,
    this.given,
    this.done,
  });

  final String course;
  final String entry;
  final String subject;
  final String text;
  final DateTime? given;
  final DateTime? done;

  String get key => homeworkKey(course, entry);

  HomeworkRecord record({DateTime? done, required DateTime now}) =>
      HomeworkRecord(
        course: course,
        entry: entry,
        subject: subject,
        text: text,
        given: given,
        done: done,
        changed: now,
      );
}

/// Offene und erledigte Hausaufgaben eines Kontos.
///
/// Offen: neueste Einträge mit Hausaufgabe, die weder das Portal noch das
/// Protokoll als erledigt führt, dazu wieder geöffnete ältere aus dem
/// Protokoll. Erledigt: alles, was das Protokoll als erledigt führt, und
/// neueste Einträge, die das Portal als erledigt meldet (Schülerkonto, auf
/// der Webseite abgehakt). [subjectOf] liefert den Fachnamen zur Kurs-ID.
({List<HomeworkItem> open, List<HomeworkItem> done}) homeworkLists(
  List<Lesson> lessons,
  HomeworkLedger ledger, {
  required String Function(Lesson l) subjectOf,
}) {
  final open = <HomeworkItem>[];
  final done = <HomeworkItem>[];
  final seen = <String>{};
  for (final l in lessons) {
    final e = l.currentEntry;
    final h = e?.homework;
    if (e == null || h == null) continue;
    final key = homeworkKey(l.courseID, e.entryID);
    seen.add(key);
    final r = ledger[key];
    final item = HomeworkItem(
      course: l.courseID,
      entry: e.entryID,
      subject: subjectOf(l),
      text: h.description.trim(),
      given: e.topicDate,
      done: r?.done,
    );
    final isDone = r != null ? r.isDone : h.homeWorkDone;
    (isDone ? done : open).add(item);
  }
  for (final r in ledger.byKey.values) {
    if (seen.contains(r.key)) continue;
    final item = HomeworkItem(
      course: r.course,
      entry: r.entry,
      subject: r.subject,
      text: r.text,
      given: r.given,
      done: r.done,
    );
    (r.isDone ? done : open).add(item);
  }
  int byGiven(HomeworkItem a, HomeworkItem b) =>
      (b.given ?? DateTime(2000)).compareTo(a.given ?? DateTime(2000));
  open.sort(byGiven);
  done.sort((a, b) {
    final x = b.done ?? b.given ?? DateTime(2000);
    final y = a.done ?? a.given ?? DateTime(2000);
    return x.compareTo(y);
  });
  return (open: open, done: done);
}
