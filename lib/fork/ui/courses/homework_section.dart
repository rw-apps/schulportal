import 'package:flutter/material.dart';

import '../../homework_ledger.dart';
import '../../l10n/l10n.dart';
import '../kit.dart';
import '../today/today_page.dart' show dayDiff;
import 'exam_card.dart' show KidLine, KidTag;

/// Eine Hausaufgabe in [HomeworkSection]; [kid] nur in „Alle“.
class HwEntry {
  const HwEntry({
    required this.item,
    required this.onDone,
    required this.onReopen,
    this.kid,
    this.onOpen,
  });

  final HomeworkItem item;

  final KidTag? kid;

  /// Kurs öffnen (Antippen der Karte); null = nur Anzeige.
  final VoidCallback? onOpen;
  final VoidCallback onDone;
  final VoidCallback onReopen;

  String get key => '${kid?.name ?? ''}|${item.key}';
}

/// Offene Hausaufgaben mit sichtbarem Übergang beim Abhaken, darunter
/// „Erledigt (n)“ zum Aufklappen – gemeinsam für Unterricht eines Kindes
/// und „Alle“ (Entwurf abgenommen 20.10.26).
///
/// Ursache (Rückmeldung 20.10.26): Abgehakte Aufgaben verschwanden
/// schlagartig, wohin sie gingen, war nicht zu sehen; Zurückholen ging nur
/// über eine eigene Seite. Jetzt: Haken füllt sich, Text gestrichen
/// ([_hold]), Karte klappt zu ([_collapse]), „Erledigt (n)“ leuchtet auf.
/// Unter „Erledigt“ holt derselbe Haken die Aufgabe zurück; sie klappt dort
/// zu und leuchtet oben kurz auf.
///
/// Abläufe nur über Animationen (TweenAnimationBuilder.onEnd), keine
/// Zeitgeber. Ursache: Die Liste kommt erst einen Bildaufbau nach onDone
/// neu – eine Karte, die bis dahin wieder aufginge, flackerte. Deshalb
/// bleibt eine abgeschlossene Karte unsichtbar ([_gone]), bis sie in der
/// neuen Liste fehlt. Grenze: Unter „Erledigt“ stehen die [shownDone]
/// neuesten; alle zeigt die bisherige Seite ([onShowAll]).
class HomeworkSection extends StatefulWidget {
  const HomeworkSection({
    super.key,
    required this.open,
    required this.done,
    required this.emptyText,
    this.doneTotal,
    this.onShowAll,
    this.readOnly = false,
    this.now,
    this.expiredCount = 0,
  });

  /// Abgelaufene, nicht abgehakte (homeworkLists.expired): eigener Link
  /// zum Archiv, auch ohne erledigte. Ursache (Prüfung 27.10.26): Der Weg
  /// ins Archiv erschien nur bei mehr als [shownDone] erledigten – „Nicht
  /// abgehakt“ und „Wieder offen“ waren sonst unerreichbar.
  final int expiredCount;

  /// Nur Tests/Entwürfe (Frist-Zeile).
  final DateTime? now;

  final List<HwEntry> open;

  /// Nur Anzeige (Vorschau ohne Daten): kein Abhaken.
  final bool readOnly;

  /// Neueste zuerst (homeworkLists).
  final List<HwEntry> done;

  /// Zahl aller erledigten; Standard [done].length.
  final int? doneTotal;
  final String emptyText;
  final VoidCallback? onShowAll;

  /// Ursache für 5 (Rückmeldung 20.10.26, „nicht zu groß, nicht zu
  /// unruhig“): Mit zehn erledigten wurde die Seite lang; ältere stehen auf
  /// der eigenen Seite (onShowAll).
  static const shownDone = 5;

  @override
  State<HomeworkSection> createState() => _HomeworkSectionState();
}

const _hold = Duration(milliseconds: 350);
const _collapse = Duration(milliseconds: 280);
const _flash = Duration(milliseconds: 1400);

class _HomeworkSectionState extends State<HomeworkSection> {
  /// Karten im Übergang, je Liste getrennt (dieselbe Aufgabe wechselt die
  /// Liste): 1 = markiert, 2 = klappt zu, 3 = weg (wartet auf die neue
  /// Liste).
  final _openStage = <String, int>{};
  final _doneStage = <String, int>{};
  bool _expanded = false;
  int _doneFlash = 0;
  String? _flashKey;
  int _keyFlash = 0;

