package com.example.app.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * Regeln des Startbildschirm-Widgets, Entwurf 10 (Abnahme 30.10.26), ohne
 * Android: Datei Version 3, gezeigter Tag, Zeitraum-Text, Symbole, Größen,
 * Auswahl je Widget, „veraltet“, Wecker. Erfundene Kinder (Jonas, Lena, Mia,
 * Tom) und erfundene Zeiten.
 */
class WidgetModelTest {
    // Montag, 2.11.2026.
    private val mon = LocalDate.of(2026, 11, 2)
    private fun at(h: Int, m: Int = 0, d: LocalDate = mon) = d.atTime(h, m)

    private val labels = """
        "labels": {"today": "HEUTE",
          "weekdaysLong": ["MONTAG","DIENSTAG","MITTWOCH","DONNERSTAG","FREITAG","SAMSTAG","SONNTAG"],
          "weekdays": ["Mo","Di","Mi","Do","Fr","Sa","So"],
          "from": "ab %s", "until": "bis %s", "range": "%1${'$'}s–%2${'$'}s", "slot": "%s Std.",
          "off": "frei", "stale": "Stand %s", "staleText": "App öffnen",
          "exam": "Arbeit", "homework": "Aufgaben", "homeworkN": ["1 Aufgabe", "%d Aufgaben"],
          "meal": "Essen", "mealOrder": "Essen bestellen", "balance": "Guthaben aufladen",
          "sub": "Vertretung", "subAt": "Vertretung %s", "room": "Raum", "roomAt": "Raum %s",
          "more": "+%d nach Plan",
          "cdCancel": "Ausfall", "cdExam": "Arbeit", "cdHomework": "Hausaufgaben", "cdMeal": "Essen",
          "cdSub": "Vertretung", "cdRoom": "Raumwechsel",
          "configTitle": "Kinder im Widget", "configAll": "Alle Kinder", "configOk": "Fertig"}
    """

    /** Schultag mit Uhrzeiten; Abweichungen über die Parameter. */
    private fun day(
        date: LocalDate,
        start: String = "08:00",
        end: String = "13:45",
        planStart: String = "08:00",
        planEnd: String = "13:45",
        mid: String = "",
        subs: String = "",
        rooms: String = "",
        allOff: Boolean = false,
    ): String {
        val times = if (allOff) "" else """"start": "$start", "end": "$end", """
        return """{"date": "$date", "timed": true, $times "planStart": "$planStart", "planEnd": "$planEnd",
            "startSlot": "1.", "endSlot": "6.", "planStartSlot": "1.", "planEndSlot": "6.",
            "allOff": $allOff, "mid": [$mid], "subs": [$subs], "rooms": [$rooms], "free": null}"""
    }

    /** Schultag ohne Uhrzeiten (nur Stunden). */
    private fun untimed(date: LocalDate, startSlot: String = "1.", endSlot: String = "6.") =
        """{"date": "$date", "timed": false, "startSlot": "$startSlot", "endSlot": "$endSlot",
            "planStartSlot": "1.", "planEndSlot": "6.", "allOff": false, "mid": [], "subs": [], "rooms": [], "free": null}"""

    private fun free(date: LocalDate, text: String) =
        """{"date": "$date", "timed": true, "allOff": false, "mid": [], "subs": [], "rooms": [], "free": "$text"}"""

    private fun kid(
        account: Int,
        name: String,
        days: String,
        own: Boolean = false,
        shown: Boolean = true,
        stand: String = "2026-11-02T06:30:00.000",
        hwDue: String = "",
        exams: String = "",
        mealOpen: String = "",
        lowBalance: Boolean = false,
    ) = """{"account": $account, "name": "$name", "color": ${account % 4}, "stand": "$stand", "own": $own,
        "shown": $shown, "days": [$days], "hwDue": [$hwDue], "exams": [$exams], "mealOpen": [$mealOpen],
        "lowBalance": $lowBalance}"""

