## Schulportal (rw-apps) – Änderungen gegenüber Lanis-Mobile

**4.1.0+9321**

- Gruppen werden automatisch vorgewählt, wenn „Mein Unterricht“ sie verrät. Projekt Text: Der Kurs nennt zwei Lehrkräfte, beide stehen in jeder TXT-Stunde – die App zeigt beide als eine Stunde. Ändern über das Tauschen-Symbol; die Wahl ist mit „Erkannt über den Kurs in „Mein Unterricht““ markiert.
- Fachnamen: TXT = „Projekt Text“ (nur Schule A), ÄSTH = „Ästhetik“, KL = „Klassenstunde“.
- Schriftgröße in der Vorschau unter „Mehr“: Normal / Groß / Sehr groß, alle Stufen größer als bisher.
- Lehrernamen fett.
- Unbekannte Kürzel lassen sich benennen: Stunde antippen → „Name für …“. Die Namen bleiben nur auf diesem Gerät, je Konto.
- Titel „Stundenplan“ bricht bei großer Schrift nicht mehr mitten im Wort um.

**4.1.0+9320**

- Vorschau „Plan“ zeigt jetzt den **echten Stundenplan** des angemeldeten Kontos (Einstellungen → „Neue Oberfläche (Vorschau)“ → Plan). „Heute“ bleibt vorerst mit Beispieldaten.
- Lehrkräfte mit Namen aus „Mein Unterricht“, Fächer ausgeschrieben, wo das Kürzel eindeutig ist (sonst bleibt das Kürzel, z. B. TXT).
- Doppelbesetzung (gleiches Fach, gleicher Raum, zwei Lehrkräfte) wird eine Stunde; nur echte Parallelgruppen erscheinen unter „Gruppe wählen“.
- Die Gruppenwahl wird je Konto gespeichert.

**4.1.0+9319**

- Krankmeldung: neuer Knopf **„Beim Portal prüfen (sendet nichts)“**. Das Portal sagt, ob es die Meldung annehmen würde, oder nennt seine Gründe. Es wird nichts gespeichert, die Schule sieht davon nichts.
- Absenden bleibt gesperrt.

**4.1.0+9318**

- Krankmeldung wie im Portal: „Abwesend“ = Von- und Bis-Tag ohne Blöcke, „Verspätet“ = ein Tag („Am“) mit Block von–bis.
- Kommentarfeld zeigt die Warnung des Portals „Bitte keine Gesundheitsdaten eingeben“.
- Bestehende Meldungen der Schule erscheinen unter der Maske.
- Abschicken bleibt gesperrt, bis es ausdrücklich freigegeben ist.

**4.1.0+9317**

- Wochenansicht: Zeilen höchstens 72 dp hoch; bei wenigen Blöcken (Schule A) nicht mehr aufgebläht, unten bleibt Platz frei.
- Lehrkräfte ausgeschrieben statt Kürzel: Tagesansicht und Gruppenwahl mit Vor- und Nachname, Wochenraster mit Nachname. Die Namen kommen später aus „Mein Unterricht“; wer dort nicht vorkommt (z. B. Vertretung), bleibt als Kürzel.

**4.1.0+9316**

- Vorschau: Inhalte laufen nicht mehr unter die untere Leiste, sie enden darüber.
- Wochenansicht neu: Die ganze Woche passt ohne Scrollen auf den Bildschirm, Zeilenhöhe nach freiem Platz. Breitere Zellen mit lesbaren Fachnamen, Raum und Lehrkraft. Pausen als sichtbare Lücke, heutige Spalte hinterlegt mit Jetzt-Linie. Jedes Fach eines Kindes bekommt eine eigene Farbe.
- „Gruppe wählen“ nur noch als eine Zeile über dem Plan.

**4.1.0+9315**

- Vorschau „Plan“ im neuen Stil: je Kind umschaltbar, Tagesansicht (Uhrzeit links, laufende Stunde mit Fortschritt, Vertretung/Ausfall farbig, Pausen) und Wochenraster (Doppelstunden als ein Block, Farbe je Fach, Tag antippen öffnet ihn).
- Neu: **Gruppe wählen** bei Parallelgruppen (z. B. vier Textil-Gruppen oder Religion/Ethik). Einmal je Fach gewählt, zeigt der Plan nur noch die eigene Gruppe – statt jede Kachel einzeln auszublenden.

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
