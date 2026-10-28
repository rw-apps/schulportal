package com.example.app.widget

import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.util.Locale

/**
 * Inhalt des Startbildschirm-Widgets (Entwurf 5, Abnahme 28.10.26) ohne
 * Android-Oberfläche: Datei lesen, Kacheln je Kind wählen und ordnen, Stufe
 * nach Zahl der Kinder. Rein (nur org.json und java.time), damit die Regeln
 * als JVM-Test laufen (src/test/.../WidgetModelTest.kt); das Zeichnen steht
 * in SchoolWidget.kt.
 *
 * Die Datei schreibt die App (lib/fork/widget/home_widget_data.dart) mit
 * fertigen, übersetzten Texten. Hier wird nur noch nach dem aktuellen Datum
 * gefiltert und „heute“/„morgen“/Wochentag gewählt. Ursache: So stimmt das
 * Widget auch nach Mitternacht und nach dem Ende einer Stunde, ohne dass die
 * App neu lädt (Takt: updatePeriodMillis 30 Min., res/xml/widget_*_info.xml).
 * Grenze: Was die App nie geladen hat (Vertretungsplan für übermorgen), kann
 * auch das Widget nicht zeigen.
 */

/** Größe nach Anbieter (SchoolWidgetSmall/Medium/Large). */
enum class WidgetSize { SMALL, MEDIUM, LARGE }

/** Stufe nach Zahl der gezeigten Kinder (Entwurf 5): 1, 2, ab 3. */
enum class Tier { ONE, TWO, MANY }

/**
 * Art einer Kachel – bestimmt Farbe und Lagebild. [STALE]: grau „Stand Fr
 * 18:05“ statt der ruhigen Kachel, wenn der Vertretungsplan heute nicht mehr
 * abdeckt (WidgetModel.quietTile).
 */
enum class TileKind { CANCEL, CHANGE, ROOM, EXAM, HOMEWORK, MEAL, CALM, STALE }

/** Kleine Kachel: Lagebild und drei kurze Zeilen; leere Zeilen entfallen. */
data class Tile(val kind: TileKind, val l1: String, val l2: String, val l3: String)

/** Kompakte Zelle ab drei Kindern: zwei Zeilen. */
data class Cell(val kind: TileKind, val l1: String, val l2: String)

class Deviation(
    val date: LocalDate,
    val kind: TileKind,
    val title: String,
    val what: String,
    val word: String,
    val slot: String,
    val end: LocalTime?,
)

class Exam(val date: LocalDate, val subject: String, val kind: String)

class Kid(
    val account: Int,
    val name: String,
    val color: Int,
    val stand: LocalDateTime?,
    val items: List<Deviation>,
    val homework: String,
    val homeworkDue: LocalDate?,
    val exam: Exam?,
    val mealDate: LocalDate?,
    val meal: String?,
)

class Labels(o: JSONObject?, val legacy: Boolean) {
    val today: String = o?.optString("today").orEmpty()
    val tomorrow: String = o?.optString("tomorrow").orEmpty()
    val weekdays: List<String> = strings(o?.optJSONArray("weekdays"))

    /** Fehlt in Version 1: dann die Kurznamen. */
    val weekdaysLong: List<String> = strings(o?.optJSONArray("weekdaysLong")).ifEmpty { weekdays }
    val calmTitle: String = o?.optString("calmTitle").orEmpty()
    val calmText: String = o?.optString("calmText").orEmpty()
    val calmShort: String = o?.optString("calmShort").orEmpty().ifEmpty { calmTitle }

    /** „und %s“ – Kotlin setzt den nächsten Schultag ein; fehlt vor 28.10.26. */
    val calmAnd: String = o?.optString("calmAnd").orEmpty()

    /** „Stand %s“ (ForkL10n.asOf) und „App öffnen“; fehlen vor 28.10.26. */
    val stale: String = o?.optString("stale").orEmpty().ifEmpty { "%s" }
    val staleText: String = o?.optString("staleText").orEmpty()
    val homeworkOpen: String = o?.optString("homeworkOpen").orEmpty()
    val dueFor: String = o?.optString("dueFor").orEmpty()
    val exam: String = o?.optString("exam").orEmpty()
    val meal: String = o?.optString("meal").orEmpty()

