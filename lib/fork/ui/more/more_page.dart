import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
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

/// Bereich „Mehr“: Dienste und Aktionen; Einstellungen als eigener Eintrag.
class MorePage extends StatelessWidget {
  const MorePage({super.key, this.entries = const []});

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
          Text(context.t.navMore, style: k.pageTitle),
          const SizedBox(height: Sp.l),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: _EntryTile(entry: e),
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
Future<String?> askMensaUrl(
  BuildContext context,
  String? current, {
  String? childName,
  String? suggestion,
}) => showDialog<String>(
  context: context,
  builder: (context) => _MensaUrlDialog(
    current: current,
    childName: childName,
    suggestion: current == null ? suggestion : null,
  ),
);

/// Eigenes Widget, damit der TextEditingController mit dem Dialog freigegeben
/// wird (Prüfbefund 17.10.26: vorher nie dispose).
class _MensaUrlDialog extends StatefulWidget {
  const _MensaUrlDialog({this.current, this.childName, this.suggestion});

  final String? current;
  final String? childName;

  /// Aus der App-Liste der Schule (mensaSuggestion); nur ohne eigene Adresse.
  final String? suggestion;

  @override
  State<_MensaUrlDialog> createState() => _MensaUrlDialogState();
}

class _MensaUrlDialogState extends State<_MensaUrlDialog> {
  late final _c = TextEditingController(
    text: widget.current ?? widget.suggestion ?? '',
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    return AlertDialog(
      title: Text(
        widget.childName == null
            ? t.mensaDialogTitle
            : t.mensaDialogTitleFor(widget.childName!),
        style: k.sheetTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.mensaDialogText, style: k.meta),
          if (widget.suggestion != null) ...[
            const SizedBox(height: Sp.s),
            Text(t.mensaSuggested, style: k.planMeta(k.p.ink)),
          ],
          const SizedBox(height: Sp.m),
          TextField(
            controller: _c,
            autofocus: true,
            keyboardType: TextInputType.url,
            style: k.body,
            decoration: InputDecoration(
              hintText: t.mensaDialogHint,
              hintStyle: k.meta,
            ),
          ),
        ],
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(t.delete, style: k.link),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel, style: k.link),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _c.text),
          child: Text(t.save, style: k.link),
        ),
      ],
    );
  }
}
