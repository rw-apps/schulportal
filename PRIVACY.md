# Datenschutzhinweis – App „Schulportal“ (rw-apps)

Stand: 14.10.2026

„Schulportal“ ist eine inoffizielle, private und nicht kommerzielle Abwandlung der quelloffenen App [Lanis-Mobile](https://github.com/lanis-mobile/lanis). Sie wird im Familien- und Freundeskreis weitergegeben. Mit dem Land Hessen, dem Schulportal Hessen und den Entwicklern von Lanis-Mobile besteht keine Verbindung.

## Welche Daten die App verarbeitet

Die App meldet sich mit deinen Zugangsdaten **direkt beim Schulportal Hessen** an und zeigt die Inhalte an, die das Portal für dein Konto bereitstellt, etwa Vertretungsplan, Stundenplan, Nachrichten, Kalender und Kurse. Dabei läuft keine Verbindung über Server des Betreibers dieser App.

Benutzername, Schulnummer und Passwort bleiben **nur auf deinem Gerät**. Das Passwort liegt im geschützten Schlüsselspeicher von Android (Keystore). Inhalte aus dem Portal werden als Zwischenspeicher auf dem Gerät abgelegt, damit die App auch ohne Netz etwas anzeigen kann.

## Verbindungen der App

- **Schulportal Hessen** (`*.schulportal.hessen.de`, auch Moodle deiner Schule): für Anmeldung und Inhalte.
- **GitHub** (`api.github.com`): Die App prüft dort, ob es eine neue Version gibt, und lädt auf der Seite „Über diese App“ die Liste der Mitwirkenden. GitHub erfährt dabei deine IP-Adresse, aber keine Zugangsdaten und keine Portal-Inhalte.

## Was die App nicht tut

Diese Fassung sendet **keine** Nutzungs- oder Login-Statistik und **keine** automatischen Fehlerberichte. Beides war im Original enthalten und wurde entfernt. Werbung und Tracking gibt es nicht.

## Löschen

Abmelden oder Deinstallieren entfernt die gespeicherten Zugangsdaten und Inhalte vom Gerät.

## Kontakt

Fragen und Fehlermeldungen bitte als Issue in diesem Repository: https://github.com/rw-apps/schulportal/issues
