# Datenschutzhinweis – App „Schulportal“ (rw-apps)

Stand: 26.10.2026

„Schulportal“ ist eine inoffizielle, private und nicht kommerzielle Abwandlung der quelloffenen App [Lanis-Mobile](https://github.com/lanis-mobile/lanis). Sie wird im Familien- und Freundeskreis weitergegeben. Mit dem Land Hessen, dem Schulportal Hessen und den Entwicklern von Lanis-Mobile besteht keine Verbindung.

## Welche Daten die App verarbeitet

Die App meldet sich mit deinen Zugangsdaten **direkt beim Schulportal Hessen** an und zeigt die Inhalte an, die das Portal für dein Konto bereitstellt, etwa Vertretungsplan, Stundenplan, Nachrichten, Kalender und Kurse. Dabei läuft keine Verbindung über Server des Betreibers dieser App; einzige Ausnahme sind Fehlerberichte, denen du zugestimmt hast (siehe unten).

Benutzername, Schulnummer und Passwort bleiben **nur auf deinem Gerät**. Das Passwort liegt im geschützten Schlüsselspeicher von Android (Keystore). Inhalte aus dem Portal werden als Zwischenspeicher auf dem Gerät abgelegt, damit die App auch ohne Netz etwas anzeigen kann.

## Verbindungen der App

- **Schulportal Hessen** (`*.schulportal.hessen.de`, auch Moodle deiner Schule): für Anmeldung und Inhalte.
- **GitHub** (`api.github.com`): Die App prüft dort, ob es eine neue Version gibt, und lädt auf der Seite „Über diese App“ die Liste der Mitwirkenden. GitHub erfährt dabei deine IP-Adresse, aber keine Zugangsdaten und keine Portal-Inhalte.
- **Cloudflare** (`*.workers.dev`): nur für Fehlerberichte mit deiner Zustimmung (siehe unten).

## Fehlerberichte – nur mit deiner Zustimmung

- **Fehler automatisch melden:** Nur wenn du zustimmst (Frage auf „Heute“ oder Einstellungen → Über die App → Fehlersuche), sendet die App erkannte Fehler. Ein Bericht enthält App-Version, Bereich, Fehlerart und Stellen im Code – **keine** Namen, Noten, Nachrichten, Zugangsdaten oder sonstige Portal-Inhalte. Du kannst den Bericht vorher unter „Erkannte Probleme“ ansehen und die Zustimmung jederzeit dort zurücknehmen.
- **Anonym senden:** Kann die App eine Portalseite nicht lesen, kannst du deren Aufbau anonym senden. Alle Wörter außer festen Beschriftungen werden durch Zufallsbuchstaben ersetzt, Noten zufällig neu vergeben, Schulnummer, Bilder und Anmeldedaten entfernt. Gesendet wird erst, nachdem du die unverändert gebliebenen Wörter gesehen und auf „Senden“ getippt hast.
- **Empfänger:** Ein Weiterleitungsdienst bei Cloudflare (`schulportal-berichte.rideguide-family-2026.workers.dev`) legt den Bericht als Eintrag in einem **privaten** GitHub-Repository ab, das nur der Betreuer der App sehen kann. Cloudflare und GitHub erfahren dabei technisch bedingt deine IP-Adresse; der Dienst selbst speichert sie nicht.

## Was die App nicht tut

Diese Fassung sendet **keine** Nutzungs- oder Login-Statistik und ohne deine Zustimmung **keine** Fehlerberichte. Die automatische Fehlererfassung des Originals (Sentry) wurde entfernt. Werbung und Tracking gibt es nicht.

## Löschen

Abmelden oder Deinstallieren entfernt die gespeicherten Zugangsdaten und Inhalte vom Gerät.

## Kontakt

Fragen und Fehlermeldungen bitte als Issue in diesem Repository: https://github.com/rw-apps/schulportal/issues
