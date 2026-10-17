import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import '../../data/message_templates.dart';
import '../../l10n/l10n.dart';
import '../kit.dart';
import 'compose_model.dart';

/// Abfrage und Versand, austauschbar für Tests (kein Portal nötig).
abstract class ComposeBackend {
  Future<List<ReceiverEntry>> search(String query);
  Future<bool> send({
    required List<String> receivers,
    required String subject,
    required String text,
  });
}

/// Echter Versand über ConversationsParser (liblanis) – dieselben Aufrufe
/// wie die bisherige Ansicht (conversations_view.dart, createConversation):
/// Art nur, wenn die Schule die Wahl anbietet (canChooseType), dann wie dort
/// vorgeschlagen „groupOnly“.
class PortalComposeBackend implements ComposeBackend {
  PortalComposeBackend(this.parser);

  final ConversationsParser parser;

  @override
  Future<List<ReceiverEntry>> search(String query) =>
      parser.searchTeacher(query);

  @override
  Future<bool> send({
    required List<String> receivers,
    required String subject,
    required String text,
  }) async {
    final choose = await parser.canChooseType();
    final r = await parser.createConversation(
      receivers,
      choose ? ChatType.groupOnly.name : null,
      subject,
      text,
    );
    if (r.success) {
      // Liste nachladen darf das Ergebnis nicht kippen: Die Nachricht ist
      // schon beim Portal. Ursache: Ein Fehler hier hätte „nicht angenommen“
      // gemeldet und zum doppelten Senden verleitet (Prüfbefund 17.10.26).
      try {
        await parser.fetchData(forceRefresh: true);
      } catch (_) {}
    }
    return r.success;
  }
}

enum _State { idle, resolving, notFound }

/// „Neue Nachricht“ in drei Schritten (Konzept 17.10.26): An wen? (aus dem
/// Unterricht des Kindes, freie Suche als Rückfall) · Worum geht es?
/// (Vorlagen) · Senden (mit Rückfrage).
class ComposePage extends StatefulWidget {
  const ComposePage({
    super.key,
    required this.candidates,
    required this.backend,
    this.initialKuerzel,
  });

  final List<RecipientCandidate> candidates;
  final ComposeBackend backend;

  /// Lehrkraft, die schon gewählt sein soll (Kursseite → „Schreiben“).
  final String? initialKuerzel;

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  /// Gewählte Empfänger: Portal-ID → Anzeigename.
  final _chosen = <String, String>{};

