import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Wächter des Forks: Kein Code in lib/ darf auf Server, Mailadressen oder
/// Store-Einträge des Originals zeigen.
///
/// Ursache: Beim Nachziehen des Originals (git merge upstream/main) können neue
/// Stellen mit Adressen der Original-Entwickler hereinkommen — z. B. eine neue
/// Telemetrie-URL unter *.alessioc42.dev. Ein Merge ohne Konflikt würde sie
/// still übernehmen; dieser Test macht ihn rot.
///
/// Grenze: Erlaubt sind nur die unten begründeten Stellen. Kommentare werden
/// mitgeprüft (einfacher, und ein Kommentar mit Adresse markiert eine
/// bewusste Ausnahme, die hier eingetragen gehört).
void main() {
  // Datei → Teilstring, der dort erlaubt ist (+ Begründung).
  const erlaubt = <String, List<String>>{
    // Herkunftshinweis + Doku der Fork-Identität (GPL-3.0 §5).
    'lib/fork_identity.dart': ['lanis-mobile', 'Lanis-Mobile', 'alessioc42'],
    // Interne Kanal-ID der Benachrichtigungen; nie im Netz. Ändern hieße:
    // Android legt einen neuen Kanal an, Nutzer verlieren ihre Kanal-Einstellung.
    'lib/background_service.dart': ['io.github.alessioc42.sphplan'],
    // Interner MethodChannel; muss zum Kotlin-Gegenstück passen
    // (android/app/src/main/kotlin/.../MainActivity.kt).
    'lib/utils/file_operations.dart': ['io.github.lanis-mobile/storage'],
    // Mitwirkende des Originals bewusst sichtbar (Namensnennung).
    'lib/view/settings/subsettings/about.dart': [
      'api.github.com/repos/lanis-mobile/lanis/contributors',
    ],
    // Kommentare, die die entfernten Ziele als Ursache dokumentieren.
    'lib/bridge/login_telemetry.dart': [
      'lanis-logger.orion.alessioc42.dev',
      'lanis-mobile/school-monitor-backend',
    ],
    'lib/view/startup_error_view.dart': ['lanis-mobile@alessioc42.dev'],
    'lib/utils/whats_new.dart': ['io.github.alessioc42.sph'],
  };
  final muster = RegExp(r'alessioc42|lanis-mobile', caseSensitive: false);

  test('lib/ zeigt nirgends auf Infrastruktur des Originals', () {
    final funde = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.startsWith('lib/generated/')) continue;
      final ok = erlaubt[f.path] ?? const <String>[];
      final zeilen = f.readAsLinesSync();
      for (var i = 0; i < zeilen.length; i++) {
        var z = zeilen[i];
        for (final e in ok) {
          z = z.replaceAll(e, '');
        }
        if (muster.hasMatch(z))
          funde.add('${f.path}:${i + 1}: ${zeilen[i].trim()}');
      }
    }
    expect(funde, isEmpty, reason: funde.join('\n'));
  });

  test('Login-Telemetrie ist entfernt', () {
    final s = File('lib/bridge/login_telemetry.dart').readAsStringSync();
    expect(s.contains('Dio('), isFalse);
    expect(s.contains('asyncLogLoginRequest'), isFalse);
  });

  // Ursache: Beim Umbau des Release-Workflows (14.10.26) fiel der
  // permissions-Block weg; der Lauf baute die APK und scheiterte erst beim
  // Anlegen des Releases (HTTP 403). Dieser Test meldet das schon lokal.
  test('Release-Workflow darf Releases anlegen', () {
    final s = File('.github/workflows/release-fork.yml').readAsStringSync();
    expect(
      RegExp(
        r'^permissions:\s*\n\s+contents: write',
        multiLine: true,
      ).hasMatch(s),
      isTrue,
    );
  });

  // Seit 4.1.0+9337 ohne Sentry-SDK: Es darf gar nicht mehr eingebunden sein.
  test('kein Fehlerbericht-SDK', () {
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('sentry')));
    expect(
      File('lib/utils/glitchtip.dart').readAsStringSync(),
      isNot(contains('package:sentry')),
    );
  });
}
