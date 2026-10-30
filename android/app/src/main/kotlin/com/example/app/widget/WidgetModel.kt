package com.example.app.widget

import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.util.Locale

/**
 * Inhalt des Startbildschirm-Widgets, Entwurf 10 (Abnahme 30.10.26), ohne
 * Android-Oberfläche: Datei Version 3 lesen, je Kind den gezeigten Tag, den
 * Zeitraum-Text und die feste Symbolreihe bestimmen, Anordnung nach Fläche,
 * Auswahl je Widget, Wecker-Zeitpunkt. Rein (nur org.json und java.time),
 * damit alle Regeln als JVM-Test laufen (src/test/.../WidgetModelTest.kt);
 * das Zeichnen steht in SchoolWidget.kt.
 *
 * Die Datei schreibt die App (lib/fork/widget/home_widget_data.dart) mit
 * fertigen, übersetzten Texten und den Tagen heute bis +7. Hier wird nur
 * nach der Gerätezeit gewählt. Ursache: So stimmt das Widget nach Ende des
 * Unterrichts, ab 17 Uhr und nach Mitternacht, ohne dass die App neu lädt
 * (Wecker [WidgetModel.nextWakeup] plus Takt 30 Min., res/xml/widget_*_info.xml).
 * Grenze: Was die App nie geladen hat (Plan über +7 hinaus), zeigt das
 * Widget nicht; ist die Datei zu alt, steht „Stand …“ ([WidgetModel.isStale]).
 */

/** Symbol der festen Reihe (Entwurf 10: Ausfall ist KEIN Symbol, er steht am Zeitraum). */
enum class Signal { EXAM, HOMEWORK, SUB, ROOM, MEAL }

/** Klick-Ziel, wie es in der Uri steht (target=…); die App liest es (Dart). */
enum class Target(val key: String) {
    TODAY("today"), EXAMS("exams"), HOMEWORK("homework"), MEAL("meal"),
}

/** Anordnung nach tatsächlicher Fläche ([WidgetModel.mode]). */
enum class Mode { STRIP, MEDIUM, SMALL }

/**
 * Aufbau nach Anordnung und Zahl der Kinder ([WidgetModel.layout]):
 * ONE_WIDE = _one41, ROWS = _strip10/_four42, ONE_LIST = _oneList (Variante A),
 * TWO_SMALL = _small2, GRID = _four22 (test/_local/widget_v9_mockup_test.dart).
 */
enum class Layout { ONE_WIDE, ROWS, ONE_LIST, TWO_SMALL, GRID }

/** Stunde mit Ende (Ausfall mitten am Tag, Vertretung, Raum). [end] null = Schule ohne Uhrzeiten. */
class Lesson(val slot: String, val end: LocalTime?, val room: String = "")

class Day(
    val date: LocalDate,
    val timed: Boolean,
    val start: LocalTime?,
    val end: LocalTime?,
    val planStart: LocalTime?,
    val planEnd: LocalTime?,
    val startSlot: String,
    val endSlot: String,
    val planStartSlot: String,
    val planEndSlot: String,
    val allOff: Boolean,
    val mid: List<Lesson>,
    val subs: List<Lesson>,
    val rooms: List<Lesson>,
    /** Tag ohne Unterricht (Ferien, frei) mit fertigem Text; null = Schultag. */
    val free: String?,
)

class Kid(
    val account: Int,
    val name: String,
    val color: Int,
    val stand: LocalDateTime?,
    val own: Boolean,
    val shown: Boolean,
    val days: List<Day>,
    val hwDue: List<LocalDate>,
    val exams: Set<LocalDate>,
    val mealOpen: Set<LocalDate>,
    val lowBalance: Boolean,
)

class Labels(private val o: JSONObject?) {
    private fun s(k: String) = o?.optString(k).orEmpty()

