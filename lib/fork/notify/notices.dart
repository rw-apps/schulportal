import 'package:liblanis/liblanis.dart';

import '../l10n/l10n.dart';
import '../ui/plan/plan_model.dart';
import '../ui/today/today_from_lanis.dart';
import '../ui/today/today_model.dart';

/// Eine Benachrichtigung mit den Einträgen, die sie meldet ([keys]).
class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.lines,
    required this.keys,
  });

  /// Platz der Benachrichtigung (BackgroundTaskToolkit.sendMessage): 1 =
  /// heute, 2 = Vorabend. Gleicher Platz ersetzt die ältere Meldung.
  final int id;
  final String title;
  final List<String> lines;

  /// Schlüssel der gemeldeten Einträge; nach dem Senden gespeichert, damit
  /// nichts zweimal kommt.
  final List<String> keys;
}

/// Ruhezeit 21–6 Uhr (Konzept 17.10.26): keine Meldungen.
bool inQuietHours(DateTime now) => now.hour >= 21 || now.hour < 6;

/// Ab 19 Uhr kommt die Sammelmeldung für den nächsten Schultag.
const eveningHour = 19;

/// Große Termine, die am Vorabend gemeldet werden: Arbeiten, schulfreie
/// Tage, Fristen und Termine mit Eltern-Bezug. Ursache der Wortliste: Die
/// Schule A führt auch reine Organisationstermine im Kalender („Präsentation
/// Prüfung“ für Abschlussklassen); eine Meldung je Kalendereintrag wäre
/// Rauschen. Grenze: Ein großer Termin mit anderem Wort kommt nicht als
/// Meldung, steht aber im Kalender.
bool isBigEvent(WeekItem w) =>
    w.kind == WeekKind.exam ||
    w.kind == WeekKind.free ||
    w.kind == WeekKind.deadline ||
    (w.kind == WeekKind.event &&
        RegExp(
          r'eltern|sprechtag|ausflug|wandertag|klassenfahrt|fest\b|feier|'
          r'zeugnis|projekttag|sportfest|unterrichtsfrei|schulfrei',
          caseSensitive: false,
        ).hasMatch(w.title));

String _changeLine(ForkL10n t, ChangeItem c) {
  final what = switch (c.kind) {
    ChangeKind.cancelled => t.lessonCancelled,
    ChangeKind.roomChange => '${t.changeRoom} ${c.detail ?? ''}'.trim(),
    ChangeKind.substitution =>
      '${t.changeSubstitution} ${c.detail ?? ''}'.trim(),
  };
  return '${c.slot} ${c.subject} – $what';
}

String _changeKey(ChangeItem c) =>
    'c|${c.day.year}-${c.day.month}-${c.day.day}|${c.slot}|${c.kind.name}|${c.detail ?? ''}';

String _eventKey(WeekItem w) =>
    'e|${w.day.year}-${w.day.month}-${w.day.day}|${w.title}';

/// „Heute bei Lena“; ohne Namen beim Schülerkonto „Heute in der Schule“,
/// beim Elternkonto (Kinder nicht geladen) „Heute bei deinem Kind“.
String _title(
  ForkL10n t, {
  required bool today,
  required String name,
  required bool parent,
}) {
  if (name.trim().isNotEmpty) {
    return today ? t.noticeTodayFor(name) : t.noticeTomorrowFor(name);
  }
  if (parent) return today ? t.noticeTodayChild : t.noticeTomorrowChild;
  return today ? t.noticeTodaySchool : t.noticeTomorrowSchool;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Was jetzt zu melden ist (höchstens zwei Meldungen).
///
/// - Heute: neue Ausfälle, Vertretungen und Raumwechsel, deren Stunde noch
///   nicht vorbei ist – sofort.
/// - Vorabend (ab 19 Uhr): Änderungen und große Termine des nächsten
///   Tages, wenn er ein Schultag ist (Freitagabend nichts, Sonntagabend für
///   Montag).
///
/// [sent]: schon gemeldete Schlüssel. Ohne neuen Eintrag keine Meldung;
/// kommt einer hinzu, ersetzt eine vollständige Meldung die vorige.
/// Grenze: Die Schlüssel enthalten den Angabentext (z. B. „R101 statt
/// R106“); nach einem Sprachwechsel kann eine offene Änderung daher einmal
/// erneut kommen.
List<Notice> buildNotices({
  required KidPlan plan,
  required GroupChoice choice,
  required List<SubstitutionDay> substitutions,
  required List<CalendarEvent> events,
  required DateTime now,
  required ForkL10n t,
  bool parent = false,
  String className = '',
  Set<String> sent = const {},
  String Function(String code)? subjectName,
}) {
  if (inQuietHours(now)) return const [];
  final r = applySubstitutions(
    plan: plan,
    choice: choice,
    days: substitutions,
    now: now,
    t: t,
    subjectName: subjectName,
  );
  final out = <Notice>[];

  // Heute: nur Stunden, die noch kommen oder laufen.
  final endOf = {for (final l in r.today) l.slot: minutesOf(l.end).minutes};
  final nowMin = now.hour * 60 + now.minute;
  // Meldet alle noch offenen Änderungen des Tages, sobald EINE neu ist –
  // die Meldung ersetzt die vorige auf demselben Platz (id), darf also
  // nichts weglassen.
  final today = [
    for (final c in r.changes)
      if (_sameDay(c.day, now) && (endOf[c.slot] ?? 24 * 60) > nowMin) c,
  ];
  if (today.any((c) => !sent.contains(_changeKey(c)))) {
    out.add(
      Notice(
        id: 1,
        title: _title(t, today: true, name: plan.firstName, parent: parent),
        lines: [for (final c in today) _changeLine(t, c)],
        keys: [for (final c in today) _changeKey(c)],
      ),
    );
  }

  // Vorabend für den nächsten Schultag.
  final next = DateTime(now.year, now.month, now.day + 1);
  if (now.hour >= eveningHour && next.weekday <= DateTime.friday) {
    final changes = [
      for (final c in r.changes)
        if (_sameDay(c.day, next)) c,
    ];
    final big = [
      for (final w in weekItemsFromCalendar(
        events,
        now,
        className: className,
        days: 2,
      ))
        if (_sameDay(w.day, next) && isBigEvent(w)) w,
    ];
    final fresh =
        changes.any((c) => !sent.contains(_changeKey(c))) ||
        big.any((w) => !sent.contains(_eventKey(w)));
    if (fresh) {
      out.add(
        Notice(
          id: 2,
          title: _title(t, today: false, name: plan.firstName, parent: parent),
          lines: [
            for (final c in changes) _changeLine(t, c),
            for (final w in big) [w.title, ?w.time].join(' · '),
          ],
          keys: [
            for (final c in changes) _changeKey(c),
            for (final w in big) _eventKey(w),
          ],
        ),
      );
    }
  }
  return out;
}

/// Gemeldete Schlüssel begrenzt halten (die neuesten [max]).
List<String> rememberKeys(List<String> old, List<String> add, {int max = 300}) {
  final all = [...old.where((k) => !add.contains(k)), ...add];
  return all.length <= max ? all : all.sublist(all.length - max);
}
