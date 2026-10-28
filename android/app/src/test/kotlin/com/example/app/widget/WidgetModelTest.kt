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
}
