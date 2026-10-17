import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/applets/lessons/routes.dart' show isLessonsUploadUrl;
import 'package:lanis/utils/file_operations.dart'
    show safeFileName, DownloadableFile;

/// Prüfbefunde der Sicherheitsprüfung 17.10.26.
void main() {
  test('Dateinamen ohne Pfadanteile', () {
    expect(safeFileName('../../lanis.db', 'x'), 'lanis.db');
    expect(safeFileName('/data/data/a/b.txt', 'x'), 'b.txt');
    expect(safeFileName('..\\..\\c.pdf', 'x'), 'c.pdf');
    expect(safeFileName('..', 'x'), 'x');
    expect(safeFileName('a\nb.pdf', 'x'), 'ab.pdf');
    expect(DownloadableFile(name: '../x/y.pdf').name, 'y.pdf');
  });

  test('Abgabe-Route nur für „Mein Unterricht“', () {
    expect(
      isLessonsUploadUrl(
        'https://start.schulportal.hessen.de/meinunterricht.php?a=sus_abgabe&id=1',
      ),
      isTrue,
    );
    expect(isLessonsUploadUrl('meinunterricht.php?a=sus_abgabe'), isTrue);
    expect(
      isLessonsUploadUrl('https://evil.example/meinunterricht.php'),
      isFalse,
    );
    expect(
      isLessonsUploadUrl(
        'http://start.schulportal.hessen.de/meinunterricht.php',
      ),
      isFalse,
    );
    expect(
      isLessonsUploadUrl('https://start.schulportal.hessen.de/nachrichten.php'),
      isFalse,
    );
  });
}
