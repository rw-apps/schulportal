import 'package:html/dom.dart';
import 'package:liblanis/liblanis.dart';

import 'error_log.dart';

/// Schüler-Übersicht von `meinunterricht.php`, eine kaputte Zeile kostet nur
/// diese Zeile.
///
/// Ursache (Prüfung 27.10.26, liblanis lessons/student_parser.dart:38, :42,
/// :72, :84, :90, :139): LessonsStudentParser.getHome liest jede Kachel und
/// Zeile mit `!`, `[0]` und `DateTime.parse`. Fehlt in EINER Kursmappe der
/// Knopf `a.btn.btn-primary`, in EINEM Eintrag `.realHomework` oder
/// `data-entry`, steht ein Datum anders oder hat EINE Anwesenheitszeile
/// weniger Zellen als der Kopf, wirft die ganze Übersicht. AppletParser
/// .fetchData (applet_parser.dart:150–153) meldet sich daraufhin bei jedem
/// Abruf neu an und scheitert wieder – die Kursliste bleibt leer bzw. auf
/// dem alten Stand. Jetzt wird nur die betroffene Zeile übersprungen und mit
/// Zählwerten (ohne Inhalte) im Fehlerprotokoll vermerkt.
///
/// Grenze: Fehlt `#mappen` ganz, ist das keine kaputte Zeile, sondern
/// keine Unterrichtsseite (meist abgelaufene Sitzung) – dann wird wie bisher
/// geworfen, damit die Neuanmeldung greift. Selektoren, Kurs-ID
/// (`split("id=")[1]`) und Sortierung sind bewusst dieselben wie in
/// liblanis, damit gespeicherte Kurs-IDs (Hausaufgaben, Kurs-Scan) passen.
({Lessons lessons, int skipped}) parseStudentLessons(Document document) {
  final mappenDom = document.getElementById('mappen');
  if (mappenDom == null) {
    throw UnknownException('meinunterricht.php: keine Kursmappen');
  }
  var skipped = 0;
  final lessons = <Lesson>[];

  // Kursmappen (student_parser.dart:36–61).
  final rows = mappenDom.getElementsByClassName('row');
  final mappen = rows.isEmpty ? const <Element>[] : rows[0].children;
  for (final mappe in mappen) {
    final href = mappe.querySelector('a.btn.btn-primary')?.attributes['href'];
    final h2 = mappe.getElementsByTagName('h2');
    final parts = href?.split('id=') ?? const <String>[];
    final url = href == null ? null : Uri.tryParse(href);
    if (h2.isEmpty || parts.length < 2 || url == null) {
      skipped++;
      continue;
    }
    lessons.add(
      Lesson(
        name: h2[0].text.trim(),
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
        courseID: parts[1],
      ),
    );
  }

  // Aktuelle Einträge (student_parser.dart:63–107).
  for (final tr in document.querySelectorAll('tr.printable')) {
    final dateText = tr.querySelector('.datum')?.text.trim();
    if (dateText == null) continue;
    final entryId = tr.attributes['data-entry'];
    if (entryId == null) {
      skipped++;
      continue;
    }
    final courseUrl = tr.querySelector('td>h3>a')?.attributes['href'];
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
    for (final lesson in lessons) {
      if (lesson.courseURL.toString() == courseUrl) {
        lesson.currentEntry = CurrentEntry(
          entryID: entryId,
          topicTitle: tr.querySelector('.thema')?.text.trim(),
          // Unlesbares Datum: Eintrag bleibt, nur ohne Datum (die Sortierung
          // unten behandelt null wie liblanis).
          topicDate: DateTime.tryParse(dateText.split('.').reversed.join('-')),
          homework: homework,
          uploads: const [],
          files: List.generate(
            tr.getElementsByClassName('file').length,
            (_) => FileInfo(),
          ),
        );
        break;
      }
    }
  }

  // Anwesenheiten (student_parser.dart:109–149).
  final attendance = document.getElementById('anwesend');
  final keys = [
    for (final th in attendance?.querySelector('thead>tr')?.children ?? [])
      th.text.trim(),
  ];
  for (final tr in attendance?.querySelectorAll('tbody>tr') ?? <Element>[]) {
    final links = tr.getElementsByTagName('a');
    final courseUrl = links.isEmpty ? null : links[0].attributes['href'];
    if (courseUrl == null || tr.children.length < keys.length) {
      skipped++;
      continue;
    }
    final values = <String, String>{};
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i].toLowerCase();
      if (key == 'kurs' || key == 'lehrkraft') continue;
      final cell = tr.children[i];
      cell.querySelector('div.hidden.hidden_encoded')?.innerHtml = '';
      final v = cell.text.trim();
      values[key] = v.isEmpty ? '0' : v;
    }
    for (final lesson in lessons) {
      if (courseUrl.contains(lesson.courseID)) {
        lesson.attendances = values;
        break;
      }
    }
  }

  lessons.sort((a, b) {
    final da = a.currentEntry?.topicDate;
    final db = b.currentEntry?.topicDate;
    if (da == null || db == null) return 0;
    return db.compareTo(da);
  });
  if (skipped > 0) {
    ErrorLog.instance.notice('meinunterricht.php', 'SkippedRows', {
      'skipped': skipped,
      'lessons': lessons.length,
    });
  }
  return (lessons: lessons, skipped: skipped);
}

/// Datei-Adresse einer Kursdatei mit richtig kodiertem Dateinamen.
///
/// Ursache (Prüfung 27.10.26, liblanis lessons/student_parser.dart:238):
/// liblanis setzt `Uri.parse("$baseURL&f=$filename")` unkodiert zusammen.
/// Ein `&` im Namen beginnt dort einen neuen Parameter („f=a“, „b.pdf=“),
/// `#` schneidet den Rest als Fragment ab, `+` und `%20` liest PHP als
/// Leerzeichen – das Portal liefert eine falsche Datei oder einen Fehler.
/// Jetzt wird alles ab dem ersten `&f=` aus [name] (dem rohen `data-file`)
/// neu und kodiert angehängt.
///
/// Grenze: Nur Namen mit `&`, `#`, `+` oder `%` werden umgeschrieben; alle
/// anderen Adressen bleiben Zeichen für Zeichen gleich, damit schon
/// gespeicherte Dateien (StorageManager.resolvePath, Hash der Adresse)
/// weiter gefunden werden. Ohne `&f=` in der Adresse bleibt sie unverändert.
Uri? fixedLessonFileUrl(Uri? url, String? name) {
  if (url == null || name == null || !RegExp(r'[&#+%]').hasMatch(name)) {
    return url;
  }
  final raw = url.toString();
  // Der Name kann selbst „&f=“ enthalten; die Basis (ZIP-Link des Eintrags
  // aus `div.alert.alert-info>a`, ohne `&b=zip`, student_parser.dart:226)
  // erwartungsgemäß nicht – daher das ERSTE.
  final i = raw.indexOf('&f=');
  if (i < 0) return url;
  return Uri.parse('${raw.substring(0, i)}&f=${Uri.encodeComponent(name)}');
}
