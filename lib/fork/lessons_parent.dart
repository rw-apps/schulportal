import 'package:html/dom.dart';
import 'package:liblanis/liblanis.dart';

/// Kurse eines Kindes aus der Eltern-Ansicht von meinunterricht.php.
class ChildLessons {
  ChildLessons({
    required this.pupilId,
    required this.pupilName,
    required this.lessons,
  });

  final String pupilId;

  /// So, wie das Portal ihn zeigt („Nachname, Vorname“).
  final String pupilName;
  final Lessons lessons;

  /// Vorname für kurze Beschriftungen; fällt auf [pupilName] zurück.
  String get firstName {
    final parts = pupilName.split(',');
    return parts.length > 1 ? parts[1].trim() : pupilName.trim();
  }
}

/// Liest die Eltern-Ansicht von `meinunterricht.php`.
///
/// Ursache: LessonsStudentParser.getHome (liblanis, lessons/student_parser.dart)
/// erwartet `#mappen`, `#aktuell`, `#anwesend`. Die Eltern-Seite hat stattdessen
/// je Kind einen Block `div.pupilbox` mit `h2[data-pupil=<ID>]` und Reitern
/// `mappen<ID>`, `aktuell<ID>`, `anwesend<ID>` (Export Schule A 16.10.26 10:47). Der
/// Schülerparser bricht dort mit einem Null-Fehler bei `row!` ab.
///
/// Grenze: Innerhalb der Reiter sind die Strukturen gleich wie bei Schülern
/// (Kursmappen-Kacheln, `tr.printable`, Anwesenheitstabelle); die Selektoren
/// sind daher bewusst dieselben. Kurs-IDs kommen aus dem Query-Parameter `id`,
/// weil Eltern-Links zusätzlich `&p=<Kind>` tragen (der Schülerparser nimmt
/// alles hinter `id=`).
List<ChildLessons> parseParentLessons(Document document) {
  final result = <ChildLessons>[];
  for (final box in document.querySelectorAll('div.pupilbox')) {
    final head = box.querySelector('h2[data-pupil]');
    final id = head?.attributes['data-pupil'];
    if (head == null || id == null) continue;

    final lessons = <Lesson>[];

    // Kursmappen
    final row = box.querySelector('#mappen$id .row');
    for (final mappe in row?.children ?? const <Element>[]) {
      final link = mappe.querySelector('a.btn.btn-primary')?.attributes['href'];
      final name = mappe.querySelector('h2')?.text.trim();
      if (link == null || name == null) continue;
      final url = Uri.parse(link);
      lessons.add(
        Lesson(
          name: name,
          teachers: mappe
              .querySelectorAll('div.btn-group>button')
              .map(
                (e) => LessonTeacher(
                  teacher: e.attributes['title']?.split(' (')[0].trim(),
                  teacherKuerzel: e.text.trim(),
                ),
              )
              .toList(),
          courseURL: url,
          courseID: url.queryParameters['id'] ?? link,
        ),
      );
    }

    // Aktuelle Einträge
    for (final tr in box.querySelectorAll('#aktuell$id tr.printable')) {
      final dateText = tr.querySelector('.datum')?.text.trim();
      final entryId = tr.attributes['data-entry'];
      final courseLink = tr.querySelector('td>h3>a')?.attributes['href'];
      if (dateText == null || entryId == null || courseLink == null) continue;
      final courseId = Uri.parse(courseLink).queryParameters['id'];
      final lesson = lessons.where((l) => l.courseID == courseId).firstOrNull;
      if (lesson == null) continue;

      Homework? homework;
      if (tr.querySelector('.homework') != null) {
        homework = Homework(
          description: tr.querySelector('.realHomework')?.text.trim() ?? '',
          homeWorkDone: tr.querySelector('.undone') == null,
        );
      }
      lesson.currentEntry = CurrentEntry(
        entryID: entryId,
        topicTitle: tr.querySelector('.thema')?.text.trim(),
        topicDate: _parseGermanDate(dateText),
        homework: homework,
        uploads: const [],
        files: List.generate(
          tr.getElementsByClassName('file').length,
          (_) => FileInfo(),
        ),
      );
    }

    // Anwesenheiten
    final attendance = box.querySelector('#anwesend$id');
    final keys = [
      for (final th in attendance?.querySelectorAll('thead>tr>*') ?? const [])
        th.text.trim().toLowerCase(),
    ];
    for (final tr in attendance?.querySelectorAll('tbody>tr') ?? const []) {
      final href = tr.querySelector('a')?.attributes['href'];
      final courseId = href == null ? null : Uri.parse(href).queryParameters['id'];
      final lesson = lessons.where((l) => l.courseID == courseId).firstOrNull;
      if (lesson == null) continue;
      final values = <String, String>{};
      for (var i = 0; i < tr.children.length && i < keys.length; i++) {
        if (keys[i] == 'kurs' || keys[i] == 'lehrkraft') continue;
        final cell = tr.children[i];
        cell.querySelector('div.hidden.hidden_encoded')?.innerHtml = '';
        final v = cell.text.trim();
        values[keys[i]] = v.isEmpty ? '0' : v;
      }
      lesson.attendances = values;
    }

    // Neueste Einträge zuerst, wie im Schülerparser.
    lessons.sort((a, b) {
      final da = a.currentEntry?.topicDate;
      final db = b.currentEntry?.topicDate;
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });

    result.add(
      ChildLessons(pupilId: id, pupilName: head.text.trim(), lessons: lessons),
    );
  }
  return result;
}

DateTime? _parseGermanDate(String text) {
  final m = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(text);
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(3)!),
    int.parse(m.group(2)!),
    int.parse(m.group(1)!),
  );
}
