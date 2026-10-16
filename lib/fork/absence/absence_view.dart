import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/utils/responsive.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';

import 'absence_form.dart';
import 'absence_parser.dart';

const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
String _shortDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day}.${d.month}.';

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
          title: const Text('Krankmeldung'),
          actions: [
            if (refresh != null)
              IconButton(
                tooltip: 'Neu laden',
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
      helpText: isFrom ? 'Erster Tag' : 'Letzter Tag',
    );
    if (picked == null) return;
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

  String _summary() {
    final names = f.pupils
        .where((p) => _pupils.contains(p.id))
        .map((p) => p.firstName)
        .join(' und ');
    AbsenceBlock? block(String v) =>
        f.blocks.where((b) => b.value == v).firstOrNull;
    final String when;
    if (_isLate) {
      final bf = block(_blockFrom)?.label ?? '?';
      final bt = block(_blockTo)?.label ?? '?';
      when = bf == bt
          ? '${_shortDate(_from)}, $bf'
          : '${_shortDate(_from)}, $bf bis $bt';
    } else {
      when = DateUtils.isSameDay(_from, _to)
          ? '${_shortDate(_from)}, ganzer Tag'
          : '${_shortDate(_from)} bis ${_shortDate(_to)}';
    }
    final kind = _isLate ? 'verspätet' : 'abwesend';
    return '${names.isEmpty ? 'Kein Kind gewählt' : names} – $kind\n$when';
  }

  Future<void> _check() async {
    final onCheck = widget.onCheck;
    if (onCheck == null) return;
    setState(() => _busy = true);
    String title;
    List<String> lines;
    try {
      final r = await onCheck(_draft.toFields(f));
      title = r.ok ? 'Prüfung bestanden' : 'Das Portal lehnt ab';
      lines = r.ok
          ? [
              'Das Portal würde diese Meldung annehmen.',
              'Gesendet wurde nichts – die Schule sieht davon nichts.',
            ]
          : r.errors;
    } catch (_) {
      title = 'Prüfung nicht möglich';
      lines = ['Keine Verbindung zum Portal oder unerwartete Antwort.'];
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
        title: const Text('Das würde ans Portal gehen'),
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
            child: const Text('Kopieren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errors = validateAbsenceDraft(f, _draft);
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
                      'Das Portal nimmt Meldungen ${f.rules.join(' und ')} an.',
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
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text(
              'Die Schule erlaubt derzeit für kein Kind eine Meldung über das Portal.',
            ),
          )
        else ...[
          if (f.kinds.length > 1)
            section(
              'Art',
              SegmentedButton<String>(
                segments: [
                  for (final k in f.kinds)
                    ButtonSegment(
                      value: k.value,
                      label: Text(
                        k.value == 'krank' ? 'Abwesend' : 'Verspätet',
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
            'Kind',
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
              'Tag',
              _DateTile(
                label: 'Am',
                date: _from,
                onTap: () => _pickDate(isFrom: true),
              ),
            ),
            section(
              'Unterricht',
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _blockFrom,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Von Block',
                      border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: 'Bis Block (einschließlich)',
                      border: OutlineInputBorder(),
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
              'Zeitraum',
              Column(
                children: [
                  _DateTile(
                    label: 'Von',
                    date: _from,
                    onTap: () => _pickDate(isFrom: true),
                  ),
                  const SizedBox(height: 8),
                  _DateTile(
                    label: 'Bis',
                    date: _to,
                    onTap: () => _pickDate(isFrom: false),
                  ),
                ],
              ),
            ),
          section(
            'Kommentar (freiwillig)',
            TextField(
              controller: _comment,
              maxLength: 200,
              // Warnung des Portals immer sichtbar (dort erst beim Antippen).
              // Vorher stand hier „z. B. Arzttermin“ – genau die Art Angabe,
              // vor der das Portal warnt.
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                helperText:
                    f.commentWarning ??
                    'Bitte keine Gesundheitsdaten eingeben.',
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
                  Text('Zusammenfassung', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(_summary(), style: theme.textTheme.bodyLarge),
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
          const FilledButton(
            onPressed: null,
            child: Text('Absenden (folgt nach gemeinsamem Test)'),
          ),
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
            child: const Text('Beim Portal prüfen (sendet nichts)'),
          ),
          TextButton(
            onPressed: errors.isEmpty ? _showFields : null,
            child: const Text('Vorschau der Portal-Felder'),
          ),
          if (f.entries.isNotEmpty)
            section(
              'Aktuelle und zukünftige Meldungen',
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
          '${_shortDate(date)}${date.year}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