    val today = s("today")
    val weekdaysLong = strings(o?.optJSONArray("weekdaysLong"))
    val weekdays = strings(o?.optJSONArray("weekdays"))
    val from = s("from")
    val until = s("until")
    val range = s("range")
    val slot = s("slot").ifEmpty { "%s" }
    val off = s("off")
    val stale = s("stale").ifEmpty { "%s" }
    val staleText = s("staleText")
    val exam = s("exam")
    val homework = s("homework")
    val homeworkN = strings(o?.optJSONArray("homeworkN"))
    val meal = s("meal")
    val mealOrder = s("mealOrder")
    val balance = s("balance")
    val sub = s("sub")
    val subAt = s("subAt")
    val room = s("room")
    val roomAt = s("roomAt")
    val more = s("more").ifEmpty { "+%d" }
    val cdCancel = s("cdCancel")
    val cdExam = s("cdExam")
    val cdHomework = s("cdHomework")
    val cdMeal = s("cdMeal")
    val cdSub = s("cdSub")
    val cdRoom = s("cdRoom")
    val configTitle = s("configTitle")
    val configAll = s("configAll")
    val configOk = s("configOk")

    /**
     * Platzhalter ersetzen statt String.format. Ursache: Die Texte kommen aus
     * der App (ForkL10n); ein verirrtes „%“ in einer Übersetzung ließe
     * String.format mit Ausnahme abbrechen und das Widget bliebe leer.
     */
    fun one(fmt: String, a: String) = fmt.replace("%s", a)
    fun two(fmt: String, a: String, b: String) = fmt.replace("%1\$s", a).replace("%2\$s", b)
    fun num(fmt: String, n: Int) = fmt.replace("%d", n.toString())

    private companion object {
        fun strings(a: JSONArray?): List<String> =
            if (a == null) emptyList() else List(a.length()) { a.optString(it) }
    }
}

class Payload(val version: Int, val generatedAt: LocalDateTime?, val kids: List<Kid>, val labels: Labels)

/**
 * Zeitraum-Text eines Kindes. [red] = geändert (rot, fett); [busy] = rotes
 * event_busy davor; [mid] = Ausfall mitten am Tag („4.“, „4. +1“), rot mit
 * Symbol dahinter; leer = keiner.
 */
data class When(val text: String, val red: Boolean, val busy: Boolean, val mid: String)

/** Ein Symbol der Reihe für den gezeigten Tag. */
data class SlotState(
    val signal: Signal,
    val on: Boolean,
    /** Marke oben rechts („3“, „2“, „!“); leer = keine. */
    val mark: String,
    /** Zeile der Liste (_oneList): „3 Aufgaben“, „Vertretung 2. Std.“, blass „Aufgaben“. */
    val text: String,
    /** Beschriftung unter dem Symbol (_one41): „Aufgaben“. */
    val label: String,
    /** Vorlesetext; leer bei blassen Symbolen (Vertrag Punkt 8). */
    val cd: String,
    val target: Target,
)

/** Alles, was eine Kind-Zeile zeigt. [day] null = kein Tag in der Datei (veraltet). */
class KidView(
    val kid: Kid,
    val day: LocalDate?,
    val stale: Boolean,
    val time: When,
    val slots: List<SlotState>,
) {
    /** Abweichung oder ein leuchtendes Symbol – für die Auswahl bei Platzmangel ([WidgetModel.plan]). */
    val relevant: Boolean get() = !stale && (time.red || time.mid.isNotEmpty() || slots.any { it.on })
}

/**
 * Gezeigte Kinder bei begrenztem Platz. [more] = nicht gezeigte Kinder;
 * [moreCalm] true = sie haben alle nichts (eigene Zeile „+N nach Plan“),
 * false = „+N“ hinter der letzten Zeile.
 */
class Plan(val rows: List<KidView>, val more: Int, val moreCalm: Boolean)

object WidgetModel {
    /** Gleicher Name wie homeWidgetDataKey in home_widget_data.dart. */
    const val PAYLOAD_KEY = "fork_widget_payload"