  @override
  void didUpdateWidget(HomeworkSection old) {
    super.didUpdateWidget(old);
    // Abgeschlossene Übergänge vergessen, sobald die Liste nachgezogen hat.
    void prune(Map<String, int> stage, List<HwEntry> list) {
      final keys = {for (final e in list) e.key};
      stage.removeWhere((k, v) => v == 3 && !keys.contains(k));
    }

    prune(_openStage, widget.open);
    prune(_doneStage, widget.done);
  }

  void _start(Map<String, int> stage, HwEntry e) {
    if (stage.containsKey(e.key)) return;
    setState(() => stage[e.key] = 1);
  }

  void _finishTick(HwEntry e) {
    setState(() {
      _openStage[e.key] = 3;
      _doneFlash++;
    });
    e.onDone();
    final t = context.t;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(t.homeworkMarkedDone),
          action: SnackBarAction(label: t.undo, onPressed: () => _back(e)),
        ),
      );
  }

  void _finishReopen(HwEntry e) {
    setState(() => _doneStage[e.key] = 3);
    _back(e);
  }

  /// Wieder offen (auch „Rückgängig“); die Karte leuchtet oben kurz auf.
  void _back(HwEntry e) {
    e.onReopen();
    if (!mounted) return;
    setState(() {
      _openStage.remove(e.key);
      _flashKey = e.key;
      _keyFlash++;
    });
  }

  /// [child] mit Übergang: markiert (blasser), dann zuklappen.
  Widget _leaving(
    Map<String, int> stages,
    HwEntry e,
    Widget child,
    VoidCallback onEnd,
  ) {
    final stage = stages[e.key] ?? 0;
    if (stage == 3) return const SizedBox.shrink();
    Widget w = child;
    if (stage >= 1) {
      w = TweenAnimationBuilder<double>(
        key: const ValueKey('hold'),
        tween: Tween(begin: 1, end: 0.6),
        duration: _hold,
        onEnd: stage == 1 ? () => setState(() => stages[e.key] = 2) : null,
        builder: (c, v, ch) => Opacity(opacity: v, child: ch),
        child: w,
      );
    }
    if (stage >= 2) {
      w = TweenAnimationBuilder<double>(
        key: const ValueKey('collapse'),
        tween: Tween(begin: 1, end: 0),
        duration: _collapse,
        curve: Curves.easeInOut,
        onEnd: onEnd,
        builder: (c, v, ch) => ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: v,
            child: ch,
          ),
        ),
        child: w,
      );
    }
    return KeyedSubtree(key: ValueKey('hw-${e.key}'), child: w);
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final open = widget.open;
    final done = widget.done;
    final total = widget.doneTotal ?? done.length;
    final shown = done.take(HomeworkSection.shownDone).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (open.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: Sp.xs, bottom: Sp.s),
            child: Text(widget.emptyText, style: k.meta),
          ),
        for (final e in open)
          _leaving(
            _openStage,
            e,
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: _OpenCard(
                entry: e,
                ticked: (_openStage[e.key] ?? 0) >= 1,
                flash: e.key == _flashKey ? _keyFlash : null,
                onTick: widget.readOnly ? null : () => _start(_openStage, e),
                now: widget.now,
              ),
            ),
            () => _finishTick(e),
          ),
        if (total > 0)
          _DoneToggle(
            count: total,
            open: _expanded,
            flash: _doneFlash,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
        if (_expanded) ...[
          const SizedBox(height: Sp.s),
          for (final e in shown)
            _leaving(
              _doneStage,
              e,
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.s),
                child: _DoneCard(
                  entry: e,
                  unticked: (_doneStage[e.key] ?? 0) >= 1,
                  onTick: () => _start(_doneStage, e),
                ),
              ),
              () => _finishReopen(e),
            ),
          if (total > shown.length && widget.onShowAll != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.onShowAll,
                child: Text(t.homeworkShowAll(total), style: k.link),
              ),
            ),
        ],
        if (widget.expiredCount > 0 && widget.onShowAll != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: widget.onShowAll,
              child: Text(t.hwExpiredLink(widget.expiredCount), style: k.link),
            ),
          ),
      ],
    );
  }
}

/// Offene Hausaufgabe: Kreis hakt ab ([ticked] = Haken gefüllt, Text
/// gestrichen); [flash] lässt die Karte nach dem Zurückholen aufleuchten.
class _OpenCard extends StatelessWidget {
  const _OpenCard({
    required this.entry,
    required this.ticked,
    required this.onTick,
    this.flash,
    this.now,
  });

