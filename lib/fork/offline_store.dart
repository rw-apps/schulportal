/// Ablage auf dem Gerät für Quellen, die liblanis nicht offline speichert:
/// Kalender (kalender.php) und „Mein Unterricht“ (meinunterricht.php, mit
/// den offenen Hausaufgaben).
///
/// Ursache (Rückmeldung 21.10.26, Vorschlag b): Bei einem Ausfall des
/// Portals blieben Termine und Hausaufgaben leer; liblanis legt nur
/// Stundenplan und Vertretungsplan ab (AppletMeta.allowOffline). Gespeichert
/// wird in derselben Tabelle wie bei liblanis (applet_offline_data), unter
/// „fork/…“, damit sie nie mit deren Einträgen verwechselt wird.
///
/// Grenzen:
/// - Nur, was die Anzeige braucht: Dateien und Abgaben einer Stunde fehlen
///   (öffnen geht ohnehin nur mit Verbindung).
/// - Nachrichten werden bewusst nicht abgelegt – sie sind persönlicher als
///   Plan, Termine und Hausaufgaben (Entscheidung 21.10.26).
library;

import 'dart:convert';

import 'package:liblanis/liblanis.dart';

import 'lessons_parent.dart';

/// Kodierung einer Quelle für die Ablage; [decode] darf am Parser Nötiges
/// wiederherstellen (Kinder des Elternkontos, LessonsParentAwareParser).
class OfflineCodec<T> {
  const OfflineCodec({required this.encode, required this.decode});

  /// [parser] null in Tests ohne Parser.
  final String Function(T value, AppletParser<T>? parser) encode;
  final T Function(String json, AppletParser<T>? parser) decode;
}

/// Schlüssel in applet_offline_data für [phpUrl].
String forkOfflineId(String phpUrl) => 'fork/$phpUrl';

String? _iso(DateTime? d) => d?.toIso8601String();
DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v');

// ---- Kalender -------------------------------------------------------------

Map<String, dynamic> _event(CalendarEvent e) => {
  'start': _iso(e.startTime),
  'end': _iso(e.endTime),
  'secret': e.secret,
  'id': e.id,
  'school': e.schoolID,
  'modified': _iso(e.lastModified),
  'new': e.isNew,
  'public': e.public,
  'place': e.place,
  'private': e.private,
  'responsible': e.responsibleID,
  'allDay': e.allDay,
  if (e.category case final c?)
    'category': {'id': c.id, 'color': c.colorArgb, 'name': c.name},
  'description': e.description,
  'title': e.title,
};

CalendarEvent _eventOf(Map<String, dynamic> j) {
  final c = j['category'];
  return CalendarEvent(
    startTime: _date(j['start'])!,
    endTime: _date(j['end'])!,
    secret: j['secret'] == true,
    id: '${j['id'] ?? ''}',
    schoolID: j['school'] as String?,
    lastModified: _date(j['modified']),
    isNew: j['new'] == true,
    public: j['public'] == true,
    place: j['place'] as String?,
    private: j['private'] == true,
    responsibleID: j['responsible'] as String?,
    allDay: j['allDay'] == true,
    category: c is Map<String, dynamic>
        ? CalendarEventCategory(
            id: c['id'] as int,
            colorArgb: c['color'] as int,
            name: '${c['name'] ?? ''}',
          )
        : null,
    description: '${j['description'] ?? ''}',
    title: '${j['title'] ?? ''}',
  );
}

final calendarCodec = OfflineCodec<List<CalendarEvent>>(
  encode: (v, _) => jsonEncode([for (final e in v) _event(e)]),
  decode: (s, _) => [
    for (final j in (jsonDecode(s) as List).cast<Map<String, dynamic>>())
      _eventOf(j),
  ],
);

// ---- Mein Unterricht ------------------------------------------------------

Map<String, dynamic> _lesson(Lesson l) => {
  'id': l.courseID,
  'name': l.name,
  'url': l.courseURL.toString(),
  'teachers': [
    for (final t in l.teachers) {'name': t.teacher, 'code': t.teacherKuerzel},
  ],
  'attendances': l.attendances,
  if (l.currentEntry case final e?)
    'entry': {
      'id': e.entryID,
      'topic': e.topicTitle,
      'description': e.description,
      'date': _iso(e.topicDate),
      'hours': e.schoolHours,
      'presence': e.presence,
      if (e.homework case final h?)
        'homework': {'text': h.description, 'done': h.homeWorkDone},
    },
};

Lesson _lessonOf(Map<String, dynamic> j) {
  final e = j['entry'];
  final h = e is Map<String, dynamic> ? e['homework'] : null;
  return Lesson(
    courseID: '${j['id']}',
    name: '${j['name'] ?? ''}',
    courseURL: Uri.parse('${j['url'] ?? ''}'),
    teachers: [
      for (final t in (j['teachers'] as List? ?? const []).cast<Map>())
        LessonTeacher(
          teacher: t['name'] as String?,
          teacherKuerzel: t['code'] as String?,
        ),
    ],
    attendances: (j['attendances'] as Map?)?.map(
      (k, v) => MapEntry('$k', '$v'),
    ),
    currentEntry: e is Map<String, dynamic>
        ? CurrentEntry(
            entryID: '${e['id']}',
            topicTitle: e['topic'] as String?,
            description: e['description'] as String?,
            topicDate: _date(e['date']),
            schoolHours: e['hours'] as String?,
            presence: e['presence'] as String?,
            // Gespeicherter Platzhalter („-“) zählt nicht (Homework
            // .isPlaceholder) – Ablage von vor dem 28.10.26.
            homework: h is Map && !Homework.isPlaceholder('${h['text'] ?? ''}')
                ? Homework(
                    description: '${h['text'] ?? ''}',
                    homeWorkDone: h['done'] == true,
                  )
                : null,
            files: const [],
            uploads: const [],
          )
        : null,
  );
}

/// Beim Elternkonto auch die Kinder (LessonsParentAwareParser.lastKids):
/// Vorname, Mensa und Kurse hängen daran.
final lessonsCodec = OfflineCodec<Lessons>(
  encode: (v, p) => jsonEncode({
    'lessons': [for (final l in v) _lesson(l)],
    if (p is LessonsParentAwareParser)
      'kids': [
        for (final k in p.lastKids)
          {
            'id': k.pupilId,
            'name': k.pupilName,
            'lessons': [for (final l in k.lessons) _lesson(l)],
          },
      ],
  }),
  decode: (s, p) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    List<Lesson> list(Object? v) => [
      for (final x in (v as List? ?? const []).cast<Map<String, dynamic>>())
        _lessonOf(x),
    ];
    final kids = [
      for (final k
          in (j['kids'] as List? ?? const []).cast<Map<String, dynamic>>())
        ChildLessons(
          pupilId: '${k['id']}',
          pupilName: '${k['name'] ?? ''}',
          lessons: list(k['lessons']),
        ),
    ];
    if (p is LessonsParentAwareParser && kids.isNotEmpty) p.lastKids = kids;
    return list(j['lessons']);
  },
);
