import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../kid_chips.dart';
import '../kit.dart';
import '../pinned_page.dart';
import '../segments.dart';

/// Bausteine der Einstellungsseiten (Entwurf 20.10.26 „verdichtet“,
/// abgenommen): Abschnitt mit Überschrift, Gruppe als eine Karte mit
/// Trennlinien, Zeilen mit Symbol, Schalter- und Umschalterzeilen.
///
/// Ursache: Vorher war jede Wahl eine eigene Karte (Design, Schriftgröße
/// und Sprache allein elf Zeilen); die Seite wurde unübersichtlich
/// (Rückmeldung 20.10.26). Gemeinsam für Einstellungen, „Über die App“ und
/// „Was und wann“.

/// Kopf einer Unterseite: Zurück und Titel.
class SettingsHeader extends StatelessWidget {
  const SettingsHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    // Pfeil schon in der Pillenzeile (BackInChips): nur der Titel.
    final back = !BackInChips.of(context);
    return Row(
      children: [
        if (back) ...[
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back, color: k.p.ink),
            tooltip: context.t.back,
          ),
          const SizedBox(width: Sp.xs),
        ] else
          const SizedBox(width: Sp.xs),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(title, style: k.pageTitle),
          ),
        ),
      ],
    );
  }
}

/// Seite mit Kopf und Liste; der Kopf (Zurück, Titel) steht fest
/// (PinnedPage, Rückmeldung 21.10.26).
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.onRefresh,
  });

  final String title;
  final List<Widget> children;

  /// Kleine Zeile unter dem Titel (z. B. Ordner in der Dateiablage).
  final String? subtitle;

  /// Ziehen zum Aktualisieren; null = ohne.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Scaffold(
      backgroundColor: k.p.bg,
      body: PinnedPage(
        headerPadding: const EdgeInsets.fromLTRB(Sp.page, Sp.m, Sp.page, 0),
        bodyPadding: const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, Sp.xl),
        onRefresh: onRefresh,
        header: [
          SettingsHeader(title: title),
          if (subtitle case final sub? when sub.isNotEmpty)
            Padding(
              // Bündig mit dem Titel neben dem Zurück-Pfeil.
              padding: const EdgeInsets.only(left: Sp.xxl + Sp.l),
              child: Text(sub, style: k.cardMeta),
            ),
        ],
        children: children,
      ),
    );
  }
}

/// Überschrift und darunter eine Gruppe ([SettingsGroup]); [note] klein
/// unter der Gruppe.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.note,
  });

  final String title;
  final List<Widget> children;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Sp.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Sp.xs, bottom: Sp.s),
            child: Text(title, style: k.section),
          ),
          SettingsGroup(children: children),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(left: Sp.xs, top: Sp.s),
              child: Text(note!, style: k.planMeta(k.p.muted)),
            ),
        ],
      ),
    );
  }
}

/// Mehrere Zeilen in einer Karte, getrennt durch feine Linien.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Material(
      color: k.p.card,
      borderRadius: BorderRadius.circular(Rad.signal),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: Sp.l,
                endIndent: Sp.l,
                color: k.p.line,
              ),
            c,
          ],
        ],
      ),
    );
  }
}

/// Zeile mit Symbol (oder [lead]), Titel, bis zu zwei Zusatzzeilen; mit
/// [onTap] und ohne [trailing] ein Pfeil rechts. [ink] färbt Symbol und
/// Titel (z. B. Abmelden).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.icon,
    this.lead,
    this.detail,
    this.extra,
    this.onTap,
    this.trailing,
    this.ink,
    this.chevron = true,
  });

  final String label;
  final IconData? icon;
  final Widget? lead;
  final String? detail;
  final String? extra;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? ink;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final c = ink ?? k.p.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.m),
        child: Row(
          children: [
            if (lead != null)
              lead!
            else if (icon != null)
              Icon(icon, size: Sz.navIcon, color: c),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: k.planSubject(c)),
                  if (detail != null && detail!.isNotEmpty)
                    Text(detail!, style: k.planMeta(k.p.muted)),
                  if (extra != null && extra!.isNotEmpty)
                    Text(extra!, style: k.planMeta(k.p.muted)),
                ],
              ),
            ),
            ?trailing,
            if (trailing == null && onTap != null && chevron)
              Icon(Icons.chevron_right, size: Sz.icon, color: k.p.muted),
          ],
        ),
      ),
    );
  }
}

/// Zeile mit Schalter rechts; Antippen der Zeile schaltet ebenfalls.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
    this.detail,
  });

  final String label;
  final IconData? icon;
  final String? detail;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final off = onChanged == null;
    return SettingsRow(
      label: label,
      icon: icon,
      detail: detail,
      ink: off ? k.p.muted : null,
      onTap: off ? null : () => onChanged!(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

/// Bezeichnung und darunter ein Umschalter über die volle Breite
/// (Design, Schriftgröße).
class SettingsSegmentsRow extends StatelessWidget {
  const SettingsSegmentsRow({
    super.key,
    required this.label,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Padding(
      padding: const EdgeInsets.all(Sp.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: k.planMeta(k.p.muted)),
          const SizedBox(height: Sp.s),
          PillSegments(
            labels: labels,
            selected: selected,
            onChanged: onChanged,
            bg: k.p.inset,
            ink: k.p.ink,
          ),
        ],
      ),
    );
  }
}

/// Wahlzeile mit Haken (Sprache).
class SettingsChoiceRow extends StatelessWidget {
  const SettingsChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return SettingsRow(
      label: label,
      onTap: onTap,
      trailing: selected
          ? Icon(Icons.check, size: Sz.icon, color: k.kid(0).accent)
          : const SizedBox.shrink(),
    );
  }
}
