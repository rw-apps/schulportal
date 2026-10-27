import 'package:liblanis/liblanis.dart';

import '../l10n/l10n.dart';
import '../ui/today/today_from_lanis.dart';
import '../ui/today/today_model.dart';
import '../data/portal_rules.dart';

/// Eine Benachrichtigung mit den Einträgen, die sie meldet ([keys]).
class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.lines,
    required this.keys,
  });

  /// Platz der Benachrichtigung (BackgroundTaskToolkit.sendMessage): 2 =
  /// Vorabend (1 war die frühere Tagesmeldung, jetzt Sammelmeldung
  /// summary.dart). Gleicher Platz ersetzt die ältere Meldung.
  final int id;
  final String title;
  final List<String> lines;

  /// Schlüssel der gemeldeten Einträge; nach dem Senden gespeichert, damit
  /// nichts zweimal kommt.
  final List<String> keys;
}

// Ruhezeit: keine eigene feste Regel mehr. Ursache (Prüfbefund 17.10.26):
// Die feste 21–6-Uhr-Sperre überstimmte das Zeitfenster aus den
// Einstellungen (Benachrichtigungen → Zeitfenster, Standard 6–21 Uhr), das
// background_service.dart (isTaskWithinConstraints) schon vor jeder Aufgabe
// prüft – ein Ende 22 Uhr blieb wirkungslos.

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
    (w.kind == WeekKind.event && PortalRules.bigEvent.hasMatch(w.title));

String _eventKey(WeekItem w) =>
    'e|${w.day.year}-${w.day.month}-${w.day.day}|${w.title}';

/// „Morgen bei Lena“; ohne Namen beim Schülerkonto „Morgen in der Schule“,
/// beim Elternkonto (Kinder nicht geladen) „Morgen bei deinem Kind“.
String _title(ForkL10n t, {required String name, required bool parent}) {
  if (name.trim().isNotEmpty) return t.noticeTomorrowFor(name);
  return parent ? t.noticeTomorrowChild : t.noticeTomorrowSchool;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Was jetzt zu melden ist: große Termine des nächsten Tages am Vorabend
/// (ab 19 Uhr), wenn er ein Schultag ist (Freitagabend nichts,
/// Sonntagabend für Montag) – höchstens eine Meldung (id 2).
///
/// Ausfälle, Vertretungen und Raumwechsel meldet die Sammelmeldung
/// (summary.dart, changeSummaryItems). Ursache (Prüfung 27.10.26): Seit
/// der Sammelmeldung (Wunsch 27.10.26) bekam diese Funktion nur noch eine
/// leere Vertretungsliste; die Tagesmeldung (id 1) und die Änderungen am
/// Vorabend waren toter Code. Grenze: [name] wie die übrige Meldung des
/// Kontos (notify_task.dart).
///
/// [sent]: schon gemeldete Schlüssel. Ohne neuen Eintrag keine Meldung;
/// kommt einer hinzu, ersetzt eine vollständige Meldung die vorige.
List<Notice> buildNotices({
  required List<CalendarEvent> events,
  required DateTime now,
  required ForkL10n t,
  String name = '',
  bool parent = false,
  String className = '',
  Set<String> sent = const {},
}) {
  final next = DateTime(now.year, now.month, now.day + 1);
  if (now.hour < eveningHour || next.weekday > DateTime.friday) {
    return const [];
  }
  final big = [
    for (final w in weekItemsFromCalendar(
      events,
      now,
      className: className,
      days: 2,
    ))
      if (_sameDay(w.day, next) && isBigEvent(w)) w,
  ];
  if (!big.any((w) => !sent.contains(_eventKey(w)))) return const [];
  return [
    Notice(
      id: 2,
      title: _title(t, name: name, parent: parent),
      lines: [
        for (final w in big) [w.title, ?w.time].join(' · '),
      ],
      keys: [for (final w in big) _eventKey(w)],
    ),
  ];
}

/// Gemeldete Schlüssel begrenzt halten (die neuesten [max]).
List<String> rememberKeys(List<String> old, List<String> add, {int max = 300}) {
  final all = [...old.where((k) => !add.contains(k)), ...add];
  return all.length <= max ? all : all.sublist(all.length - max);
}
