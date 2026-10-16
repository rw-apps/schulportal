/// Datenform der Seite „Heute“ (Familienübersicht).
///
/// Bewusst unabhängig von liblanis: Der Entwurf füllt sie mit Beispieldaten
/// (fork/ui/preview/demo_family.dart), später je Kind aus der jeweiligen
/// Schul-Sitzung (Stundenplan, Vertretungsplan, Unterricht, Nachrichten,
/// Kalender). So bleibt die Oberfläche gleich, egal woher die Daten kommen.
library;

/// Eine Unterrichtsstunde oder ein Block.
class LessonRef {
  const LessonRef({
    required this.subject,
    required this.start,
    required this.end,
    this.room,
    this.teacher,
  });

  /// Ausgeschrieben („Mathematik“), nicht das Kürzel aus dem Plan.
  final String subject;
  final String start;
  final String end;
  final String? room;
  final String? teacher;
}

enum ChangeKind { substitution, roomChange, cancelled }

/// Eine Abweichung vom Plan, heute oder in den nächsten Tagen.
class ChangeItem {
  const ChangeItem({
    required this.day,
    required this.slot,
    required this.subject,
    required this.kind,
    this.detail,
  });

  final DateTime day;

  /// „5./6. Std.“ oder „3. Block“, wie die Schule zählt.
  final String slot;
  final String subject;
  final ChangeKind kind;

  /// „Vertretung Hr. Sommer, Raum 112“.
  final String? detail;
}

/// Alles, was die Karte eines Kindes zeigt.
class ChildToday {
  const ChildToday({
    required this.firstName,
    required this.school,
    required this.className,
    required this.colorIndex,
    this.now,
    this.next,
    this.dayEnd,
    this.changes = const [],
    this.openHomework = 0,
    this.unreadMessages = 0,
    this.canReportAbsence = false,
  });

  final String firstName;
  final String school;
  final String className;

  /// Platz in Kit.childSeeds; bleibt je Kind fest.
  final int colorIndex;

  /// Läuft gerade; null = Pause oder unterrichtsfrei.
  final LessonRef? now;
  final LessonRef? next;

  /// „Schulschluss 13:45“ bzw. „Morgen ab 08:00“, wenn [now]/[next] fehlen.
  final String? dayEnd;
  final List<ChangeItem> changes;
  final int openHomework;
  final int unreadMessages;

  /// Schule bietet die Krankmeldung im Portal an (Modul in der App-Liste).
  final bool canReportAbsence;
}

enum WeekKind { exam, event, deadline, free }

/// Ein Eintrag der gemeinsamen Wochenübersicht.
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
