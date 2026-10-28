/// Daten des Startbildschirm-Widgets (Android, Entwurf 4, Abnahme 28.10.26).
///
/// Das Widget selbst ist native Android-Oberfläche (RemoteViews,
/// android/app/src/main/kotlin/com/example/app/widget/SchoolWidget.kt): Ein
/// Startbildschirm kann keine Flutter-Ansicht zeigen. Darum rechnet Dart
/// hier alles, was Wissen über Plan, Vertretungsplan und Sprache braucht, zu
/// fertigen Texten (ForkL10n) – Kotlin legt sie nur noch in die Kacheln.
///
/// Was Kotlin selbst entscheidet: „heute“/„morgen“/Wochentag aus dem Datum
/// eines Eintrags und dem aktuellen Tag, vergangene Tage und heute schon
/// beendete Stunden fallen weg. Ursache: Ohne neuen Abruf (nachts kein
/// Hintergrundlauf, notify_window.dart) bliebe sonst nach Mitternacht
/// „morgen“ an einem Eintrag von heute stehen. Grenze: Kommt länger keine
/// neue Datei, zeigt das Widget „Alles nach Plan“, sobald alle bekannten
/// Einträge vorbei sind – die Zeile „Stand“ im Kopf nennt dann Wochentag und
/// Uhrzeit des letzten Abrufs.
library;

import 'package:intl/intl.dart';
import 'package:liblanis/liblanis.dart' show SubstitutionDay;

import '../exams.dart';
import '../l10n/l10n.dart';
import '../ui/plan/plan_model.dart';
import '../ui/today/kid_hints.dart' show cancelEffect, nextSchoolDay;
import '../ui/today/today_from_lanis.dart'
    show applySubstitutions, dayLessonsFor, planWithSubstitutions;
import '../ui/today/today_model.dart';

/// Schlüssel der Widget-Daten in den SharedPreferences „HomeWidgetPreferences“
/// (Paket home_widget); Kotlin liest denselben Namen (SchoolWidget.kt,
/// PAYLOAD_KEY).
const homeWidgetDataKey = 'fork_widget_payload';

/// Konto, dessen Kind das Widget zeigt (localId als Text, geteilte
/// Einstellungen). Fehlt der Eintrag, gilt das aktive Konto der App.
const widgetAccountSetting = 'fork-widget/account';

/// Höchstzahl der Einträge in der Datei. Ursache: Das mittlere Widget zeigt
/// zwei Kacheln und „+N“; mehr als ein Dutzend Abweichungen an zwei Tagen
/// kommen praktisch nicht vor. Grenze: „+N“ zählt höchstens bis hierher.
const widgetMaxItems = 12;

/// Vorschau für Arbeiten in der Fußzeile (Abnahme 28.10.26: „nächste Arbeit
/// innerhalb von 7 Tagen“).
const widgetExamDays = 7;

/// Art einer Kachel – bestimmt Farbe und Lagebild in Kotlin: [cancel] rot
/// mit durchgestrichenem Termin, [change] gelb mit anderer Lehrkraft
/// (Vertretung, „bitte prüfen“), [room] gelb mit Fußgänger.
enum WidgetKind { cancel, change, room }

/// Eine Abweichung als Kachel.
class WidgetItem {
  const WidgetItem({
    required this.date,
    required this.kind,
    required this.title,
    required this.what,
    required this.slot,
    this.end,
    this.detail,
  });

  /// Tag der Stunde (ohne Uhrzeit).
  final DateTime date;
  final WidgetKind kind;

  /// Fach („Englisch“).
  final String title;

  /// „fällt aus“, „Vertretung“, „Raumwechsel“.
  final String what;

  /// „4. Std.“, „1.–2. Std.“, „2. Block“.
  final String slot;

  /// Ende der Stunde „HH:mm“ – Kotlin nimmt heutige Einträge danach heraus;
  /// null ohne Uhrzeiten der Schule (dann bleiben sie bis Mitternacht).
  final String? end;

  /// Folge in Klartext: „Start erst 09:55“, „Schluss 11:30“, „Raum R117“,
  /// „R310 statt R021“; null, wenn nichts Sinnvolles zu sagen ist.
  final String? detail;

