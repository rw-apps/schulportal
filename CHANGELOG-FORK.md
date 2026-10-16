## Schulportal (rw-apps) – Änderungen gegenüber Lanis-Mobile

**4.1.0+9314**

- Vorschau „Heute“ im neuen Stil (Entwurf A + C): Begrüßung, Wochenleiste mit Terminpunkten, Kasten „Wichtig heute und morgen“ für alle Kinder, je Kind eine Karte mit „Jetzt“ und Restzeit, Tagesleiste und aufklappbarem Tag (Doppelstunden zusammengefasst, längere Pausen sichtbar), „Demnächst“ als Kacheln, schwebende Leiste unten.
- Eigene Schrift (Manrope), fest eingebaut; hell und dunkel nach Handy-Einstellung.
- Behoben (nur Vorschau): Datumsrechnung über die Zeitumstellung, Leiste bei großer Systemschrift.

**4.1.0+9313**

- Neu: **Vorschau der neuen Oberfläche** unter Einstellungen → „Neue Oberfläche (Vorschau)“. Erster Entwurf der Seite „Heute“: je Kind eine Karte (laufende und nächste Stunde, Vertretungen und Ausfälle, Hausaufgaben, Nachrichten, Krankmeldung) und darunter „Demnächst“ für alle Kinder. Nur erfundene Beispieldaten, keine Abfragen beim Portal.
- Neue untere Leiste im Entwurf: Heute · Plan · Nachrichten · Termine · Mehr (die übrigen Ziele folgen nach Abnahme).

**4.1.0+9312**

- Behoben: Die Krankmeldung ließ sich nicht ganz nach unten scrollen; der letzte Knopf lag halb unter der Navigationsleiste.

**4.1.0+9311**

- Neu für Elternkonten: **Krankmeldung** im Menü, wenn die Schule das Modul anbietet. Die Maske übernimmt Kind, Art (abwesend/verspätet), Blöcke und die erlaubten Tage direkt vom Portal und prüft die Eingaben.
- Abschicken ist noch gesperrt, bis wir es gemeinsam getestet haben. „Vorschau der Portal-Felder“ zeigt, was gesendet würde.
- Debug-Export „Abwesenheiten“ liest zusätzlich das Portal-Skript der Seite (nur lesen). Daraus geht hervor, wie das Portal die Meldung abschickt.

**4.1.0+9310**

- Neu für Elternkonten: **Unterricht**, also die Kurse des Kindes mit aktuellen Einträgen, Kursseiten und Anwesenheiten. Bei mehreren Kindern an einer Schule steht der Vorname vor dem Kurs.
- Eltern sehen den Hausaufgaben-Stand, abhaken kann ihn nur das Kind. Abgaben gibt es im Elternkonto nicht.

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
