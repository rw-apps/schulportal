package com.example.app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import com.example.app.MainActivity
import com.example.app.R
import org.json.JSONObject
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.util.Locale

/**
 * Startbildschirm-Widget (Entwurf 4, Abnahme 28.10.26): zeigt NUR Abweichungen
 * vom Stundenplan – Ausfall, Vertretung, Raumwechsel – für heute und den
 * nächsten Schultag, sonst „Alles nach Plan“.
 *
 * Die Daten schreibt die App als fertige, übersetzte Texte
 * (lib/fork/widget/home_widget_data.dart → SharedPreferences des Pakets
 * home_widget). Hier wird nur noch nach dem aktuellen Datum gefiltert und
 * „heute“/„morgen“/Wochentag gewählt. Ursache: So stimmt das Widget auch nach
 * Mitternacht und nach dem Ende einer Stunde, ohne dass die App neu lädt
 * (Takt: updatePeriodMillis 30 Min., res/xml/widget_*_info.xml). Grenze: Was
 * die App nie geladen hat (Vertretungsplan für übermorgen), kann auch das
 * Widget nicht zeigen.
 */
abstract class SchoolWidgetBase : AppWidgetProvider() {
    protected abstract val small: Boolean

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            manager.updateAppWidget(id, SchoolWidgetRenderer.render(context, small))
        }
    }
}

/** Mittel 4 × 2 (Variante A): Kopf, bis zu zwei Kacheln, Fußzeile. */
class SchoolWidgetMedium : SchoolWidgetBase() {
    override val small = false
}

/** Klein 2 × 2 (Variante B): die dringendste Kachel, offene Aufgaben. */
class SchoolWidgetSmall : SchoolWidgetBase() {
    override val small = true
}

internal object SchoolWidgetRenderer {
    /** Ablage des Pakets home_widget (HomeWidgetPlugin.PREFERENCES). */
    private const val PREFS = "HomeWidgetPreferences"

    /** Gleicher Name wie homeWidgetDataKey in home_widget_data.dart. */
    private const val PAYLOAD_KEY = "fork_widget_payload"

    /** Tage, die die nächste Arbeit voraus sein darf (widgetExamDays). */
    private const val EXAM_DAYS = 7L

    // Farbfamilien der Kinder (KitPalette.kids, res/values/widget_colors.xml).
    // Als Ressourcen je Kind statt eingefärbt: Formen und Symbole lösen hell/
    // dunkel dann selbst auf (values-night), auch auf Android vor 12.
    private val dots = intArrayOf(
        R.drawable.widget_kid0_dot, R.drawable.widget_kid1_dot,
        R.drawable.widget_kid2_dot, R.drawable.widget_kid3_dot,
    )
    private val schools = intArrayOf(
        R.drawable.ic_widget_school_kid0, R.drawable.ic_widget_school_kid1,
        R.drawable.ic_widget_school_kid2, R.drawable.ic_widget_school_kid3,
    )
    private val calms = intArrayOf(
        R.drawable.widget_kid0_calm, R.drawable.widget_kid1_calm,
        R.drawable.widget_kid2_calm, R.drawable.widget_kid3_calm,
    )
    private val suns = intArrayOf(
        R.drawable.ic_widget_sun_kid0, R.drawable.ic_widget_sun_kid1,
        R.drawable.ic_widget_sun_kid2, R.drawable.ic_widget_sun_kid3,
    )
    private val onTints = intArrayOf(
        R.color.widget_kid0_on_tint, R.color.widget_kid1_on_tint,
        R.color.widget_kid2_on_tint, R.color.widget_kid3_on_tint,
    )
    private val metas = intArrayOf(
        R.color.widget_kid0_meta, R.color.widget_kid1_meta,
        R.color.widget_kid2_meta, R.color.widget_kid3_meta,
    )

    private class Item(
        val date: LocalDate,
        val kind: String,
        val title: String,
        val what: String,
        val slot: String,
        val detail: String?,
    )

    private class Labels(o: JSONObject?) {
        val today: String = o?.optString("today").orEmpty()
        val tomorrow: String = o?.optString("tomorrow").orEmpty()
        val weekdays: List<String> = o?.optJSONArray("weekdays")?.let { a ->
            List(a.length()) { a.optString(it) }
        } ?: emptyList()
        val calmTitle: String = o?.optString("calmTitle").orEmpty()
        val calmText: String = o?.optString("calmText").orEmpty()