  Map<String, Object?> toJson() => {
    'date': isoDate(date),
    'kind': kind.name,
    'title': title,
    'what': what,
    'slot': slot,
    if (end != null) 'end': end,
    if (detail != null) 'detail': detail,
  };
}

/// „2026-10-27“ – das Format, das Kotlin mit LocalDate.parse liest.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// „4.“ → „4. Std.“; „2. Block“ bleibt. Ursache: Die Schule zählt teils in
/// Blöcken, dann steht das Wort schon in der Beschriftung (blockLabel).
String widgetSlotLabel(ForkL10n t, String slot) =>
    RegExp(r'^[\d.\s–-]+$').hasMatch(slot) ? t.widgetSlot(slot.trim()) : slot;

/// Abweichungen von heute und dem nächsten Schultag ([nextSchoolDay]) für das
/// Widget, in der Reihenfolge von [applySubstitutions] (Tag, dann Stunde).
///
/// Dieselbe Zuordnung wie „Heute“, Kalender und Sammelmeldung
/// (applySubstitutions, Gruppenwahl, Klassenfilter, freie Tage). Die Folge
/// eines Ausfalls („Start erst“/„Schluss“) kommt aus dem überlagerten Plan
/// des jeweiligen Tages ([planWithSubstitutions] + [dayLessonsFor]) nach
/// derselben Regel wie die Kinderkarte ([cancelEffect]).
///
/// Grenze: Heute schon vorbei Stunden bleiben in der Liste (mit [end]);
/// herausgenommen werden sie erst in Kotlin, damit es auch ohne neuen Abruf
/// stimmt.
List<WidgetItem> widgetItems({
  required KidPlan plan,
  required GroupChoice choice,
  required List<SubstitutionDay> days,
  required DateTime now,
  required ForkL10n t,
  String Function(String code)? subjectName,
  Map<DateTime, String> free = const {},
  String className = '',
}) {
  final today = _day(now);
  final next = nextSchoolDay(now);
  final r = applySubstitutions(
    plan: plan,
    choice: choice,
    days: days,
    now: now,
    t: t,
    subjectName: subjectName,
    free: free,
    className: className,
  );
  final lessonsByDay = <DateTime, List<DayLesson>>{};
  List<DayLesson> lessonsOf(DateTime d) => lessonsByDay.putIfAbsent(d, () {
    final wd = d.weekday - 1;
    if (wd > 4 || free.containsKey(d)) return const [];
    final rows = [
      for (final x in days)
        if (_day(x.dateTime) == d) x,
    ];
    final over = planWithSubstitutions(
      plan: plan,
      days: rows,
      week: [
        for (var i = 0; i < 5; i++) DateTime(d.year, d.month, d.day - wd + i),
      ],
      t: t,
      className: className,
    );
    return dayLessonsFor(over, wd, choice, t: t);
  });

  final out = <WidgetItem>[];
  for (final c in r.changes) {
    final d = _day(c.day);
    if (d != today && d != next) continue;
    final lessons = lessonsOf(d);
    final i = lessons.indexWhere(
      (l) => l.slot == c.slot && l.subject == c.subject && l.change == c.kind,
    );
    final lesson = i < 0 ? null : lessons[i];
    // Ende: aus dem Abschnitt, sonst (Zusatzstunde ohne Abschnitt) aus dem
    // Zeitraster der Schule, wenn die Beschriftung genau eine Stunde ist.
    final slotEnd = plan.timed
        ? plan.slots.where((s) => s.label == c.slot).firstOrNull?.end
        : null;
    final end = lesson != null
        ? (hasTime(lesson) ? lesson.end : null)
        : slotEnd;
    final room = c.room;
    final (kind, what, detail) = switch (c.kind) {
      ChangeKind.cancelled => (
        WidgetKind.cancel,
        t.lessonCancelled,
        switch (cancelEffect(lessons, i)) {
          (start: final s?, end: _) => t.widgetStartLate(s),
          (start: _, end: final e?) => t.widgetEndEarly(e),
          _ => null,
        },
      ),
      ChangeKind.substitution => (
        WidgetKind.change,
        t.changeSubstitution,
        room == null ? null : t.widgetRoom(room),
      ),
      // „R310 statt R021“ steht schon in detail (classifySubstitution,
      // roomInsteadOf); ohne alten Raum ist detail nur der neue Raum.
      ChangeKind.roomChange => (
        WidgetKind.room,
        t.changeRoom,
        c.detail == null || c.detail == room
            ? (room == null ? null : t.widgetRoom(room))
            : c.detail,
      ),
      // Unsicher: gelb wie in der App, nie als sicherer Ausfall; der Text
      // der App sagt, was zu prüfen ist („Ausfall, Kurs nicht angegeben“).
      ChangeKind.unclear => (WidgetKind.change, t.changeUnclear, c.detail),
    };
    out.add(
      WidgetItem(
        date: d,
        kind: kind,
        title: c.subject,
        what: what,
        slot: widgetSlotLabel(t, c.slot),
        end: end == null || end.isEmpty ? null : end,
        detail: detail,
      ),
    );
    if (out.length >= widgetMaxItems) break;
  }
  return out;
}