    /** Einzige Fassung, die Kotlin darstellt (Vertrag Entwurf 10). */
    const val VERSION = 3

    /**
     * Ohne neue Datei länger als so viele Stunden: „Stand …“ statt Zeitraum.
     * Ursache: Ein Vertretungsplan von vorgestern kann längst überholt sein,
     * das Widget sähe aber unverändert aus. Grenze: Innerhalb der 36 h
     * kann eine kurzfristige Änderung fehlen, wenn der Hintergrund-Lauf
     * nicht kam.
     */
    const val STALE_HOURS = 36L

    /**
     * Ohne Uhrzeiten bzw. bei ganz freiem Tag gilt „heute“ bis 17 Uhr
     * (Vertrag Punkt 1). Ursache: Ohne Ende des Unterrichts gibt es keinen
     * besseren Wechselpunkt; „frei“ soll den Tag über sichtbar bleiben.
     * Gleiche Grenze wie lib/fork/ui/today (ab 17 Uhr nächster Tag).
     */
    val EVENING: LocalTime = LocalTime.of(17, 0)

    /** Breite/Höhe in dp für die Anordnung (Vertrag Punkt 4). */
    const val STRIP_MAX_H = 100f
    const val SMALL_MAX_W = 250f

    /** Höchstzahl der Kinder je Anordnung; mehr → [plan]. */
    fun capacity(layout: Layout): Int = when (layout) {
        Layout.ROWS -> 4
        Layout.GRID -> 4
        Layout.TWO_SMALL -> 2
        else -> 1
    }

    // ---- Datei ---------------------------------------------------------------

    /**
     * Datei lesen; null ohne Datei, bei kaputtem Inhalt und bei jeder anderen
     * Version als 3. Ursache: Version 2 (Entwurf 5) hat weder Zeiträume noch
     * Symbole; bis die App beim nächsten Start neu schreibt, zeigt das Widget
     * den no_data-Text (SchoolWidget.kt) statt halber Angaben.
     */
    fun parse(raw: String?): Payload? {
        if (raw == null) return null
        val p = runCatching { JSONObject(raw) }.getOrNull() ?: return null
        val version = p.optInt("v", 0)
        if (version != VERSION) return null
        val a = p.optJSONArray("kids") ?: JSONArray()
        val kids = ArrayList<Kid>()
        for (i in 0 until a.length()) {
            val k = a.optJSONObject(i) ?: continue
            val days = ArrayList<Day>()
            val ds = k.optJSONArray("days") ?: JSONArray()
            for (j in 0 until ds.length()) day(ds.optJSONObject(j))?.let { days.add(it) }
            days.sortBy { it.date }
            kids.add(
                Kid(
                    account = k.optInt("account", 0),
                    name = k.optString("name", ""),
                    color = k.optInt("color", 0),
                    stand = dateTime(k.optString("stand")),
                    own = k.optBoolean("own", false),
                    shown = k.optBoolean("shown", true),
                    days = days,
                    hwDue = dates(k.optJSONArray("hwDue")),
                    exams = dates(k.optJSONArray("exams")).toSet(),
                    mealOpen = dates(k.optJSONArray("mealOpen")).toSet(),
                    lowBalance = k.optBoolean("lowBalance", false),
                ),
            )
        }
        return Payload(version, dateTime(p.optString("generatedAt")), kids, Labels(p.optJSONObject("labels")))
    }

    private fun day(o: JSONObject?): Day? {
        if (o == null) return null
        val date = date(o.optString("date")) ?: return null
        return Day(
            date = date,
            timed = o.optBoolean("timed", false),
            start = time(o, "start"),
            end = time(o, "end"),
            planStart = time(o, "planStart"),
            planEnd = time(o, "planEnd"),
            startSlot = o.optString("startSlot", ""),
            endSlot = o.optString("endSlot", ""),
            planStartSlot = o.optString("planStartSlot", ""),
            planEndSlot = o.optString("planEndSlot", ""),
            allOff = o.optBoolean("allOff", false),
            mid = lessons(o.optJSONArray("mid")),
            subs = lessons(o.optJSONArray("subs")),
            rooms = lessons(o.optJSONArray("rooms")),
            // JSON null kommt bei optString als „null“ – deshalb isNull zuerst.
            free = if (o.isNull("free")) null else o.optString("free").ifEmpty { null },
        )
    }

