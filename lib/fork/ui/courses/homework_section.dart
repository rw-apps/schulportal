import 'package:flutter/material.dart';

import '../../homework_ledger.dart';
import '../../l10n/l10n.dart';
import '../kit.dart';
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
  });

  final List<HwEntry> open;

  /// Nur Anzeige (Vorschau ohne Daten): kein Abhaken.
  final bool readOnly;

  /// Neueste zuerst (homeworkLists).
  final List<HwEntry> done;

  /// Zahl aller erledigten; Standard [done].length.
  final int? doneTotal;
  final String emptyText;
  final VoidCallback? onShowAll;

  static const shownDone = 10;

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
  });

  final HwEntry entry;
  final bool ticked;

  /// null = nur Anzeige.
  final VoidCallback? onTick;
  final int? flash;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final tone = k.p.change;
    final item = entry.item;
    final text = item.text.isEmpty ? t.homeworkEntered : item.text;
    final meta = item.given == null
        ? item.subject
        : t.givenOn(item.subject, formatDate(t, t.dateShort, item.given!));
    final strike = ticked
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;
    final circle = Icon(
      ticked ? Icons.check_circle : Icons.radio_button_unchecked,
      size: Sz.navIcon,
      color: tone.ink,
    );
    final card = Material(
      color: tone.bg,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.signal),
        onTap: entry.onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.xs, Sp.l, Sp.xs),
          child: Row(
            children: [
              // Eigene Trefferfläche (48 dp), getrennt vom Öffnen des Kurses.
              if (onTick == null && !ticked)
                Padding(padding: const EdgeInsets.all(Sp.m), child: circle)
              else
                IconButton(
                  onPressed: ticked ? null : onTick,
                  tooltip: t.homeworkMarkDone,
                  icon: circle,
                ),
              const SizedBox(width: Sp.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Sp.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text, style: k.boxStrong(tone).merge(strike)),
                      Text(meta, style: k.planMeta(tone.ink)),
                      if (entry.kid != null) ...[
                        const SizedBox(height: Sp.xxs),
                        KidLine(kid: entry.kid!),
                      ],
                    ],
                  ),
                ),
              ),
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
    final meta = [
      if (item.given == null)
        item.subject
      else
        t.givenOn(item.subject, formatDate(t, t.dateShort, item.given!)),
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
          padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.xs, Sp.l, Sp.xs),
          child: Row(
            children: [
              IconButton(
                onPressed: unticked ? null : onTick,
                tooltip: t.homeworkReopen,
                icon: Icon(
                  unticked ? Icons.radio_button_unchecked : Icons.check_circle,
                  size: Sz.navIcon,
                  color: k.p.faint,
                ),
              ),
              const SizedBox(width: Sp.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Sp.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: k.body.copyWith(
                          color: k.p.muted,
                          decoration: unticked
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                      Text(meta, style: k.meta),
                      if (entry.kid != null) ...[
                        const SizedBox(height: Sp.xxs),
                        KidLine(kid: entry.kid!),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