    private fun file(vararg kids: String) =
        """{"v": 3, "generatedAt": "2026-11-02T06:30:00.000", "kids": [${kids.joinToString(",")}], $labels}"""

    private fun one(k: String): Pair<Kid, Labels> {
        val p = WidgetModel.parse(file(k))!!
        return p.kids[0] to p.labels
    }

    private fun view(k: String, now: LocalDateTime): KidView {
        val (kid, l) = one(k)
        return WidgetModel.view(kid, now, l)
    }

    private val tue = mon.plusDays(1)

    // ---- Datei ------------------------------------------------------------------

    @Test
    fun liestVersion3UndVerwirftAndere() {
        val p = WidgetModel.parse(file(kid(12, "Jonas", day(mon), own = true, hwDue = "\"$mon\"")))
        assertNotNull(p)
        val k = p!!.kids[0]
        assertEquals(12, k.account)
        assertTrue(k.own)
        assertEquals(1, k.days.size)
        assertNull(k.days[0].free)
        assertEquals(listOf(mon), k.hwDue)
        assertEquals("HEUTE", p.labels.today)
        // Version 2 (Entwurf 5) und Kaputtes → null (no_data).
        assertNull(WidgetModel.parse("""{"v": 2, "kids": [], "labels": {}}"""))
        assertNull(WidgetModel.parse("""{"kids": []}"""))
        assertNull(WidgetModel.parse("kein json"))
        assertNull(WidgetModel.parse(null))
    }

    // ---- Punkt 1: Tagwahl ----------------------------------------------------------

    @Test
    fun heuteSolangeDerUnterrichtLaeuft() {
        val (k, _) = one(kid(1, "Jonas", day(mon) + "," + day(tue)))
        assertEquals(mon, WidgetModel.shownDay(k, at(9))?.date)
        assertEquals(mon, WidgetModel.shownDay(k, at(13, 44))?.date)
        // Ab dem tatsächlichen Ende: nächster Schultag.
        assertEquals(tue, WidgetModel.shownDay(k, at(13, 45))?.date)
    }

    @Test
    fun tatsaechlichesEndeZaehltNichtDasGeplante() {
        val (k, _) = one(kid(1, "Jonas", day(mon, end = "11:20") + "," + day(tue)))
        assertEquals(tue, WidgetModel.shownDay(k, at(12))?.date)
    }

    @Test
    fun ganzFreiZaehltBis17Uhr() {
        val (k, _) = one(kid(1, "Lena", day(mon, allOff = true) + "," + day(tue)))
        assertEquals(mon, WidgetModel.shownDay(k, at(16, 59))?.date)
        assertEquals(tue, WidgetModel.shownDay(k, at(17))?.date)
    }

    @Test
    fun ohneUhrzeitenBis17Uhr() {
        val (k, _) = one(kid(1, "Tom", untimed(mon) + "," + untimed(tue)))
        assertEquals(mon, WidgetModel.shownDay(k, at(16))?.date)
        assertEquals(tue, WidgetModel.shownDay(k, at(17, 30))?.date)
    }

    @Test
    fun wochenendeZeigtMontag() {
        val sat = LocalDate.of(2026, 10, 31)
        val (k, l) = one(kid(1, "Mia", day(mon), stand = "2026-10-31T10:00:00.000"))
        val now = sat.atTime(10, 0)
        assertEquals(mon, WidgetModel.shownDay(k, now)?.date)
        val v = WidgetModel.view(k, now, l)
        assertEquals("MONTAG", WidgetModel.dayTag(listOf(v), sat, l))
    }

    @Test
    fun ferienTextStattZeitraum() {
        val fri = LocalDate.of(2026, 10, 30)
        val days = free(fri, "Herbstferien bis Fr 6.11.") + "," + free(mon, "Herbstferien bis Fr 6.11.") + "," +
            day(LocalDate.of(2026, 11, 9))
        val v = view(kid(1, "Jonas", days, stand = "2026-10-30T10:00:00.000"), fri.atTime(10, 0))
        assertEquals(LocalDate.of(2026, 11, 9), v.day)
        assertEquals(When("Herbstferien bis Fr 6.11.", red = false, busy = false, mid = ""), v.time)
        assertFalse(v.stale)
    }

