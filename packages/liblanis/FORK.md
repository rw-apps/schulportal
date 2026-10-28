# liblanis – eingebettete Kopie

**Herkunft:** pub.dev-Paket `liblanis` Version **0.1.4**
(<https://github.com/lanis-mobile/liblanis>), unverändert übernommen am
**28.10.26**. Lizenz: GPL-3.0 (`LICENSE`, unverändert) – dieselbe Lizenz wie
die App, die Einbettung ist damit zulässig; Änderungen sind hier und in den
Code-Kommentaren („Fork: …“) vermerkt.

**Warum:** Die Prüfung vom 27.10.26 fand Fehler, die sich nur in der
Bibliothek selbst beheben lassen (Login-Ablauf, Verschlüsselung, Parser,
Datenbank-Verbindung). Die Umgehungen in der App (`lib/fork/…`, z. B.
`session_guard.dart`, `db_wal.dart`) bleiben gültig und bestehen weiter.

**Einbindung:** `pubspec.yaml` der App: `liblanis: {path: packages/liblanis}`.
Die öffentliche Schnittstelle ist gleich geblieben (Ausnahme:
`LanisSession.parseAccountType` liefert jetzt `AccountType?`; neu ist
`LanisSession.loginFailure`). Die Paket-eigenen Tests waren im pub-Paket nicht
enthalten; die Tests der Änderungen stehen in der App unter
`test/fork/liblanis_fork_test.dart`. `flutter analyze` der App prüft das Paket
mit (eigene `analysis_options.yaml`). Kein `pub get` im Paketordner nötig.

**Commits:** 1. unveränderte Kopie, 2. nur `dart format`, 3. Korrekturen –
so zeigt `git diff` gegen Commit 2 genau die Änderungen.

## Änderungen (Befund-Nummern der Prüfung 27.10.26)

| Befund | Datei | Änderung |
|---|---|---|
| 2 | `session/session.dart` `getLoginURL` | Login-Dio: Verbindung 8 s, Empfang 30 s (vorher 8 s), Senden 60 s (vorher keins) – wie `lib/fork/session_guard.dart`. |
| 3 | `session/session.dart` `authenticate` | Neuanmeldung je Sitzung „single flight“: gleichzeitige Aufrufer warten auf dieselbe Anmeldung und bekommen deren Ergebnis; `sendTimeout` zählt als `NoConnectionException`. |
| 3 | `session/cryptor.dart` `initialize` | Neuer Schlüssel erst nach bestätigtem Handshake; unlesbare Challenge → `EncryptionCheckFailedException`. |
| 4 | `applets/applet_parser.dart` | Schon in 0.1.4 behoben (gescheiterte Neuanmeldung → Status `error`); nur Test ergänzt. |
| 5 | `session/session.dart` `preventLogout` | Schon in 0.1.4 behoben (wirft nicht mehr); nur Test ergänzt. |
| 6 | `session/session.dart` `loginFailure` | „Falsches Passwort“ nur noch, wenn das Anmeldeformular zurückkommt oder „fehlgeschlagen“ dasteht; Wartungsseite → `LanisDownException`, sonst `UnknownException`. |
| 9 | `applets/lessons/student_parser.dart` `getDetailedCourseView` | Fehlende `#marks`/`#klausuren`, Überschrift ohne `<small>`, Lehrkraft ohne Namensliste, kurze Anwesenheitszeilen werden toleriert; Kommentar nur aus einer echten Kommentarzeile, „:“ im Kommentar bleiben erhalten. |
| 10 | `session/cryptor.dart` | Längen-/Kennungsprüfung vor dem Zerschneiden, kein `!` mehr; ein kaputtes `<encoded>` bleibt stehen (Protokoll `liblanis.cryptor`), statt die ganze Seite scheitern zu lassen. |
| 11 | `session/session.dart` `parseUserData`/`parseAccountType` | Ungewöhnliche Zeilen überspringen; unbekannte Kontoart → `null` statt Absturz. |
| 12 | `database/database.dart` `open` | Bis zu 5 s auf Sperren warten (eigener Busy-Handler, da `PRAGMA busy_timeout` im mitgelieferten SQLite gemessen viel zu kurz wartet). |
| 13 | `models/calendar_event.dart` | `parseStrict` statt `parse` – Zeiten ohne Sekunden und ISO-Zeiten werden nicht mehr zu 00:00; ISO mit Zeitzone → Ortszeit. |

Die übrigen Befundnummern der Prüfung (1, 7, 8) waren nicht Teil dieser
Runde.
- 28.10.26: `Homework.isPlaceholder` – „-“, „keine HA“ u. Ä. gelten nicht als Hausaufgabe (getHome, getDetailedCourseView).