    private fun lessons(a: JSONArray?): List<Lesson> {
        if (a == null) return emptyList()
        val out = ArrayList<Lesson>()
        for (i in 0 until a.length()) {
            val o = a.optJSONObject(i) ?: continue
            out.add(Lesson(o.optString("slot", ""), time(o, "end"), o.optString("room", "")))
        }
        return out
    }

    private fun time(o: JSONObject, k: String): LocalTime? =
        if (!o.has(k) || o.isNull(k)) null else runCatching { LocalTime.parse(o.optString(k)) }.getOrNull()

    private fun dates(a: JSONArray?): List<LocalDate> {
        if (a == null) return emptyList()
        return List(a.length()) { date(a.optString(it)) }.filterNotNull()
    }

    private fun date(s: String?): LocalDate? =
        if (s.isNullOrEmpty()) null else runCatching { LocalDate.parse(s) }.getOrNull()

    private fun dateTime(s: String?): LocalDateTime? =
        if (s.isNullOrEmpty()) null else runCatching { LocalDateTime.parse(s) }.getOrNull()

    // ---- Punkt 1: gezeigter Tag ---------------------------------------------

    /**
     * Läuft der heutige Tag [d] noch? timed: bis zum tatsächlichen Ende;
     * ohne Uhrzeiten und bei allOff bis [EVENING]. Ursache allOff: Ein ganz
     * freier Tag hat kein Ende; „frei“ soll trotzdem tagsüber stehen, statt
     * sofort den nächsten Tag zu zeigen (Vertrag Punkt 1).
     */
    fun running(d: Day, now: LocalTime): Boolean = when {
        d.allOff || !d.timed || d.end == null -> now.isBefore(EVENING)
        else -> now.isBefore(d.end)
    }

    /**
     * Gezeigter Tag: heute, solange er läuft ([running]), sonst der erste
     * spätere Schultag (ohne `free`). null = die Datei deckt nichts mehr ab
     * → veraltet ([isStale]). Grenze: Tage vor heute in der Datei werden
     * übergangen, auch wenn die App länger nicht lief.
     */
    fun shownDay(kid: Kid, now: LocalDateTime): Day? {
        val today = now.toLocalDate()
        val t = now.toLocalTime()
        return kid.days.firstOrNull { d ->
            d.free == null && !d.date.isBefore(today) && (d.date != today || running(d, t))
        }
    }

    /** Kein gezeigter Tag oder Abruf älter als [STALE_HOURS] (Vertrag Punkt 6). Ohne „stand“ zählt nur der Tag. */
    fun isStale(kid: Kid, day: Day?, now: LocalDateTime): Boolean =
        day == null || (kid.stand != null && kid.stand.plusHours(STALE_HOURS).isBefore(now))

    // ---- Punkt 2: Zeitraum ----------------------------------------------------

    /** „09:50“ – Locale.ROOT: immer lateinische Ziffern wie in der App. */
    fun hm(t: LocalTime): String = String.format(Locale.ROOT, "%02d:%02d", t.hour, t.minute)