    // ---- Punkt 2: Zeitraum ------------------------------------------------------------

    @Test
    fun zeitraumTexte() {
        val l = one(kid(1, "Jonas", day(mon))).second
        fun t(d: String, now: LocalDateTime) = view(kid(1, "Jonas", d), now).time
        // Vor dem Unterricht.
        assertEquals(When("08:00–13:45", false, false, ""), t(day(mon), at(7)))
        assertEquals(When("ab 09:50", true, true, ""), t(day(mon, start = "09:50"), at(7)))
        assertEquals(When("bis 11:20", true, true, ""), t(day(mon, end = "11:20"), at(7)))
        assertEquals(When("09:50–11:20", true, true, ""), t(day(mon, start = "09:50", end = "11:20"), at(7)))
        assertEquals(When("frei", true, true, ""), t(day(mon, allOff = true), at(7)))
        // Während des Unterrichts nur noch „bis“, rot nur bei geändertem Ende.
        assertEquals(When("bis 13:45", false, false, ""), t(day(mon), at(9)))
        assertEquals(When("bis 13:45", false, false, ""), t(day(mon, start = "09:50"), at(10)))
        assertEquals(When("bis 11:20", true, true, ""), t(day(mon, end = "11:20"), at(9)))
        // Morgen läuft noch nichts: voller Zeitraum.
        assertEquals(When("08:00–13:45", false, false, ""), t(day(tue), at(15)))
        assertEquals("HEUTE", l.today)
    }

    @Test
    fun zeitraumOhneUhrzeitenMitStunden() {
        fun t(d: String) = view(kid(1, "Tom", d), at(7)).time
        assertEquals(When("1.–6. Std.", false, false, ""), t(untimed(mon)))
        assertEquals(When("ab 3. Std.", true, true, ""), t(untimed(mon, startSlot = "3.")))
        assertEquals(When("bis 4. Std.", true, true, ""), t(untimed(mon, endSlot = "4.")))
        // Auch um 10 Uhr kein „bis“: ohne Uhrzeit kein laufender Unterricht.
        assertEquals("1.–6. Std.", view(kid(1, "Tom", untimed(mon)), at(10)).time.text)
    }

    @Test
    fun ausfallMittenOhneVergangene() {
        val mid = """{"slot": "4.", "end": "11:20"}, {"slot": "6.", "end": "13:00"}"""
        val k = kid(1, "Lena", day(mon, mid = mid) + "," + day(tue, mid = mid))
        assertEquals("4. +1", view(k, at(9)).time.mid)
        assertEquals("6.", view(k, at(12)).time.mid)
        // Der Zeitraum selbst bleibt grau (ungeändert).
        assertFalse(view(k, at(12)).time.red)
        // Morgen: nichts ist vorbei.
        val (kid, _) = one(k)
        assertEquals("4. +1", WidgetModel.midText(kid.days[1], mon, at(14).toLocalTime()))
    }

    // ---- Punkt 3: Symbole ------------------------------------------------------------------

    @Test
    fun hausaufgabenZaehlenOhneUeberfaellige() {
        val hw = listOf(mon.minusDays(1), mon, mon, tue, tue.plusDays(1)).joinToString(",") { "\"$it\"" }
        // 14 Uhr: heute vorbei → gezeigter Tag Dienstag; zählt heute bis Dienstag.
        val v = view(kid(1, "Jonas", day(mon) + "," + day(tue), hwDue = hw), at(14))
        val s = v.slots.first { it.signal == Signal.HOMEWORK }
        assertTrue(s.on)
        assertEquals("3", s.mark)
        assertEquals("3 Aufgaben", s.text)
        assertEquals("Hausaufgaben 3", s.cd)
        assertEquals(Target.HOMEWORK, s.target)
        // Eine Aufgabe: Einzahl.
        val one = view(kid(1, "Jonas", day(mon), hwDue = "\"$mon\""), at(9)).slots.first { it.signal == Signal.HOMEWORK }
        assertEquals("1 Aufgabe", one.text)
        // Nur überfällige → blass, ohne Vorlesetext.
        val old = view(kid(1, "Jonas", day(mon), hwDue = "\"${mon.minusDays(2)}\""), at(9)).slots.first { it.signal == Signal.HOMEWORK }
        assertFalse(old.on)
        assertEquals("", old.cd)
        assertEquals("Aufgaben", old.text)
    }