  /// Nur Tests/Entwürfe.
  final DateTime? now;

  final HwEntry entry;
  final bool ticked;

  /// null = nur Anzeige.
  final VoidCallback? onTick;
  final int? flash;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    // Dezent grau (KitPalette.todo), nicht Gelb wie eine Vertretung.
    final tone = k.p.todo;
    final item = entry.item;
    final text = item.text.isEmpty ? t.homeworkEntered : item.text;
    final meta = item.given == null
        ? item.subject
        : t.givenOn(item.subject, formatDate(t, t.dateShort, item.given!));
    final strike = ticked
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;
    final card = Material(
      color: tone.bg,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.signal),
        onTap: entry.onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.l, Sp.m, Sp.m, Sp.m),
          // Knopf nur neben dem Aufgabentext; Fach und Kind darunter in
          // voller Breite. Ursache (Bild 20.10.26): Neben dem Knopf brach
          // die Fachzeile um („aufgegeben Di / 20.10.“) – unruhig.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(text, style: k.boxStrong(tone).merge(strike)),
                  ),
                  if (onTick != null) ...[
                    const SizedBox(width: Sp.s),
                    _CardAction(
                      icon: Icons.check,
                      label: t.homeworkDoneButton,
                      color: tone.ink,
                      fill: tone.bg,
                      active: ticked,
                      onPressed: ticked ? null : onTick,
                    ),
                  ],
                ],
              ),
              // Kind in der Fachzeile wie bei den erledigten (eine Zeile
              // weniger in „Alle“).
              Wrap(
                spacing: Sp.s,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(meta, style: k.planMeta(tone.ink)),
                  if (entry.kid != null) KidLine(kid: entry.kid!),
                ],
              ),
              if (entry.item.due case final due?) ...[
                const SizedBox(height: Sp.xs),
                _DueLine(due: due, now: now ?? DateTime.now()),
              ],
            ],
          ),
        ),
      ),
    );
    final f = flash;
    if (f == null) return card;
    return TweenAnimationBuilder<double>(
      key: ValueKey('flash-$f'),
      tween: Tween(begin: 1, end: 0),
      duration: _flash,
      builder: (c, v, ch) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Rad.signal),
          border: Border.all(
            color: k.p.onNavSelected.withValues(alpha: v),
            width: 2,
          ),
        ),
        child: ch,
      ),
      child: card,
    );
  }
}

/// Erledigte Hausaufgabe unter „Erledigt“: Haken antippen = wieder offen
/// ([unticked] = Kreis leer, Text ungestrichen).
class _DoneCard extends StatelessWidget {
  const _DoneCard({
    required this.entry,
    required this.unticked,
    required this.onTick,
  });

