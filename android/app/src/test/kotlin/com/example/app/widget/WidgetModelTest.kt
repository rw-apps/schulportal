package com.example.app.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate
import java.time.LocalTime

/**
 * Regeln des Startbildschirm-Widgets (Entwurf 5, Abnahme 28.10.26) ohne
 * Android: Lesen der Datei (Version 2 und noch Version 1), Reihenfolge der
 * Kacheln, Stufen, kompakte Zellen. Erfundene Kinder (Jonas, Lena, Tom, Mia).
 */
class WidgetModelTest {
    // Mittwoch, 28.10.2026, 9:00.
    private val today = LocalDate.of(2026, 10, 28)
    private val nine = LocalTime.of(9, 0)

    private val labels = """
        "labels": {"today": "heute", "tomorrow": "morgen",
          "weekdays": ["Mo","Di","Mi","Do","Fr","Sa","So"],
          "weekdaysLong": ["Montag","Dienstag","Mittwoch","Donnerstag","Freitag","Samstag","Sonntag"],
          "calmTitle": "Nach Plan", "calmText": "und morgen", "calmShort": "nach Plan",
          "calmAnd": "und %s", "stale": "Stand %s", "staleText": "App öffnen",
          "homeworkOpen": "offen", "dueFor": "für %s", "exam": "Arbeit", "meal": "Essen"}
    """

    private fun v2(kids: String, extra: String = "") = """
        {"v": 2, "kids": [$kids], "dates": {"2026-10-28": "Mi, 28. Okt."}, $labels $extra}
    """

    private val jonas = """
        {"account": 1, "name": "Jonas", "color": 0, "stand": "2026-10-28T07:52:00.000",
         "items": [
           {"date": "2026-10-28", "kind": "change", "title": "Mathe", "what": "Vertretung", "word": "Vertretung", "slot": "1.", "end": "08:45"},
           {"date": "2026-10-28", "kind": "change", "title": "Mathe", "what": "Vertretung", "word": "Vertretung", "slot": "3.", "end": "10:40"},
           {"date": "2026-10-29", "kind": "cancel", "title": "Deutsch", "what": "fällt aus", "word": "fällt aus", "slot": "1.–2.", "end": "09:35"}
         ],
         "hw": 2, "hwText": "2 Aufgaben", "hwDue": "2026-10-29",
         "exam": {"date": "2026-11-02", "subject": "Mathe", "kind": "Lernkontrolle"},
         "meal": {"date": "2026-10-28", "name": "Gnocchi"}}
    """
    private val lena = """
        {"account": 2, "name": "Lena", "color": 1, "stand": "2026-10-27T18:05:00.000",
         "items": [{"date": "2026-10-28", "kind": "room", "title": "Bio", "what": "Raum R310", "word": "Raumwechsel", "slot": "6.", "end": "13:20"}]}
    """
    private val tom = """{"account": 3, "name": "Tom", "color": 2, "items": [], "exam": {"date": "2026-10-29", "subject": "Englisch", "kind": ""}}"""
    private val mia = """{"account": 4, "name": "Mia", "color": 3, "items": [], "exam": {"date": "2026-11-12", "subject": "Bio", "kind": "Test"}}"""

    @Test
    fun ordnetKachelnNachEntwurf5() {
        val p = WidgetModel.parse(v2(jonas))!!
        val tiles = WidgetModel.tilesFor(p.kids[0], p.labels, today, nine, withMeal = true)
        // 1. Stunde ist um 9:00 vorbei; dann heute vor morgen, Arbeit,
        // Aufgaben, Essen.
        assertEquals(
            listOf(
                Tile(TileKind.CHANGE, "Mathe", "Vertretung", "heute 3."),
                Tile(TileKind.CANCEL, "Deutsch", "fällt aus", "morgen 1.–2."),
                Tile(TileKind.EXAM, "Mathe", "Lernkontrolle", "Montag"),
                Tile(TileKind.HOMEWORK, "2 Aufgaben", "offen", "für morgen"),
                Tile(TileKind.MEAL, "Essen", "Gnocchi", "heute"),
            ),
            tiles,
        )
        // Essen nur, wenn verlangt (groß, ein Kind).
        assertEquals(4, WidgetModel.tilesFor(p.kids[0], p.labels, today, nine, withMeal = false).size)
    }