    @Test
    fun arbeitUndEssen() {
        val v = view(kid(1, "Lena", day(mon), exams = "\"$mon\"", mealOpen = "\"$mon\""), at(9))
        assertEquals(listOf(Signal.EXAM, Signal.HOMEWORK, Signal.MEAL), v.slots.map { it.signal })
        val exam = v.slots[0]
        assertTrue(exam.on)
        assertEquals(Target.EXAMS, exam.target)
        val meal = v.slots[2]
        assertTrue(meal.on)
        assertEquals("", meal.mark)
        assertEquals("Essen bestellen", meal.text)
        assertEquals(Target.MEAL, meal.target)
        // Guthaben niedrig: Marke „!“.
        val low = view(kid(1, "Lena", day(mon), lowBalance = true), at(9)).slots[2]
        assertTrue(low.on)
        assertEquals("!", low.mark)
        assertEquals("Guthaben aufladen", low.text)
        // Essen für einen anderen Tag: blass.
        val other = view(kid(1, "Lena", day(mon), mealOpen = "\"$tue\""), at(9)).slots[2]
        assertFalse(other.on)
        assertTrue(v.relevant)
    }

    @Test
    fun schuelerkontoVertretungUndRaum() {
        val subs = """{"slot": "1.", "end": "08:45"}, {"slot": "2.", "end": "09:35"}"""
        val rooms = """{"slot": "5.", "end": "12:10", "room": "R020"}"""
        val v = view(kid(7, "Mia", day(mon, subs = subs, rooms = rooms), own = true), at(9))
        assertEquals(listOf(Signal.EXAM, Signal.HOMEWORK, Signal.SUB, Signal.ROOM, Signal.MEAL), v.slots.map { it.signal })
        val sub = v.slots[2]
        // 1. Stunde ist um 9:00 vorbei.
        assertEquals("2", sub.mark)
        assertEquals("Vertretung 2. Std.", sub.text)
        assertEquals("Vertretung 2", sub.cd)
        assertEquals(Target.TODAY, sub.target)
        val room = v.slots[3]
        assertEquals("5", room.mark)
        assertEquals("Raum 5. Std.", room.text)
        assertEquals("Raumwechsel 5", room.cd)
        // Nach 12:10 kein Raumwechsel mehr.
        assertFalse(view(kid(7, "Mia", day(mon, rooms = rooms), own = true), at(12, 30)).slots[3].on)
        // Eltern: keine Vertretung/Raum, auch wenn die Datei sie hat.
        assertEquals(3, view(kid(7, "Mia", day(mon, subs = subs)), at(9)).slots.size)
    }

    // ---- Punkt 4: Größen -------------------------------------------------------------------

