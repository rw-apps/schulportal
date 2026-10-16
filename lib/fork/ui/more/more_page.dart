import 'package:flutter/material.dart';

import '../kit.dart';

/// Ein Eintrag unter „Mehr“: Dienste und Aktionen, die keinen eigenen
/// Bereich brauchen (Konzept 17.10.26).
class MoreEntry {
  const MoreEntry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onTap;
}

/// Bereich „Mehr“: Einträge, darunter die Schriftgröße der Oberfläche.
class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.font,
    required this.onFont,
    this.entries = const [],
  });

  final KitFontStep font;
  final ValueChanged<KitFontStep> onFont;
  final List<MoreEntry> entries;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(Sp.page, Sp.xl, Sp.page, bottom + Sp.xl),
        children: [
          Text('Mehr', style: k.pageTitle),
          const SizedBox(height: Sp.l),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: _EntryTile(entry: e),
            ),
          const SizedBox(height: Sp.l),
          Text('Schriftgröße', style: k.section),
          const SizedBox(height: Sp.xs),
          Text(
            'Gilt für die neue Oberfläche, zusätzlich zur Einstellung des '
            'Handys.',
            style: k.meta,
          ),
          const SizedBox(height: Sp.m),
          for (final step in KitFontStep.values)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: Material(
                color: step == font ? k.kid(0).tint : k.p.card,
                borderRadius: BorderRadius.circular(Rad.signal),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.signal),
                  onTap: () => onFont(step),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Sp.l,
                      vertical: Sp.m,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            step.label,
                            style: k.planSubject(k.p.ink),
                          ),
                        ),
                        if (step == font)
                          Icon(
                            Icons.check,
                            size: Sz.icon,
                            color: k.kid(0).label,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final MoreEntry entry;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Material(
      color: k.p.card,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.signal),
        onTap: entry.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.m),
          child: Row(
            children: [
              Icon(entry.icon, size: Sz.navIcon, color: k.p.ink),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.label, style: k.planSubject(k.p.ink)),
                    if (entry.detail != null)
                      Text(entry.detail!, style: k.planMeta(k.p.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: Sz.icon, color: k.p.muted),
            ],
          ),
        ),
      ),
    );
  }
}
