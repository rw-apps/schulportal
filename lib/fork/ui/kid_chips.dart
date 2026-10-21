import 'package:flutter/material.dart';

import 'kit.dart';

/// Auswahl der Kinder als Pillen (Kalender, Bereiche mit [FamilySwitch]).
///
/// Mit [allLabel] steht vorn eine Pille „Alle“ ohne Farbpunkt; sie meldet
/// [onSelect] mit -1 und ist bei [selected] = -1 gewählt. Ursache
/// (Rückmeldung 18.10.26): In „Termine“ fehlte ein Filter je Kind; die
/// gemeinsame Liste bleibt dort der Normalfall.
class KidChips extends StatelessWidget {
  const KidChips({
    super.key,
    required this.kids,
    required this.selected,
    required this.onSelect,
    this.allLabel,
  });

  final List<({String name, int color})> kids;
  final int selected;
  final ValueChanged<int> onSelect;
  final String? allLabel;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    // Gewählt: volle Farbe (Kind) bzw. dunkel („Alle“) mit Haken; nicht
    // gewählt: weiß mit Rand und Farbpunkt. Ursache (Rückmeldung 20.10.26,
    // Bildschirmfoto Nachrichten: „schwer erkennbar, welches Profil
    // ausgewählt ist“): Vorher war „Alle“ gewählt grau auf grauem Grund und
    // die NICHT gewählten Kinder weiß – die Hervorhebung wirkte verkehrt.
    Widget chip({
      required bool sel,
      required VoidCallback onTap,
      required String label,
      required Color fill,
      required Color onFill,
      Color? dot,
    }) => Semantics(
      selected: sel,
      button: true,
      child: Material(
        color: sel ? fill : k.p.card,
        shape: StadiumBorder(
          side: sel ? BorderSide.none : BorderSide(color: k.p.line),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: Sz.buttonSmall,
            padding: const EdgeInsets.symmetric(horizontal: Sp.l),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sel)
                  Padding(
                    padding: const EdgeInsets.only(right: Sp.s),
                    child: Icon(Icons.check, size: Sz.icon, color: onFill),
                  )
                else if (dot != null)
                  Padding(
                    padding: const EdgeInsets.only(right: Sp.s),
                    child: Container(
                      width: Sz.dot + Sp.xxs,
                      height: Sz.dot + Sp.xxs,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Text(label, style: k.chipLabel(sel, onFill)),
              ],
            ),
          ),
        ),
      ),
    );

    return Wrap(
      spacing: Sp.s,
      runSpacing: Sp.s,
      children: [
        if (allLabel != null)
          chip(
            sel: selected < 0,
            onTap: () => onSelect(-1),
            label: allLabel!,
            fill: k.p.strong,
            onFill: k.p.onStrong,
          ),
        for (final (i, kid) in kids.indexed)
          chip(
            sel: i == selected,
            onTap: () => onSelect(i),
            label: kid.name,
            fill: k.kid(kid.color).accent,
            onFill: k.p.card,
            dot: k.kid(kid.color).accent,
          ),
      ],
    );
  }
}

/// Kind-Pillen fest oben über einer Seite – EIN Baustein für alle Reiter
/// (Heute, Kalender, Unterricht, Nachrichten, Mehr).
///
/// Ursache (Rückmeldung 20.10.26, „zentrale Logik für identisches
/// Aussehen“): Der Kalender setzte die Pillen selbst unter die Überschrift
/// und ließ sie mitscrollen; die übrigen Reiter (FamilySwitch) oben fest.
/// Abstand oben [Sp.m] unter der Statusleiste, seitlich [Sp.page]; die
/// Seite darunter bekommt keinen oberen Rand mehr (sie liegt schon unter
/// der Statusleiste).
class PinnedKidChips extends StatelessWidget {
  const PinnedKidChips({
    super.key,
    required this.chips,
    required this.child,
    this.leading,
  });

  final KidChips chips;
  final Widget child;

  /// Links in derselben Zeile (Zurück auf Unterseiten, SubpageKidChips).
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.page, Sp.m, Sp.page, 0),
          child: leading == null
              ? chips
              : Row(
                  children: [
                    leading!,
                    const SizedBox(width: Sp.xs),
                    Expanded(child: chips),
                  ],
                ),
        ),
      ),
      Expanded(
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: child,
        ),
      ),
    ],
  );
}

/// Markiert eine Seite, deren Zurück-Pfeil schon in der Pillenzeile steht
/// (SubpageKidChips). Die Seite zeigt dann keinen eigenen.
///
/// Ursache (Rückmeldung 21.10.26: „Warum ist der Pfeil zurück nicht auf
/// gleicher Höhe wie die Schülerauswahl?“): Pillen und Pfeil standen in zwei
/// Zeilen übereinander. Grenze: Ohne Pillen (ein Kind, Einstellungen) bleibt
/// der Pfeil im Kopf der Seite.
class BackInChips extends InheritedWidget {
  const BackInChips({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BackInChips>() != null;

  @override
  bool updateShouldNotify(BackInChips old) => false;
}
