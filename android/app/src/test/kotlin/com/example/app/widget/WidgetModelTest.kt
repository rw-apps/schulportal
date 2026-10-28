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

    // Maßstab für Tablets (Foto Tablet 28.10.26). Bedarf groß mit zwei
    // Kindern bei Schrift 1: Kopf 22,4 + 2 × (2 × 59,2 + 6) + 8 + Rand 28
    // = 307,2 dp; mittel: 22,4 + 59,2 × 2 + 8 + 28 = 176,8 dp.

    @Test
    fun telefonMasseWieBisher() {
        val m = WidgetMetrics(1f, 1f)
        assertEquals(14.4f, m.line, 0.001f)
        assertEquals(3 * 14.4f + 16f, m.tileH, 0.001f)
        assertEquals(14.4f + 8f, m.headH, 0.001f)
        assertEquals(14.4f + 4f, m.nameH, 0.001f)
        assertEquals(2 * 14.4f + 8f, m.cellH, 0.001f)
        assertEquals(28f, m.pad, 0.001f)
        assertEquals(307.2f, WidgetScale.neededHeight(WidgetSize.LARGE, 2, 1f), 0.01f)
        assertEquals(176.8f, WidgetScale.neededHeight(WidgetSize.MEDIUM, 2, 1f), 0.01f)
    }

    @Test
    fun massstabAufTelefonenImmerEins() {
        val need = WidgetScale.neededHeight(WidgetSize.LARGE, 2, 1f)
        // Pixel 9a hochkant 4 × 3 und quer; auch groß gezogen bleibt es 1.
        assertEquals(1f, WidgetScale.scale(false, Area(370f, 430f), 360f, need), 0f)
        assertEquals(1f, WidgetScale.scale(false, Area(700f, 250f), 360f, need), 0f)
        assertEquals(1f, WidgetScale.scale(false, Area(1000f, 1000f), 360f, need), 0f)
        // Tablet, aber Fläche nicht größer als am Telefon: 1, nie kleiner.
        assertEquals(1f, WidgetScale.scale(true, Area(300f, 200f), 360f, need), 0f)
        assertEquals(1f, WidgetScale.scale(true, Area(370f, 900f), 360f, need), 0f)
        // Fläche unbekannt.
        assertEquals(1f, WidgetScale.scale(true, null, 360f, need), 0f)
        assertEquals(1f, WidgetScale.scale(true, Area(850f, null), 360f, need), 0f)
    }

    @Test
    fun massstabAufTabletsNachBreiteUndHoehe() {
        val large = WidgetScale.neededHeight(WidgetSize.LARGE, 2, 1f)
        // Foto: zwei Drittel der Breite, halbe Höhe eines Tablets quer.
        // Die Höhe begrenzt: 400 / 307,2 = 1,302 → 1,30.
        assertEquals(1.30f, WidgetScale.scale(true, Area(850f, 400f), 360f, large), 0.001f)
        // Die Breite begrenzt: 540 / 360 = 1,5.
        assertEquals(1.5f, WidgetScale.scale(true, Area(540f, 900f), 360f, large), 0.001f)
        // Höchstens doppelt: mittel 850 × 400 ergäbe 2,26.
        val medium = WidgetScale.neededHeight(WidgetSize.MEDIUM, 2, 1f)
        assertEquals(2f, WidgetScale.scale(true, Area(850f, 400f), 360f, medium), 0f)
        assertEquals(2f, WidgetScale.scale(true, Area(2000f, 2000f), 360f, large), 0f)
        // Größere Systemschrift braucht mehr Höhe → kleinerer Maßstab.
        val big = WidgetScale.neededHeight(WidgetSize.LARGE, 2, 1.3f)
        assertEquals(true, WidgetScale.scale(true, Area(850f, 400f), 360f, big) < 1.30f)
        // Klein (zwei Zellen breit): Bezug 180 dp.
        assertEquals(180f, WidgetScale.referenceWidth(WidgetSize.SMALL), 0f)
        assertEquals(360f, WidgetScale.referenceWidth(WidgetSize.LARGE), 0f)
    }

    @Test
    fun flaecheNachLage() {
        // Hochkant minWidth × maxHeight, quer maxWidth × minHeight.
        assertEquals(Area(300f, 400f), WidgetScale.area(false, 300, 500, 200, 400))
        assertEquals(Area(500f, 200f), WidgetScale.area(true, 300, 500, 200, 400))
        // 0 = nicht gemeldet.
        assertEquals(Area(null, null), WidgetScale.area(false, 0, 500, 200, 0))
        assertEquals(Area(500f, null), WidgetScale.area(true, 0, 500, 0, 400))
    }

    @Test
    fun zweiKinderMehrReihenNurAufTablets() {
        val one = WidgetMetrics(1f, 1f)
        // Telefon: groß 2, mittel 1 – auch mit viel Höhe.
        assertEquals(2, WidgetScale.twoKidRows(WidgetSize.LARGE, false, 900f, one))
        assertEquals(1, WidgetScale.twoKidRows(WidgetSize.MEDIUM, false, 900f, one))
        // Telefon zu niedrig: groß fällt auf 1.
        assertEquals(1, WidgetScale.twoKidRows(WidgetSize.LARGE, false, 200f, one))
        // Höhe unbekannt: Telefonzahl, auch auf Tablets.
        assertEquals(2, WidgetScale.twoKidRows(WidgetSize.LARGE, true, null, one))
        assertEquals(1, WidgetScale.twoKidRows(WidgetSize.MEDIUM, true, null, one))
        // Tablet mit Platz: groß 3 (22,4 + 2 × 189,6 + 8 = 409,6), mittel 2.
        assertEquals(3, WidgetScale.twoKidRows(WidgetSize.LARGE, true, 410f, one))
        assertEquals(2, WidgetScale.twoKidRows(WidgetSize.LARGE, true, 409f, one))
        assertEquals(2, WidgetScale.twoKidRows(WidgetSize.MEDIUM, true, 400f, one))
        // Foto: Maßstab 1,30, Inhalt 400 − 28 × 1,3 = 363,6 dp: zwei Reihen
        // passen gerade (362,96), drei nicht.
        val photo = WidgetMetrics(1f, 1.3f)
        assertEquals(2, WidgetScale.twoKidRows(WidgetSize.LARGE, true, 400f - photo.pad, photo))
    }
}