  /// Welche Portal-ID zu welcher Lehrkraft (Kürzel) gehört.
  final _idOf = <String, String>{};
  final _state = <String, _State>{};
  final _subject = TextEditingController();
  final _text = TextEditingController();
  final _search = TextEditingController();
  List<ReceiverEntry> _found = const [];
  bool _searching = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final kz = widget.initialKuerzel;
    final c = widget.candidates.where((c) => c.kuerzel == kz).firstOrNull;
    // Nach dem ersten Bild: _toggle sucht im Portal und kann bei mehreren
    // Treffern eine Auswahl öffnen (braucht einen fertigen Kontext).
    if (c != null)
      WidgetsBinding.instance.addPostFrameCallback((_) => _toggle(c));
  }

  @override
  void dispose() {
    _subject.dispose();
    _text.dispose();
    _search.dispose();
    super.dispose();
  }

  bool get _ready =>
      _chosen.isNotEmpty &&
      _subject.text.trim().isNotEmpty &&
      _text.text.trim().isNotEmpty &&
      !_sending;

  Future<void> _toggle(RecipientCandidate c) async {
    final id = _idOf[c.kuerzel];
    if (id != null && _chosen.containsKey(id)) {
      setState(() => _chosen.remove(id));
      return;
    }
    setState(() => _state[c.kuerzel] = _State.resolving);
    List<ReceiverEntry> hits;
    try {
      hits = matchReceivers(await widget.backend.search(c.lastName), c);
    } catch (_) {
      hits = const [];
    }
    if (!mounted) return;
    ReceiverEntry? pick;
    if (hits.length == 1) {
      pick = hits.single;
    } else if (hits.length > 1) {
      pick = await _choose(c.display, hits);
    }
    if (!mounted) return;
    setState(() {
      if (pick == null) {
        _state[c.kuerzel] = hits.isEmpty ? _State.notFound : _State.idle;
        return;
      }
      _state[c.kuerzel] = _State.idle;
      _idOf[c.kuerzel] = pick.id;
      _chosen[pick.id] = c.display;
    });
  }

  Future<ReceiverEntry?> _choose(String who, List<ReceiverEntry> hits) {
    final k = Kit.of(context);
    return showModalBottomSheet<ReceiverEntry>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: k.p.card,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.l),
          children: [
            Text(context.t.whichPerson(who), style: k.sheetTitle),
            const SizedBox(height: Sp.m),
            for (final h in hits)
              ListTile(
                title: Text(h.name, style: k.planSubject(k.p.ink)),
                onTap: () => Navigator.of(context).pop(h),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _runSearch() async {
    final q = _search.text.trim();
    if (q.length < 2) return;
    setState(() => _searching = true);
    List<ReceiverEntry> r;
    try {
      r = await widget.backend.search(q);
    } catch (_) {
      r = const [];
    }
    if (!mounted) return;
    setState(() {
      _found = r;
      _searching = false;
    });
  }

  void _template(MessageTemplate m) {
    setState(() {
      if (_subject.text.trim().isEmpty) _subject.text = m.subject;
      if (_text.text.trim().isEmpty) _text.text = m.text;
    });
  }

  Future<void> _send() async {
    final k = Kit.of(context);
    final t = context.t;
    final names = _chosen.values.join(', ');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.sendQuestion, style: k.sheetTitle),
        content: Text(t.sendConfirmText(names), style: k.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel, style: k.link),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.send, style: k.link),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _sending = true);
    var sent = false;
    try {
      sent = await widget.backend.send(
        receivers: _chosen.keys.toList(),
        subject: _subject.text.trim(),
        text: _text.text.trim(),
      );
    } catch (_) {
      sent = false;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    if (sent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.sentTo(names))));
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.sendFailed)));
    }
  }

  /// Beschriftung der Vorlage in der App-Sprache (Inhalt bleibt deutsch).
  String _templateLabel(ForkL10n t, MessageTemplate m) => switch (m.id) {
    'homeworkQuestion' => t.tplHomeworkQuestion,
    'callback' => t.tplCallback,
    'appointment' => t.tplAppointment,
    _ => m.subject,
  };

  InputDecoration _field(Kit k, String hint) => InputDecoration(
    hintText: hint,
    hintStyle: k.meta,
    filled: true,
    fillColor: k.p.card,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Rad.row),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.all(Sp.m),
  );

  Widget _step(Kit k, String n, String title) => Padding(
    padding: const EdgeInsets.only(top: Sp.xl, bottom: Sp.s, left: Sp.xs),
    child: Text('$n  $title', style: k.section),
  );

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final german = Localizations.localeOf(context).languageCode == 'de';
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: k.p.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(Sp.page, Sp.m, Sp.page, bottom + Sp.xl),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.close, color: k.p.ink),
                  tooltip: t.cancel,
                ),
                const SizedBox(width: Sp.xs),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(t.newMessage, style: k.pageTitle),
                  ),
                ),
              ],
            ),
            _step(k, '1', t.stepToWhom),
            if (widget.candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: Sp.xs, bottom: Sp.s),
                child: Text(t.noKnownTeachers, style: k.meta),
              ),
            for (final c in widget.candidates)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.s),
                child: _CandidateTile(
                  candidate: c,
                  selected: _chosen.containsKey(_idOf[c.kuerzel]),
                  state: _state[c.kuerzel] ?? _State.idle,
                  onTap: () => _toggle(c),
                ),
              ),
            const SizedBox(height: Sp.s),
            TextField(
              controller: _search,
              style: k.body,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              decoration: _field(k, t.searchOtherPerson).copyWith(
                suffixIcon: IconButton(
                  icon: _searching
                      ? const SizedBox.square(
                          dimension: Sz.icon,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.search, color: k.p.muted),
                  onPressed: _runSearch,
                ),
              ),
            ),
            for (final r in _found)
              CheckboxListTile(
                value: _chosen.containsKey(r.id),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _chosen[r.id] = r.name;
                  } else {
                    _chosen.remove(r.id);
                  }
                }),
                title: Text(r.name, style: k.planSubject(k.p.ink)),
                subtitle: r.isTeacher
                    ? Text(t.teacher, style: k.planMeta(k.p.muted))
                    : null,
              ),
            _step(k, '2', t.stepTopic),
            Wrap(
              spacing: Sp.s,
              runSpacing: Sp.s,
              children: [
                for (final m in messageTemplates)
                  ActionChip(
                    label: Text(
                      _templateLabel(t, m),
                      style: k.chipLabel(false, k.p.onStrong),
                    ),
                    backgroundColor: k.p.card,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Rad.pill),
                    ),
                    onPressed: () => _template(m),
                  ),
              ],
            ),
            if (!german)
              Padding(
                padding: const EdgeInsets.only(top: Sp.s, left: Sp.xs),
                child: Text(t.templatesNote, style: k.meta),
              ),
            const SizedBox(height: Sp.m),
            TextField(
              controller: _subject,
              style: k.body,
              onChanged: (_) => setState(() {}),
              decoration: _field(k, t.subject),
            ),
            const SizedBox(height: Sp.s),
            TextField(
              controller: _text,
              style: k.body,
              minLines: 6,
              maxLines: null,
              onChanged: (_) => setState(() {}),
              decoration: _field(k, t.message),
            ),
            _step(k, '3', t.send),
            Material(
              color: _ready ? k.p.strong : k.p.inset,
              borderRadius: BorderRadius.circular(Rad.button),
              child: InkWell(
                borderRadius: BorderRadius.circular(Rad.button),
                onTap: _ready ? _send : null,
                child: SizedBox(
                  height: Sz.button,
                  child: Center(
                    child: _sending
                        ? const CircularProgressIndicator()
                        : Text(
                            _chosen.isEmpty
                                ? t.chooseRecipientFirst
                                : _chosen.length == 1
                                ? t.sendToOne(_chosen.values.single)
                                : t.sendToMany(_chosen.length),
                            style: k.button(_ready ? k.p.onStrong : k.p.muted),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.candidate,
    required this.selected,
    required this.state,
    required this.onTap,
  });

  final RecipientCandidate candidate;
  final bool selected;
  final _State state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final tone = k.kid(0);
    final sub = state == _State.notFound
        ? context.t.notReachable
        : candidate.subjects.join(', ');
    return Material(
      color: selected ? tone.tint : k.p.card,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.signal),
        onTap: state == _State.resolving ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.m),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.display,
                      style: k.planSubject(selected ? tone.onTint : k.p.ink),
                    ),
                    Text(
                      sub,
                      style: k.planMeta(selected ? tone.meta : k.p.muted),
                    ),
                  ],
                ),
              ),
              if (state == _State.resolving)
                const SizedBox.square(
                  dimension: Sz.icon,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  selected ? Icons.check_circle : Icons.add_circle_outline,
                  size: Sz.navIcon,
                  color: selected ? tone.label : k.p.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Für die Live-Seite: Backend aus dem Provider.
ComposeBackend portalBackend(WidgetRef ref) =>
    PortalComposeBackend(ref.read(conversationsParserProvider));