    /**
     * Zeitraum-Text für den Tag [d] (Vertrag Punkt 2). Ferien: Hat HEUTE
     * `free` und ist [d] ein späterer Tag, steht grau der heutige Ferientext
     * („Herbstferien bis Fr 6.11.“) – Ursache: „08:00–13:45“ ohne Wochentag
     * läse sich in den Ferien wie heute. Grenze: Der Vertrag nennt „ein Tag
     * mit free zwischen heute und D UND heute free“ – heute ist selbst ein
     * solcher Tag, also genügt die zweite Bedingung.
     */
    fun whenText(kid: Kid, d: Day, now: LocalDateTime, l: Labels): When {
        val today = now.toLocalDate()
        val t = now.toLocalTime()
        if (d.date != today) {
            kid.days.firstOrNull { it.date == today }?.free?.let { return When(it, red = false, busy = false, mid = "") }
        }
        if (d.allOff) return When(l.off, red = true, busy = true, mid = "")
        val mid = midText(d, today, t)
        val base = if (d.timed && d.start != null && d.end != null) {
            val startCh = d.planStart != null && d.start != d.planStart
            val endCh = d.planEnd != null && d.end != d.planEnd
            pick(
                startCh, endCh,
                // Läuft der Unterricht, zählt nur noch das Ende; rot nur, wenn
                // das Ende abweicht – ein verschobener Beginn ist dann vorbei.
                running = d.date == today && !t.isBefore(d.start),
                from = { l.one(l.from, hm(d.start)) },
                until = { l.one(l.until, hm(d.end)) },
                range = { l.two(l.range, hm(d.start), hm(d.end)) },
            )
        } else {
            // Ohne Uhrzeiten dieselbe Logik mit Stunden („ab 3. Std.“); einen
            // laufenden Unterricht kann es ohne Uhrzeit nicht geben.
            val startCh = d.planStartSlot.isNotEmpty() && d.startSlot != d.planStartSlot
            val endCh = d.planEndSlot.isNotEmpty() && d.endSlot != d.planEndSlot
            if (d.startSlot.isEmpty() || d.endSlot.isEmpty()) {
                When("", red = false, busy = false, mid = "")
            } else {
                pick(
                    startCh, endCh, running = false,
                    from = { l.one(l.from, l.one(l.slot, d.startSlot)) },
                    until = { l.one(l.until, l.one(l.slot, d.endSlot)) },
                    range = { l.one(l.slot, l.two(l.range, d.startSlot, d.endSlot)) },
                )
            }
        }
        return base.copy(mid = mid)
    }

    private fun pick(
        startCh: Boolean,
        endCh: Boolean,
        running: Boolean,
        from: () -> String,
        until: () -> String,
        range: () -> String,
    ): When = when {
        running -> When(until(), red = endCh, busy = endCh, mid = "")
        startCh && !endCh -> When(from(), red = true, busy = true, mid = "")
        endCh && !startCh -> When(until(), red = true, busy = true, mid = "")
        else -> (startCh || endCh).let { ch -> When(range(), red = ch, busy = ch, mid = "") }
    }

    /** Stunden von [d], die heute schon vorbei sind, fallen weg (end ≤ jetzt); ohne end bleiben sie. */
    fun upcoming(list: List<Lesson>, d: Day, today: LocalDate, now: LocalTime): List<Lesson> =
        if (d.date != today) list else list.filter { it.end == null || now.isBefore(it.end) }

    /** Ausfall mitten am Tag: erste kommende Stunde, mehrere „4. +1“. */
    fun midText(d: Day, today: LocalDate, now: LocalTime): String {
        val m = upcoming(d.mid, d, today, now)
        if (m.isEmpty()) return ""
        return if (m.size == 1) m[0].slot else "${m[0].slot} +${m.size - 1}"
    }

    // ---- Punkt 3: Symbole ------------------------------------------------------

    fun signalsFor(kid: Kid): List<Signal> =
        if (kid.own) listOf(Signal.EXAM, Signal.HOMEWORK, Signal.SUB, Signal.ROOM, Signal.MEAL)
        else listOf(Signal.EXAM, Signal.HOMEWORK, Signal.MEAL)

    /**
     * Offene Aufgaben mit Frist heute bis [day]. Überfällige zählen nicht:
     * Ursache: Die Frist ist nur vermutet (nächste Stunde des Fachs); eine
     * alte, längst abgegebene Aufgabe hielte das Symbol sonst dauerhaft an.
     */
    fun homeworkCount(kid: Kid, today: LocalDate, day: LocalDate): Int =
        kid.hwDue.count { !it.isBefore(today) && !it.isAfter(day) }

