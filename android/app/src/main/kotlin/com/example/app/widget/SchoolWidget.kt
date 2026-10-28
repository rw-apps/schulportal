package com.example.app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import com.example.app.MainActivity
import com.example.app.R
import java.time.LocalDate
import java.time.LocalTime

/**
 * Startbildschirm-Widget (Entwurf 5, Abnahme 28.10.26,
 * test/_local/widget_v5_mockup_test.dart): dicht, ALLE gezeigten Kinder in
 * kleinen Kacheln (Fach / was / wann). Inhalt und Reihenfolge entscheidet
 * WidgetModel.kt; hier wird nur gezeichnet.
 *
 * Drei Größen als eigene Anbieter (klein 2 × 2, mittel 4 × 2, groß 4 × 3),
 * je drei Stufen nach Zahl der Kinder (WidgetModel.tier). Ursache: Mit
 * mehreren Kindern war Entwurf 4 „viel Fläche für wenig Information“
 * (Rückmeldung 28.10.26). Grenze: Die Größe kommt vom Anbieter, nicht von
 * der tatsächlichen Fläche; nach dem Verkleinern entfallen nur ganze Reihen
 * (WidgetModel.rowsThatFit), mehr Kacheln als die Stufe vorsieht kommen
 * beim Vergrößern nicht dazu.
 */
abstract class SchoolWidgetBase : AppWidgetProvider() {
    protected abstract val size: WidgetSize

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            manager.updateAppWidget(id, SchoolWidgetRenderer.render(context, size, manager.getAppWidgetOptions(id)))
        }
    }

    /** Größe geändert: neu zeichnen, damit die Reihen zur Höhe passen. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        options: Bundle?,
    ) {
        manager.updateAppWidget(id, SchoolWidgetRenderer.render(context, size, options))
    }
}

/** Klein 2 × 2. */
class SchoolWidgetSmall : SchoolWidgetBase() {
    override val size = WidgetSize.SMALL
}

/** Mittel 4 × 2. */
class SchoolWidgetMedium : SchoolWidgetBase() {
    override val size = WidgetSize.MEDIUM
}

/** Groß 4 × 3 (neu in Entwurf 5). */
class SchoolWidgetLarge : SchoolWidgetBase() {
    override val size = WidgetSize.LARGE
}

internal object SchoolWidgetRenderer {
    /** Ablage des Pakets home_widget (HomeWidgetPlugin.PREFERENCES). */
    private const val PREFS = "HomeWidgetPreferences"

    // Kinderfarben (KitPalette.kids, res/values/widget_colors.xml). Als
    // Ressourcen je Kind statt eingefärbt: Formen lösen hell/dunkel dann
    // selbst auf (values-night), auch auf Android vor 12.
    private val dots = intArrayOf(
        R.drawable.widget_kid0_dot, R.drawable.widget_kid1_dot,
        R.drawable.widget_kid2_dot, R.drawable.widget_kid3_dot,
    )
    private val calms = intArrayOf(
        R.drawable.widget_kid0_calm, R.drawable.widget_kid1_calm,
        R.drawable.widget_kid2_calm, R.drawable.widget_kid3_calm,
    )
    private val onTints = intArrayOf(
        R.color.widget_kid0_on_tint, R.color.widget_kid1_on_tint,
        R.color.widget_kid2_on_tint, R.color.widget_kid3_on_tint,
    )

    // Maße für das Einpassen der Reihen (dp), aus res/values/widget_dimens.xml.
    private const val PAD = 14f * 2
    private const val GAP = 8f
    private const val GAP_SMALL = 6f
    private const val TILE_PAD = 8f * 2
    private const val CELL_PAD = 4f * 2

