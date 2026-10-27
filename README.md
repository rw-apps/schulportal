# Schulportal

*[Read this in English](README.en.md)*

Eine Android-App für das **Schulportal Hessen** – gemacht für Eltern und Schüler, die den Alltag auf einen Blick sehen wollen: was heute ansteht, was ausfällt, welche Hausaufgaben offen sind. Privat und nicht kommerziell, weitergegeben im Familien- und Freundeskreis.

Die App ist eine Abwandlung von [Lanis-Mobile](https://github.com/lanis-mobile/lanis) und steht wie das Original unter der **GPL-3.0**. Mit dem Land Hessen, dem Schulportal Hessen und den Entwicklern von Lanis-Mobile besteht keine Verbindung.

## Was die App kann

- **Heute** – je Kind eine Karte: Ausfälle, Vertretungen und Raumwechsel zuerst, darunter der Stundenplan des Tages mit der laufenden Stunde; offene Hausaufgaben, neue Nachrichten, nächste Termine.
- **Kalender** – Tag, Woche und Termine; Vertretungen bleiben auch für vergangene Tage sichtbar; Gruppenwahl bei parallelen Kursen (z. B. Religion/Ethik).
- **Unterricht** – Kursmappen, offene Hausaufgaben mit vermuteter Frist (nächste Stunde im Fach), Archiv für erledigte und abgelaufene, anstehende Arbeiten, Noten und Fehlzeiten.
- **Nachrichten** – lesen, beantworten, neu schreiben.
- **Familie** – mehrere Konten nebeneinander, auch an verschiedenen Schulen (Eltern- und Schülerkonten).
- **Essen** – bestellte Gerichte der Woche, bestellen und abbestellen in der App, Hinweise bei fehlender Bestellung und niedrigem Guthaben (für die bekannten Bestellseiten; sonst öffnet sich die Seite des Caterers).
- **Ohne Netz** – zeigt den zuletzt gespeicherten Stand und sagt, von wann er ist.
- **Benachrichtigungen** – eine Sammelmeldung mit dem Wichtigsten (Ausfälle, Vertretungen, Raumwechsel, neue Nachrichten, nicht bestelltes Essen), die nur erscheint, wenn etwas ansteht, und von selbst verschwindet.
- **Demo** – „Demo ansehen“ auf der Startseite zeigt die App mit einer erfundenen Schule, ohne Anmeldung.

## Installation

Die App gibt es nur für **Android**.

1. Die APK aus den [Releases](https://github.com/rw-apps/schulportal/releases/latest) herunterladen und installieren. Android fragt einmal, ob Installationen aus dieser Quelle erlaubt sind.
2. Für automatische Updates: [Obtainium](https://github.com/ImranR98/Obtainium) installieren und dort `https://github.com/rw-apps/schulportal` hinzufügen.

Die App hat eine eigene App-ID (`io.github.rwapps.sph`) und läuft parallel zu Lanis-Mobile.

## Datenschutz

Die App meldet sich **direkt beim Schulportal** an; Zugangsdaten bleiben auf dem Gerät. Es gibt keine Werbung, kein Tracking und keine Nutzungsstatistik. Fehlerberichte gehen nur mit Zustimmung raus und enthalten keine Namen, Noten oder Nachrichten. Einzelheiten: [PRIVACY.md](PRIVACY.md).

## Fehler melden

In der App unter **Einstellungen → Über die App → Fehlersuche**: „Erkannte Probleme“ teilen oder – mit Zustimmung – automatisch melden. Kann die App eine Seite des Portals nicht lesen (z. B. an einer anderen Schule oder mit einem Lehrerkonto), hilft der **anonyme Export**: Er zeigt den Aufbau der Seiten ohne Namen, Noten und Texte.

Fragen und Hinweise gern als [Issue](https://github.com/rw-apps/schulportal/issues).

## Für Entwickler

- Flutter (stable, siehe `pubspec.yaml`), Riverpod, [liblanis](https://pub.dev/packages/liblanis) für den Zugriff aufs Portal.
- Eigener Code liegt in `lib/fork/`, die Oberfläche in `lib/fork/ui/` mit dem zentralen Design-Kit `lib/fork/ui/kit.dart`.
- Texte: `lib/fork/l10n/fork_*.arb` (Deutsch, Englisch, Türkisch), danach `flutter gen-l10n`.
- Prüfen: `dart format lib test/fork`, `flutter analyze`, `flutter test`.
- Testdaten sind frei erfunden – echte Schul- oder Personendaten gehören nicht ins Repo.
- Ein Release entsteht durch einen Versionssprung in `pubspec.yaml` auf `main` (`.github/workflows/release-fork.yml`).

Änderungen gegenüber dem Original: [CHANGELOG-FORK.md](CHANGELOG-FORK.md).

## Herkunft und Lizenz

Grundlage ist [Lanis-Mobile](https://github.com/lanis-mobile/lanis) – vielen Dank an alle, die daran mitgearbeitet haben. Lizenz: [GPL-3.0](LICENSE). Die Schrift Manrope steht unter der SIL Open Font License 1.1.
