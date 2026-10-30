package com.example.app.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import com.example.app.MainActivity
import com.example.app.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * Startbildschirm-Widget, Entwurf 10 (Abnahme 30.10.26; Bilder widget10*.png,
 * Nachbau test/_local/widget_v9_mockup_test.dart): je Kind Name, tatsächlicher
 * Zeitraum des gezeigten Tages, feste Symbolreihe. WAS gezeigt wird,
 * entscheidet WidgetModel.kt (rein, JVM-getestet); hier wird nur gezeichnet,
 * verknüpft (Klick-Ziele) und geweckt.
 *
 * Vier Anbieter (Leiste 4 × 1, klein 2 × 2, mittel 4 × 2, groß 4 × 3); die
 * Anordnung richtet sich aber nach der tatsächlichen Fläche
 * (WidgetModel.mode), die Klasse gibt nur die Vorgabe, wenn der
 * Startbildschirm keine Größe meldet. Ursache: Startbildschirme lassen jedes
 * Widget frei ziehen; ein 4 × 2 auf 4 × 1 verkleinert soll wie die Leiste
 * aussehen statt abgeschnitten. Grenze: Kein Mitwachsen der Schrift auf
 * Tablets mehr (Entwurf 5 hatte einen Maßstab) – große Flächen verteilen die
 * Zeilen nur gleichmäßig (spaceEvenly).
 */
abstract class SchoolWidgetBase : AppWidgetProvider() {
    /** Anordnung, wenn der Startbildschirm keine Fläche meldet. */
    protected abstract val fallback: Mode

    /** Eindeutige Anfragekennung des Weckers je Anbieter-Klasse (Vertrag Punkt 9). */
    protected abstract val alarmCode: Int

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            manager.updateAppWidget(id, SchoolWidgetRenderer.build(context, id, fallback, manager.getAppWidgetOptions(id)))
        }
        SchoolWidgetRenderer.scheduleWakeup(context, javaClass, alarmCode)
    }

    /**
     * Größe geändert: neu zeichnen, damit die Anordnung zur Fläche passt.
     * Grenze: Das Drehen des Geräts meldet der Startbildschirm hier nicht –
     * dafür die Fassungen je Größe in [SchoolWidgetRenderer.build].
     */
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle?) {
        manager.updateAppWidget(id, SchoolWidgetRenderer.build(context, id, fallback, options ?: manager.getAppWidgetOptions(id)))
    }

    /** Auswahl je Widget wegräumen (Vertrag Punkt 7), sonst bliebe sie für immer liegen. */
    override fun onDeleted(context: Context, ids: IntArray) {
        val e = context.getSharedPreferences(SchoolWidgetRenderer.INSTANCES, Context.MODE_PRIVATE).edit()
        for (id in ids) e.remove(WidgetModel.selectionKey(id))
        e.apply()
    }

    /** Letztes Widget dieser Klasse entfernt: Wecker aus. */
    override fun onDisabled(context: Context) {
        SchoolWidgetRenderer.cancelWakeup(context, javaClass, alarmCode)
    }
}

/** Leiste 4 × 1 (neu in Entwurf 10). */
class SchoolWidgetStrip : SchoolWidgetBase() {
    override val fallback = Mode.STRIP
    override val alarmCode = 4101
}

/** Klein 2 × 2. */
class SchoolWidgetSmall : SchoolWidgetBase() {
    override val fallback = Mode.SMALL
    override val alarmCode = 4102
}

/** Mittel 4 × 2. */
class SchoolWidgetMedium : SchoolWidgetBase() {
    override val fallback = Mode.MEDIUM
    override val alarmCode = 4103
}

/**
 * Groß 4 × 3 / 4 × 4: ab [WidgetModel.LARGE_MIN_H] Höhe mit Tagesvorschau
 * (Abnahme 30.10.26); meldet der Startbildschirm keine Größe, ebenso.
 */
class SchoolWidgetLarge : SchoolWidgetBase() {
    override val fallback = Mode.LARGE
    override val alarmCode = 4104
}

internal object SchoolWidgetRenderer {
    /** Ablage des Pakets home_widget (HomeWidgetPlugin.PREFERENCES). */
    const val PREFS = "HomeWidgetPreferences"

