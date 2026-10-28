package com.example.app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.util.TypedValue
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
 * (Rückmeldung 28.10.26). Auf Tablets wächst alles mit der tatsächlichen
 * Fläche (WidgetScale, Foto Tablet 28.10.26). Grenze: Auf Telefonen kommt
 * die Größe vom Anbieter, nicht von der Fläche; nach dem Verkleinern
 * entfallen nur ganze Reihen (WidgetModel.rowsThatFit), mehr Kacheln als
 * die Stufe vorsieht kommen nur auf Tablets dazu (WidgetScale.twoKidRows).
 */
abstract class SchoolWidgetBase : AppWidgetProvider() {
    protected abstract val size: WidgetSize

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            manager.updateAppWidget(id, SchoolWidgetRenderer.build(context, size, manager.getAppWidgetOptions(id)))
        }
    }

    /**
     * Größe geändert: neu zeichnen, damit Reihen und (Tablet) Maßstab zur
     * Fläche passen. Grenze: Das Drehen des Geräts meldet der
     * Startbildschirm hier nicht – dafür die Größen je Lage in [SchoolWidgetRenderer.build].
     */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        options: Bundle?,
    ) {
        manager.updateAppWidget(id, SchoolWidgetRenderer.build(context, size, options ?: manager.getAppWidgetOptions(id)))
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

    /** Höchstzahl der Fassungen je Größe (RemoteViews.MAX_INIT_VIEW_COUNT). */
    private const val MAX_SIZES = 16

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

    private fun isTablet(ctx: Context) =
        ctx.resources.configuration.smallestScreenWidthDp >= WidgetScale.TABLET_SW

    /**
     * Widget für [options] zeichnen. Tablet ab Android 12: eine Fassung je
     * gemeldeter Größe (OPTION_APPWIDGET_SIZES, meist hochkant und quer);
     * der Startbildschirm wählt beim Drehen selbst. Ursache (Foto Tablet
     * 28.10.26): Tablets werden oft gedreht, und mit Maßstab passt eine für
     * hochkant gerechnete Fassung quer nicht mehr in die Höhe. Sonst (Telefon,
     * älteres Android, keine Größen gemeldet) EINE Fassung für die Lage beim
     * Zeichnen (WidgetScale.area). Grenze: Telefone bleiben beim bisherigen
     * Weg, damit sie genau wie vorher aussehen.
     */
    fun build(ctx: Context, size: WidgetSize, options: Bundle?): RemoteViews {
        if (isTablet(ctx) && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            @Suppress("DEPRECATION")
            val sizes = options?.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
                ?.filter { it.width > 0f && it.height > 0f }?.distinct()?.take(MAX_SIZES).orEmpty()
            if (sizes.isNotEmpty()) {
                val views = runCatching {
                    RemoteViews(sizes.associateWith { render(ctx, size, Area(it.width, it.height)) })
                }.getOrNull()
                if (views != null) return views
            }
        }
        val landscape = ctx.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        val area = options?.let {
            WidgetScale.area(
                landscape,
                it.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0),
                it.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0),
                it.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0),
                it.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0),
            )
        }
        return render(ctx, size, area)
    }

    /** Eine Fassung für die Fläche [area] (dp; null = nicht gemeldet). */
    private fun render(ctx: Context, size: WidgetSize, area: Area?): RemoteViews {
        val v = RemoteViews(ctx.packageName, R.layout.widget_root)
        v.setOnClickPendingIntent(android.R.id.background, openApp(ctx))
        v.removeAllViews(R.id.body)
        v.setViewVisibility(R.id.head, View.GONE)
        v.setViewVisibility(R.id.footer, View.GONE)
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(WidgetModel.PAYLOAD_KEY, null)
        val p = WidgetModel.parse(raw)
        // Maßstab (Telefon immer 1) und damit alle Höhen; Zeilenhöhe mit der
        // Schriftgröße des Systems geschätzt (WidgetMetrics). Ohne Daten wie
        // mit einem Kind.
        val tablet = isTablet(ctx)
        val fontScale = ctx.resources.configuration.fontScale
        val s = WidgetScale.scale(
            tablet,
            area,
            WidgetScale.referenceWidth(size),
            WidgetScale.neededHeight(size, p?.kids?.size?.coerceAtLeast(1) ?: 1, fontScale),
        )
        val m = WidgetMetrics(fontScale, s)
        val sc = Scaler(ctx, s)
        sc.root(v)
        if (p == null || p.kids.isEmpty()) {
            // Noch nie Daten (App seit dem Hinzufügen nicht geöffnet bzw. Demo).
            v.setViewVisibility(R.id.no_data, View.VISIBLE)
            return v
        }
        v.setViewVisibility(R.id.no_data, View.GONE)

        val today = LocalDate.now()
        val now = LocalTime.now()
        val l = p.labels
        // Höhe des Inhalts; null = vom Startbildschirm nicht gemeldet, dann
        // gelten nur die Höchstzahlen der Stufe.
        val avail = area?.height?.minus(m.pad)
        val tier = WidgetModel.tier(p.kids.size)
        if (size != WidgetSize.SMALL) header(v, p, tier, today)

        when (tier) {
            Tier.ONE -> {
                val kid = p.kids[0]
                val tiles = WidgetModel.tilesFor(kid, l, today, now, withMeal = size == WidgetSize.LARGE)
                if (size == WidgetSize.SMALL) {
                    // Klein: Vorname, darunter die zwei wichtigsten Kacheln.
                    v.addView(R.id.body, nameLine(ctx, sc, kid))
                    val n = WidgetModel.rowsThatFit(avail?.minus(m.nameH), m.tileH, m.gapSmall, 2)
                    tiles.take(n).forEachIndexed { i, t ->
                        if (i > 0) v.addView(R.id.body, gap(ctx, sc, R.layout.widget_vgap_small))
                        v.addView(R.id.body, row(ctx, sc, kid, listOf(t)))
                    }
                } else {
                    val cap = if (size == WidgetSize.LARGE) 3 else 2
                    val rows = WidgetModel.rowsThatFit(avail?.minus(m.headH), m.tileH, m.gapSmall, cap)
                    grid(ctx, sc, v, R.id.body, kid, tiles.take(rows * 2))
                }
            }
            Tier.TWO -> {
                if (size == WidgetSize.SMALL && (avail == null || 2 * m.tileH + m.gapSmall <= avail)) {
                    // Klein: je Kind eine Kachel mit dem Vornamen als erster
                    // Zeile (WidgetModel.namedTileFor, Pixel 28.10.26).
                    p.kids.forEachIndexed { i, kid ->
                        if (i > 0) v.addView(R.id.body, gap(ctx, sc, R.layout.widget_vgap_small))
                        v.addView(R.id.body, row(ctx, sc, kid, listOf(WidgetModel.namedTileFor(kid, l, today, now))))
                    }
                } else if (size == WidgetSize.SMALL && !WidgetModel.twoKidsFit(avail, m.nameH, m.tileH, m.gap)) {
                    // Zu niedrig für zwei Namen und zwei dreizeilige Kacheln:
                    // die kompakten Zellen wie ab drei Kindern (WidgetModel.twoKidsFit).
                    many(ctx, sc, v, p, size, today, now, avail, m)
                } else if (size == WidgetSize.SMALL) {
                    // Klein: je Kind Vorname und die wichtigste Kachel.
                    p.kids.forEachIndexed { i, kid ->
                        if (i > 0) v.addView(R.id.body, gap(ctx, sc, R.layout.widget_vgap))
                        v.addView(R.id.body, nameLine(ctx, sc, kid))
                        WidgetModel.tilesFor(kid, l, today, now, false).firstOrNull()?.let {
                            v.addView(R.id.body, row(ctx, sc, kid, listOf(it)))
                        }
                    }
                } else {
                    // Je Kind eine Zeile: Kürzel und Name links, Kacheln rechts;
                    // groß bis zwei Reihen (Tablet bis drei, mittel bis zwei),
                    // wenn beide Kinder hineinpassen.
                    val rows = WidgetScale.twoKidRows(size, tablet, avail, m)
                    p.kids.forEachIndexed { i, kid ->
                        if (i > 0) v.addView(R.id.body, gap(ctx, sc, R.layout.widget_vgap))
                        val tiles = WidgetModel.tilesFor(kid, l, today, now, false)
                        v.addView(R.id.body, kidRow(ctx, sc, kid, tiles.take(rows * 2)))
                    }
                }
            }
            Tier.MANY -> many(ctx, sc, v, p, size, today, now, avail, m)
        }
        return v
    }

    /** Ab drei Kindern (widget5_c/d). */
    private fun many(
        ctx: Context,
        sc: Scaler,
        v: RemoteViews,
        p: Payload,
        size: WidgetSize,
        today: LocalDate,
        now: LocalTime,
        avail: Float?,
        m: WidgetMetrics,
    ) {
        val l = p.labels
        val shown = when (size) {
            // Klein: je Kind eine kompakte Zeile, nur Name und Art.
            WidgetSize.SMALL -> {
                val n = WidgetModel.rowsThatFit(avail?.minus(m.footH), m.cellH, m.gapSmall, WidgetModel.MAX_KIDS)
                val kids = p.kids.take(n)
                kids.forEachIndexed { i, kid ->
                    if (i > 0) v.addView(R.id.body, gap(ctx, sc, R.layout.widget_vgap_small))
                    val r = RemoteViews(ctx.packageName, R.layout.widget_row)
                    r.addView(R.id.row, cell(ctx, sc, kid, WidgetModel.cellFor(kid, l, today, now, detailed = false)))
                    v.addView(R.id.body, r)
                }
                kids.size
            }
            // Mittel: zwei kompakte Zellen je Reihe, Fußzeile mit Arbeiten
            // und Aufgaben aller Kinder.
            WidgetSize.MEDIUM -> {
                val rows = WidgetModel.rowsThatFit(avail?.minus(m.headH + m.footH), m.cellH, m.gapSmall, WidgetModel.MAX_KIDS / 2)
                val kids = p.kids.take(rows * 2)
                kids.chunked(2).forEachIndexed { i, pair ->
                    if (i > 0) v.addView(R.id.body, gap(ctx, sc, R.layout.widget_vgap_small))
                    val r = RemoteViews(ctx.packageName, R.layout.widget_row)
                    pair.forEachIndexed { j, kid ->
                        if (j > 0) r.addView(R.id.row, gap(ctx, sc, R.layout.widget_hgap))
                        r.addView(R.id.row, cell(ctx, sc, kid, WidgetModel.cellFor(kid, l, today, now, detailed = true)))
                    }
                    if (pair.size == 1) {
                        r.addView(R.id.row, gap(ctx, sc, R.layout.widget_hgap))
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
                val n = WidgetModel.rowsThatFit(avail?.minus(m.headH + m.footH), m.tileH, m.gap, WidgetModel.MAX_KIDS)
                val kids = p.kids.take(n)
                kids.forEachIndexed { i, kid ->
                    if (i > 0) v.addView(R.id.body, gap(ctx, sc, R.layout.widget_vgap))
                    v.addView(R.id.body, kidRow(ctx, sc, kid, WidgetModel.tilesFor(kid, l, today, now, false).take(2)))
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
    private fun grid(ctx: Context, sc: Scaler, v: RemoteViews, parent: Int, kid: Kid, tiles: List<Tile>) {
        tiles.chunked(2).forEachIndexed { i, pair ->
            if (i > 0) v.addView(parent, gap(ctx, sc, R.layout.widget_vgap_small))
            v.addView(parent, row(ctx, sc, kid, pair, pairs = true))
        }
    }

    /**
     * Eine Reihe: eine Kachel über die volle Breite, oder (pairs) zwei
     * gleich breite; eine einzelne zweite Hälfte bleibt leer (widget5_e).
     */
    private fun row(ctx: Context, sc: Scaler, kid: Kid, tiles: List<Tile>, pairs: Boolean = false): RemoteViews {
        val r = RemoteViews(ctx.packageName, R.layout.widget_row)
        tiles.forEachIndexed { i, t ->
            if (i > 0) r.addView(R.id.row, gap(ctx, sc, R.layout.widget_hgap))
            r.addView(R.id.row, tile(ctx, sc, kid, t))
        }
        if (pairs && tiles.size == 1) {
            r.addView(R.id.row, gap(ctx, sc, R.layout.widget_hgap))
            r.addView(R.id.row, RemoteViews(ctx.packageName, R.layout.widget_filler))
        }
        return r
    }

    /** Kind-Zeile (2 Kinder, groß ab 3): Kürzel im Kreis, Vorname, Kacheln. */
    private fun kidRow(ctx: Context, sc: Scaler, kid: Kid, tiles: List<Tile>): RemoteViews {
        val k = RemoteViews(ctx.packageName, R.layout.widget_kid)
        k.setInt(R.id.kid_avatar, "setBackgroundResource", dots[color(kid)])
        k.setTextViewText(R.id.kid_initial, initial(kid.name))
        k.setTextViewText(R.id.kid_name, kid.name)
        sc.kid(k)
        k.removeAllViews(R.id.kid_tiles)
        tiles.chunked(2).forEachIndexed { i, pair ->
            if (i > 0) k.addView(R.id.kid_tiles, gap(ctx, sc, R.layout.widget_vgap_small))
            k.addView(R.id.kid_tiles, row(ctx, sc, kid, pair, pairs = true))
        }
        return k
    }

    /** Punkt in der Kinderfarbe und Vorname (klein). */
    private fun nameLine(ctx: Context, sc: Scaler, kid: Kid): RemoteViews {
        val n = RemoteViews(ctx.packageName, R.layout.widget_name)
        n.setInt(R.id.name_dot, "setBackgroundResource", dots[color(kid)])
        n.setTextViewText(R.id.name_text, kid.name)
        sc.name(n)
        return n
    }

    /** Kleine Kachel (Entwurf 5, _Mini). */
    private fun tile(ctx: Context, sc: Scaler, kid: Kid, t: Tile): RemoteViews {
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
        sc.tile(v)
        return v
    }

    /** Kompakte Zelle (Entwurf 5, _Compact). */
    private fun cell(ctx: Context, sc: Scaler, kid: Kid, cell: Cell): RemoteViews {
        val c = color(kid)
        val layout = when (cell.kind) {
            TileKind.CANCEL -> R.layout.widget_cell_cancel
            TileKind.CHANGE, TileKind.ROOM -> R.layout.widget_cell_change
            // Veraltet: grau wie Arbeit/Aufgaben, nicht in der Kinderfarbe.
            TileKind.STALE -> R.layout.widget_cell_info
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
        sc.cell(v)
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
        TileKind.STALE -> R.drawable.ic_widget_stale
    }

    private fun line(v: RemoteViews, id: Int, text: String) {
        v.setTextViewText(id, text)
        v.setViewVisibility(id, if (text.isEmpty()) View.GONE else View.VISIBLE)
    }

    /** Abstand (widget_vgap, widget_vgap_small, widget_hgap) im Maßstab. */
    private fun gap(ctx: Context, sc: Scaler, layout: Int): RemoteViews {
        val g = RemoteViews(ctx.packageName, layout)
        when (layout) {
            R.layout.widget_vgap -> sc.gapTop(g, R.dimen.widget_gap)
            R.layout.widget_vgap_small -> sc.gapTop(g, R.dimen.widget_gap_small)
            R.layout.widget_hgap -> sc.gapStart(g, R.dimen.widget_gap_small)
        }
        return g
    }

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

/**
 * Vergrößert die festen Maße der Layouts um den Maßstab [s]
 * (WidgetScale.scale): Schrift (setTextViewTextSize, sp) und Innenabstände
 * (setViewPadding) auf jedem Android; Kreise, Symbole, Punkte, die
 * Namensspalte und Außenabstände (setViewLayoutWidth/Height/Margin) erst ab
 * Android 12 – diese Aufrufe gibt es davor nicht. Die Grundwerte kommen aus
 * res/values/widget_dimens.xml, nicht als Zahl von hier.
 *
 * Ursache (Foto Tablet 28.10.26): Schrift 12 sp und Maße in dp sind auf
 * einer Tablet-Fläche winzig. Grenze: Bei [s] = 1 (jedes Telefon) bleibt
 * jeder Aufruf aus – das Widget ist dort Zeichen für Zeichen das bisherige.
 * Vor Android 12 bleiben Kreise und Symbole in Telefongröße, und die
 * Namensspalte (Kürzel, Vorname) wächst gar nicht, weil ihr Kreis und ihre
 * Breite fest sind; die Kacheln daneben wachsen trotzdem.
 */
private class Scaler(ctx: Context, val s: Float) {
    private val on = s > 1f
    private val res = ctx.resources
    private val density = res.displayMetrics.density

    /** Größen und Außenabstände nur ab Android 12 (s. o.). */
    private val boxes = on && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S

    private fun dp(id: Int) = res.getDimension(id) / density * s

    private fun px(id: Int) = Math.round(res.getDimension(id) * s)

    private fun text(v: RemoteViews, id: Int, sp: Float = WidgetScale.TEXT_SP) {
        if (on) v.setTextViewTextSize(id, TypedValue.COMPLEX_UNIT_SP, sp * s)
    }

    private fun pad(v: RemoteViews, id: Int, h: Int, vert: Int) {
        if (on) v.setViewPadding(id, px(h), px(vert), px(h), px(vert))
    }

    private fun square(v: RemoteViews, id: Int, dim: Int) {
        if (boxes && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            v.setViewLayoutWidth(id, dp(dim), TypedValue.COMPLEX_UNIT_DIP)
            v.setViewLayoutHeight(id, dp(dim), TypedValue.COMPLEX_UNIT_DIP)
        }
    }

    private fun margin(v: RemoteViews, id: Int, type: Int, dim: Int) {
        if (boxes && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            v.setViewLayoutMargin(id, type, dp(dim), TypedValue.COMPLEX_UNIT_DIP)
        }
    }

    /** Rand, Kopf und Fußzeile (widget_root). */
    fun root(v: RemoteViews) {
        pad(v, android.R.id.background, R.dimen.widget_padding, R.dimen.widget_padding)
        text(v, R.id.head_day)
        text(v, R.id.head_stand)
        text(v, R.id.foot_exam_text)
        text(v, R.id.foot_hw_text)
        text(v, R.id.foot_more)
        text(v, R.id.no_data)
        if (!boxes) return
        margin(v, R.id.head, RemoteViews.MARGIN_BOTTOM, R.dimen.widget_gap)
        square(v, R.id.head_dot, R.dimen.widget_dot)
        margin(v, R.id.head_dot, RemoteViews.MARGIN_END, R.dimen.widget_gap_small)
        square(v, R.id.head_sync, R.dimen.widget_icon_small)
        margin(v, R.id.head_stand, RemoteViews.MARGIN_START, R.dimen.widget_gap_hair)
        margin(v, R.id.footer, RemoteViews.MARGIN_TOP, R.dimen.widget_gap)
        margin(v, R.id.foot_exam, RemoteViews.MARGIN_END, R.dimen.widget_foot_gap)
        square(v, R.id.foot_exam_icon, R.dimen.widget_icon_foot)
        square(v, R.id.foot_hw_icon, R.dimen.widget_icon_foot)
        margin(v, R.id.foot_exam_text, RemoteViews.MARGIN_START, R.dimen.widget_gap_tiny)
        margin(v, R.id.foot_hw_text, RemoteViews.MARGIN_START, R.dimen.widget_gap_tiny)
    }

    /** Kachel (widget_mini_*). */
    fun tile(v: RemoteViews) {
        pad(v, R.id.tile_bg, R.dimen.widget_tile_pad_h, R.dimen.widget_tile_pad_v)
        text(v, R.id.tile_l1)
        text(v, R.id.tile_l2)
        text(v, R.id.tile_l3)
        square(v, R.id.tile_circle, R.dimen.widget_circle)
        square(v, R.id.tile_icon, R.dimen.widget_circle_icon)
        margin(v, R.id.tile_text, RemoteViews.MARGIN_START, R.dimen.widget_gap_small)
    }

    /** Kompakte Zelle (widget_cell_*). */
    fun cell(v: RemoteViews) {
        pad(v, R.id.cell_bg, R.dimen.widget_tile_pad_h, R.dimen.widget_cell_pad_v)
        text(v, R.id.cell_l1)
        text(v, R.id.cell_l2)
        square(v, R.id.cell_circle, R.dimen.widget_circle)
        square(v, R.id.cell_icon, R.dimen.widget_circle_icon)
        margin(v, R.id.cell_text, RemoteViews.MARGIN_START, R.dimen.widget_gap_small)
        square(v, R.id.cell_dot, R.dimen.widget_dot_small)
        margin(v, R.id.cell_l1, RemoteViews.MARGIN_START, R.dimen.widget_gap_tiny)
    }

    /**
     * Kind-Zeile (widget_kid): Namensspalte nur ab Android 12 – Kürzel und
     * Vorname liegen in Kreis und Spalte fester Breite (s. Klasse).
     */
    fun kid(v: RemoteViews) {
        margin(v, R.id.kid_tiles, RemoteViews.MARGIN_START, R.dimen.widget_gap_tiny)
        if (!boxes || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        v.setViewLayoutWidth(R.id.kid_col, dp(R.dimen.widget_avatar_col), TypedValue.COMPLEX_UNIT_DIP)
        v.setViewPadding(R.id.kid_col, 0, px(R.dimen.widget_gap_tiny), 0, 0)
        square(v, R.id.kid_avatar, R.dimen.widget_avatar)
        text(v, R.id.kid_initial)
        text(v, R.id.kid_name, WidgetScale.NAME_SP)
        margin(v, R.id.kid_name, RemoteViews.MARGIN_TOP, R.dimen.widget_gap_hair)
    }

    /** Namenszeile (widget_name). */
    fun name(v: RemoteViews) {
        text(v, R.id.name_text)
        square(v, R.id.name_dot, R.dimen.widget_dot)
        margin(v, R.id.name_text, RemoteViews.MARGIN_START, R.dimen.widget_gap_small)
        margin(v, R.id.name_row, RemoteViews.MARGIN_BOTTOM, R.dimen.widget_gap_tiny)
    }

    /** Senkrechter Abstand (Höhe als paddingTop, widget_vgap*.xml). */
    fun gapTop(v: RemoteViews, dim: Int) {
        if (on) v.setViewPadding(R.id.gap, 0, px(dim), 0, 0)
    }

    /** Waagerechter Abstand (Breite als Innenabstand, widget_hgap.xml). */
    fun gapStart(v: RemoteViews, dim: Int) {
        if (on) v.setViewPadding(R.id.gap, px(dim), 0, 0, 0)
    }
}
