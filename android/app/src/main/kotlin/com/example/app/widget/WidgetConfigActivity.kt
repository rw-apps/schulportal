package com.example.app.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.os.Bundle
import android.util.TypedValue
import android.widget.Button
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import com.example.app.R

/**
 * „Kinder im Widget“ je Widget, Entwurf 10 (Abnahme 30.10.26, Vertrag Punkt 7):
 * schlichte Mehrfachauswahl der Kinder aus der Datei plus „Alle Kinder“.
 * Gespeichert in „fork_widget_instances“, Schlüssel kids_<appWidgetId>
 * (WidgetModel.selectionKey), als JSON-Liste der accounts; gelesen von
 * WidgetModel.selected. Startet beim Hinzufügen (vor Android 12 immer, ab
 * Android 12 nur auf Wunsch – widgetFeatures configuration_optional) und über
 * „Widget einstellen“ (reconfigurable).
 *
 * Ohne Flutter, ohne AndroidX: Ursache: Für die Einstellung müsste sonst die
 * ganze Flutter-Engine starten (MainActivity, HomeWidget.
 * initiallyLaunchedFromHomeWidgetConfigure); ein Dialog aus Systembausteinen
 * öffnet sofort und braucht nur die Datei. Grenze: Aussehen
 * des Systems (WidgetConfigTheme), nicht das der App. Die Texte kommen aus
 * der Datei (labels.config*); fehlt sie, nur der no_data-Hinweis.
 */
class WidgetConfigActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        widgetId = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        // Gleich RESULT_OK: Ursache: Beim Hinzufügen entfernt Android das
        // Widget wieder, wenn die Einstellung mit RESULT_CANCELED endet (Zurück).
        // So bleibt es mit der Vorgabe (alle mit shown: true) stehen.
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))

        val pad = dp(24)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad, pad, dp(12))
        }
        val p = SchoolWidgetRenderer.payload(this)
        if (p == null || p.kids.isEmpty()) {
            // Ohne Datei (oder alte Fassung): Hinweis „App öffnen“, Ende mit OK.
            root.addView(text(getString(R.string.widget_no_data), 16f, bold = false))
            root.addView(button(getString(android.R.string.ok)) { finish() })
            setContentView(root)
            return
        }
        val l = p.labels
        root.addView(text(l.configTitle, 20f, bold = true))
        val prefs = getSharedPreferences(SchoolWidgetRenderer.INSTANCES, Context.MODE_PRIVATE)
        val chosen = WidgetModel.selected(p.kids, prefs.getString(WidgetModel.selectionKey(widgetId), null))
            .map { it.account }.toSet()
        val all = CheckBox(this).apply { text = l.configAll }
        val boxes = p.kids.map { k -> CheckBox(this).apply { text = k.name; isChecked = k.account in chosen } }
        val ok = button(l.configOk.ifEmpty { getString(android.R.string.ok) }) {
            val accounts = p.kids.filterIndexed { i, _ -> boxes[i].isChecked }.map { it.account }
            prefs.edit().putString(WidgetModel.selectionKey(widgetId), WidgetModel.encodeSelection(accounts)).apply()
            redraw()
            finish()
        }
        fun sync() {
            all.isChecked = boxes.all { it.isChecked }
            // Keins gewählt: Fertig gesperrt, sonst fiele das Widget still auf
            // die Vorgabe zurück (WidgetModel.selected).
            ok.isEnabled = boxes.any { it.isChecked }
        }
        all.setOnClickListener {
            boxes.forEach { b -> b.isChecked = all.isChecked }
            sync()
        }
        boxes.forEach { b -> b.setOnClickListener { sync() } }
        sync()
        root.addView(all)
        boxes.forEach { root.addView(it) }
        root.addView(ok)
        setContentView(ScrollView(this).apply { addView(root) })
    }

    /** Nur dieses Widget neu zeichnen – über seinen Anbieter (onUpdate). */
    private fun redraw() {
        val info = AppWidgetManager.getInstance(this).getAppWidgetInfo(widgetId) ?: return
        sendBroadcast(
            Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .setComponent(info.provider)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(widgetId)),
        )
    }

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    private fun text(s: String, sp: Float, bold: Boolean) = TextView(this).apply {
        text = s
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
        if (bold) setTypeface(typeface, Typeface.BOLD)
        setPadding(0, 0, 0, dp(12))
    }

    private fun button(s: String, onClick: () -> Unit) = Button(this).apply {
        text = s
        setOnClickListener { onClick() }
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply { topMargin = dp(12) }
    }
}
