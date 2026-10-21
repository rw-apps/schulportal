import 'package:flutter/material.dart';

import 'kit.dart';

/// Seite mit feststehendem Kopf – EIN Baustein für alle Seiten mit eigener
/// Überschrift (Heute, Kalender, Unterricht, Fachseite, Nachrichten, Mehr,
/// Einstellungen und ihre Unterseiten).
///
/// Ursache (Rückmeldung 21.10.26: „auf jeder Seite muss die Überschrift
/// fixiert sein“): Die Überschrift lag im scrollenden Inhalt und verschwand
/// beim Scrollen; fest standen nur die Kind-Pillen (PinnedKidChips) und
/// Seiten mit Zurück-Leiste (AppBar). Der Kopf ([header]: Überschrift,
/// Unterzeile, Umschalter) steht jetzt außerhalb der Liste. Sobald Inhalt
/// unter ihm weggescrollt ist, trennt eine feine Linie (KitPalette.line),
/// damit man sieht, dass die Liste nicht am Anfang steht.
///
/// Grenze: Der Kopf nimmt seine Höhe dauerhaft ein. Deshalb gehören nur
/// Überschrift und Bedienelemente der Seite hinein, keine Hinweise oder
/// Inhalte.
class PinnedPage extends StatefulWidget {
  const PinnedPage({
    super.key,
    required this.header,
    this.children = const [],
    this.slivers,
    this.onRefresh,
    this.headerPadding = const EdgeInsets.fromLTRB(
      Sp.page,
      Sp.xl,
      Sp.page,
      Sp.m,
    ),
    this.bodyPadding = const EdgeInsets.fromLTRB(
      Sp.page,
      Sp.xs,
      Sp.page,
      Sp.xl,
    ),
  });

  /// Kopf von oben nach unten (Überschrift zuerst).
  final List<Widget> header;

  /// Inhalt als Liste …
  final List<Widget> children;

  /// … oder als Slivers (lange Listen wie die Nachrichten); dann gilt
  /// [children] nicht und [bodyPadding] umschließt die Slivers.
  final List<Widget>? slivers;

  /// Ziehen zum Aktualisieren; null = ohne.
  final Future<void> Function()? onRefresh;

  /// Rand um den Kopf. Die Statusleiste kommt oben hinzu (nicht unter den
  /// Kind-Pillen, PinnedKidChips entfernt sie dort schon).
  final EdgeInsets headerPadding;

  /// Rand um den Inhalt. Unten kommt die Höhe der schwebenden Leiste hinzu
  /// (MediaQuery.padding.bottom bei Scaffold(extendBody: true)).
  final EdgeInsets bodyPadding;

  @override
  State<PinnedPage> createState() => _PinnedPageState();
}

class _PinnedPageState extends State<PinnedPage> {
  bool _under = false;

  bool _onScroll(ScrollNotification n) {
    // Nur die Liste selbst, nicht verschachtelte (z. B. waagrechte Pillen).
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final under = n.metrics.pixels > 0.5;
    if (under != _under) setState(() => _under = under);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final pad = MediaQuery.paddingOf(context);
    final body = widget.bodyPadding.copyWith(
      bottom: widget.bodyPadding.bottom + pad.bottom,
    );
    final slivers = widget.slivers;
    Widget list = slivers == null
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: body,
            children: widget.children,
          )
        : CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: body,
                sliver: SliverMainAxisGroup(slivers: slivers),
              ),
            ],
          );
    final refresh = widget.onRefresh;
    if (refresh != null) {
      list = RefreshIndicator(onRefresh: refresh, child: list);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: widget.headerPadding.copyWith(
            top: widget.headerPadding.top + pad.top,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: widget.header,
          ),
        ),
        // Immer 1 dp hoch, damit der Inhalt beim Erscheinen nicht springt.
        ColoredBox(
          color: _under ? k.p.line : Colors.transparent,
          child: const SizedBox(height: 1),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: list,
            ),
          ),
        ),
      ],
    );
  }
}