    fun render(ctx: Context, size: WidgetSize, options: Bundle?): RemoteViews {
        val v = RemoteViews(ctx.packageName, R.layout.widget_root)
        v.setOnClickPendingIntent(android.R.id.background, openApp(ctx))
        v.removeAllViews(R.id.body)
        v.setViewVisibility(R.id.head, View.GONE)
        v.setViewVisibility(R.id.footer, View.GONE)
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(WidgetModel.PAYLOAD_KEY, null)
        val p = WidgetModel.parse(raw)
        if (p == null || p.kids.isEmpty()) {
            // Noch nie Daten (App seit dem Hinzufügen nicht geöffnet bzw. Demo).
            v.setViewVisibility(R.id.no_data, View.VISIBLE)
            return v
        }
        v.setViewVisibility(R.id.no_data, View.GONE)

        val today = LocalDate.now()
        val now = LocalTime.now()
        val l = p.labels
        // Höhe hochkant (OPTION_APPWIDGET_MAX_HEIGHT); 0 = vom Startbildschirm
        // nicht gemeldet, dann gelten nur die Höchstzahlen der Stufe.
        val avail = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
            ?.takeIf { it > 0 }?.toFloat()?.minus(PAD)
        // Zeilenhöhe 12 sp ohne Schriftpolster, mit der Schriftgröße des
        // Systems geschätzt. Grenze: Herstellerschriften können höher sein.
        val line = 12f * ctx.resources.configuration.fontScale * 1.2f
        val tileH = 3 * line + TILE_PAD
        val headH = line + GAP
        val tier = WidgetModel.tier(p.kids.size)
        if (size != WidgetSize.SMALL) header(v, p, tier, today)

        when (tier) {
            Tier.ONE -> {
                val kid = p.kids[0]
                val tiles = WidgetModel.tilesFor(kid, l, today, now, withMeal = size == WidgetSize.LARGE)
                if (size == WidgetSize.SMALL) {
                    // Klein: Vorname, darunter die zwei wichtigsten Kacheln.
                    v.addView(R.id.body, nameLine(ctx, kid))
                    val n = WidgetModel.rowsThatFit(avail?.minus(line + 4f), tileH, GAP_SMALL, 2)
                    tiles.take(n).forEachIndexed { i, t ->
                        if (i > 0) v.addView(R.id.body, gap(ctx, R.layout.widget_vgap_small))
                        v.addView(R.id.body, row(ctx, kid, listOf(t)))
                    }
                } else {
                    val cap = if (size == WidgetSize.LARGE) 3 else 2
                    val rows = WidgetModel.rowsThatFit(avail?.minus(headH), tileH, GAP_SMALL, cap)
                    grid(ctx, v, R.id.body, kid, tiles.take(rows * 2))
                }
            }
            Tier.TWO -> {
                if (size == WidgetSize.SMALL) {
                    // Klein: je Kind Vorname und die wichtigste Kachel.
                    p.kids.forEachIndexed { i, kid ->
                        if (i > 0) v.addView(R.id.body, gap(ctx, R.layout.widget_vgap))
                        v.addView(R.id.body, nameLine(ctx, kid))
                        WidgetModel.tilesFor(kid, l, today, now, false).firstOrNull()?.let {
                            v.addView(R.id.body, row(ctx, kid, listOf(it)))
                        }
                    }
                } else {
                    // Je Kind eine Zeile: Kürzel und Name links, Kacheln rechts;
                    // groß bis zwei Reihen, wenn beide Kinder hineinpassen.
                    val cap = if (size == WidgetSize.LARGE) 2 else 1
                    var rows = cap
                    if (avail != null) {
                        while (rows > 1 && headH + 2 * (rows * tileH + (rows - 1) * GAP_SMALL) + GAP > avail) rows--
                    }
                    p.kids.forEachIndexed { i, kid ->
                        if (i > 0) v.addView(R.id.body, gap(ctx, R.layout.widget_vgap))
                        val tiles = WidgetModel.tilesFor(kid, l, today, now, false)
                        v.addView(R.id.body, kidRow(ctx, kid, tiles.take(rows * 2)))
                    }
                }
            }
            Tier.MANY -> many(ctx, v, p, size, today, now, avail, line, tileH, headH)
        }
        return v
    }