  final HwEntry entry;
  final bool unticked;
  final VoidCallback onTick;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final item = entry.item;
    final text = item.text.isEmpty ? t.homeworkEntered : item.text;
    // Nur Fach und Erledigt-Tag – das Aufgabedatum steht auf der Seite
    // „Erledigte Hausaufgaben“. Ursache: drei Zeilen je erledigter Karte
    // machten die Liste lang und unruhig (Rückmeldung 20.10.26).
    final meta = [
      item.subject,
      if (item.done != null)
        t.homeworkDoneOn(formatDate(t, t.dateShort, item.done!)),
    ].join(' · ');
    return Material(
      color: k.p.card,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.signal),
        onTap: entry.onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.l, Sp.m, Sp.m, Sp.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: k.body.copyWith(
                        color: k.p.muted,
                        decoration: unticked
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                  const SizedBox(width: Sp.s),
                  _CardAction(
                    icon: Icons.undo,
                    // Kurz („Unerledigt“): Oben rechts ließ der lange Text
                    // „Als unerledigt markieren“ der Aufgabe kaum Platz (Wörter
                    // brachen mitten im Wort, Bild 20.10.26); der lange steht
                    // für Bildschirmleser als Tooltip.
                    label: t.homeworkMarkOpenShort,
                    tooltip: t.homeworkMarkOpen,
                    outlined: false,
                    color: k.p.onNavSelected,
                    fill: k.p.card,
                    active: unticked,
                    onPressed: unticked ? null : onTick,
                  ),
                ],
              ),
              // Kind in derselben Zeile wie Fach und Tag („Alle“), damit
              // erledigte Karten zweizeilig bleiben; bricht nur bei
              // Platzmangel um.
              Wrap(
                spacing: Sp.s,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(meta, style: k.meta),
                  if (entry.kid != null) KidLine(kid: entry.kid!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Knopf mit Klartext oben rechts in der Karte („✓ Erledigt“, „↺ Als
/// unerledigt markieren“); [active] = gerade angetippt (gefüllt, während
/// die Karte wandert). Ursache (Rückmeldung 20.10.26): Ein Kreis links als
/// einziges Bedienelement war nicht selbsterklärend; er entfällt.
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.fill,
    required this.active,
    required this.onPressed,
    this.tooltip,
    this.outlined = true,
  });

  final IconData icon;
  final String label;
  final String? tooltip;

  /// Rahmen nur für die Hauptaktion („Erledigt“); „Unerledigt“ ohne.
  /// Ursache (Bild der ganzen Seite, 20.10.26): Fünf gleiche Rahmen unter
  /// „Erledigt“ wirkten unruhig.
  final bool outlined;
  final Color color;

  /// Farbe der Schrift im gefüllten Zustand (Kartenfarbe).
  final Color fill;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final fg = active ? fill : color;
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: Sz.iconSmall, color: fg),
      label: Text(label, style: k.buttonTiny(fg)),
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? color : null,
        disabledBackgroundColor: active ? color : null,
        // Klein (Sz.buttonTiny) und ohne unsichtbaren Rand, damit die Zeile
        // so hoch bleibt wie der Aufgabentext. Grenze: Die Trefferfläche ist
        // 28 dp statt 48 dp; ein Fehlgriff daneben öffnet die Kursseite.
        minimumSize: const Size(0, Sz.buttonTiny),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: Sp.s),
        side: outlined ? BorderSide(color: color, width: 1.5) : BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rad.pill),
        ),
      ),
    );
    final tip = tooltip;
    return tip == null ? button : Tooltip(message: tip, child: button);
  }
}

/// „Erledigt (n)“ zum Auf- und Zuklappen; leuchtet nach dem Abhaken kurz
/// auf ([flash] zählt hoch).
class _DoneToggle extends StatelessWidget {
  const _DoneToggle({
    required this.count,
    required this.open,
    required this.flash,
    required this.onTap,
  });

  final int count;
  final bool open;
  final int flash;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    return TweenAnimationBuilder<double>(
      key: ValueKey('done-flash-$flash'),
      tween: Tween(begin: flash == 0 ? 0 : 1, end: 0),
      duration: _flash,
      builder: (c, v, ch) => Material(
        color: Color.lerp(
          k.p.navSelected.withValues(alpha: 0),
          k.p.navSelected,
          v,
        ),
        borderRadius: BorderRadius.circular(Rad.pill),
        child: ch,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.s, vertical: Sp.s),
          child: Row(
            children: [
              Icon(
                open ? Icons.expand_less : Icons.expand_more,
                size: Sz.navIcon,
                color: k.p.onNavSelected,
              ),
              const SizedBox(width: Sp.xs),
              Text(t.homeworkArchive(count), style: k.link),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frist unter einer offenen Hausaufgabe (Entwurf 27.10.26): „fällig
/// Mi 28.10.“ (Nebenschrift), „fällig heute“/„fällig morgen“ (kräftig),
/// nach dem Tag gelb „war fällig Mi 22.10. · erledigt?“. Gelb wie andere
/// Hinweise, die etwas zu tun verlangen; das Fragezeichen, weil die Frist
/// nur vermutet ist (HomeworkItem.due) – die App hakt nichts selbst ab.
class _DueLine extends StatelessWidget {
  const _DueLine({required this.due, required this.now});

  final DateTime due;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    // dayDiff rechnet in UTC (Zeitumstellung: sonst „heute“ statt „morgen“).
    final diff = dayDiff(now, due);
    final day = formatDate(t, t.dateShort, due);
    if (diff < 0) {
      final tone = k.p.change;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.s, vertical: Sp.xxs),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(Rad.pill),
        ),
        child: Text(
          t.hwOverdue(day),
          style: k.tileCaption.copyWith(color: tone.ink),
        ),
      );
    }
    final text = switch (diff) {
      0 => t.hwDueToday,
      1 => t.hwDueTomorrow,
      _ => t.hwDueOn(day),
    };
    return Text(
      text,
      style: diff <= 1 ? k.planTeacher(k.p.ink) : k.planMeta(k.p.muted),
    );
  }
}
