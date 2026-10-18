import 'package:flutter/material.dart';

import '../ui/kit.dart';

/// Bausteine der Erstanmeldung (Entwurf 18.10.26, abgenommen): Seite mit
/// Inhalt oben und Knöpfen unten, höchstens [maxWidth] breit (Tablet:
/// mittig), Farben und Schrift aus dem Kit.
///
/// Ursache: Bisher lief die Anmeldung über die Lanis-Oberfläche (lila
/// Material-Standard, sechs Einführungsseiten der Vorlage) – der
/// einzige Teil der App im fremden Stil.
class OnbPage extends StatelessWidget {
  const OnbPage({
    super.key,
    required this.top,
    this.bottom = const [],
    this.onBack,
    this.step,
  });

  static const maxWidth = 480.0;

  final List<Widget> top;
  final List<Widget> bottom;
  final VoidCallback? onBack;

  /// „SCHRITT 1 VON 2“ oben rechts; null = ohne.
  final String? step;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Scaffold(
      backgroundColor: k.p.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.s, Sp.xl, Sp.l),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: box.maxHeight - Sp.s - Sp.l,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: Sz.buttonSmall,
                          child: Row(
                            children: [
                              if (onBack != null)
                                IconButton(
                                  onPressed: onBack,
                                  icon: Icon(Icons.arrow_back, color: k.p.ink),
                                  padding: EdgeInsets.zero,
                                  alignment: Alignment.centerLeft,
                                ),
                              const Spacer(),
                              if (step != null)
                                Text(upper(step!), style: k.dateCaps),
                            ],
                          ),
                        ),
                        ...top,
                        const Spacer(),
                        const SizedBox(height: Sp.l),
                        ...bottom,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String upper(String s) => s.toUpperCase();
}

/// Großer Knopf: [strong] dunkel (Hauptaktion), sonst hell mit Rand.
class OnbButton extends StatelessWidget {
  const OnbButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.strong = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool strong;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final enabled = onPressed != null;
    final fg = strong ? k.p.onStrong : k.p.ink;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: strong ? k.p.strong : k.p.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rad.button),
          side: strong ? BorderSide.none : BorderSide(color: k.p.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.button),
          onTap: onPressed,
          child: SizedBox(
            height: Sz.button,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: Sz.navIcon, color: fg),
                  const SizedBox(width: Sp.s),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: k.button(fg),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Zeile mit Symbol in farbiger Fläche, Titel und Erklärung (Willkommen,
/// Benachrichtigungen).
class OnbFeature extends StatelessWidget {
  const OnbFeature({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    required this.bg,
    required this.ink,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color bg;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: Sz.avatar,
            height: Sz.avatar,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(Rad.row),
            ),
            child: Icon(icon, color: ink, size: Sz.navIcon),
          ),
          const SizedBox(width: Sp.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: k.planSubject(k.p.ink)),
                Text(text, style: k.meta),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Eingabefeld im Stil der App (Karte mit Rand, Symbol, Beschriftung).
InputDecoration onbInput(Kit k, {required String label, IconData? icon}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(Rad.row),
    borderSide: BorderSide(color: c),
  );
  return InputDecoration(
    labelText: label,
    labelStyle: k.meta,
    floatingLabelStyle: k.dateCaps,
    prefixIcon: icon == null ? null : Icon(icon, color: k.p.muted),
    filled: true,
    fillColor: k.p.card,
    border: border(k.p.line),
    enabledBorder: border(k.p.line),
    disabledBorder: border(k.p.line),
    focusedBorder: border(k.p.ink),
  );
}