        /** „heute“, „morgen“, sonst der Wochentag („Mo“ am Freitag). */
        fun day(d: LocalDate, today: LocalDate): String = when (d) {
            today -> this.today
            today.plusDays(1) -> tomorrow
            else -> weekdays.getOrNull(d.dayOfWeek.value - 1).orEmpty()
        }
    }

    fun render(ctx: Context, small: Boolean): RemoteViews {
        val v = RemoteViews(
            ctx.packageName,
            if (small) R.layout.widget_small else R.layout.widget_medium,
        )
        v.setOnClickPendingIntent(android.R.id.background, openApp(ctx))
        v.removeAllViews(R.id.tiles)
        val p = load(ctx)
        if (p == null) {
            // Noch nie Daten (App seit dem Hinzufügen nicht geöffnet bzw. Demo).
            v.setViewVisibility(R.id.no_data, View.VISIBLE)
            v.setViewVisibility(R.id.tiles, View.GONE)
            v.setViewVisibility(R.id.calm, View.GONE)
            v.setViewVisibility(if (small) R.id.foot_hw else R.id.footer, View.GONE)
            if (!small) {
                v.setViewVisibility(R.id.head_sync, View.GONE)
                v.setTextViewText(R.id.head_day, "")
                v.setTextViewText(R.id.head_stand, "")
            }
            return v
        }
        val today = LocalDate.now()
        val now = LocalTime.now()
        val labels = Labels(p.optJSONObject("labels"))
        val kid = Math.floorMod(p.optInt("kid", 0), dots.size)
        val items = visibleItems(p, today, now)

        if (!small) header(v, p, labels, kid, today)

        val shown = items.take(if (small) 1 else 2)
        if (shown.isEmpty()) {
            v.setViewVisibility(R.id.tiles, View.GONE)
            v.setViewVisibility(R.id.calm, View.VISIBLE)
            v.setInt(R.id.calm, "setBackgroundResource", calms[kid])
            v.setImageViewResource(R.id.calm_sun, suns[kid])
            v.setTextViewText(R.id.calm_title, labels.calmTitle)
            v.setTextViewText(R.id.calm_text, labels.calmText)
            textColor(ctx, v, R.id.calm_title, onTints[kid])
            textColor(ctx, v, R.id.calm_text, metas[kid])
        } else {
            v.setViewVisibility(R.id.calm, View.GONE)
            v.setViewVisibility(R.id.tiles, View.VISIBLE)
            shown.forEachIndexed { i, item ->
                if (i > 0) v.addView(R.id.tiles, RemoteViews(ctx.packageName, R.layout.widget_tile_gap))
                v.addView(R.id.tiles, tile(ctx, item, labels, today))
            }
        }
        v.setViewVisibility(R.id.no_data, View.GONE)

        // Fußzeile: offene Aufgaben (beide Größen), nächste Arbeit und „+N“
        // (nur mittel).
        val homework = p.optString("homework", "")
        v.setTextViewText(R.id.foot_hw_text, homework)
        v.setViewVisibility(R.id.foot_hw, if (homework.isEmpty()) View.GONE else View.VISIBLE)
        if (!small) {
            val exam = examText(p, labels, today)
            v.setTextViewText(R.id.foot_exam_text, exam.orEmpty())
            v.setViewVisibility(R.id.foot_exam, if (exam == null) View.INVISIBLE else View.VISIBLE)
            val more = items.size - shown.size
            v.setTextViewText(R.id.foot_more, if (more > 0) "+$more" else "")
            v.setViewVisibility(
                R.id.footer,
                if (homework.isEmpty() && exam == null && more <= 0) View.GONE else View.VISIBLE,
            )
        }
        return v
    }