    /** Ab drei Kindern (widget5_c/d). */
    private fun many(
        ctx: Context,
        v: RemoteViews,
        p: Payload,
        size: WidgetSize,
        today: LocalDate,
        now: LocalTime,
        avail: Float?,
        line: Float,
        tileH: Float,
        headH: Float,
    ) {
        val l = p.labels
        val cellH = 2 * line + CELL_PAD
        val footH = line + GAP
        val shown = when (size) {
            // Klein: je Kind eine kompakte Zeile, nur Name und Art.
            WidgetSize.SMALL -> {
                val n = WidgetModel.rowsThatFit(avail?.minus(footH), cellH, GAP_SMALL, WidgetModel.MAX_KIDS)
                val kids = p.kids.take(n)
                kids.forEachIndexed { i, kid ->
                    if (i > 0) v.addView(R.id.body, gap(ctx, R.layout.widget_vgap_small))
                    val r = RemoteViews(ctx.packageName, R.layout.widget_row)
                    r.addView(R.id.row, cell(ctx, kid, WidgetModel.cellFor(kid, l, today, now, detailed = false)))
                    v.addView(R.id.body, r)
                }
                kids.size
            }
            // Mittel: zwei kompakte Zellen je Reihe, Fußzeile mit Arbeiten
            // und Aufgaben aller Kinder.
            WidgetSize.MEDIUM -> {
                val rows = WidgetModel.rowsThatFit(avail?.minus(headH + footH), cellH, GAP_SMALL, WidgetModel.MAX_KIDS / 2)
                val kids = p.kids.take(rows * 2)
                kids.chunked(2).forEachIndexed { i, pair ->
                    if (i > 0) v.addView(R.id.body, gap(ctx, R.layout.widget_vgap_small))
                    val r = RemoteViews(ctx.packageName, R.layout.widget_row)
                    pair.forEachIndexed { j, kid ->
                        if (j > 0) r.addView(R.id.row, gap(ctx, R.layout.widget_hgap))
                        r.addView(R.id.row, cell(ctx, kid, WidgetModel.cellFor(kid, l, today, now, detailed = true)))
                    }
                    if (pair.size == 1) {
                        r.addView(R.id.row, gap(ctx, R.layout.widget_hgap))
                        r.addView(R.id.row, RemoteViews(ctx.packageName, R.layout.widget_filler))
                    }
                    v.addView(R.id.body, r)
                }
                val exams = WidgetModel.examLine(p.kids, l, today)
                v.setTextViewText(R.id.foot_exam_text, exams)
                v.setViewVisibility(R.id.foot_exam, if (exams.isEmpty()) View.GONE else View.VISIBLE)
                v.setTextViewText(R.id.foot_hw_text, p.homeworkTotal)
                v.setViewVisibility(R.id.foot_hw, if (p.homeworkTotal.isEmpty()) View.GONE else View.VISIBLE)
                kids.size
            }
            // Groß: wie zwei Kinder, je Kind Kürzel und zwei Kacheln.
            WidgetSize.LARGE -> {
                val n = WidgetModel.rowsThatFit(avail?.minus(headH + footH), tileH, GAP, WidgetModel.MAX_KIDS)
                val kids = p.kids.take(n)
                kids.forEachIndexed { i, kid ->
                    if (i > 0) v.addView(R.id.body, gap(ctx, R.layout.widget_vgap))
                    v.addView(R.id.body, kidRow(ctx, kid, WidgetModel.tilesFor(kid, l, today, now, false).take(2)))
                }
                v.setViewVisibility(R.id.foot_exam, View.GONE)
                v.setViewVisibility(R.id.foot_hw, View.GONE)
                kids.size
            }
        }
        val more = p.kids.size - shown
        v.setTextViewText(R.id.foot_more, if (more > 0) "+$more" else "")
        v.setViewVisibility(R.id.foot_more, if (more > 0) View.VISIBLE else View.GONE)
        if (size == WidgetSize.SMALL) {
            v.setViewVisibility(R.id.foot_exam, View.GONE)
            v.setViewVisibility(R.id.foot_hw, View.GONE)
        }
        val any = more > 0 || (size == WidgetSize.MEDIUM &&
            (WidgetModel.examLine(p.kids, l, today).isNotEmpty() || p.homeworkTotal.isNotEmpty()))
        v.setViewVisibility(R.id.footer, if (any) View.VISIBLE else View.GONE)
    }

