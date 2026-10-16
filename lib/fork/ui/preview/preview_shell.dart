import 'package:flutter/material.dart';

import '../kit.dart';
import '../today/today_model.dart';
import '../plan/plan_model.dart' show GroupChoice;
import '../plan/plan_page.dart';
import '../today/today_page.dart';
import 'demo_plan.dart';
import 'demo_family.dart';

/// Vorschau der neuen Oberfläche, erreichbar über Einstellungen.
///
/// Ursache: Gestaltung braucht Abnahme auf dem Gerät (Pixel 9a), bevor die
/// echte Anbindung gebaut wird. Grenze: „Heute“ und „Plan“ sind gebaut, mit
/// erfundenen Daten ([demoFamily], [demoPlans]); die übrigen Ziele zeigen
/// einen Platzhalter, Antippen löst nichts im Portal aus.
class PreviewShell extends StatefulWidget {
  const PreviewShell({super.key});

  @override
  State<PreviewShell> createState() => _PreviewShellState();
}

class _PreviewShellState extends State<PreviewShell> {
  int _index = 0;
  final FamilyToday _data = demoFamily();
  final _plans = demoPlans();
  Map<int, GroupChoice> _choices = {};

  void _notYet(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$what – in der Vorschau noch ohne Funktion')),
      );
  }

  static const _dest = [
    (Icons.home_outlined, Icons.home, 'Heute'),
    (Icons.calendar_view_week_outlined, Icons.calendar_view_week, 'Plan'),
    (Icons.chat_bubble_outline, Icons.chat_bubble, 'Nachrichten'),
    (Icons.event_outlined, Icons.event, 'Termine'),
    (Icons.more_horiz, Icons.more_horiz, 'Mehr'),
  ];

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    // Schrift des Kits auch für Material-Bausteine (SnackBar, Knöpfe).
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: kitFont),
      ),
      child: Scaffold(
        backgroundColor: k.p.bg,
        // Inhalt läuft unter der schwebenden Leiste weiter; deren Höhe kommt
        // über MediaQuery.padding.bottom bei TodayPage an.
        extendBody: true,
        body: switch (_index) {
          0 => TodayPage(
            data: _data,
            onReportAbsence: (c) => _notYet('Krankmeldung für ${c.firstName}'),
            onOpenHomework: (c) => _notYet('Hausaufgaben von ${c.firstName}'),
            onOpenMessages: (c) => _notYet('Nachrichten von ${c.firstName}'),
            onOpenCalendar: () => setState(() => _index = 3),
          ),
          1 => PlanPage(
            plans: _plans,
            now: _data.now,
            initialChoices: _choices,
            onChoicesChanged: (c) => _choices = {
              for (final e in c.entries) e.key: {...e.value},
            },
          ),
          _ => _Placeholder(label: _dest[_index].$3),
        },
        bottomNavigationBar: FloatingNavBar(
          selected: _index,
          items: _dest,
          onSelect: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

/// Schwebende Leiste (Pille) aus dem Entwurf A + C.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.selected,
    required this.items,
    required this.onSelect,
  });

  final int selected;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final inset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Sz.navMargin,
        0,
        Sz.navMargin,
        Sz.navBottom + inset,
      ),
      child: Container(
        height: Sz.navHeight,
        padding: const EdgeInsets.symmetric(horizontal: Sp.s),
        decoration: BoxDecoration(
          color: k.p.navBg,
          borderRadius: BorderRadius.circular(Rad.nav),
          boxShadow: k.navShadow,
        ),
        // Jedes Ziel bekommt ein Fünftel der Breite. Ursache: Mit freier
        // Breite lief die Leiste bei großer Systemschrift um bis zu 220 px
        // über („Nachrichten“, Test today_page_test, Schrift ×1,3).
        child: Row(
          children: [
            for (final (i, (icon, iconSel, label)) in items.indexed)
              Expanded(
                child: _NavItem(
                  icon: i == selected ? iconSel : icon,
                  label: label,
                  selected: i == selected,
                  onTap: () => onSelect(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final fg = selected ? k.p.onNavSelected : k.p.muted;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.navItem),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.xs, vertical: Sp.xs + Sp.xxs),
          decoration: BoxDecoration(
            color: selected ? k.p.navSelected : null,
            borderRadius: BorderRadius.circular(Rad.navItem),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: Sz.navIcon, color: fg),
              const SizedBox(height: Sp.xxs),
              // Zu lange Beschriftung wird verkleinert, nie abgeschnitten
              // oder umgebrochen („Stundenpla-n“ im Lanis-Original).
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: k.navLabel(selected),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: k.pageTitle),
            const SizedBox(height: Sp.l),
            Text(
              'Entwurf folgt nach Abnahme von „Heute“ und „Plan“.',
              style: k.meta,
            ),
            const SizedBox(height: Sp.l),
            TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close),
              label: Text('Vorschau schließen', style: k.button(k.p.ink)),
            ),
          ],
        ),
      ),
    );
  }
}
