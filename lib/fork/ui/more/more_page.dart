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
    this.startNew,
    this.onStartNew,
  });

  final KitFontStep font;
  final ValueChanged<KitFontStep> onFont;
  final List<MoreEntry> entries;

  /// Startet die App mit der neuen Oberfläche? null = Schalter fehlt.
  final bool? startNew;
  final ValueChanged<bool>? onStartNew;

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
          if (startNew != null) ...[
            const SizedBox(height: Sp.s),
            Material(
              color: k.p.card,
              borderRadius: BorderRadius.circular(Rad.signal),
              child: SwitchListTile(
                value: startNew!,
                onChanged: onStartNew,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Rad.signal),
                ),
                title: Text(
                  'Mit der neuen Oberfläche starten',
                  style: k.planSubject(k.p.ink),
                ),
                subtitle: Text(
                  startNew!
                      ? 'Aus: Die App startet wieder mit der bisherigen Ansicht.'
                      : 'Die App startet mit der bisherigen Ansicht.',
                  style: k.planMeta(k.p.muted),
                ),
              ),
            ),
          ],
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

/// Fragt die Adresse der Mensa-Bestellseite ab. null = abgebrochen, '' =
/// Eintrag löschen.
Future<String?> askMensaUrl(BuildContext context, String? current) {
  final k = Kit.of(context);
  final c = TextEditingController(text: current ?? '');
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Bestellseite der Mensa', style: k.sheetTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adresse der Seite, auf der ihr das Essen bestellt. Die App '
            'öffnet sie im Browser; die Anmeldung bleibt dort.',
            style: k.meta,
          ),
          const SizedBox(height: Sp.m),
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: TextInputType.url,
            style: k.body,
            decoration: InputDecoration(
              hintText: 'z. B. bestellung.example.de',
              hintStyle: k.meta,
            ),
          ),
        ],
      ),
      actions: [
        if (current != null)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text('Löschen', style: k.link),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Abbrechen', style: k.link),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, c.text),
          child: Text('Speichern', style: k.link),
        ),
      ],
    ),
  );
}
