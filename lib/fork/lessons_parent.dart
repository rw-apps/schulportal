import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;
import 'package:liblanis/liblanis.dart';

import 'lessons_student.dart';

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
/// sind daher bewusst dieselben.
///
/// `courseID` lautet `<id>&p=<Kind>`. Ursache: Die Kursroute baut die URL als
/// `meinunterricht.php?a=sus_view&id=$courseId` (applets/lessons/routes.dart);
/// das Kind muss mit, sonst weiß das Portal bei mehreren Kindern nicht, wessen
/// Kurs gemeint ist. Dieselbe Form ergibt auch LessonsStudentParser
/// .getDetailedCourseView (`url.split("id=")[1]`), damit bleibt beides gleich.
/// Zuordnungen innerhalb der Seite laufen über die reine Kurs-ID.
List<ChildLessons> parseParentLessons(Document document) {
  final result = <ChildLessons>[];
  for (final box in document.querySelectorAll('div.pupilbox')) {
    final head = box.querySelector('h2[data-pupil]');
    final id = head?.attributes['data-pupil'];
    if (head == null || id == null) continue;

    final lessons = <Lesson>[];
    final byPureId = <String, Lesson>{};

    // Kursmappen
    final row = box.querySelector('#mappen$id .row');
    for (final mappe in row?.children ?? const <Element>[]) {
      final link = mappe.querySelector('a.btn.btn-primary')?.attributes['href'];
      final name = mappe.querySelector('h2')?.text.trim();
      if (link == null || name == null) continue;
      final url = Uri.parse(link);
      // Ohne `id` kein Kurs. Ursache (Prüfung 27.10.26): Bisher galt dann der
      // ganze Link als Kurs-ID – die Kursroute baute daraus
      // „…&id=<Link>&p=<Kind>“, Einträge und Anwesenheit (byPureId, über
      // `id` zugeordnet) fanden den Kurs nie. Grenze: Eine solche Kachel
      // fehlt in der Liste; das Portal hat sie ohnehin nicht verlinkt.
      final pureId = url.queryParameters['id'];
      if (pureId == null || pureId.isEmpty) continue;
      final lesson = Lesson(
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
        courseID: '$pureId&p=$id',
      );
      lessons.add(lesson);
      byPureId[pureId] = lesson;
    }

    // Aktuelle Einträge
    for (final tr in box.querySelectorAll('#aktuell$id tr.printable')) {
      final dateText = tr.querySelector('.datum')?.text.trim();
      final entryId = tr.attributes['data-entry'];
      final courseLink = tr.querySelector('td>h3>a')?.attributes['href'];
      if (dateText == null || entryId == null || courseLink == null) continue;
      final lesson = byPureId[Uri.parse(courseLink).queryParameters['id']];
      if (lesson == null) continue;

      Homework? homework;
      // Platzhalter („-“) ist keine Hausaufgabe (Homework.isPlaceholder).
      if (tr.querySelector('.homework') != null &&
          !Homework.isPlaceholder(
            tr.querySelector('.realHomework')?.text ?? '',
          )) {
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
      final lesson = href == null
          ? null
          : byPureId[Uri.parse(href).queryParameters['id']];
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

/// Alle Kinder in eine Liste, neueste Einträge zuerst. Bei mehreren Kindern
/// steht der Vorname vor dem Kursnamen, damit die Liste eindeutig bleibt
/// („Lena: Mathematik …“, [kidPrefix]; zurück mit [courseNameWithoutKid]).
Lessons flattenChildLessons(List<ChildLessons> kids) {
  final all = <Lesson>[];
  for (final k in kids) {
    for (final l in k.lessons) {
      if (kids.length > 1) l.name = '${kidPrefix(k)}${l.name}';
      all.add(l);
    }
  }
  all.sort((a, b) {
    final da = a.currentEntry?.topicDate;
    final db = b.currentEntry?.topicDate;
    if (da == null || db == null) return 0;
    return db.compareTo(da);
  });
  return all;
}

/// Vorsatz vor dem Kursnamen bei mehreren Kindern (flattenChildLessons).
String kidPrefix(ChildLessons kid) => '${kid.firstName}: ';

/// Kind-ID aus der Kurs-ID des Elternkontos (`<id>&p=<Kind>`,
/// parseParentLessons); null bei Schülerkonten.
String? kidOfCourseId(String courseId) {
  final i = courseId.lastIndexOf('&p=');
  if (i < 0) return null;
  final kid = courseId.substring(i + 3);
  return kid.isEmpty ? null : kid;
}

/// Das Kind zum Kurs [courseId] aus [kids]; null ohne Treffer.
ChildLessons? kidOfCourse(String courseId, List<ChildLessons> kids) {
  final id = kidOfCourseId(courseId);
  if (id == null) return null;
  for (final k in kids) {
    if (k.pupilId == id) return k;
  }
  return null;
}

/// Kursname ohne den Vornamen, den [flattenChildLessons] bei mehreren
/// Kindern voranstellt („Lena: Mathematik 06a“ → „Mathematik 06a“).
///
/// Ursache (Prüfung 27.10.26): Mit zwei Kindern trug jeder Kurs den
/// Vorsatz, die Zuordnung zum Stundenplan (lessonBelongsTo,
/// course_detail_model.dart) verglich „Lena: Mathematik“ mit „Mathematik“
/// und fand nie etwas – alle Kurse standen unter „Weitere Angebote“, „Als
/// Nächstes“ fehlte. Entfernt wird genau der Vorsatz des Kindes aus der
/// Kurs-ID (`&p=`), nicht irgendein Text vor einem Doppelpunkt: Ein Kurs
/// „Projekt: Text“ bleibt, wie er ist. Grenze: Ohne [kids] (z. B. im
/// Hintergrund) bleibt der Name unverändert.
String courseNameWithoutKid(
  String name,
  String courseId,
  List<ChildLessons> kids,
) {
  if (kids.length < 2) return name;
  final kid = kidOfCourse(courseId, kids);
  if (kid == null) return name;
  final prefix = kidPrefix(kid);
  return name.startsWith(prefix) ? name.substring(prefix.length) : name;
}

/// Kind, dessen Stundenplan die App zeigt; null bei einem Kind oder
/// Schülerkonto (dann gehört alles zum Plan).
///
/// Grenze: Wie LiveSnapshot.firstName und mensaKid (live_data.dart) gilt
/// der Plan des Kontos als Plan des ERSTEN Kindes der Eltern-Ansicht; zeigt
/// stundenplan.php bei Geschwistern einen anderen, ordnet die App die Kurse
/// des falschen Kindes zu.
String? shownPlanKid(List<ChildLessons> kids) =>
    kids.length > 1 ? kids.first.pupilId : null;

/// LessonsStudentParser mit Eltern-Übersicht.
///
/// Ursache: siehe [parseParentLessons]. Grenze: Nur getHome() unterscheidet
/// nach Kontoart; die Kursdetailseite liest der Schülerparser auch für Eltern
/// korrekt (lokal gegen zwei Eltern-Kursseiten von Schule A geprüft, 16.10.26:
/// 0 bzw. 5 Einträge, Anwesenheit erkannt). Aktionen wie setHomework oder
/// Uploads blendet die Oberfläche für Eltern aus.
class LessonsParentAwareParser extends LessonsStudentParser {
  LessonsParentAwareParser(super.ctx, {super.isConnected});

  /// Zuletzt gelesene Kinder (Elternkonto), z. B. für den Vornamen im
  /// Stundenplan der neuen Oberfläche; leer bei Schülerkonten.
  List<ChildLessons> lastKids = const [];

  bool get _isParent =>
      (ctx.session.accountTypeOrNull ?? ctx.account.accountType) ==
      AccountType.parent;

  @override
  Future<Lessons> getHome() async {
    // Schüler: dieselbe Seite wie LessonsStudentParser.getHome
    // (student_parser.dart:31), aber zeilenweise fehlertolerant
    // (parseStudentLessons, lessons_student.dart).
    if (!_isParent) {
      final response = await ctx.session.dio.get(
        'https://start.schulportal.hessen.de/meinunterricht.php'
        '?cacheBreaker=${DateTime.now().millisecondsSinceEpoch}',
      );
      return parseStudentLessons(parse(response.data.toString())).lessons;
    }
    final response = await ctx.session.dio.get(
      'https://start.schulportal.hessen.de/meinunterricht.php'
      '?cacheBreaker=${DateTime.now().millisecondsSinceEpoch}',
    );
    final kids = parseParentLessons(parse(response.data.toString()));
    // Leere Eltern-Seite heißt fast immer: Sitzung verloren. Werfen, damit
    // AppletParser.fetchData einmal neu anmeldet und es erneut versucht.
    if (kids.isEmpty) {
      throw UnknownException('meinunterricht.php: keine pupilbox');
    }
    lastKids = kids;
    return flattenChildLessons(kids);
  }
}
