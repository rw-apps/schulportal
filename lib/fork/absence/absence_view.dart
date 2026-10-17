import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/utils/responsive.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';

import '../l10n/l10n.dart';
import 'absence_form.dart';
import 'absence_parser.dart';

String _shortDate(ForkL10n t, DateTime d) => formatDate(t, t.dateShort, d);

/// Seite „Krankmeldung“ für Elternkonten.
class AbsencePage extends ConsumerWidget {
  const AbsencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).asData?.value;
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final openDrawer = Responsive.isTablet(context)
        ? null
        : () => Scaffold.of(context).openDrawer();
    Widget? leading() => openDrawer != null
        ? IconButton(icon: const Icon(Icons.menu), onPressed: openDrawer)
        : null;

    return CombinedAppletBuilder<AbsenceForm>(
      parser: ref.watch(absenceParserProvider),
      phpUrl: forkAbsenceApplet.appletPhpUrl,
      settingsDefaults: const {},
      accountType: AccountType.parent,
      showErrorAppBar: true,
      loadingAppBar: AppBar(leading: leading()),
      builder: (context, form, _, _, _, refresh) => Scaffold(
        appBar: AppBar(
          leading: leading(),
          title: Text(context.t.absenceTitle),
          actions: [
            if (refresh != null)
              IconButton(
                tooltip: context.t.reload,
                icon: const Icon(Icons.refresh),
                onPressed: refresh,
              ),
          ],
        ),
        body: AbsenceFormView(
          form: form,
          onCheck: (fields) => checkAbsence(session, fields),
        ),
      ),
    );
  }
}

/// Die eigentliche Maske; getrennt von [AbsencePage], damit sie ohne Portal
/// testbar ist.
class AbsenceFormView extends StatefulWidget {
  const AbsenceFormView({
    super.key,
    required this.form,
    this.now,
    this.onCheck,
  });

  final AbsenceForm form;

  /// Fragt das Portal, ob es die Meldung annehmen würde (sendet nichts).
  final Future<AbsenceCheck> Function(Map<String, String> fields)? onCheck;

  /// Nur für Tests.
  final DateTime? now;

  @override
  State<AbsenceFormView> createState() => _AbsenceFormViewState();
}

class _AbsenceFormViewState extends State<AbsenceFormView> {
  late Set<String> _pupils;
  late String _kind;
  late DateTime _from;
  late DateTime _to;
  late String _blockFrom;
  late String _blockTo;
  final _comment = TextEditingController();
  bool _busy = false;