    @Test
    fun ruhigeKachelOhneAbweichung() {
        val p = WidgetModel.parse(v2(tom))!!
        val tiles = WidgetModel.tilesFor(p.kids[0], p.labels, today, nine, false)
        assertEquals(Tile(TileKind.CALM, "Nach Plan", "heute", "und morgen"), tiles[0])
        // Arbeit ohne Art: das Wort „Arbeit“.
        assertEquals(Tile(TileKind.EXAM, "Englisch", "Arbeit", "morgen"), tiles[1])
        // Nach Ende der letzten Stunde wird auch Lena ruhig.
        val l = WidgetModel.parse(v2(lena))!!
        assertEquals(TileKind.CALM, WidgetModel.tilesFor(l.kids[0], l.labels, today, LocalTime.of(14, 0), false)[0].kind)
    }

    @Test
    fun stufenNachZahlDerKinder() {
        assertEquals(Tier.ONE, WidgetModel.tier(1))
        assertEquals(Tier.TWO, WidgetModel.tier(2))
        assertEquals(Tier.MANY, WidgetModel.tier(3))
        assertEquals(Tier.MANY, WidgetModel.tier(5))
        val p = WidgetModel.parse(v2("$jonas,$lena,$tom,$mia", """, "hwTotal": "2 Aufgaben""""))!!
        assertEquals(listOf("Jonas", "Lena", "Tom", "Mia"), p.kids.map { it.name })
        assertEquals("2 Aufgaben", p.homeworkTotal)
    }

    @Test
    fun kompakteZelleNenntDieArtImKlartext() {
        val p = WidgetModel.parse(v2("$jonas,$lena,$tom"))!!
        val l = p.labels
        assertEquals(Cell(TileKind.CHANGE, "Jonas · Mathe", "Vertretung heute"), WidgetModel.cellFor(p.kids[0], l, today, nine, true))
        // Raumwechsel: das Wort, nicht der Raum.
        assertEquals(Cell(TileKind.ROOM, "Lena · Bio", "Raumwechsel heute"), WidgetModel.cellFor(p.kids[1], l, today, nine, true))
        assertEquals(Cell(TileKind.CALM, "Tom", "nach Plan"), WidgetModel.cellFor(p.kids[2], l, today, nine, true))
        assertEquals(Cell(TileKind.CHANGE, "Jonas", "Vertretung"), WidgetModel.cellFor(p.kids[0], l, today, nine, false))
    }

    @Test
    fun fusszeileArbeitenNachTag() {
        val p = WidgetModel.parse(v2("$jonas,$lena,$tom,$mia"))!!
        // Mia (12.11.) liegt jenseits von 7 Tagen.
        assertEquals("morgen Tom, Mo Jonas", WidgetModel.examLine(p.kids, p.labels, today))
    }

    @Test
    fun standIstDerAeltesteAbruf() {
        val p = WidgetModel.parse(v2("$jonas,$lena"))!!
        val stand = WidgetModel.standOf(p.kids)!!
        assertEquals("Di 18:05", WidgetModel.standText(stand, p.labels, today))
        assertEquals("Mi, 28. Okt.", WidgetModel.headDay(p, today))
    }

    @Test
    fun liestNochVersion1() {
        // Datei aus Entwurf 4 (9437/9438): ein Kind, ohne „kids“.
        val raw = """
            {"v": 1, "account": 3, "kid": 1, "name": "Lena", "stand": "2026-10-28T07:52:00.000",
             "items": [{"date": "2026-10-28", "kind": "cancel", "title": "Sport", "what": "fällt aus", "slot": "5.–6. Std.", "end": "13:20", "detail": "Schluss 11:30"}],
             "homework": "2 Aufgaben", "exam": {"date": "2026-10-29", "label": "Test"},
             "labels": {"today": "heute", "tomorrow": "morgen", "weekdays": ["Mo","Di","Mi","Do","Fr","Sa","So"],
                        "calmTitle": "Alles nach Plan", "calmText": "heute und morgen"}}
        """
        val p = WidgetModel.parse(raw)
        assertNotNull(p)
        p!!
        assertEquals(1, p.version)
        assertEquals(1, p.kids.size)
        val kid = p.kids[0]
        assertEquals("Lena", kid.name)
        assertEquals(1, kid.color)
        val tiles = WidgetModel.tilesFor(kid, p.labels, today, nine, false)
        assertEquals(Tile(TileKind.CANCEL, "Sport", "fällt aus", "heute 5.–6. Std."), tiles[0])
        // Version 1: „label“ ist die Art; ohne Wort „Arbeit“ bleibt Zeile 2 leer.
        assertEquals(Tile(TileKind.EXAM, "Test", "", "morgen"), tiles[1])
        assertEquals(Tile(TileKind.HOMEWORK, "2 Aufgaben", "", ""), tiles[2])
        assertEquals(Cell(TileKind.CANCEL, "Lena", "fällt aus"), WidgetModel.cellFor(kid, p.labels, today, nine, false))
        // Ruhig in Version 1: eine Zeile „heute und morgen“.
        val calm = WidgetModel.tilesFor(kid, p.labels, today, LocalTime.of(14, 0), false)[0]
        assertEquals(Tile(TileKind.CALM, "Alles nach Plan", "heute und morgen", ""), calm)
        assertEquals("2 Aufgaben", p.homeworkTotal)
    }

    @Test
    fun kaputteDateiGibtNichts() {
        assertNull(WidgetModel.parse(null))
        assertNull(WidgetModel.parse("{kaputt"))
        assertEquals(0, WidgetModel.parse("""{"v": 2}""")!!.kids.size)
    }

    @Test
    fun reihenPassenInDieHoehe() {
        assertEquals(3, WidgetModel.rowsThatFit(null, 60f, 6f, 3))
        assertEquals(1, WidgetModel.rowsThatFit(100f, 60f, 6f, 3))
        assertEquals(2, WidgetModel.rowsThatFit(126f, 60f, 6f, 3))
        assertEquals(3, WidgetModel.rowsThatFit(500f, 60f, 6f, 3))
        assertEquals(1, WidgetModel.rowsThatFit(10f, 60f, 6f, 2))
    }

    private fun kid(stand: String?, extra: String = "") = WidgetModel.parse(
        v2("""{"account": 5, "name": "Mia", "color": 3, ${if (stand == null) "" else "\"stand\": \"$stand\","} "items": [] $extra}"""),
    )!!

    @Test
    fun veralteterStandStattRuhigerKachel() {
        // Abruf Montag 26.10. deckt Montag und Dienstag; am Mittwoch veraltet.
        val p = kid("2026-10-26T18:05:00.000")
        val k = p.kids[0]
        assertEquals(Tile(TileKind.STALE, "Stand Mo 18:05", "App öffnen", ""), WidgetModel.tilesFor(k, p.labels, today, nine, false)[0])
        assertEquals(Cell(TileKind.STALE, "Mia", "Stand Mo 18:05"), WidgetModel.cellFor(k, p.labels, today, nine, false))
        // Abruf Dienstag deckt heute (Mittwoch), aber nicht morgen: ohne „und morgen“.
        val q = kid("2026-10-27T18:05:00.000")
        assertEquals(Tile(TileKind.CALM, "Nach Plan", "heute", ""), WidgetModel.tilesFor(q.kids[0], q.labels, today, nine, false)[0])
        assertEquals(Cell(TileKind.CALM, "Mia", "nach Plan"), WidgetModel.cellFor(q.kids[0], q.labels, today, nine, false))
        // Abruf heute: ruhig mit „und morgen“; ohne Stand (unbekannt) ebenso.
        val r = kid("2026-10-28T07:00:00.000")
        assertEquals(Tile(TileKind.CALM, "Nach Plan", "heute", "und morgen"), WidgetModel.tilesFor(r.kids[0], r.labels, today, nine, false)[0])
        val u = kid(null)
        assertEquals(TileKind.CALM, WidgetModel.tilesFor(u.kids[0], u.labels, today, nine, false)[0].kind)
        // Freitagabend abgerufen: Montag ist noch abgedeckt, Dienstag nicht.
        val fri = kid("2026-10-30T18:05:00.000")
        assertEquals(TileKind.CALM, WidgetModel.tilesFor(fri.kids[0], fri.labels, LocalDate.of(2026, 11, 2), nine, false)[0].kind)
        assertEquals(
            Tile(TileKind.STALE, "Stand Fr 18:05", "App öffnen", ""),
            WidgetModel.tilesFor(fri.kids[0], fri.labels, LocalDate.of(2026, 11, 3), nine, false)[0],
        )
    }

    @Test
    fun undNaechsterSchultagStattUndMorgen() {
        val p = kid("2026-10-30T07:00:00.000")
        val k = p.kids[0]
        fun third(d: LocalDate) = WidgetModel.tilesFor(k, p.labels, d, nine, false)[0].l3
        assertEquals("und Montag", third(LocalDate.of(2026, 10, 30)))
        assertEquals("und Montag", third(LocalDate.of(2026, 10, 31)))
        assertEquals("und morgen", third(LocalDate.of(2026, 11, 1)))
        assertEquals(LocalDate.of(2026, 11, 2), WidgetModel.nextSchoolDay(LocalDate.of(2026, 10, 30)))
        assertEquals(LocalDate.of(2026, 10, 29), WidgetModel.nextSchoolDay(today))
        // Datei vor 28.10.26 ohne „calmAnd“: „und morgen“ nur, wenn es stimmt.
        val old = WidgetModel.parse(
            v2("""{"account": 5, "name": "Mia", "stand": "2026-10-30T07:00:00.000", "items": []}""").replace("\"calmAnd\": \"und %s\",", ""),
        )!!
        assertEquals("", WidgetModel.tilesFor(old.kids[0], old.labels, LocalDate.of(2026, 10, 30), nine, false)[0].l3)
    }

    @Test
    fun arbeitUndFristNurMitEindeutigemWochentag() {
        // Mittwoch: Arbeit am Mittwoch in einer Woche hieße „Mittwoch“ wie heute.
        val p = kid(
            "2026-10-28T07:00:00.000",
            """, "exam": {"date": "2026-11-04", "subject": "Bio", "kind": "Test"}, "hwText": "1 Aufgabe", "hwDue": "2026-11-04"""",
        )
        val tiles = WidgetModel.tilesFor(p.kids[0], p.labels, today, nine, false)
        assertEquals(listOf(TileKind.CALM, TileKind.HOMEWORK), tiles.map { it.kind })
        assertEquals("", tiles[1].l3)
        assertEquals("", WidgetModel.examLine(p.kids, p.labels, today))
        // Einen Tag früher (Dienstag, 6 Tage): mit Wochentag.
        val q = kid(
            "2026-10-28T07:00:00.000",
            """, "exam": {"date": "2026-11-03", "subject": "Bio", "kind": "Test"}, "hwText": "1 Aufgabe", "hwDue": "2026-11-03"""",
        )
        val t2 = WidgetModel.tilesFor(q.kids[0], q.labels, today, nine, false)
        assertEquals(Tile(TileKind.EXAM, "Bio", "Test", "Dienstag"), t2[1])
        assertEquals("für Dienstag", t2[2].l3)
        assertEquals("Di Mia", WidgetModel.examLine(q.kids, q.labels, today))
    }

    @Test
    fun zweiKinderKleinPassenOderKompakt() {
        // Name 18, Kachel 60, Abstand 8: braucht 2 × 78 + 8 = 164.
        assertEquals(true, WidgetModel.twoKidsFit(null, 18f, 60f, 8f))
        assertEquals(true, WidgetModel.twoKidsFit(164f, 18f, 60f, 8f))
        assertEquals(false, WidgetModel.twoKidsFit(150f, 18f, 60f, 8f))
    }
}