    @Test
    fun groessenNachFlaeche() {
        assertEquals(Mode.STRIP, WidgetModel.mode(392f, 92f, Mode.MEDIUM))
        assertEquals(Mode.STRIP, WidgetModel.mode(200f, 80f, Mode.SMALL))
        assertEquals(Mode.MEDIUM, WidgetModel.mode(392f, 200f, Mode.STRIP))
        assertEquals(Mode.MEDIUM, WidgetModel.mode(250f, 100f, Mode.SMALL))
        assertEquals(Mode.SMALL, WidgetModel.mode(184f, 204f, Mode.MEDIUM))
        assertEquals(Mode.SMALL, WidgetModel.mode(249f, 300f, Mode.MEDIUM))
        // Nicht gemeldet: Vorgabe der Anbieter-Klasse.
        assertEquals(Mode.STRIP, WidgetModel.mode(null, null, Mode.STRIP))
        assertEquals(Mode.SMALL, WidgetModel.mode(null, 150f, Mode.SMALL))

        assertEquals(Layout.ONE_WIDE, WidgetModel.layout(Mode.STRIP, 1))
        assertEquals(Layout.ROWS, WidgetModel.layout(Mode.STRIP, 3))
        assertEquals(Layout.ONE_WIDE, WidgetModel.layout(Mode.MEDIUM, 1))
        assertEquals(Layout.ROWS, WidgetModel.layout(Mode.MEDIUM, 4))
        assertEquals(Layout.ONE_LIST, WidgetModel.layout(Mode.SMALL, 1))
        assertEquals(Layout.TWO_SMALL, WidgetModel.layout(Mode.SMALL, 2))
        assertEquals(Layout.GRID, WidgetModel.layout(Mode.SMALL, 4))
        assertEquals(2, WidgetModel.rowsFor(Mode.STRIP, Layout.ROWS))
        assertEquals(4, WidgetModel.rowsFor(Mode.MEDIUM, Layout.ROWS))
    }

    @Test
    fun leisteMitDreiKindern() {
        val p = WidgetModel.parse(
            file(
                kid(1, "Jonas", day(mon)),
                kid(2, "Lena", day(mon, start = "09:50")),
                kid(3, "Tom", day(mon)),
            ),
        )!!
        val views = p.kids.map { WidgetModel.view(it, at(7), p.labels) }
        // Nur Lena weicht ab: Lena, dann „+2 nach Plan“.
        val a = WidgetModel.plan(views, 2)
        assertEquals(listOf("Lena"), a.rows.map { it.kid.name })
        assertEquals(2, a.more)
        assertTrue(a.moreCalm)
        // Zwei weichen ab: beide in Datei-Reihenfolge, „+1“ hinten.
        val p2 = WidgetModel.parse(
            file(
                kid(1, "Jonas", day(mon)),
                kid(2, "Lena", day(mon, start = "09:50")),
                kid(3, "Tom", day(mon), exams = "\"$mon\""),
            ),
        )!!
        val b = WidgetModel.plan(p2.kids.map { WidgetModel.view(it, at(7), p2.labels) }, 2)
        assertEquals(listOf("Lena", "Tom"), b.rows.map { it.kid.name })
        assertEquals(1, b.more)
        assertFalse(b.moreCalm)
        // Genug Platz: alle, nichts „mehr“.
        val c = WidgetModel.plan(views, 4)
        assertEquals(3, c.rows.size)
        assertEquals(0, c.more)
        // Niemand weicht ab: erstes Kind, Rest „nach Plan“.
        val calm = WidgetModel.parse(file(kid(1, "Jonas", day(mon)), kid(2, "Lena", day(mon)), kid(3, "Tom", day(mon))))!!
        val d = WidgetModel.plan(calm.kids.map { WidgetModel.view(it, at(7), calm.labels) }, 2)
        assertEquals(listOf("Jonas"), d.rows.map { it.kid.name })
        assertEquals(2, d.more)
        assertTrue(d.moreCalm)
    }

    // ---- Punkt 7: Auswahl je Widget -----------------------------------------------------------