    /** Symbole für den gezeigten Tag [d]; veraltet ([stale]) alle blass. */
    fun slotsFor(kid: Kid, d: Day?, stale: Boolean, now: LocalDateTime, l: Labels): List<SlotState> {
        val today = now.toLocalDate()
        val t = now.toLocalTime()
        return signalsFor(kid).map { s ->
            if (stale || d == null) return@map off(s, l)
            when (s) {
                Signal.EXAM ->
                    if (d.date in kid.exams) SlotState(s, true, "", l.exam, l.exam, l.cdExam, Target.EXAMS) else off(s, l)
                Signal.HOMEWORK -> {
                    val n = homeworkCount(kid, today, d.date)
                    if (n == 0) off(s, l) else {
                        val text = if (n == 1) l.homeworkN.getOrElse(0) { "1" } else l.num(l.homeworkN.getOrElse(1) { "%d" }, n)
                        SlotState(s, true, n.toString(), text, l.homework, "${l.cdHomework} $n".trim(), Target.HOMEWORK)
                    }
                }
                Signal.MEAL -> {
                    val open = d.date in kid.mealOpen
                    if (!open && !kid.lowBalance) off(s, l) else {
                        // Beides: Bestellen ist die Handlung des Tages, „!“ sagt
                        // zusätzlich, dass das Guthaben knapp ist.
                        val text = if (open) l.mealOrder else l.balance
                        val cd = listOf(l.cdMeal, if (open) l.mealOrder else "", if (kid.lowBalance) l.balance else "")
                            .filter { it.isNotEmpty() }.distinct().joinToString(", ")
                        SlotState(s, true, if (kid.lowBalance) "!" else "", text, l.meal, cd, Target.MEAL)
                    }
                }
                Signal.SUB, Signal.ROOM -> {
                    val list = upcoming(if (s == Signal.SUB) d.subs else d.rooms, d, today, t)
                    if (list.isEmpty()) off(s, l) else {
                        val first = list[0].slot
                        val mark = first.trimEnd('.')
                        val at = if (s == Signal.SUB) l.subAt else l.roomAt
                        val cd = if (s == Signal.SUB) l.cdSub else l.cdRoom
                        SlotState(s, true, mark, l.one(at, l.one(l.slot, first)), if (s == Signal.SUB) l.sub else l.room, "$cd $mark".trim(), Target.TODAY)
                    }
                }
            }
        }
    }

    private fun off(s: Signal, l: Labels): SlotState {
        val (name, target) = when (s) {
            Signal.EXAM -> l.exam to Target.EXAMS
            Signal.HOMEWORK -> l.homework to Target.HOMEWORK
            Signal.MEAL -> l.meal to Target.MEAL
            Signal.SUB -> l.sub to Target.TODAY
            Signal.ROOM -> l.room to Target.TODAY
        }
        return SlotState(s, false, "", name, name, "", target)
    }

    // ---- Zusammensetzen ----------------------------------------------------------

    /** Alles für ein Kind zum Zeitpunkt [now] (Punkte 1–3, 6). */
    fun view(kid: Kid, now: LocalDateTime, l: Labels): KidView {
        val d = shownDay(kid, now)
        val stale = isStale(kid, d, now)
        val time = if (stale) {
            val text = kid.stand?.let { l.one(l.stale, standText(it, l, now.toLocalDate())) } ?: l.staleText
            When(text, red = false, busy = false, mid = "")
        } else {
            whenText(kid, d!!, now, l)
        }
        return KidView(kid, if (stale) null else d!!.date, stale, time, slotsFor(kid, d, stale, now, l))
    }

    /** „18:05“, von einem anderen Tag mit Wochentag („Fr 18:05“). */
    fun standText(stand: LocalDateTime, l: Labels, today: LocalDate): String {
        val date = stand.toLocalDate()
        val t = hm(stand.toLocalTime())
        return if (date == today) t else "${l.weekdays.getOrNull(date.dayOfWeek.value - 1).orEmpty()} $t".trim()
    }