/// Erste Arbeit ab heute innerhalb von [widgetExamDays] Tagen; [exams] wie
/// von upcomingExamsOf (nach Tag sortiert).
UpcomingExam? nextExamWithin(List<UpcomingExam> exams, DateTime now) {
  final today = _day(now);
  final last = DateTime(now.year, now.month, now.day + widgetExamDays);
  for (final e in exams) {
    final d = _day(e.day);
    if (!d.isBefore(today) && !d.isAfter(last)) return e;
  }
  return null;
}

/// Die ganze Datei für Kotlin (JSON-fähige Map).
///
/// [account]/[kid]: Konto (localId) und Farbplatz des Kindes (KitPalette.kids,
/// in Kotlin widget_kidN_*). [stand]: Ladezeitpunkt des Vertretungsplans.
/// [homework]: offene Hausaufgaben (liveOpenHomework); [exam]: nächste
/// Arbeit ([nextExamWithin]). Kurztext der Arbeit: die Art („Test“), ohne
/// Art das Fach – Abnahme 28.10.26 („Do Test“), mehr passt nicht in die
/// Fußzeile.
///
/// [dates]: Kopfzeile („Di, 27. Okt.“) für heute und die nächsten 7 Tage,
/// damit Kotlin nach Mitternacht ohne neue Datei das richtige Datum zeigt;
/// [labels.weekdays]: Kurznamen Mo–So für Einträge jenseits von morgen
/// (Freitag → „Mo“) und für die Arbeit.
Map<String, Object?> homeWidgetPayload({
  required int account,
  required int kid,
  required List<WidgetItem> items,
  required DateTime now,
  required ForkL10n t,
  DateTime? stand,
  int homework = 0,
  UpcomingExam? exam,
}) {
  final monday = DateTime(2024, 1, 1); // ein Montag
  final day = DateFormat('ccc', t.localeName);
  final head = DateFormat(t.widgetDate, t.localeName);
  return {
    'v': 1,
    'account': account,
    'kid': kid,
    'generatedAt': now.toIso8601String(),
    if (stand != null) 'stand': stand.toIso8601String(),
    'items': [for (final i in items) i.toJson()],
    if (homework > 0) 'homework': t.homeworkShort(homework),
    if (exam != null)
      'exam': {
        'date': isoDate(exam.day),
        'label': exam.kind.isEmpty ? exam.subject : exam.kind,
      },
    'dates': {
      for (var i = 0; i <= 7; i++)
        isoDate(DateTime(now.year, now.month, now.day + i)): head.format(
          DateTime(now.year, now.month, now.day + i),
        ),
    },
    'labels': {
      'today': t.widgetToday,
      'tomorrow': t.widgetTomorrow,
      'weekdays': [
        for (var i = 0; i < 7; i++)
          day.format(DateTime(monday.year, monday.month, monday.day + i)),
      ],
      'calmTitle': t.widgetCalmTitle,
      'calmText': t.widgetCalmText,
    },
  };
}