    /** „heute“, „morgen“, sonst der Wochentag lang („Donnerstag“). */
    fun dayLong(d: LocalDate, today: LocalDate): String = when (d) {
        today -> this.today
        today.plusDays(1) -> tomorrow
        else -> weekdaysLong.getOrNull(d.dayOfWeek.value - 1).orEmpty()
    }

    /** „heute“, „morgen“, sonst kurz („Mo“) – Fußzeile, kompakte Zelle. */
    fun dayShort(d: LocalDate, today: LocalDate): String = when (d) {
        today -> this.today
        today.plusDays(1) -> tomorrow
        else -> weekdays.getOrNull(d.dayOfWeek.value - 1).orEmpty()
    }

    private companion object {
        fun strings(a: JSONArray?): List<String> =
            if (a == null) emptyList() else List(a.length()) { a.optString(it) }
    }
}

class Payload(
    val version: Int,
    val kids: List<Kid>,
    val labels: Labels,
    val dates: Map<String, String>,
    val homeworkTotal: String,
)

object WidgetModel {
    /** Gleicher Name wie homeWidgetDataKey in home_widget_data.dart. */
    const val PAYLOAD_KEY = "fork_widget_payload"

    /**
     * Arbeit (und Frist der Aufgaben) nur, wenn sie WENIGER als so viele Tage
     * voraus liegt (widgetExamDays): heute bis heute + 6.
     *
     * Ursache (Prüfung 28.10.26): Die Kachel nennt den Wochentag
     * (Labels.dayLong); eine Arbeit genau 7 Tage voraus hieß am Mittwoch
     * „Mittwoch“ und las sich wie heute. Innerhalb von 7 Tagen ist jeder
     * Wochentag eindeutig. Grenze: Eine Arbeit in genau einer Woche erscheint
     * erst am folgenden Tag.
     */
    const val EXAM_DAYS = 7L

    /** [d] liegt heute bis heute + 6 – der Wochentag ist eindeutig. */
    fun nameable(d: LocalDate, today: LocalDate): Boolean =
        !d.isBefore(today) && d.isBefore(today.plusDays(EXAM_DAYS))

    /**
     * Nächster Schultag nach [d]: morgen, ab Freitag der Montag – wie
     * nextSchoolDay in lib/fork/ui/today/kid_hints.dart. Grenze: Feiertage und
     * Ferien kennt die Rechnung nicht.
     */
    fun nextSchoolDay(d: LocalDate): LocalDate {
        var n = d.plusDays(1)
        while (n.dayOfWeek.value >= 6) n = n.plusDays(1)
        return n
    }

    /**
     * Letzter Tag, den der Vertretungsplan eines Kindes abdeckt: der nächste
     * Schultag nach dem Abruf (die App liest heute und den nächsten Schultag,
     * home_widget_data.dart, widgetItems). null ohne „stand“ (unbekannt).
     */
    fun coveredUntil(kid: Kid): LocalDate? = kid.stand?.let { nextSchoolDay(it.toLocalDate()) }

    /** Höchstzahl der Kinder ab drei (mittel/groß), sonst „+N“. */
    const val MAX_KIDS = 4