    /**
     * Tag-Marke: Tag des ERSTEN gezeigten Kindes (Vertrag Punkt 1); heute
     * oder veraltet → labels.today, sonst der lange Wochentag. Grenze: Zeigt
     * ein weiteres Kind einen anderen Tag (andere Schule, früher Schluss),
     * nennt die Marke ihn nicht.
     */
    fun dayTag(views: List<KidView>, today: LocalDate, l: Labels): String {
        val d = views.firstOrNull()?.day
        return if (d == null || d == today) l.today else l.weekdaysLong.getOrNull(d.dayOfWeek.value - 1).orEmpty()
    }

    // ---- Punkt 4: Größen -----------------------------------------------------------

    /**
     * Anordnung nach tatsächlicher Fläche in dp (nicht nach Anbieter):
     * niedriger als [STRIP_MAX_H] → Leiste; schmaler als [SMALL_MAX_W] →
     * klein; sonst mittel. Unbekannte Fläche (Startbildschirm meldet 0) →
     * [fallback] der Anbieter-Klasse (SchoolWidget.kt). Grenze: Die Schwellen
     * sind dp, die Zellgröße hängt vom Startbildschirm ab – ein 3 × 2 kann je
     * nach Gerät klein oder mittel sein.
     */
    fun mode(width: Float?, height: Float?, fallback: Mode): Mode = when {
        height != null && height < STRIP_MAX_H -> Mode.STRIP
        width != null && width < SMALL_MAX_W -> Mode.SMALL
        width != null && height != null -> Mode.MEDIUM
        else -> fallback
    }

    fun layout(mode: Mode, kids: Int): Layout = when (mode) {
        Mode.STRIP, Mode.MEDIUM -> if (kids <= 1) Layout.ONE_WIDE else Layout.ROWS
        Mode.SMALL -> when {
            kids <= 1 -> Layout.ONE_LIST
            kids == 2 -> Layout.TWO_SMALL
            else -> Layout.GRID
        }
    }

    /** Zeilen der Leiste: zwei (Höhe < 100 dp); mittel bis vier. */
    fun rowsFor(mode: Mode, layout: Layout): Int = if (mode == Mode.STRIP) 2 else capacity(layout)

    /**
     * Mehr Kinder als Platz [cap]: die mit Abweichung/Symbol zuerst
     * (Vertrag Punkt 4). Reichen die Plätze für alle relevanten, wird der
     * letzte Platz zu „+N nach Plan“ ([Plan.moreCalm]) – das stimmt dann,
     * weil der Rest nichts hat. Sonst die ersten [cap] relevanten und „+N“
     * hinter der letzten Zeile. Reihenfolge der gezeigten bleibt die der
     * Datei. Ursache: Gleiche Kinder an gleicher Stelle; die Farbe allein
     * soll das Kind nicht erkennbar machen müssen.
     */
    fun plan(views: List<KidView>, cap: Int): Plan {
        if (views.size <= cap) return Plan(views, 0, false)
        val rel = views.filter { it.relevant }
        if (rel.size < cap) {
            val keep = HashSet<KidView>(rel)
            for (v in views) {
                if (keep.size >= cap - 1) break
                keep.add(v)
            }
            val rows = views.filter { it in keep }
            return Plan(rows, views.size - rows.size, true)
        }
        val keep = rel.take(cap).toSet()
        return Plan(views.filter { it in keep }, views.size - cap, false)
    }

    // ---- Punkt 7: Auswahl je Widget ---------------------------------------------------

    /** Schlüssel in SharedPreferences „fork_widget_instances“. */
    fun selectionKey(widgetId: Int) = "kids_$widgetId"