    /** Auswahl je Widget (WidgetConfigActivity, Vertrag Punkt 7). */
    const val INSTANCES = "fork_widget_instances"

    /** Höchstzahl der Fassungen je Größe (RemoteViews.MAX_INIT_VIEW_COUNT). */
    private const val MAX_SIZES = 16

    private val kidLabels = intArrayOf(
        R.color.widget_kid0_label, R.color.widget_kid1_label,
        R.color.widget_kid2_label, R.color.widget_kid3_label,
    )

    fun payload(ctx: Context): Payload? =
        WidgetModel.parse(ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(WidgetModel.PAYLOAD_KEY, null))

    /**
     * Widget [id] zeichnen. Ab Android 12 eine Fassung je gemeldeter Größe
     * (OPTION_APPWIDGET_SIZES, meist hochkant und quer); der Startbildschirm
     * wählt beim Drehen selbst. Ursache: Mit der Wahl nach Fläche
     * (WidgetModel.mode) kann dasselbe Widget hochkant „klein“ und quer
     * „mittel“ sein. Sonst EINE Fassung für die Lage beim Zeichnen
     * (WidgetModel.area). Grenze: Vor Android 12 stimmt die Anordnung nach
     * dem Drehen erst beim nächsten Zeichnen (Wecker oder 30 Min.).
     */
    fun build(ctx: Context, id: Int, fallback: Mode, options: Bundle?): RemoteViews {
        val p = payload(ctx)
        val saved = ctx.getSharedPreferences(INSTANCES, Context.MODE_PRIVATE).getString(WidgetModel.selectionKey(id), null)
        val now = LocalDateTime.now()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            @Suppress("DEPRECATION")
            val sizes = options?.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
                ?.filter { it.width > 0f && it.height > 0f }?.distinct()?.take(MAX_SIZES).orEmpty()
            if (sizes.isNotEmpty()) {
                // Je Größe eine eigene Fassung: RemoteViews(Map) setzt an jeder
                // die Idealgröße, ein geteiltes Objekt bekäme nur die letzte.
                val views = runCatching {
                    RemoteViews(sizes.associateWith { render(ctx, p, saved, WidgetModel.mode(it.width, it.height, fallback), now) })
                }.getOrNull()
                if (views != null) return views
            }
        }
        val landscape = ctx.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        val (w, h) = options?.let {
            WidgetModel.area(
                landscape,
                it.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0),
                it.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0),
                it.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0),
                it.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0),
            )
        } ?: (null to null)
        return render(ctx, p, saved, WidgetModel.mode(w, h, fallback), now)
    }

    /** Eine Fassung für die Anordnung [mode]. */
    private fun render(ctx: Context, p: Payload?, saved: String?, mode: Mode, now: LocalDateTime): RemoteViews {
        val v = RemoteViews(ctx.packageName, R.layout.widget_root)
        // Leerer Hintergrund: Heute ohne Kind (Vertrag Punkt 5).
        v.setOnClickPendingIntent(android.R.id.background, launch(ctx, null, Target.TODAY))
        v.removeAllViews(R.id.body)
        val kids = p?.let { WidgetModel.selected(it.kids, saved) }.orEmpty()
        if (p == null || kids.isEmpty()) {
            // Keine Datei, Version ≠ 3 (WidgetModel.parse) oder keine Kinder.
            v.setViewVisibility(R.id.body, View.GONE)
            v.setViewVisibility(R.id.no_data, View.VISIBLE)
            return v
        }
        val l = p.labels
        val views = kids.map { WidgetModel.view(it, now, l) }
        val layout = WidgetModel.layout(mode, views.size)
        val cap = if (layout == Layout.ROWS) WidgetModel.rowsFor(mode, layout) else WidgetModel.capacity(layout)
        val plan = WidgetModel.plan(views, cap)
        val tag = WidgetModel.dayTag(plan.rows, now.toLocalDate(), l)
        val padRes = when (layout) {
            Layout.ONE_WIDE, Layout.ROWS, Layout.DAYS -> R.dimen.widget_pad_wide
            Layout.GRID -> R.dimen.widget_pad_grid
            else -> R.dimen.widget_pad_small
        }
        val pad = ctx.resources.getDimensionPixelSize(padRes)
        v.setViewPadding(android.R.id.background, pad, pad, pad, pad)

        when (layout) {
            Layout.ONE_WIDE -> {
                v.addView(R.id.body, tagView(ctx, tag, mode))
                v.addView(R.id.body, oneWide(ctx, plan.rows[0], l))
            }
            // Mittel (4 × 2) mit zwei Kindern: je Kind eine hohe Zeile wie
            // beim einzelnen Kind (Name groß, Symbole mit Beschriftung), Linie
            // dazwischen. Ursache (Bildschirmfoto Pixel 30.10.26: „nutzt den
            // Platz nicht gut“): Die schmalen Zeilen der Leiste ließen im
            // 4 × 2 die Hälfte leer. Grenze: ab drei Kindern weiter die
            // schmalen Zeilen (_four42), sonst reicht die Höhe nicht.
            Layout.ROWS -> if (mode == Mode.MEDIUM && plan.rows.size <= 2 && !plan.moreCalm && plan.more == 0) {
                v.addView(R.id.body, tagView(ctx, tag, mode))
                val col = RemoteViews(ctx.packageName, R.layout.widget_col)
                // Ein Kind mit fünf Symbolen (Schülerkonto): beide Zeilen
                // etwas kleiner, sonst werden Name und Uhrzeit gekürzt.
                val crowded = plan.rows.any { it.slots.size > 3 }
                plan.rows.forEachIndexed { i, kv ->
                    if (i > 0) col.addView(R.id.col, RemoteViews(ctx.packageName, R.layout.widget_line))
                    col.addView(R.id.col, wideRow(ctx, kv, l, crowded))
                }
                v.addView(R.id.body, col)
            } else {
                v.addView(R.id.body, tagView(ctx, tag, mode))
                val col = RemoteViews(ctx.packageName, R.layout.widget_col)
                col.addView(R.id.col, space(ctx))
                plan.rows.forEachIndexed { i, kv ->
                    val tail = if (i == plan.rows.lastIndex && !plan.moreCalm) plan.more else 0
                    col.addView(R.id.col, kidRow(ctx, kv, l, tail))
                    col.addView(R.id.col, space(ctx))
                }
                if (plan.moreCalm) {
                    val row = RemoteViews(ctx.packageName, R.layout.widget_more_row)
                    row.addView(R.id.more_row, moreLine(ctx, l, plan.more))
                    col.addView(R.id.col, row)
                    col.addView(R.id.col, space(ctx))
                }
                v.addView(R.id.body, col)
            }
            // Groß (4 × 4, Abnahme 30.10.26): Kopfzeile (Symbol, Name der
            // App, Tag, Stand), je Kind Name/Zeitraum und drei umrandete Tage
            // mit allen vier Zeichen. Bis zwei Kinder größer.
            Layout.DAYS -> {
                val big = plan.rows.size <= 2
                val col = RemoteViews(ctx.packageName, R.layout.widget_col)
                col.addView(R.id.col, daysHead(ctx, tag, plan.rows, l, now))
                col.addView(R.id.col, RemoteViews(ctx.packageName, R.layout.widget_line))
                plan.rows.forEachIndexed { i, kv ->
                    if (i > 0) col.addView(R.id.col, RemoteViews(ctx.packageName, R.layout.widget_line))
                    val tail = if (i == plan.rows.lastIndex && !plan.moreCalm) plan.more else 0
                    col.addView(R.id.col, daysBlock(ctx, kv, l, now, big, tail))
                }
                if (plan.moreCalm) {
                    val row = RemoteViews(ctx.packageName, R.layout.widget_more_row)
                    row.addView(R.id.more_row, moreLine(ctx, l, plan.more))
                    col.addView(R.id.col, row)
                }
                v.addView(R.id.body, col)
            }
            Layout.ONE_LIST -> v.addView(R.id.body, oneList(ctx, plan.rows[0], l, tag))
            Layout.TWO_SMALL -> {
                v.setTextViewText(R.id.corner_day, tag)
                v.setViewVisibility(R.id.corner_day, View.VISIBLE)
                val col = RemoteViews(ctx.packageName, R.layout.widget_col)
                col.addView(R.id.col, space(ctx))
                plan.rows.forEachIndexed { i, kv ->
                    if (i > 0) {
                        col.addView(R.id.col, RemoteViews(ctx.packageName, R.layout.widget_line))
                        col.addView(R.id.col, space(ctx))
                    }
                    col.addView(R.id.col, block2(ctx, kv, l))
                    col.addView(R.id.col, space(ctx))
                }
                v.addView(R.id.body, col)
            }
            Layout.GRID -> {
                // Der Nachbau (_four22) hat keine Tag-Marke; ohne sie läse sich
                // ein Montag am Freitagabend wie heute. Deshalb klein rechts
                // oben, aber nur, wenn es nicht heute ist (dort fehlt sie wie im
                // abgenommenen Bild).
                if (plan.rows.firstOrNull()?.let { it.day != null && it.day != now.toLocalDate() } == true) {
                    v.setTextViewText(R.id.corner_day, tag)
                    v.setViewVisibility(R.id.corner_day, View.VISIBLE)
                }
                val col = RemoteViews(ctx.packageName, R.layout.widget_col)
                col.addView(R.id.col, space(ctx))
                val cells: List<KidView?> = plan.rows + if (plan.moreCalm) listOf(null) else emptyList()
                cells.chunked(2).forEachIndexed { r, pair ->
                    val row = RemoteViews(ctx.packageName, R.layout.widget_grid_row)
                    pair.forEachIndexed { j, kv ->
                        if (j > 0) row.addView(R.id.grid_row, RemoteViews(ctx.packageName, R.layout.widget_hgap))
                        val last = r * 2 + j == plan.rows.lastIndex
                        row.addView(
                            R.id.grid_row,
                            if (kv == null) moreLine(ctx, l, plan.more)
                            else cell4(ctx, kv, l, if (last && !plan.moreCalm) plan.more else 0),
                        )
                    }
                    if (pair.size == 1) {
                        row.addView(R.id.grid_row, RemoteViews(ctx.packageName, R.layout.widget_hgap))
                        row.addView(R.id.grid_row, RemoteViews(ctx.packageName, R.layout.widget_filler))
                    }
                    col.addView(R.id.col, row)
                    col.addView(R.id.col, space(ctx))
                }
                v.addView(R.id.body, col)
            }
        }
        return v
    }

    // ---- Bausteine ------------------------------------------------------------

    private fun space(ctx: Context) = RemoteViews(ctx.packageName, R.layout.widget_vspace)

    /**
     * Tag-Marke links; im mittleren Widget mit kleinem App-Symbol darüber
     * (widget_tag_logo, Wunsch 30.10.26). Leiste ohne Symbol (kein Platz).
     */
    private fun tagView(ctx: Context, tag: String, mode: Mode): RemoteViews =
        RemoteViews(ctx.packageName, if (mode == Mode.STRIP) R.layout.widget_tag else R.layout.widget_tag_logo)
            .apply { setTextViewText(R.id.tag_text, tag) }

    /** Kopfzeile 4 × 4: Symbol, „Schulportal“, Tag und ältester Stand der gezeigten Kinder. */
    private fun daysHead(ctx: Context, tag: String, rows: List<KidView>, l: Labels, now: LocalDateTime): RemoteViews {
        val r = RemoteViews(ctx.packageName, R.layout.widget_days_head)
        r.setTextViewText(R.id.head_day, tag)
        val stand = rows.mapNotNull { it.kid.stand }.minOrNull()
        r.setTextViewText(
            R.id.head_stand,
            stand?.let { "  ·  " + l.one(l.stale, WidgetModel.standText(it, l, now.toLocalDate())) }.orEmpty(),
        )
        return r
    }

    private fun moreLine(ctx: Context, l: Labels, n: Int): RemoteViews =
        RemoteViews(ctx.packageName, R.layout.widget_more).apply { setTextViewText(R.id.more_line, l.num(l.more, n)) }

    /** Kind-Zeile (_strip10/_four42); [tail] > 0 → „+N“ hinter dem Zeitraum (WidgetModel.plan). */
    private fun kidRow(ctx: Context, kv: KidView, l: Labels, tail: Int): RemoteViews {
        val r = RemoteViews(ctx.packageName, R.layout.widget_kid_row)
        head(ctx, r, kv, l, tail)
        for (s in kv.slots) r.addView(R.id.slots, slot(ctx, R.layout.widget_slot_27, kv, s))
        return r
    }

    /** Ein Kind breit (_one41): Symbole mit Beschriftung, ab vier Symbolen schmaler. */
    private fun oneWide(ctx: Context, kv: KidView, l: Labels): RemoteViews {
        val r = RemoteViews(ctx.packageName, R.layout.widget_one)
        head(ctx, r, kv, l, 0)
        val res = if (kv.slots.size > 3) R.layout.widget_slot_label_narrow else R.layout.widget_slot_label
        for (s in kv.slots) r.addView(R.id.slots, slot(ctx, res, kv, s))
        return r
    }

    /** Hohe Kind-Zeile im mittleren Widget mit zwei Kindern (widget_wide_row). */
    private fun wideRow(ctx: Context, kv: KidView, l: Labels, crowded: Boolean): RemoteViews {
        val r = RemoteViews(ctx.packageName, if (crowded) R.layout.widget_wide_row_compact else R.layout.widget_wide_row)
        head(ctx, r, kv, l, 0)
        // Größere Fassung (Rückmeldung 30.10.26: Platz besser nutzen); bei
        // fünf Symbolen die schmalen (48 dp), damit Name und Uhrzeit passen.
        val res = when {
            kv.slots.size > 3 -> R.layout.widget_slot_label_narrow
            crowded -> R.layout.widget_slot_label
            else -> R.layout.widget_slot_label_big
        }
        for (s in kv.slots) r.addView(R.id.slots, slot(ctx, res, kv, s))
        return r
    }

    /** Ein Kind der Tagesvorschau (4 × 4): Kopf wie überall, darunter drei Tage. */
    private fun daysBlock(ctx: Context, kv: KidView, l: Labels, now: LocalDateTime, big: Boolean, tail: Int): RemoteViews {
        val r = RemoteViews(ctx.packageName, if (big) R.layout.widget_days_kid_big else R.layout.widget_days_kid)
        head(ctx, r, kv, l, tail)
        for (c in WidgetModel.daysFor(kv.kid, now, l)) r.addView(R.id.days, dayCell(ctx, kv, c, l, big))
        return r
    }

    /**
     * Ein Tag: Kürzel, vier Zeichen an fester Stelle (an = Feld + Farbe,
     * aus = blass), Rahmen; Antippen öffnet Heute des Kindes. Vorlesetext
     * nennt nur, was zutrifft („Mo: Ausfall, Arbeit, Hausaufgaben 2“).
     */
    private fun dayCell(ctx: Context, kv: KidView, c: DayCell, l: Labels, big: Boolean): RemoteViews {
        val r = RemoteViews(ctx.packageName, if (big) R.layout.widget_day_cell_big else R.layout.widget_day_cell)
        r.setTextViewText(R.id.day_label, c.label)
        textColor(ctx, r, R.id.day_label, if (c.first) R.color.widget_ink else R.color.widget_muted)
        r.setInt(R.id.day, "setBackgroundResource", if (c.first) R.drawable.widget_day_first else R.drawable.widget_day)
        r.setOnClickPendingIntent(R.id.day, launch(ctx, kv.kid.account, Target.TODAY))
        if (c.free != null) {
            r.setTextViewText(R.id.day_free, c.free)
            r.setViewVisibility(R.id.day_free, View.VISIBLE)
            r.setViewVisibility(R.id.day_slots, View.GONE)
            r.setContentDescription(R.id.day, "${c.label}: ${c.free}")
            return r
        }
        fun mark(on: Boolean, box: Int, img: Int, onIcon: Int, offIcon: Int, bg: Int) {
            r.setImageViewResource(img, if (on) onIcon else offIcon)
            r.setInt(box, "setBackgroundResource", if (on) bg else 0)
        }
        mark(c.cancel, R.id.d_cancel_box, R.id.d_cancel, R.drawable.ic_widget_busy, R.drawable.ic_widget_busy_off, R.drawable.widget_slot_cancel)
        mark(c.exam, R.id.d_exam_box, R.id.d_exam, R.drawable.ic_widget_exam_on, R.drawable.ic_widget_exam_off, R.drawable.widget_slot_exam)
        mark(c.hw > 0, R.id.d_hw_box, R.id.d_hw, R.drawable.ic_widget_homework_on, R.drawable.ic_widget_homework_off, R.drawable.widget_slot_homework)
        mark(c.meal, R.id.d_meal_box, R.id.d_meal, R.drawable.ic_widget_meal_on, R.drawable.ic_widget_meal_off, R.drawable.widget_slot_change)
        r.setTextViewText(R.id.d_hw_mark, if (c.hw > 0) c.hw.toString() else "")
        r.setInt(R.id.d_hw_mark, "setBackgroundResource", R.drawable.widget_mark_homework)
        r.setViewVisibility(R.id.d_hw_mark, if (c.hw > 0) View.VISIBLE else View.GONE)
        val cd = listOfNotNull(
            l.cdCancel.takeIf { c.cancel },
            l.cdExam.takeIf { c.exam },
            "${l.cdHomework} ${c.hw}".takeIf { c.hw > 0 },
            l.cdMeal.takeIf { c.meal },
        )
        r.setContentDescription(R.id.day, if (cd.isEmpty()) c.label else "${c.label}: ${cd.joinToString(", ")}")
        return r
    }

    /** Ein Kind klein (_oneList): je Symbol eine Zeile mit Text. */
    private fun oneList(ctx: Context, kv: KidView, l: Labels, tag: String): RemoteViews {
        val r = RemoteViews(ctx.packageName, R.layout.widget_list)
        head(ctx, r, kv, l, 0)
        r.setTextViewText(R.id.tag_inline, tag)
        val res = if (kv.slots.size > 3) R.layout.widget_list_item_small else R.layout.widget_list_item
        for (s in kv.slots) r.addView(R.id.items, slot(ctx, res, kv, s))
        return r
    }

    /**
     * Ein Kind im kleinen Widget mit zwei Kindern (_small2): Symbole über die
     * Breite verteilt (Füller dazwischen wie Row spaceBetween). Grenze:
     * Schülerkonto mit fünf Symbolen braucht 160 dp – auf sehr schmalen
     * 2 × 2 berühren sie sich.
     */
    private fun block2(ctx: Context, kv: KidView, l: Labels): RemoteViews {
        val r = RemoteViews(ctx.packageName, R.layout.widget_block2)
        head(ctx, r, kv, l, 0)
        kv.slots.forEachIndexed { i, s ->
            if (i > 0) r.addView(R.id.slots, RemoteViews(ctx.packageName, R.layout.widget_filler))
            r.addView(R.id.slots, slot(ctx, R.layout.widget_slot_32, kv, s))
        }
        return r
    }

    /**
     * Feld des Rasters (_four22). Nur die drei Symbole der Eltern (Arbeit,
     * Aufgaben, Essen), auch beim Schülerkonto. Ursache: Ein Feld ist ~78 dp
     * breit; fünf Symbole à 20 dp + Abstand (120 dp) passen nicht. Grenze:
     * Vertretung/Raum eines Schülerkontos fehlen im Raster – praktisch selten,
     * weil ein Schülerkonto fast immer allein im Widget steht.
     */
    private fun cell4(ctx: Context, kv: KidView, l: Labels, tail: Int): RemoteViews {
        val r = RemoteViews(ctx.packageName, R.layout.widget_cell4)
        head(ctx, r, kv, l, tail)
        for (s in kv.slots.filter { it.signal == Signal.EXAM || it.signal == Signal.HOMEWORK || it.signal == Signal.MEAL }) {
            r.addView(R.id.slots, slot(ctx, R.layout.widget_slot_20, kv, s))
        }
        return r
    }

    /**
     * Name (Kinderfarbe), Zeitraum und Klick → today (Vertrag Punkt 5). Alle
     * Kind-Layouts nutzen dieselben Kennungen (row, name, busy, time,
     * time_red, mid_busy, mid, more; gen_widget_layouts10.py).
     */
    private fun head(ctx: Context, r: RemoteViews, kv: KidView, l: Labels, tail: Int) {
        r.setTextViewText(R.id.name, kv.kid.name)
        textColor(ctx, r, R.id.name, kidLabels[Math.floorMod(kv.kid.color, kidLabels.size)])
        r.setOnClickPendingIntent(R.id.row, launch(ctx, kv.kid.account, Target.TODAY))
        val t = kv.time
        r.setViewVisibility(R.id.busy, if (t.busy) View.VISIBLE else View.GONE)
        r.setContentDescription(R.id.busy, l.cdCancel)
        // Geändert: eigenes Textfeld rot/fett statt Farbe zur Laufzeit –
        // so löst der Startbildschirm hell/dunkel selbst auf, auch vor Android 12.
        r.setTextViewText(R.id.time, if (t.red) "" else t.text)
        r.setTextViewText(R.id.time_red, if (t.red) t.text else "")
        r.setViewVisibility(R.id.time, if (t.red || t.text.isEmpty()) View.GONE else View.VISIBLE)
        r.setViewVisibility(R.id.time_red, if (t.red) View.VISIBLE else View.GONE)
        val mid = t.mid.isNotEmpty()
        r.setViewVisibility(R.id.mid_busy, if (mid) View.VISIBLE else View.GONE)
        r.setContentDescription(R.id.mid_busy, l.cdCancel)
        r.setTextViewText(R.id.mid, t.mid)
        r.setViewVisibility(R.id.mid, if (mid) View.VISIBLE else View.GONE)
        r.setTextViewText(R.id.more, if (tail > 0) "+$tail" else "")
        r.setViewVisibility(R.id.more, if (tail > 0) View.VISIBLE else View.GONE)
    }

    /**
     * Ein Symbol in der Fassung [layout] (widget_slot_*, widget_list_item*).
     * Blass: kein Feld, blasses Symbol, KEIN eigenes Klick-Ziel und keine
     * Beschreibung. Ursache (Vertrag Punkt 8): Blasse Symbole sollen
     * Bildschirmleser nicht vorlesen; ein anklickbares Feld ohne
     * Beschreibung läse TalkBack als „Schaltfläche ohne Label“. Grenze:
     * Tippen auf ein blasses Symbol öffnet deshalb „Heute“ des Kindes (Klick
     * der Zeile) statt etwa der Arbeiten.
     */
    private fun slot(ctx: Context, layout: Int, kv: KidView, s: SlotState): RemoteViews {
        val r = RemoteViews(ctx.packageName, layout)
        r.setImageViewResource(R.id.slot_icon, icon(s.signal, s.on))
        r.setInt(R.id.slot_box, "setBackgroundResource", if (s.on) box(s.signal) else 0)
        val list = layout == R.layout.widget_list_item || layout == R.layout.widget_list_item_small
        if (list) {
            // Liste (_oneList): ohne Marke, die Zahl steht im Text.
            r.setTextViewText(R.id.item_on, if (s.on) s.text else "")
            r.setTextViewText(R.id.item_off, if (s.on) "" else s.text)
            r.setViewVisibility(R.id.item_on, if (s.on) View.VISIBLE else View.GONE)
            r.setViewVisibility(R.id.item_off, if (s.on) View.GONE else View.VISIBLE)
        } else {
            val mark = s.on && s.mark.isNotEmpty()
            r.setTextViewText(R.id.slot_mark, s.mark)
            r.setInt(R.id.slot_mark, "setBackgroundResource", markBg(s.signal))
            r.setViewVisibility(R.id.slot_mark, if (mark) View.VISIBLE else View.GONE)
        }
        if (layout == R.layout.widget_slot_label || layout == R.layout.widget_slot_label_narrow ||
            layout == R.layout.widget_slot_label_big || layout == R.layout.widget_slot_label_big_narrow
        ) {
            r.setTextViewText(R.id.slot_label_on, if (s.on) s.label else "")
            r.setTextViewText(R.id.slot_label_off, if (s.on) "" else s.label)
            r.setViewVisibility(R.id.slot_label_on, if (s.on) View.VISIBLE else View.GONE)
            r.setViewVisibility(R.id.slot_label_off, if (s.on) View.GONE else View.VISIBLE)
        }
        if (s.on) {
            r.setOnClickPendingIntent(R.id.slot, launch(ctx, kv.kid.account, s.target))
            r.setContentDescription(R.id.slot, s.cd)
        }
        return r
    }

    private fun icon(s: Signal, on: Boolean): Int = when (s) {
        Signal.EXAM -> if (on) R.drawable.ic_widget_exam_on else R.drawable.ic_widget_exam_off
        Signal.HOMEWORK -> if (on) R.drawable.ic_widget_homework_on else R.drawable.ic_widget_homework_off
        Signal.MEAL -> if (on) R.drawable.ic_widget_meal_on else R.drawable.ic_widget_meal_off
        Signal.SUB -> if (on) R.drawable.ic_widget_sub_on else R.drawable.ic_widget_sub_off
        Signal.ROOM -> if (on) R.drawable.ic_widget_room_on else R.drawable.ic_widget_room_off
    }

    private fun box(s: Signal): Int = when (s) {
        Signal.EXAM -> R.drawable.widget_slot_exam
        Signal.HOMEWORK -> R.drawable.widget_slot_homework
        else -> R.drawable.widget_slot_change
    }

    private fun markBg(s: Signal): Int = when (s) {
        Signal.EXAM -> R.drawable.widget_mark_exam
        Signal.HOMEWORK -> R.drawable.widget_mark_homework
        else -> R.drawable.widget_mark_change
    }

    /**
     * Textfarbe der Kinderfarbe. Ab Android 12 als Ressource, die der
     * Startbildschirm selbst hell/dunkel auflöst; davor als feste Farbe des
     * Augenblicks. Grenze (vor Android 12): Nach einem Wechsel hell/dunkel
     * stimmt der Name erst mit dem nächsten Zeichnen (Wecker oder 30 Min.).
     */
    private fun textColor(ctx: Context, v: RemoteViews, id: Int, res: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            v.setColorStateList(id, "setTextColor", res)
        } else {
            v.setTextColor(id, ctx.getColor(res))
        }
    }

    /**
     * Klick-Ziel (Vertrag Punkt 5) über home_widget: Aktion
     * HOME_WIDGET_LAUNCH_ACTION und die Uri als Daten an MainActivity
     * (singleTop). Dart liest sie mit HomeWidget.initiallyLaunchedFromHomeWidget()
     * (Kaltstart, Activity.intent) bzw. HomeWidget.widgetClicked (App lief,
     * onNewIntent). Eindeutig je Kind und Ziel: home_widget nimmt immer
     * requestCode 0, aber PendingIntents mit verschiedener Uri sind
     * verschieden (Intent.filterEquals vergleicht die Daten). Grenze: Zwei
     * Widgets mit demselben Kind teilen sich dasselbe PendingIntent – mit
     * identischem Ziel, also ohne Folgen.
     */
    private fun launch(ctx: Context, account: Int?, target: Target): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(ctx, MainActivity::class.java, Uri.parse(WidgetModel.uri(account, target)))

    // ---- Wecker (Vertrag Punkt 9) ------------------------------------------------

    private fun wakeIntent(ctx: Context, cls: Class<*>, code: Int, ids: IntArray): PendingIntent {
        val intent = Intent(ctx, cls)
            .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        return PendingIntent.getBroadcast(ctx, code, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    /**
     * Wecker auf den nächsten Wechselpunkt (WidgetModel.nextWakeup) über
     * ALLE Kinder der Datei, nicht nur die gezeigten. Ursache: Ein Wecker je
     * Anbieter-Klasse (dasselbe PendingIntent ersetzt den vorigen), die
     * Widgets einer Klasse können verschiedene Kinder zeigen. Grenze: Ein
     * Widget wird dadurch manchmal ohne sichtbare Änderung neu gezeichnet.
     * RTC (nicht _WAKEUP) und ungenau: weckt das Gerät nicht, braucht keine
     * Berechtigung für genaue Wecker (Android 12+).
     */
    fun scheduleWakeup(ctx: Context, cls: Class<*>, code: Int) {
        val ids = AppWidgetManager.getInstance(ctx).getAppWidgetIds(ComponentName(ctx, cls))
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return
        val pi = wakeIntent(ctx, cls, code, ids)
        val p = payload(ctx)
        if (ids.isEmpty() || p == null || p.kids.isEmpty()) {
            am.cancel(pi)
            return
        }
        val at = WidgetModel.nextWakeup(p.kids, LocalDateTime.now())
        am.setAndAllowWhileIdle(AlarmManager.RTC, at.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli(), pi)
    }

    fun cancelWakeup(ctx: Context, cls: Class<*>, code: Int) {
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return
        am.cancel(wakeIntent(ctx, cls, code, IntArray(0)))
    }
}