    /**
     * Datei lesen; null ohne Datei oder bei kaputtem Inhalt.
     *
     * Version 1 (Entwurf 4, ein Kind ohne `kids`) wird weiter gelesen –
     * Ursache: Bis die App nach dem Update einmal läuft, liegt noch die alte
     * Datei vor; ein leeres Widget sähe kaputt aus. Grenze: Version 1 kennt
     * weder lange Wochentage noch die Zeilen der ruhigen Kachel; die Stunde
     * steht dort schon mit „Std.“ („heute 4. Std.“).
     */
    fun parse(raw: String?): Payload? {
        if (raw == null) return null
        val p = runCatching { JSONObject(raw) }.getOrNull() ?: return null
        val version = p.optInt("v", 1)
        val dates = HashMap<String, String>()
        p.optJSONObject("dates")?.let { d ->
            for (k in d.keys()) dates[k] = d.optString(k)
        }
        if (version < 2) {
            val labels = Labels(p.optJSONObject("labels"), legacy = true)
            val hw = p.optString("homework", "")
            val e = p.optJSONObject("exam")
            val kid = Kid(
                account = p.optInt("account", 0),
                name = p.optString("name", ""),
                color = p.optInt("kid", 0),
                stand = dateTime(p.optString("stand")),
                items = deviations(p.optJSONArray("items")),
                homework = hw,
                homeworkDue = null,
                // Version 1: „label“ ist die Art, ohne Art das Fach.
                exam = e?.let { x -> date(x.optString("date"))?.let { Exam(it, x.optString("label"), "") } },
                mealDate = null,
                meal = null,
            )
            return Payload(version, listOf(kid), labels, dates, hw)
        }
        val labels = Labels(p.optJSONObject("labels"), legacy = false)
        val a = p.optJSONArray("kids") ?: JSONArray()
        val kids = ArrayList<Kid>()
        for (i in 0 until a.length()) {
            val k = a.optJSONObject(i) ?: continue
            val e = k.optJSONObject("exam")
            val m = k.optJSONObject("meal")
            kids.add(
                Kid(
                    account = k.optInt("account", 0),
                    name = k.optString("name", ""),
                    color = k.optInt("color", 0),
                    stand = dateTime(k.optString("stand")),
                    items = deviations(k.optJSONArray("items")),
                    homework = k.optString("hwText", ""),
                    homeworkDue = date(k.optString("hwDue")),
                    exam = e?.let { x ->
                        date(x.optString("date"))?.let { Exam(it, x.optString("subject"), x.optString("kind")) }
                    },
                    mealDate = m?.let { date(it.optString("date")) },
                    meal = m?.optString("name")?.ifEmpty { null },
                ),
            )
        }
        return Payload(version, kids, labels, dates, p.optString("hwTotal", ""))
    }

    fun tier(kids: Int): Tier = when {
        kids <= 1 -> Tier.ONE
        kids == 2 -> Tier.TWO
        else -> Tier.MANY
    }

    /**
     * Abweichungen ab heute; heutige, deren Stunde vorbei ist, fallen weg
     * („end“, nur mit Uhrzeiten der Schule). Reihenfolge wie geliefert (Tag,
     * dann Stunde) – damit steht die nächste Abweichung vorn.
     */
    fun visible(kid: Kid, today: LocalDate, now: LocalTime): List<Deviation> = kid.items.filter { d ->
        !d.date.isBefore(today) && !(d.date == today && d.end != null && !now.isBefore(d.end))
    }

    /**
     * Kacheln eines Kindes in der Reihenfolge des Entwurfs 5: Abweichungen
     * (heute, dann nächster Schultag), ohne Abweichung die ruhige Kachel,
     * dann Arbeit (bis [EXAM_DAYS] Tage), Aufgaben, Essen. Ursache (Abnahme
     * 28.10.26): Das Dringende zuerst; die Größe schneidet hinten ab.
     * [withMeal]: nur groß mit einem Kind – Grenze: sonst reicht der Platz
     * nie bis zum Essen.
     */
    fun tilesFor(kid: Kid, l: Labels, today: LocalDate, now: LocalTime, withMeal: Boolean): List<Tile> {
        val out = ArrayList<Tile>()
        val devs = visible(kid, today, now)
        for (d in devs) {
            out.add(Tile(d.kind, d.title, d.what, "${l.dayLong(d.date, today)} ${d.slot}".trim()))
        }
        if (devs.isEmpty()) out.add(quietTile(kid, l, today))
        kid.exam?.let { e ->
            if (nameable(e.date, today)) {
                val kind = e.kind.ifEmpty { l.exam }
                out.add(
                    if (e.subject.isEmpty()) Tile(TileKind.EXAM, kind, "", l.dayLong(e.date, today))
                    else Tile(TileKind.EXAM, e.subject, kind, l.dayLong(e.date, today)),
                )
            }
        }
        if (kid.homework.isNotEmpty()) {
            // Frist nur mit eindeutigem Wochentag ([nameable]), sonst ohne.
            val due = kid.homeworkDue?.takeIf { nameable(it, today) && l.dueFor.isNotEmpty() }
            out.add(
                Tile(
                    TileKind.HOMEWORK,
                    kid.homework,
                    l.homeworkOpen,
                    due?.let { l.dueFor.replace("%s", l.dayLong(it, today)) }.orEmpty(),
                ),
            )
        }
        if (withMeal && kid.meal != null && kid.mealDate == today) {
            out.add(Tile(TileKind.MEAL, l.meal.ifEmpty { kid.meal }, kid.meal, l.today))
        }
        return out
    }