    /**
     * Kinder eines Widgets: gespeicherte Liste (JSON-Liste der accounts) in
     * Reihenfolge der Datei; gelöschte Konten fallen weg. Fehlt sie, ist sie
     * kaputt oder bleibt danach niemand übrig → alle mit `shown: true`, und
     * gibt es davon keins → alle. Ursache: Ein leeres Widget mit Daten sähe
     * kaputt aus. Grenze: Ein neu angemeldetes Kind erscheint in einem Widget
     * mit eigener Auswahl erst nach erneutem Einstellen.
     */
    fun selected(kids: List<Kid>, saved: String?): List<Kid> {
        val ids = saved?.let { s ->
            runCatching { JSONArray(s) }.getOrNull()?.let { a -> List(a.length()) { a.optInt(it, Int.MIN_VALUE) }.toSet() }
        }
        if (ids != null) {
            val chosen = kids.filter { it.account in ids }
            if (chosen.isNotEmpty()) return chosen
        }
        return kids.filter { it.shown }.ifEmpty { kids }
    }

    fun encodeSelection(accounts: List<Int>): String = JSONArray().apply { accounts.forEach { put(it) } }.toString()

    // ---- Punkt 5: Klick-Ziele ---------------------------------------------------------

    /** schulportal-widget://open?account=<id>&target=<…>; ohne account für den leeren Hintergrund. */
    fun uri(account: Int?, target: Target): String =
        if (account == null) "schulportal-widget://open?target=${target.key}"
        else "schulportal-widget://open?account=$account&target=${target.key}"

    // ---- Punkt 9: Wecker ----------------------------------------------------------------

    /**
     * Nächster Zeitpunkt nach [now], an dem sich die Anzeige ändert: heute
     * Beginn (Zeitraum → „bis …“), Ende, Ende jeder Ausfall-/Vertretungs-/
     * Raumstunde, 17 Uhr (ohne Uhrzeiten, allOff), das Veralten nach
     * [STALE_HOURS] und Mitternacht. Ursache: updatePeriodMillis (30 Min.)
     * allein ließe „bis 13:45“ bis zu einer halben Stunde nach Schulschluss
     * stehen. Grenze: Der Wecker ist ungenau (setAndAllowWhileIdle) und
     * weckt das Gerät nicht – bei ausgeschaltetem Bildschirm kommt er beim
     * Einschalten.
     */
    fun nextWakeup(kids: List<Kid>, now: LocalDateTime): LocalDateTime {
        val today = now.toLocalDate()
        var best = today.plusDays(1).atStartOfDay()
        fun offer(t: LocalDateTime?) {
            if (t != null && t.isAfter(now) && t.isBefore(best)) best = t
        }
        for (k in kids) {
            k.stand?.let { offer(it.plusHours(STALE_HOURS)) }
            val d = k.days.firstOrNull { it.date == today } ?: continue
            if (d.allOff || !d.timed) offer(today.atTime(EVENING))
            for (t in listOf(d.start, d.end)) t?.let { offer(today.atTime(it)) }
            for (x in d.mid + d.subs + d.rooms) x.end?.let { offer(today.atTime(it)) }
        }
        return best
    }

    // ---- Fläche ------------------------------------------------------------------------

    /**
     * Fläche nach Lage des Geräts: hochkant minWidth × maxHeight, quer
     * maxWidth × minHeight (so fasst AppWidgetManager die beiden Lagen vor
     * Android 12 zusammen). 0 = nicht gemeldet → null. Grenze: Es gilt die
     * Lage beim Zeichnen; ab Android 12 zeichnet SchoolWidget.kt deshalb je
     * gemeldeter Größe (OPTION_APPWIDGET_SIZES).
     */
    fun area(landscape: Boolean, minWidth: Int, maxWidth: Int, minHeight: Int, maxHeight: Int): Pair<Float?, Float?> {
        val w = if (landscape) maxWidth else minWidth
        val h = if (landscape) minHeight else maxHeight
        return w.takeIf { it > 0 }?.toFloat() to h.takeIf { it > 0 }?.toFloat()
    }
}
