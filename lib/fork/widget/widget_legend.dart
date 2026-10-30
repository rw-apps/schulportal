import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../ui/kit.dart';

/// Erklärung der Widget-Symbole (Entwurf 10, Vorschlag 10, Abnahme
/// 30.10.26) im Blatt „Startbildschirm-Widget“ (settings_page.dart).
///
/// Ursache: Das Widget zeigt nur noch Symbole an fester Stelle (Rückmeldung
/// 30.10.26: „mehr visuell über Icons“); was ein Symbol heißt, soll man an
/// einer Stelle nachlesen können. Dieselben Symbole und Farben wie in Kotlin
/// (SchoolWidget.kt): Ausfall rot, Arbeit blau (onNavSelected), Aufgaben
/// neutral, Essen/Vertretung/Raum gelb. Grenze: Vertretung und Raum zeigt
/// das Widget nur beim Schülerkonto.
class WidgetLegend extends StatelessWidget {
  const WidgetLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    Widget row(IconData icon, Color bg, Color fg, String text) => Padding(
      padding: const EdgeInsets.only(bottom: Sp.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: Sz.hintBadge,
            height: Sz.hintBadge,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(Rad.badge),
            ),
            child: Icon(icon, size: Sz.hintBadgeIcon, color: fg),
          ),
          const SizedBox(width: Sp.m),
          Expanded(
            child: Text(text, style: k.meta.copyWith(color: k.p.ink)),
          ),
        ],
      ),
    );
    final blue = k.p.onNavSelected;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.l, Sp.s, Sp.l, Sp.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.widgetLegendTitle, style: k.tileTitle),
          const SizedBox(height: Sp.s),
          row(
            Icons.event_busy,
            k.p.cancel.bg,
            k.p.cancel.strong,
            t.widgetLegendTime,
          ),
          row(
            Icons.edit_note,
            blue.withValues(alpha: 0.18),
            blue,
            t.widgetLegendExam,
          ),
          row(
            Icons.menu_book_outlined,
            k.p.inset,
            k.p.ink,
            t.widgetLegendHomework,
          ),
          row(
            Icons.restaurant,
            k.p.change.bg,
            k.p.change.strong,
            t.widgetLegendMeal,
          ),
          row(
            Icons.switch_account,
            k.p.change.bg,
            k.p.change.strong,
            t.widgetLegendSub,
          ),
          row(
            Icons.directions_walk,
            k.p.change.bg,
            k.p.change.strong,
            t.widgetLegendRoom,
          ),
          const SizedBox(height: Sp.xs),
          Text(t.widgetLegendTap, style: k.planMeta(k.p.muted)),
          const SizedBox(height: Sp.s),
          Text(t.widgetLegendPerWidget, style: k.planMeta(k.p.muted)),
        ],
      ),
    );
  }
}