    /**
     * Kachel ohne Abweichung: „Nach Plan / heute / und morgen“ – oder grau
     * „Stand Fr 18:05 / App öffnen“, wenn der Plan heute nicht abdeckt.
     *
     * Ursache (Prüfung 28.10.26): Kam länger keine neue Datei (App nicht
     * geöffnet, Hintergrund aus), zeigte das Widget „Nach Plan heute“, sobald
     * alle bekannten Einträge vorbei waren – auch Tage nach dem Abruf. Das
     * kleine Widget hat keinen Kopf mit „Stand“; dort fehlte jeder Hinweis.
     * Jetzt ruhig nur bis [coveredUntil]; „und morgen“ nur, wenn auch der
     * nächste Schultag abgedeckt ist, und dann mit seinem Namen („und
     * Montag“ am Freitag und Samstag, Labels.calmAnd). Grenze: Ohne „stand“
     * (unbekannt) bleibt es ruhig; „Stand“ nennt den Wochentag auch, wenn
     * der Abruf länger als eine Woche her ist (standText).
     */
    fun quietTile(kid: Kid, l: Labels, today: LocalDate): Tile {
        val until = coveredUntil(kid)
        if (until != null && today.isAfter(until)) {
            return Tile(TileKind.STALE, l.stale.replace("%s", standText(kid.stand!!, l, today)), l.staleText, "")
        }
        // Version 1 hat „heute und morgen“ in einer Zeile.
        if (l.legacy) return Tile(TileKind.CALM, l.calmTitle, l.calmText, "")
        val next = nextSchoolDay(today)
        val third = when {
            until != null && next.isAfter(until) -> ""
            l.calmAnd.isNotEmpty() -> l.calmAnd.replace("%s", l.dayLong(next, today))
            // Datei vor 28.10.26: „und morgen“ nur, wenn es stimmt.
            next == today.plusDays(1) -> l.calmText
            else -> ""
        }
        return Tile(TileKind.CALM, l.calmTitle, l.today, third)
    }

    /**
     * Klein mit zwei Kindern: eine Kachel je Kind, der Vorname als erste
     * Zeile („Lena“ / „Französisch“ / „fällt aus morgen“). Ursache
     * (Bildschirmfoto Pixel 28.10.26): Name als eigene Zeile plus
     * dreizeilige Kachel passte zweimal nicht hinein; die kompakten Zellen
     * ließen dann die halbe Fläche leer und nannten weder Fach noch Tag.
     * Grenze: Lange Fachnamen werden gekürzt („Naturwissensc…“).
     */
    fun namedTileFor(kid: Kid, l: Labels, today: LocalDate, now: LocalTime): Tile {
        val d = visible(kid, today, now).firstOrNull()
        if (d != null) {
            return Tile(d.kind, kid.name, d.title, "${d.word} ${l.dayShort(d.date, today)}".trim())
        }
        val q = quietTile(kid, l, today)
        return if (q.kind == TileKind.STALE) {
            Tile(TileKind.STALE, kid.name, q.l1, q.l2)
        } else {
            Tile(TileKind.CALM, kid.name, l.calmShort, listOf(q.l2, q.l3).filter { it.isNotEmpty() }.joinToString(" "))
        }
    }

    /**
     * Kompakte Zelle ab drei Kindern: nächste Abweichung, sonst „nach Plan“.
     * [detailed] (mittel): „Name · Fach“ / „fällt aus morgen“; sonst (klein)
     * nur Name / Art. Die Art steht IMMER als Wort (Rückmeldung 28.10.26).
     */
    fun cellFor(kid: Kid, l: Labels, today: LocalDate, now: LocalTime, detailed: Boolean): Cell {
        val d = visible(kid, today, now).firstOrNull() ?: return quietTile(kid, l, today).let {
            // Wie [quietTile]: veraltet „Stand Fr 18:05“ statt „nach Plan“.
            if (it.kind == TileKind.STALE) Cell(TileKind.STALE, kid.name, it.l1) else Cell(TileKind.CALM, kid.name, l.calmShort)
        }
        return if (detailed) {
            Cell(d.kind, "${kid.name} · ${d.title}", "${d.word} ${l.dayShort(d.date, today)}".trim())
        } else {
            Cell(d.kind, kid.name, d.word)
        }
    }