    @Test
    fun auswahlJeWidget() {
        val p = WidgetModel.parse(
            file(
                kid(1, "Jonas", day(mon)),
                kid(2, "Lena", day(mon)),
                kid(3, "Tom", day(mon), shown = false),
            ),
        )!!
        fun names(saved: String?) = WidgetModel.selected(p.kids, saved).map { it.name }
        // Gespeicherte Liste, Reihenfolge der Datei.
        assertEquals(listOf("Lena", "Tom"), names("[3, 2]"))
        // Gelöschtes Konto fällt weg.
        assertEquals(listOf("Lena"), names("[2, 99]"))
        // Nur Gelöschte, nichts gespeichert oder Kaputtes: Vorgabe shown: true.
        assertEquals(listOf("Jonas", "Lena"), names("[99]"))
        assertEquals(listOf("Jonas", "Lena"), names(null))
        assertEquals(listOf("Jonas", "Lena"), names("kaputt"))
        // Niemand shown: alle statt leer.
        val none = WidgetModel.parse(file(kid(1, "Jonas", day(mon), shown = false), kid(2, "Lena", day(mon), shown = false)))!!
        assertEquals(2, WidgetModel.selected(none.kids, null).size)
        // Hin und zurück.
        assertEquals(listOf("Jonas", "Tom"), names(WidgetModel.encodeSelection(listOf(1, 3))))
        assertEquals("kids_42", WidgetModel.selectionKey(42))
    }

    // ---- Punkt 6: veraltet -----------------------------------------------------------------------

    @Test
    fun veraltetNach36Stunden() {
        // Abruf Samstag 18:05, jetzt Montag 7:00 → 36 h 55 min.
        val v = view(kid(1, "Jonas", day(mon), exams = "\"$mon\"", stand = "2026-10-31T18:05:00.000"), at(7))
        assertTrue(v.stale)
        assertNull(v.day)
        assertEquals("Stand Sa 18:05", v.time.text)
        assertFalse(v.time.red)
        assertTrue(v.slots.none { it.on })
        assertFalse(v.relevant)
        // 35 h: noch frisch.
        assertFalse(view(kid(1, "Jonas", day(mon), stand = "2026-10-31T20:00:00.000"), at(7)).stale)
    }

    @Test
    fun veraltetWennDieDateiDenTagNichtAbdeckt() {
        val (k, l) = one(kid(1, "Jonas", day(mon), stand = "2026-11-02T06:30:00.000"))
        // Montag 15:00: heute vorbei, kein späterer Tag in der Datei.
        val v = WidgetModel.view(k, at(15), l)
        assertTrue(v.stale)
        assertEquals("Stand 06:30", v.time.text)
        assertEquals("HEUTE", WidgetModel.dayTag(listOf(v), mon, l))
    }

    // ---- Punkt 9: Wecker --------------------------------------------------------------------------

    @Test
    fun weckerAufDenNaechstenWechsel() {
        val mid = """{"slot": "4.", "end": "11:20"}"""
        val (k, _) = one(kid(1, "Jonas", day(mon, mid = mid) + "," + day(tue)))
        assertEquals(at(8), WidgetModel.nextWakeup(listOf(k), at(7)))
        assertEquals(at(11, 20), WidgetModel.nextWakeup(listOf(k), at(9)))
        assertEquals(at(13, 45), WidgetModel.nextWakeup(listOf(k), at(12)))
        // Nach Schulschluss: Mitternacht.
        assertEquals(tue.atStartOfDay(), WidgetModel.nextWakeup(listOf(k), at(14)))
        // Ohne Uhrzeiten: 17 Uhr.
        val (u, _) = one(kid(2, "Tom", untimed(mon)))
        assertEquals(at(17), WidgetModel.nextWakeup(listOf(u), at(10)))
        // Veralten vor Mitternacht: Abruf So 10:00 → Mo 22:00.
        val (s, _) = one(kid(3, "Mia", day(mon), stand = "2026-11-01T10:00:00.000"))
        assertEquals(at(22), WidgetModel.nextWakeup(listOf(s), at(14)))
    }

    // ---- Punkt 5: Klick-Ziele --------------------------------------------------------------------

    @Test
    fun klickZiele() {
        assertEquals("schulportal-widget://open?account=12&target=homework", WidgetModel.uri(12, Target.HOMEWORK))
        assertEquals("schulportal-widget://open?target=today", WidgetModel.uri(null, Target.TODAY))
    }
}
