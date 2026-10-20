import 'package:flutter/material.dart';

import '../../class_choice.dart';
import '../../l10n/l10n.dart';
import '../../onboarding/onboarding_kit.dart';
import '../kit.dart';

/// Ergebnis des Blatts: [name] null = Eintrag entfernen.
typedef ClassSheetResult = ({String? name});

/// Klasse wählen (Entwurf 20.10.26, abgenommen): Jahrgang und Buchstabe zum
/// Antippen, „andere“ für Klassennamen („6 Ahorn“), oben groß das Ergebnis.
///
/// Ursache für Knöpfe statt Textfeld (Rückmeldung 20.10.26: „Text klein und
/// optisch wenig ansprechend“): Der erste Entwurf war ein schmaler Dialog
/// mit Eingabefeld. Rückgabe null = abgebrochen.
Future<ClassSheetResult?> showClassSheet(
  BuildContext context, {
  required String kidName,
  required String school,
  required int colorIndex,
  String detected = '',
  String current = '',
  bool hasEntry = false,
}) => showModalBottomSheet<ClassSheetResult>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Kit.of(context).p.card,
  builder: (_) => ClassSheet(
    kidName: kidName,
    school: school,
    colorIndex: colorIndex,
    detected: detected,
    current: current.isEmpty ? detected : current,
    hasEntry: hasEntry,
  ),
);

class ClassSheet extends StatefulWidget {
  const ClassSheet({
    super.key,
    required this.kidName,
    required this.school,
    required this.colorIndex,
    this.detected = '',
    this.current = '',
    this.hasEntry = false,
  });

  final String kidName;
  final String school;
  final int colorIndex;
  final String detected;
  final String current;
  final bool hasEntry;

  static const grades = [5, 6, 7, 8, 9, 10, 11, 12, 13];
  static const letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  State<ClassSheet> createState() => _ClassSheetState();
}

class _ClassSheetState extends State<ClassSheet> {
  int? _grade;
  String? _letter;
  bool _other = false;
  final _otherText = TextEditingController();

  @override
  void initState() {
    super.initState();
    final (:grade, :rest) = splitClass(widget.current);
    _grade = ClassSheet.grades.contains(grade) ? grade : null;
    final up = rest.toUpperCase();
    if (ClassSheet.letters.contains(up)) {
      _letter = up;
    } else if (rest.isNotEmpty) {
      _other = true;
      _otherText.text = rest;
    }
  }

  @override
  void dispose() {
    _otherText.dispose();
    super.dispose();
  }

  /// „9C“ bzw. „6 Ahorn“; '' solange unvollständig.
  String get _value {
    final g = _grade;
    if (g == null) return '';
    if (_other) {
      final o = _otherText.text.trim();
      return o.isEmpty ? '' : '$g $o';
    }
    return _letter == null ? '' : '$g$_letter';
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final kid = k.kid(widget.colorIndex);
    final value = _value;
    Widget chip(String label, bool sel, VoidCallback onTap) => Semantics(
      selected: sel,
      button: true,
      child: Material(
        color: sel ? k.p.strong : k.p.inset,
        borderRadius: BorderRadius.circular(Rad.buttonSmall),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.buttonSmall),
          onTap: onTap,
          child: SizedBox(
            height: Sz.buttonSmall,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
                  child: Text(
                    label,
                    style: k.tileTitle.copyWith(
                      color: sel ? k.p.onStrong : k.p.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    List<Widget> row(List<Widget> chips, {List<int>? flex}) => [
      for (final (i, c) in chips.indexed) ...[
        if (i > 0) const SizedBox(width: Sp.xs + Sp.xxs),
        Expanded(flex: flex?[i] ?? 1, child: c),
      ],
    ];
    Widget caption(String s) => Padding(
      padding: const EdgeInsets.only(bottom: Sp.s),
      child: Text(upperFor(t, s), style: k.dateCaps),
    );
    final meta = [
      if (widget.school.isNotEmpty) widget.school,
      if (widget.detected.isNotEmpty)
        t.classDetectedValue(classLabel(widget.detected)),
    ].join(' · ');
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Sp.xl,
          0,
          Sp.xl,
          Sp.l + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: Sz.avatar / 2,
                  backgroundColor: kid.accent,
                  child: Text(
                    widget.kidName.isEmpty ? '?' : widget.kidName[0],
                    style: k.avatarLetter,
                  ),
                ),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.classSheetTitle(widget.kidName),
                        style: k.sheetTitle,
                      ),
                      if (meta.isNotEmpty) Text(meta, style: k.cardMeta),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.l),
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: Sp.l,
                horizontal: Sp.m,
              ),
              decoration: BoxDecoration(
                color: kid.tint,
                borderRadius: BorderRadius.circular(Rad.panel),
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value.isEmpty ? t.classLine('…') : t.classLine(value),
                  style: k.greeting.copyWith(color: kid.label),
                ),
              ),
            ),
            const SizedBox(height: Sp.l),
            caption(t.classGrade),
            Row(
              children: row([
                for (final g in ClassSheet.grades)
                  chip('$g', g == _grade, () => setState(() => _grade = g)),
              ]),
            ),
            const SizedBox(height: Sp.l),
            caption(t.classLetter),
            Row(
              children: row(
                [
                  for (final l in ClassSheet.letters)
                    chip(
                      l,
                      !_other && l == _letter,
                      () => setState(() {
                        _letter = l;
                        _other = false;
                      }),
                    ),
                  chip(
                    t.classOther,
                    _other,
                    () => setState(() => _other = true),
                  ),
                ],
                flex: [for (final _ in ClassSheet.letters) 1, 2],
              ),
            ),
            if (_other) ...[
              const SizedBox(height: Sp.m),
              TextField(
                controller: _otherText,
                autofocus: true,
                autocorrect: false,
                textCapitalization: TextCapitalization.words,
                style: k.body,
                decoration: onbInput(
                  k,
                  label: t.classOtherLabel,
                  icon: Icons.edit_outlined,
                ).copyWith(hintText: t.classOtherHint),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: Sp.l),
            Container(
              padding: const EdgeInsets.all(Sp.l),
              decoration: BoxDecoration(
                color: k.p.inset,
                borderRadius: BorderRadius.circular(Rad.panel),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    color: k.p.ink,
                    size: Sz.navIcon,
                  ),
                  const SizedBox(width: Sp.m),
                  Expanded(child: Text(t.classValidity, style: k.body)),
                ],
              ),
            ),
            const SizedBox(height: Sp.xl),
            OnbButton(
              label: t.save,
              onPressed: value.isEmpty
                  ? null
                  : () => Navigator.of(context).pop((name: value)),
            ),
            if (widget.hasEntry)
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop((name: null)),
                  child: Text(t.classRemove, style: k.link),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