    /** Kopf: (ein Kind: Punkt und Vorname ·) Datum, Stand. */
    private fun header(v: RemoteViews, p: Payload, tier: Tier, today: LocalDate) {
        v.setViewVisibility(R.id.head, View.VISIBLE)
        val day = WidgetModel.headDay(p, today)
        val one = tier == Tier.ONE
        val kid = p.kids[0]
        if (one) v.setInt(R.id.head_dot, "setBackgroundResource", dots[color(kid)])
        v.setViewVisibility(R.id.head_dot, if (one) View.VISIBLE else View.GONE)
        v.setTextViewText(R.id.head_day, if (one && kid.name.isNotEmpty()) "${kid.name} · $day" else day)
        val stand = WidgetModel.standOf(p.kids)
        v.setViewVisibility(R.id.head_sync, if (stand == null) View.GONE else View.VISIBLE)
        v.setTextViewText(R.id.head_stand, stand?.let { WidgetModel.standText(it, p.labels, today) }.orEmpty())
    }

    /** Zwei Kacheln je Reihe in [parent] (ein Kind: ohne Namensspalte). */
    private fun grid(ctx: Context, v: RemoteViews, parent: Int, kid: Kid, tiles: List<Tile>) {
        tiles.chunked(2).forEachIndexed { i, pair ->
            if (i > 0) v.addView(parent, gap(ctx, R.layout.widget_vgap_small))
            v.addView(parent, row(ctx, kid, pair, pairs = true))
        }
    }

    /**
     * Eine Reihe: eine Kachel über die volle Breite, oder (pairs) zwei
     * gleich breite; eine einzelne zweite Hälfte bleibt leer (widget5_e).
     */
    private fun row(ctx: Context, kid: Kid, tiles: List<Tile>, pairs: Boolean = false): RemoteViews {
        val r = RemoteViews(ctx.packageName, R.layout.widget_row)
        tiles.forEachIndexed { i, t ->
            if (i > 0) r.addView(R.id.row, gap(ctx, R.layout.widget_hgap))
            r.addView(R.id.row, tile(ctx, kid, t))
        }
        if (pairs && tiles.size == 1) {
            r.addView(R.id.row, gap(ctx, R.layout.widget_hgap))
            r.addView(R.id.row, RemoteViews(ctx.packageName, R.layout.widget_filler))
        }
        return r
    }

    /** Kind-Zeile (2 Kinder, groß ab 3): Kürzel im Kreis, Vorname, Kacheln. */
    private fun kidRow(ctx: Context, kid: Kid, tiles: List<Tile>): RemoteViews {
        val k = RemoteViews(ctx.packageName, R.layout.widget_kid)
        k.setInt(R.id.kid_avatar, "setBackgroundResource", dots[color(kid)])
        k.setTextViewText(R.id.kid_initial, initial(kid.name))
        k.setTextViewText(R.id.kid_name, kid.name)
        k.removeAllViews(R.id.kid_tiles)
        tiles.chunked(2).forEachIndexed { i, pair ->
            if (i > 0) k.addView(R.id.kid_tiles, gap(ctx, R.layout.widget_vgap_small))
            k.addView(R.id.kid_tiles, row(ctx, kid, pair, pairs = true))
        }
        return k
    }

    /** Punkt in der Kinderfarbe und Vorname (klein). */
    private fun nameLine(ctx: Context, kid: Kid): RemoteViews {
        val n = RemoteViews(ctx.packageName, R.layout.widget_name)
        n.setInt(R.id.name_dot, "setBackgroundResource", dots[color(kid)])
        n.setTextViewText(R.id.name_text, kid.name)
        return n
    }