    /** Fußzeile ab drei Kindern: „Mo Jonas, Do Mia“ – Arbeiten nach Tag. */
    fun examLine(kids: List<Kid>, l: Labels, today: LocalDate): String = kids
        .mapNotNull { k ->
            k.exam?.takeIf { nameable(it.date, today) }
                ?.let { it.date to k.name }
        }
        .sortedBy { it.first }
        .joinToString(", ") { "${l.dayShort(it.first, today)} ${it.second}".trim() }

    /**
     * Stand im Kopf: der ÄLTESTE Abruf der gezeigten Kinder. Ursache: So
     * sieht man, wenn eines seit gestern nichts Neues bekommen hat. Grenze:
     * Welches Kind veraltet ist, sagt die Zeile nicht.
     */
    fun standOf(kids: List<Kid>): LocalDateTime? = kids.mapNotNull { it.stand }.minOrNull()

    /** „11:52“, von einem anderen Tag mit Wochentag („Di 18:05“). */
    fun standText(stand: LocalDateTime, l: Labels, today: LocalDate): String {
        // Locale.ROOT: immer lateinische Ziffern wie in der App.
        val hm = String.format(Locale.ROOT, "%02d:%02d", stand.hour, stand.minute)
        val date = stand.toLocalDate()
        return if (date == today) hm else "${l.weekdays.getOrNull(date.dayOfWeek.value - 1).orEmpty()} $hm".trim()
    }

    /** Datum im Kopf („Mi, 28. Okt.“); fehlt der Tag in der Datei, der Wochentag. */
    fun headDay(p: Payload, today: LocalDate): String =
        p.dates[today.toString()].orEmpty().ifEmpty {
            p.labels.weekdays.getOrNull(today.dayOfWeek.value - 1).orEmpty()
        }

    /**
     * Klein mit zwei Kindern: passen je Name ([name]) und eine Kachel
     * ([tile]) mit Abstand [gap] in [avail] dp? null = unbekannt → ja.
     * Ursache (Prüfung 28.10.26): Als einziger Zweig ohne Einpassen wurde die
     * zweite Kachel auf niedrigen Startbildschirmen unten abgeschnitten;
     * passt es nicht, zeigt SchoolWidget.kt die kompakten Zellen (cellFor).
     */
    fun twoKidsFit(avail: Float?, name: Float, tile: Float, gap: Float): Boolean =
        avail == null || 2 * (name + tile) + gap <= avail

    /**
     * Wie viele Reihen der Höhe [row] (Abstand [gap]) in [avail] dp passen,
     * höchstens [cap], mindestens 1. [avail] null = unbekannt → [cap].
     * Ursache: Die Startbildschirme geben 4 × 3 sehr unterschiedlich hoch;
     * statt unten abgeschnittener Kacheln entfällt eine ganze Reihe.
     * Grenze: Zeilenhöhe ist geschätzt (SchoolWidget.kt, lineDp).
     */
    fun rowsThatFit(avail: Float?, row: Float, gap: Float, cap: Int): Int {
        if (avail == null || cap <= 1) return cap.coerceAtLeast(1)
        var n = 1
        while (n < cap && (n + 1) * row + n * gap <= avail) n++
        return n
    }

    private fun deviations(a: JSONArray?): List<Deviation> {
        if (a == null) return emptyList()
        val out = ArrayList<Deviation>()
        for (i in 0 until a.length()) {
            val o = a.optJSONObject(i) ?: continue
            val date = date(o.optString("date")) ?: continue
            val what = o.optString("what")
            out.add(
                Deviation(
                    date = date,
                    kind = when (o.optString("kind")) {
                        "cancel" -> TileKind.CANCEL
                        "room" -> TileKind.ROOM
                        else -> TileKind.CHANGE
                    },
                    title = o.optString("title"),
                    what = what,
                    // Version 1 hat kein „word“: dort ist „what“ schon das Wort.
                    word = o.optString("word", "").ifEmpty { what },
                    slot = o.optString("slot"),
                    end = if (o.has("end")) runCatching { LocalTime.parse(o.optString("end")) }.getOrNull() else null,
                ),
            )
        }
        return out
    }

    private fun date(s: String?): LocalDate? =
        if (s.isNullOrEmpty()) null else runCatching { LocalDate.parse(s) }.getOrNull()

    private fun dateTime(s: String?): LocalDateTime? =
        if (s.isNullOrEmpty()) null else runCatching { LocalDateTime.parse(s) }.getOrNull()
}
