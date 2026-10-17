import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../kit.dart';
import 'lesson_times.dart';

/// Ergebnis des Dialogs: [times] null = Eintrag löschen.
typedef LessonTimesResult = ({LessonTimes? times});

/// Stundenzeiten eintragen oder ändern; null = abgebrochen.
///
/// Vorgabe für einen neuen Eintrag: 8:00, 45 Minuten, Pause nach je zwei
/// Stunden, 15 Minuten (Raster laut Rückmeldung 17.10.26, „klassisch“).
/// Beginn und Pausenlänge kennt die App nicht – die Vorschau zeigt sofort,
/// was daraus wird.
Future<LessonTimesResult?> askLessonTimes(
  BuildContext context,
  LessonTimes? current,
) => showDialog<LessonTimesResult>(
  context: context,
  builder: (_) => _LessonTimesDialog(current: current),
);

class _LessonTimesDialog extends StatefulWidget {
  const _LessonTimesDialog({this.current});

  final LessonTimes? current;

  @override
  State<_LessonTimesDialog> createState() => _LessonTimesDialogState();
}

class _LessonTimesDialogState extends State<_LessonTimesDialog> {
  late LessonTimes _v = widget.current ?? const LessonTimes(start: 8 * 60);

  static const _lengths = [40, 45, 50, 60, 90];
  static const _everies = [1, 2, 3, 4, 0];
  static const _pauses = [5, 10, 15, 20, 25, 30];

  LessonTimes _with({int? start, int? length, int? every, int? pause}) =>
      LessonTimes(
        start: start ?? _v.start,
        length: length ?? _v.length,
        every: every ?? _v.every,
        pause: pause ?? _v.pause,
      );

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _v.start ~/ 60, minute: _v.start % 60),
    );
    if (picked == null || !mounted) return;
    setState(() => _v = _with(start: picked.hour * 60 + picked.minute));
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

  Widget _drop(
    Kit k,
    int value,
    List<int> items,
    String Function(int) label,
    void Function(int) onChanged,
  ) {
    return DropdownButton<int>(
      value: items.contains(value) ? value : null,
      hint: Text(label(value), style: k.body),
      underline: const SizedBox.shrink(),
      items: [
        for (final i in items)
          DropdownMenuItem(
            value: i,
            child: Text(label(i), style: k.body),
          ),
      ],
      onChanged: (v) {
        if (v != null) setState(() => onChanged(v));
      },
    );
  }

  /// „1. 08:00–08:45 · 2. 08:45–09:30 · Pause · 3. …“ für sechs Stunden.
  String _preview(ForkL10n t) {
    final parts = <String>[];
    for (var n = 1; n <= 6; n++) {
      final x = _v.of(n);
      if (n > 1 && _v.every > 0 && (n - 1) % _v.every == 0 && _v.pause > 0) {
        parts.add(t.breakShort);
      }
      parts.add('$n. ${LessonTimes.hm(x.start)}–${LessonTimes.hm(x.end)}');
    }
    return parts.join('\n');
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
                k,
                _v.length,
                _lengths,
                (i) => t.minutesShort(i),
                (v) => _v = _with(length: v),
              ),
            ),
            _row(
              k,
              t.lessonTimesEvery,
              _drop(
                k,
                _v.every,
                _everies,
                (i) => i == 0 ? t.noBreak : t.lessonsCount(i),
                (v) => _v = _with(every: v),
              ),
            ),
            if (_v.every > 0)
              _row(
                k,
                t.lessonTimesPause,
                _drop(
                  k,
                  _v.pause,
                  _pauses,
                  (i) => t.minutesShort(i),
                  (v) => _v = _with(pause: v),
                ),
              ),
            const SizedBox(height: Sp.m),
            Container(
              padding: const EdgeInsets.all(Sp.m),
              decoration: BoxDecoration(
                color: k.p.inset,
                borderRadius: BorderRadius.circular(Rad.row),
              ),
              child: Text(_preview(t), style: k.planMeta(k.p.ink)),
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
