/// Identität dieses Forks („Schulportal“ von rw-apps) an EINER Stelle.
///
/// Ursache: Das Original (lanis-mobile/lanis) hat Namen, Repo-, Store- und
/// Kontaktadressen über ~12 Dateien verstreut (u. a. whats_new.dart,
/// about.dart, debug_export.dart, lanis_bootstrap.dart, school_selector.dart).
/// Im Fork würden diese Stellen sonst auf das Original zeigen: Die
/// Update-Prüfung meldete deren Releases und schickte Nutzer in den Play Store
/// zur Original-App, der Debug-Export nannte deren E-Mail als Empfänger.
///
/// Grenze: Jede betroffene Datei referenziert nur noch diese Konstanten. Beim
/// Nachziehen des Originals (git merge upstream/main) bleiben Konflikte so auf
/// eine Zeile je Datei begrenzt. Neue Upstream-Stellen mit „alessioc42“ oder
/// „lanis-mobile“ fängt der Test test/fork_identity_test.dart ab.
library;

/// Anzeigename in App-Leiste und Task-Umschalter (Launcher-Name steht in
/// android/app/src/main/AndroidManifest.xml, android:label).
const forkAppName = 'Schulportal';

/// GitHub-Repo des Forks: Quelle für Update-Prüfung, Fehlermeldungen, Quellcode.
const forkRepo = 'rw-apps/schulportal';
const forkRepoUrl = 'https://github.com/$forkRepo';
const forkIssuesUrl = '$forkRepoUrl/issues';
const forkReleasesApiUrl = 'https://api.github.com/repos/$forkRepo/releases';
const forkLatestReleaseUrl = '$forkRepoUrl/releases/latest';

/// Datenschutzhinweis des Forks (liegt als PRIVACY.md im Repo).
const forkPrivacyPolicyUrl = '$forkRepoUrl/blob/main/PRIVACY.md';

/// Herkunft — Pflichthinweis (GPL-3.0 §5: geänderte Fassung kenntlich machen).
const upstreamName = 'Lanis-Mobile';
const upstreamRepoUrl = 'https://github.com/lanis-mobile/lanis';

/// User-Agent gegenüber dem Schulportal.
///
/// Ursache: Das Original meldet sich als „Lanis-Mobile/v…“. Der Fork ist eine
/// andere App mit eigener Versionszählung; unter fremdem Namen aufzutreten
/// würde Fehler im Portal-Log dem Original zuschreiben.
String forkUserAgent(String version, String buildNumber) =>
    'Schulportal-rw/v$version+$buildNumber (fork of $upstreamName)';
