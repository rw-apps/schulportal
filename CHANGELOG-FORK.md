## Schulportal (rw-apps) – Änderungen gegenüber Lanis-Mobile

**4.1.0+9309**

- Behoben: Beim Elternkonto zeigte „Stundenplan“ nur einen Fehlerhinweis. Die Navigation sprang noch auf den Pfad für Schülerkonten.

**4.1.0+9308**

- Debug-Export: neuer Punkt „Mein Unterricht: Kursseiten“, öffnet die ersten zwei Kurse nur lesend. Nötig, um Hausaufgaben und Kurse für Elternkonten zu bauen.

**4.1.0+9307**

- Neu für Elternkonten: **Stundenplan** des Kindes (bisher nur für Schülerkonten).

**4.1.0+9306**

- Debug-Export fragt nur noch Module ab, die die Schule freigeschaltet hat. Ruft man ein anderes auf, beendet das Portal die Anmeldung, und alle weiteren Abfragen wären leer gewesen.
- Neuer Export-Punkt „Abwesenheiten“ (Krankmeldung), nur die Ansicht, es wird nichts abgeschickt.
- Zurückgenommen: die Cookie-Korrektur aus 4.1.0+9305. Der Export hat gezeigt, dass das Portal die Sitzung absichtlich beendet und keinen Schlüssel austauscht; die Korrektur war wirkungslos.

**4.1.0+9305**

- Debug-Export schwärzt den Sitzungsschlüssel und prüft die Anmeldung auch nach allen Abfragen.
- (Zurückgenommen in 9306: vermutete Korrektur zum Sitzungsschlüssel, sie war wirkungslos.)

**4.1.0+9304**

- Debug-Export prüft vorab, ob die Anmeldung beim Portal noch gilt, und meldet sich bei Bedarf einmal neu an. Das Ergebnis steht im Export, ohne Sitzungsschlüssel.

**4.1.0+9303**

- Debug-Export um die „App-Übersicht der Schule“ ergänzt: Sie zeigt, welche Portal-Module die Schule freigeschaltet hat (z. B. Krankmeldung).

**4.1.0+9302**

- Debug-Export wieder erreichbar: jetzt direkt unter Einstellungen, statt wie bisher über die entfernte Seite „Fehlerberichte“.

**Erste Fassung (Basis Lanis-Mobile 4.1.0)**

- Eigener Name „Schulportal“ und eigene App-ID. Die App läuft neben dem Original und ersetzt es nicht.
- Keine Login-Statistik mehr an Server der Original-Entwickler.
- Keine automatischen Fehlerberichte; Einstellung und Login-Häkchen sind entfernt.
- Update-Hinweise, Quellcode- und Fehler-Links zeigen auf dieses Repository.
- Absturzbericht per Mail-Entwurf ohne festen Empfänger, nicht öffentlich.
- Gegenüber dem Schulportal meldet sich die App mit eigenem Namen.
- Eigener Datenschutzhinweis: PRIVACY.md.
