import 'package:liblanis/liblanis.dart';

import '../messages/messages_page.dart';
import '../courses/courses_model.dart';

/// Erfundene Kurse für Tests und Bildschirmfotos (keine echten Namen).
List<CourseItem> demoCourses() => [
  CourseItem(
    id: 'd1',
    title: 'Mathematik',
    fullName: 'Mathematik 07 b',
    teachers: const ['Maria Becker'],
    topic: 'Brüche erweitern',
    date: DateTime(2026, 10, 19),
    homework: 'Buch S. 42 Nr. 3–5',
  ),
  CourseItem(
    id: 'd2',
    title: 'Englisch',
    fullName: 'Englisch 07 b',
    teachers: const ['Tim Sommer'],
    topic: 'Unit 2: At the station',
    date: DateTime(2026, 10, 16),
    homework: 'Vokabeln Unit 2 lernen',
    homeworkDone: true,
  ),
  CourseItem(
    id: 'd3',
    title: 'Biologie',
    fullName: 'Biologie 07 b',
    teachers: const ['Jan Wolf', 'Eva Ernst'],
    topic: 'Die Zelle',
    date: DateTime(2026, 10, 15),
    attendance: 'Fehlstunden 2 · Entschuldigt 2',
  ),
];

/// Erfundene Unterhaltungen für Tests und Bildschirmfotos.
List<MessageItem> demoMessages() => const [
  MessageItem(
    id: 'm1',
    subject: 'Wandertag am Freitag',
    sender: 'Maria Becker',
    date: 'heute 08:12',
    unread: true,
  ),
  MessageItem(
    id: 'm2',
    subject: 'Elternabend 7b',
    sender: 'Tim Sommer',
    date: '14.10.2026 17:40',
  ),
];

/// Erfundene Kursmappe zur Kursliste (Beispieldaten der Vorschau).
DetailedLesson demoDetailedLesson(CourseItem c) => DetailedLesson(
  courseID: c.id,
  name: c.fullName,
  teachers: [for (final t in c.teachers) LessonTeacher(teacher: t)],
  history: [
    CurrentEntry(
      entryID: '${c.id}-1',
      topicTitle: c.topic,
      topicDate: c.date,
      files: const [],
      uploads: const [],
    ),
  ],
  marks: const [],
  exams: const [],
  attendances: const {},
);