    /** Kleine Kachel (Entwurf 5, _Mini). */
    private fun tile(ctx: Context, kid: Kid, t: Tile): RemoteViews {
        val c = color(kid)
        val layout = when (t.kind) {
            TileKind.CANCEL -> R.layout.widget_mini_cancel
            TileKind.CHANGE, TileKind.ROOM -> R.layout.widget_mini_change
            TileKind.CALM -> R.layout.widget_mini_calm
            else -> R.layout.widget_mini_info
        }
        val v = RemoteViews(ctx.packageName, layout)
        v.setImageViewResource(R.id.tile_icon, icon(t.kind))
        if (t.kind == TileKind.CALM) {
            v.setInt(R.id.tile_bg, "setBackgroundResource", calms[c])
            v.setInt(R.id.tile_circle, "setBackgroundResource", dots[c])
            for (id in intArrayOf(R.id.tile_l1, R.id.tile_l2, R.id.tile_l3)) textColor(ctx, v, id, onTints[c])
        }
        line(v, R.id.tile_l1, t.l1)
        line(v, R.id.tile_l2, t.l2)
        line(v, R.id.tile_l3, t.l3)
        return v
    }

    /** Kompakte Zelle (Entwurf 5, _Compact). */
    private fun cell(ctx: Context, kid: Kid, cell: Cell): RemoteViews {
        val c = color(kid)
        val layout = when (cell.kind) {
            TileKind.CANCEL -> R.layout.widget_cell_cancel
            TileKind.CHANGE, TileKind.ROOM -> R.layout.widget_cell_change
            else -> R.layout.widget_cell_calm
        }
        val v = RemoteViews(ctx.packageName, layout)
        v.setImageViewResource(R.id.cell_icon, icon(cell.kind))
        v.setInt(R.id.cell_dot, "setBackgroundResource", dots[c])
        if (layout == R.layout.widget_cell_calm) {
            v.setInt(R.id.cell_bg, "setBackgroundResource", calms[c])
            v.setInt(R.id.cell_circle, "setBackgroundResource", dots[c])
            textColor(ctx, v, R.id.cell_l1, onTints[c])
            textColor(ctx, v, R.id.cell_l2, onTints[c])
        }
        v.setTextViewText(R.id.cell_l1, cell.l1)
        v.setTextViewText(R.id.cell_l2, cell.l2)
        return v
    }

    /**
     * Lagebild nach der Lage, nicht nach dem Fach (Rückmeldung 28.10.26):
     * Ausfall immer der durchgestrichene Termin.
     */
    private fun icon(kind: TileKind): Int = when (kind) {
        TileKind.CANCEL -> R.drawable.ic_widget_event_busy
        TileKind.CHANGE -> R.drawable.ic_widget_switch_account
        TileKind.ROOM -> R.drawable.ic_widget_walk_change
        TileKind.EXAM -> R.drawable.ic_widget_edit_note
        TileKind.HOMEWORK -> R.drawable.ic_widget_checklist
        TileKind.MEAL -> R.drawable.ic_widget_restaurant
        TileKind.CALM -> R.drawable.ic_widget_sun
    }

    private fun line(v: RemoteViews, id: Int, text: String) {
        v.setTextViewText(id, text)
        v.setViewVisibility(id, if (text.isEmpty()) View.GONE else View.VISIBLE)
    }

    private fun gap(ctx: Context, layout: Int) = RemoteViews(ctx.packageName, layout)

    private fun color(kid: Kid) = Math.floorMod(kid.color, dots.size)

    /** Erster Buchstabe (ganzes Zeichen, auch außerhalb der BMP), groß. */
    private fun initial(name: String): String {
        if (name.isEmpty()) return ""
        return name.substring(0, name.offsetByCodePoints(0, 1)).uppercase()
    }

    /**
     * Textfarbe der Kinderfarbe. Ab Android 12 als Ressource, die der
     * Startbildschirm selbst hell/dunkel auflöst; davor als feste Farbe des
     * Augenblicks. Grenze (vor Android 12): Nach einem Wechsel hell/dunkel
     * stimmen die Zeilen der ruhigen Kachel erst mit dem nächsten Neuzeichnen
     * (spätestens 30 Min.).
     */
    private fun textColor(ctx: Context, v: RemoteViews, id: Int, res: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            v.setColorStateList(id, "setTextColor", res)
        } else {
            v.setTextColor(id, ctx.getColor(res))
        }
    }

    /** Tippen irgendwo öffnet die App (wie das Symbol im Startbildschirm). */
    private fun openApp(ctx: Context): PendingIntent {
        val intent = Intent(ctx, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        }
        return PendingIntent.getActivity(
            ctx,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
