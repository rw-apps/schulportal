/// Datenform der Seite „Heute“ (Familienübersicht).
///
/// Bewusst unabhängig von liblanis: Der Entwurf füllt sie mit Beispieldaten
/// (fork/ui/preview/demo_family.dart), später je Kind aus der jeweiligen
/// Schul-Sitzung (Stundenplan, Vertretungsplan, Unterricht, Nachrichten,
/// Kalender). „Jetzt“, „Danach“, Restzeit und Tagesleiste werden aus
/// [ChildToday.lessons] und der Uhrzeit BERECHNET ([dayStatus]), nicht
/// geliefert — so stimmen sie auch, wenn die Daten eine Stunde alt sind.
library;

enum ChangeKind { substitution, roomChange, cancelled }

/// Ein Abschnitt des heutigen Plans. Doppelstunden desselben Fachs sind
/// EIN Abschnitt („3.–4.“). Ursache: Ein Tag mit 8 Stunden bliebe sonst als
/// 8 schmale Stücke in der Tagesleiste unlesbar (Frage 16.10.26).
class DayLesson {
  const DayLesson({
    required this.slot,
    required this.subject,
    required this.start,
    required this.end,
    this.room,
    this.teacher,
    this.change,
    this.changeDetail,
  });

  /// „3.–4.“, „5.“ oder „2. Block“ – so, wie die Schule zählt.
  final String slot;

  /// Ausgeschrieben („Mathematik“).
  final String subject;

  /// „09:50“
  final String start;
  final String end;
  final String? room;
  final String? teacher;
  final ChangeKind? change;

  /// „Hr. Sommer, R 112“ bzw. „R101 statt R106“.
  final String? changeDetail;

  bool get cancelled => change == ChangeKind.cancelled;
}

/// Eine Abweichung, für den Kasten „Wichtig heute und morgen“.
class ChangeItem {
  const ChangeItem({
    required this.day,
    required this.slot,
    required this.subject,
    required this.kind,
    this.detail,
  });

  final DateTime day;
  final String slot;
  final String subject;
  final ChangeKind kind;
  final String? detail;
}

class ChildToday {
  const ChildToday({
    required this.firstName,
    required this.school,
    required this.className,
    required this.colorIndex,
    this.lessons = const [],
    this.periodsLabel,
    this.changes = const [],
    this.openHomework = 0,
    this.unreadMessages = 0,
    this.canReportAbsence = false,
  });

  final String firstName;
  final String school;
  final String className;

  /// Platz in KitPalette.kids; bleibt je Kind fest.
  final int colorIndex;

  /// Heutiger Plan, zeitlich sortiert, Doppelstunden zusammengefasst.
  final List<DayLesson> lessons;

  /// „8 Stunden heute“ (Zählung der Schule, vor dem Zusammenfassen).
  final String? periodsLabel;
  final List<ChangeItem> changes;
  final int openHomework;
  final int unreadMessages;

  /// Schule bietet die Krankmeldung im Portal an (Modul in der App-Liste).
  final bool canReportAbsence;
}

enum WeekKind { exam, event, deadline, free }

class WeekItem {
  const WeekItem({
    required this.day,
    required this.title,
    required this.kind,
    this.childIndex,
    this.time,
  });

  final DateTime day;
  final String title;
  final WeekKind kind;

  /// Index in [FamilyToday.kids]; null = betrifft alle.
  final int? childIndex;
  final String? time;
}

class FamilyToday {
  const FamilyToday({
    required this.now,
    required this.kids,
    required this.week,
    this.isDemo = false,
  });

  final DateTime now;
  final List<ChildToday> kids;
  final List<WeekItem> week;
  final bool isDemo;
}

// ---- Berechnung „Jetzt“ ---------------------------------------------------

enum DayPhase { noLessons, before, running, gap, over }

/// Zustand des Schultags eines Kindes zu einem Zeitpunkt.
class DayStatus {
  const DayStatus({
    required this.phase,
    this.current,
    this.next,
    this.minutesLeft,
    this.progress = 0,
  });

  final DayPhase phase;

  /// Index in lessons (läuft gerade).
  final int? current;

  /// Index der nächsten stattfindenden Stunde.
  final int? next;

  /// Minuten bis Ende der laufenden Stunde (aufgerundet).
  final int? minutesLeft;

  /// Anteil der laufenden Stunde, der vorbei ist (0..1).
  final double progress;
}

/// Uhrzeit „HH:mm“ als Minuten seit Mitternacht.
class Hm {
  const Hm(this.minutes);
  final int minutes;
}

Hm minutesOf(String hm) {
  final parts = hm.split(':');
  return Hm(int.parse(parts[0]) * 60 + int.parse(parts[1]));
}

int _nowMin(DateTime now) => now.hour * 60 + now.minute;

/// Berechnet Phase, laufende und nächste Stunde. Ausfälle zählen nie als
/// „läuft“ oder „Danach“ – sie stehen nur in der Liste und im Kasten.
DayStatus dayStatus(List<DayLesson> lessons, DateTime now) {
  final held = [
    for (var i = 0; i < lessons.length; i++)
      if (!lessons[i].cancelled) i,
  ];
  if (held.isEmpty) return const DayStatus(phase: DayPhase.noLessons);
  final t = _nowMin(now);
  for (final i in held) {
    final s = minutesOf(lessons[i].start).minutes;
    final e = minutesOf(lessons[i].end).minutes;
    if (t >= s && t < e) {
      final next = held.where((j) => j > i).firstOrNull;
      return DayStatus(
        phase: DayPhase.running,
        current: i,
        next: next,
        minutesLeft: e - t,
        progress: (t - s) / (e - s),
      );
    }
  }
  final upcoming = held
      .where((i) => minutesOf(lessons[i].start).minutes > t)
      .firstOrNull;
  if (upcoming == null) return const DayStatus(phase: DayPhase.over);
  final first = held.first == upcoming;
  return DayStatus(
    phase: first ? DayPhase.before : DayPhase.gap,
    next: upcoming,
  );
}

/// Ist der Abschnitt vorbei?
bool lessonDone(DayLesson l, DateTime now) =>
    minutesOf(l.end).minutes <= _nowMin(now);

/// Dauer in Minuten (für die Breite in der Tagesleiste).
int lessonMinutes(DayLesson l) =>
    minutesOf(l.end).minutes - minutesOf(l.start).minutes;

/// Pause vor Abschnitt [i] in Minuten (0 beim ersten).
int gapBefore(List<DayLesson> l, int i) => i == 0
    ? 0
    : minutesOf(l[i].start).minutes - minutesOf(l[i - 1].end).minutes;
