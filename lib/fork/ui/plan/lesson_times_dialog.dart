import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../kit.dart';
import 'lesson_times.dart';

/// Ergebnis des Dialogs: [times] null = Eintrag löschen.
typedef LessonTimesResult = ({LessonTimes? times});

/// Stundenzeiten eintragen oder ändern; null = abgebrochen.
///
/// Aufbau: Beginn und Stundenlänge oben, darunter jede Stunde mit ihrer
/// errechneten Uhrzeit und rechts der Pause bis zur nächsten. Ursache: Die
/// Pausen sind je Schule unregelmäßig (lesson_times.dart); die Uhrzeit in
/// derselben Zeile zeigt sofort, ob es zum Aushang der Schule passt.
/// Vorgabe für einen neuen Eintrag: 8:00, 45 Minuten,
/// LessonTimes.defaultPauses. Grenze: [count] Stunden (Vorgabe 10) – eine
/// gespeicherte Pause nach einer späteren Stunde verlängert die Liste.
Future<LessonTimesResult?> askLessonTimes(
  BuildContext context,
  LessonTimes? current, {
  int count = 10,
}) => showDialog<LessonTimesResult>(
  context: context,
  builder: (_) => _LessonTimesDialog(current: current, count: count),
);

class _LessonTimesDialog extends StatefulWidget {
  const _LessonTimesDialog({this.current, required this.count});

  final LessonTimes? current;
  final int count;

  @override
  State<_LessonTimesDialog> createState() => _LessonTimesDialogState();
}

class _LessonTimesDialogState extends State<_LessonTimesDialog> {
  late LessonTimes _v = widget.current ?? const LessonTimes(start: 8 * 60);

  static const _lengths = [40, 45, 50, 60, 90];
  static const _pauses = [0, 5, 10, 15, 20, 25, 30, 45, 60];

  int get _count {
    final last = _v.pauses.keys.fold(0, (a, b) => a > b ? a : b);
    return widget.count > last ? widget.count : last + 1;
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _v.start ~/ 60, minute: _v.start % 60),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _v = LessonTimes(
        start: picked.hour * 60 + picked.minute,
        length: _v.length,
        pauses: _v.pauses,
      ),
    );
  }

  Widget _row(Kit k, String label, Widget value) => Padding(
    padding: const EdgeInsets.only(top: Sp.s),
    child: Row(
      children: [
        Expanded(child: Text(label, style: k.body)),
        const SizedBox(width: Sp.s),
        value,
      ],
    ),
  );

  /// Auswahl; ein gespeicherter Wert außerhalb der Liste bleibt als Hinweis
  /// sichtbar, bis man ihn ändert.
  Widget _drop(
    TextStyle style,
    int value,
    List<int> items,
    String Function(int) label,
    void Function(int) onChanged,
  ) {
    return DropdownButton<int>(
      value: items.contains(value) ? value : null,
      hint: Text(label(value), style: style),
      underline: const SizedBox.shrink(),
      isDense: true,
      items: [
        for (final i in items)
          DropdownMenuItem(
            value: i,
            child: Text(label(i), style: style),
          ),
      ],
      onChanged: (v) {
        if (v != null) setState(() => onChanged(v));
      },
    );
  }

  /// Eine Stunde: „3.  09:50–10:35“ und rechts die Pause danach (nicht bei
  /// der letzten Zeile).
  Widget _lesson(Kit k, ForkL10n t, int n) {
    final x = _v.of(n);
    final style = k.planMeta(k.p.ink);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$n.  ${LessonTimes.hm(x.start)}–${LessonTimes.hm(x.end)}',
              style: style,
            ),
          ),
          if (n < _count)
            _drop(
              style,
              _v.pauseAfter(n),
              _pauses,
              (i) => i == 0 ? '–' : t.minutesShort(i),
              (v) => _v = _v.withPause(n, v),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    return AlertDialog(
      title: Text(t.lessonTimesTitle, style: k.sheetTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.lessonTimesText, style: k.meta),
            const SizedBox(height: Sp.s),
            _row(
              k,
              t.lessonTimesStart,
              TextButton(
                onPressed: _pickStart,
                child: Text(LessonTimes.hm(_v.start), style: k.link),
              ),
            ),
            _row(
              k,
              t.lessonTimesLength,
              _drop(
                k.body,
                _v.length,
                _lengths,
                (i) => t.minutesShort(i),
                (v) => _v = LessonTimes(
                  start: _v.start,
                  length: v,
                  pauses: _v.pauses,
                ),
              ),
            ),
            const SizedBox(height: Sp.m),
            Container(
              padding: const EdgeInsets.fromLTRB(Sp.m, Sp.s, Sp.m, Sp.s),
              decoration: BoxDecoration(
                color: k.p.inset,
                borderRadius: BorderRadius.circular(Rad.row),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.pauseAfter, style: k.meta, textAlign: TextAlign.end),
                  for (var n = 1; n <= _count; n++) _lesson(k, t, n),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () => Navigator.pop(context, (times: null)),
            child: Text(t.delete, style: k.link),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel, style: k.link),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, (times: _v)),
          child: Text(t.save, style: k.link),
        ),
      ],
    );
  }
}