  AbsenceForm get f => widget.form;
  bool get _isLate => _kind == absenceKindLate;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant AbsenceFormView old) {
    super.didUpdateWidget(old);
    if (!identical(old.form, widget.form)) _clampToForm();
  }

  /// Nach dem Neuladen (alle paar Minuten) Eingaben behalten und nur an
  /// neue Portal-Grenzen anpassen, statt alles zurückzusetzen.
  void _clampToForm() {
    final allowed = {for (final p in f.allowedPupils) p.id};
    _pupils = _pupils.where(allowed.contains).toSet();
    if (!f.kinds.any((k) => k.value == _kind)) {
      _kind = f.kinds.isNotEmpty ? f.kinds.first.value : '';
    }
    DateTime clamp(DateTime d, DateRange? r) => r == null
        ? d
        : (d.isBefore(r.first) ? r.first : (d.isAfter(r.last) ? r.last : d));
    _from = clamp(_from, f.fromRange);
    _to = clamp(_to, f.toRange);
    if (_to.isBefore(_from)) _to = _from;
    if (!f.blocks.any((b) => b.value == _blockFrom)) {
      _blockFrom = f.blocks.isNotEmpty ? f.blocks.first.value : '';
    }
    if (!f.blocks.any((b) => b.value == _blockTo)) {
      _blockTo = f.blocks.isNotEmpty ? f.blocks.last.value : '';
    }
  }

  void _reset() {
    final allowed = f.allowedPupils;
    final pre = allowed.where((p) => p.preselected).map((p) => p.id).toSet();
    _pupils = pre.isNotEmpty
        ? pre
        : (allowed.length == 1 ? {allowed.single.id} : <String>{});
    _kind = f.kinds.isNotEmpty ? f.kinds.first.value : '';
    final today = widget.now ?? DateTime.now();
    _from = f.defaultFrom ?? f.fromRange?.first ?? today;
    _to = f.defaultTo ?? _from;
    _blockFrom = f.blocks.isNotEmpty ? f.blocks.first.value : '';
    _blockTo = f.blocks.isNotEmpty ? f.blocks.last.value : '';
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  AbsenceDraft get _draft => AbsenceDraft(
    pupilIds: _pupils.toList(),
    kind: _kind,
    from: _from,
    to: _to,
    blockFrom: _blockFrom,
    blockTo: _blockTo,
    comment: _comment.text.trim(),
  );

  Future<void> _pickDate({required bool isFrom}) async {
    final range = isFrom ? f.fromRange : f.toRange;
    final current = isFrom ? _from : _to;
    final first = range?.first ?? current;
    final last = range?.last ?? current;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(first)
          ? first
          : (current.isAfter(last) ? last : current),
      firstDate: first,
      lastDate: last,
      helpText: isFrom ? context.t.absenceFirstDay : context.t.absenceLastDay,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
      }
    });
  }

  String _blockLabel(AbsenceBlock b) => b.start != null && b.end != null
      ? '${b.label}  ${b.start}–${b.end}'
      : b.label;

  String _summary(ForkL10n t) {
    final names = f.pupils
        .where((p) => _pupils.contains(p.id))
        .map((p) => p.firstName)
        .join(' ${t.and} ');
    AbsenceBlock? block(String v) =>
        f.blocks.where((b) => b.value == v).firstOrNull;
    final String when;
    if (_isLate) {
      final bf = block(_blockFrom)?.label ?? '?';
      final bt = block(_blockTo)?.label ?? '?';
      when = bf == bt
          ? t.absenceBlockOne(_shortDate(t, _from), bf)
          : t.absenceBlockRange(_shortDate(t, _from), bf, bt);
    } else {
      when = DateUtils.isSameDay(_from, _to)
          ? t.absenceWholeDay(_shortDate(t, _from))
          : t.absenceDayRange(_shortDate(t, _from), _shortDate(t, _to));
    }
    final kind = _isLate ? t.absenceKindLate : t.absenceKindAbsent;
    return '${names.isEmpty ? t.absenceNoChild : names} – $kind\n$when';
  }

  Future<void> _check() async {
    final onCheck = widget.onCheck;
    if (onCheck == null) return;
    final t = context.t;
    setState(() => _busy = true);
    String title;
    List<String> lines;
    try {
      final r = await onCheck(_draft.toFields(f));
      title = r.ok ? t.absenceCheckPassed : t.absenceRejected;
      lines = r.ok ? [t.absenceWouldAccept, t.absenceNothingSent] : r.errors;
    } catch (_) {
      title = t.absenceCheckImpossible;
      lines = [t.absenceNoConnection];
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(lines.join('\n\n')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showFields() {
    final fields = _draft.toFields(f);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.absenceFieldsTitle),
        content: SingleChildScrollView(
          child: SelectableText(
            fields.entries.map((e) => '${e.key} = ${e.value}').join('\n'),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text: fields.entries
                      .map((e) => '${e.key}=${e.value}')
                      .join('\n'),
                ),
              );
              Navigator.pop(context);
            },
            child: Text(context.t.copy),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t;
    final errors = validateAbsenceDraft(f, _draft, t);
    final allowed = f.allowedPupils;

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );

    return ListView(
      // Unterkante = 32 + Höhe der System-Navigationsleiste. Ursache: Die App
      // läuft randlos (SystemUiMode.edgeToEdge, main.dart), und ein ListView
      // mit eigenem `padding` übernimmt die MediaQuery-Ränder NICHT selbst.
      // Ohne den Zuschlag lag der letzte Knopf auf dem Pixel 9a halb unter
      // der Gestenleiste (Screenshot 16.10.26, 9311).
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (f.rules.isNotEmpty)
          Card(
            color: theme.colorScheme.secondaryContainer,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.absenceRules(f.rules.join(' ${t.and} ')),
                      style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (allowed.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(t.absenceNoneAllowed),
          )
        else ...[
          if (f.kinds.length > 1)
            section(
              t.absenceKind,
              SegmentedButton<String>(
                segments: [
                  for (final k in f.kinds)
                    ButtonSegment(
                      value: k.value,
                      label: Text(
                        k.value == 'krank' ? t.absenceAbsent : t.absenceLate,
                      ),
                      icon: Icon(
                        k.value == 'krank'
                            ? Icons.sick_outlined
                            : Icons.schedule,
                      ),
                    ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.single),
              ),
            ),
          section(
            t.absenceChild,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in f.pupils)
                  FilterChip(
                    label: Text(p.name),
                    selected: _pupils.contains(p.id),
                    onSelected: p.allowed
                        ? (v) => setState(
                            () => v ? _pupils.add(p.id) : _pupils.remove(p.id),
                          )
                        : null,
                  ),
              ],
            ),
          ),
          // Wie im Portal (meldungEltern.js): abwesend = Von/Bis-Tag ohne
          // Blöcke; verspätet = ein Tag („Am“) mit Block von–bis.
          if (_isLate) ...[
            section(
              t.absenceDay,
              _DateTile(
                label: t.absenceOn,
                date: _from,
                onTap: () => _pickDate(isFrom: true),
              ),
            ),
            section(
              t.absenceLessons,
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _blockFrom,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t.absenceFromBlock,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final b in f.blocks)
                        DropdownMenuItem(
                          value: b.value,
                          child: Text(_blockLabel(b)),
                        ),
                    ],
                    onChanged: (v) => setState(() => _blockFrom = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _blockTo,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t.absenceToBlock,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final b in f.blocks)
                        DropdownMenuItem(
                          value: b.value,
                          child: Text(_blockLabel(b)),
                        ),
                    ],
                    onChanged: (v) => setState(() => _blockTo = v!),
                  ),
                ],
              ),
            ),
          ] else
            section(
              t.absencePeriod,
              Column(
                children: [
                  _DateTile(
                    label: t.absenceFrom,
                    date: _from,
                    onTap: () => _pickDate(isFrom: true),
                  ),
                  const SizedBox(height: 8),
                  _DateTile(
                    label: t.absenceTo,
                    date: _to,
                    onTap: () => _pickDate(isFrom: false),
                  ),
                ],
              ),
            ),
          section(
            t.absenceComment,
            TextField(
              controller: _comment,
              maxLength: 200,
              // Warnung des Portals immer sichtbar (dort erst beim Antippen).
              // Vorher stand hier „z. B. Arzttermin“ – genau die Art Angabe,
              // vor der das Portal warnt.
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                helperText: f.commentWarning ?? t.absenceNoHealthData,
                helperMaxLines: 2,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.absenceSummary, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(_summary(t), style: theme.textTheme.bodyLarge),
                  for (final e in errors)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        e,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Absenden kommt erst nach dem gemeinsamen Test, siehe AbsenceDraft.
          FilledButton(onPressed: null, child: Text(t.absenceSendLater)),
          const SizedBox(height: 8),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(),
            ),
          OutlinedButton(
            onPressed: errors.isEmpty && !_busy && widget.onCheck != null
                ? _check
                : null,
            child: Text(t.absenceCheck),
          ),
          TextButton(
            onPressed: errors.isEmpty ? _showFields : null,
            child: Text(t.absencePreview),
          ),
          if (f.entries.isNotEmpty)
            section(
              t.absenceEntries,
              Column(
                children: [
                  for (final e in f.entries)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('${e.name} – ${e.kind}'),
                        subtitle: Text(
                          [
                            e.period,
                            if (e.comment.isNotEmpty) e.comment,
                          ].join('\n'),
                        ),
                        trailing: Text(
                          e.entered,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          formatDate(context.t, context.t.dateShortYear, date),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