    private fun header(v: RemoteViews, p: JSONObject, labels: Labels, kid: Int, today: LocalDate) {
        v.setInt(R.id.head_dot, "setBackgroundResource", dots[kid])
        v.setImageViewResource(R.id.head_school, schools[kid])
        // Datum aus der Datei (Muster der App-Sprache); fehlt der Tag (Datei
        // älter als eine Woche), bleibt nur der Wochentag.
        val day = p.optJSONObject("dates")?.optString(today.toString()).orEmpty()
        v.setTextViewText(R.id.head_day, day.ifEmpty { labels.weekdays.getOrNull(today.dayOfWeek.value - 1).orEmpty() })
        // Stand: Uhrzeit des Abrufs, von einem anderen Tag mit Wochentag – so
        // sieht man, wenn das Widget seit gestern nichts Neues bekommen hat.
        val stand = runCatching { LocalDateTime.parse(p.optString("stand")) }.getOrNull()
        if (stand == null) {
            v.setViewVisibility(R.id.head_sync, View.GONE)
            v.setTextViewText(R.id.head_stand, "")
        } else {
            // Locale.ROOT: immer lateinische Ziffern wie in der App.
            val hm = String.format(Locale.ROOT, "%02d:%02d", stand.hour, stand.minute)
            val date = stand.toLocalDate()
            v.setViewVisibility(R.id.head_sync, View.VISIBLE)
            v.setTextViewText(
                R.id.head_stand,
                if (date == today) hm else "${labels.weekdays.getOrNull(date.dayOfWeek.value - 1).orEmpty()} $hm".trim(),
            )
        }
    }

    /**
     * Einträge ab heute; heutige, deren Stunde vorbei ist, fallen weg
     * („end“, nur mit Uhrzeiten der Schule). Reihenfolge wie geliefert
     * (Tag, dann Stunde) – damit steht die nächste Abweichung vorn.
     */
    private fun visibleItems(p: JSONObject, today: LocalDate, now: LocalTime): List<Item> {
        val a = p.optJSONArray("items") ?: return emptyList()
        val out = ArrayList<Item>()
        for (i in 0 until a.length()) {
            val o = a.optJSONObject(i) ?: continue
            val date = runCatching { LocalDate.parse(o.optString("date")) }.getOrNull() ?: continue
            if (date.isBefore(today)) continue
            if (date == today && o.has("end")) {
                val end = runCatching { LocalTime.parse(o.optString("end")) }.getOrNull()
                if (end != null && !now.isBefore(end)) continue
            }
            out.add(
                Item(
                    date = date,
                    kind = o.optString("kind"),
                    title = o.optString("title"),
                    what = o.optString("what"),
                    slot = o.optString("slot"),
                    detail = if (o.has("detail")) o.optString("detail") else null,
                ),
            )
        }
        return out
    }

    private fun tile(ctx: Context, item: Item, labels: Labels, today: LocalDate): RemoteViews {
        val cancel = item.kind == "cancel"
        val t = RemoteViews(
            ctx.packageName,
            if (cancel) R.layout.widget_tile_cancel else R.layout.widget_tile_change,
        )
        // Lagebild nach der Lage, nicht nach dem Fach (Rückmeldung 28.10.26).
        t.setImageViewResource(
            R.id.tile_icon,
            when (item.kind) {
                "cancel" -> R.drawable.ic_widget_event_busy
                "room" -> R.drawable.ic_widget_walk_change
                else -> R.drawable.ic_widget_switch_account
            },
        )
        t.setTextViewText(R.id.tile_when, labels.day(item.date, today))
        t.setTextViewText(R.id.tile_slot, item.slot)
        t.setTextViewText(R.id.tile_title, item.title)
        t.setTextViewText(R.id.tile_what, item.what)
        t.setTextViewText(R.id.tile_detail, item.detail.orEmpty())
        t.setViewVisibility(R.id.tile_detail, if (item.detail.isNullOrEmpty()) View.GONE else View.VISIBLE)
        return t
    }

    /** „Do Test“ – nur, wenn die Arbeit heute bis in 7 Tagen liegt. */
    private fun examText(p: JSONObject, labels: Labels, today: LocalDate): String? {
        val e = p.optJSONObject("exam") ?: return null
        val date = runCatching { LocalDate.parse(e.optString("date")) }.getOrNull() ?: return null
        if (date.isBefore(today) || date.isAfter(today.plusDays(EXAM_DAYS))) return null
        return "${labels.day(date, today)} ${e.optString("label")}".trim()
    }

    private fun load(ctx: Context): JSONObject? {
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(PAYLOAD_KEY, null)
            ?: return null
        return runCatching { JSONObject(raw) }.getOrNull()
    }

    /**
     * Textfarbe der Kinderfarbe. Ab Android 12 als Ressource, die der
     * Startbildschirm selbst hell/dunkel auflöst; davor als feste Farbe des
     * Augenblicks. Grenze (vor Android 12): Nach einem Wechsel hell/dunkel
     * stimmen die zwei Zeilen der ruhigen Fläche erst mit dem nächsten
     * Neuzeichnen (spätestens 30 Min.).
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
