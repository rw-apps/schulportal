import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/bridge/lanis_bootstrap.dart' show bootstrapOverrides;

import '../../error_log.dart';
import '../../kid_colors.dart';
import '../../login_guard.dart';
import '../../l10n/l10n.dart';
import '../kid_chips.dart';
import '../kit.dart';
import 'live_data.dart';

/// Ein Konto der Familie mit seinem geladenen Stand.
///
/// [container] ist null für das aktive Konto (App-ProviderScope); weitere
/// Konten haben einen eigenen Container ([FamilyScope]).
class FamilyMember {
  const FamilyMember({
    required this.accountId,
    required this.snapshot,
    required this.colorIndex,
    this.container,
  });

  final int accountId;
  final LiveSnapshot snapshot;
  final int colorIndex;
  final ProviderContainer? container;

  bool get active => container == null;

  /// [child] mit den Providern und Daten dieses Kontos. Ursache: Bestehende
  /// Seiten (Unterricht, Nachrichten, Krankmeldung, Kursseite, Unterhaltung)
  /// lesen Parser und Sitzung über `ref` und den Stand über [LiveData]; mit
  /// diesem Rahmen arbeiten sie unverändert für jedes Konto.
  ///
  /// Der Stand kommt bei jedem Aufbau neu aus [FamilyData] (dasselbe Konto
  /// über [accountId]), nicht der beim Öffnen. Ursache (Rückmeldung
  /// 20.10.26): Eine so geöffnete Seite – Archiv „Erledigte Hausaufgaben“,
  /// Kursseite – behielt den Stand vom Öffnen; nach „Wieder offen“ blieb die
  /// Zeile stehen, obwohl gespeichert war. Grenze: Ohne [FamilyData] über
  /// der Seite (Vollbild über dem Navigator der App) bleibt es beim Stand
  /// vom Öffnen.
  Widget scope(Widget child) {
    final data = Builder(
      builder: (context) {
        final current =
            FamilyData.of(
              context,
            ).where((m) => m.accountId == accountId).firstOrNull ??
            this;
        return LiveData(
          snapshot: current.snapshot,
          child: _MemberMarker(member: current, child: child),
        );
      },
    );
    final c = container;
    return c == null
        ? data
        : UncontrolledProviderScope(container: c, child: data);
  }

  /// Konto, in dessen Rahmen [context] liegt (null = aktives Konto ohne
  /// Rahmen).
  static FamilyMember? around(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_MemberMarker>()?.member;
}

/// Merkt sich das Konto eines [FamilyMember.scope] für neu geöffnete Seiten.
///
/// Ursache: Eine Seite, die man aus „Unterricht“ eines weiteren Kontos
/// öffnet, liegt im Navigator des Reiters – und der hängt am Rahmen des
/// AKTIVEN Kontos. Ohne erneuten Rahmen (nav.dart, pushInTab/pushFullScreen)
/// läsen Unterhaltung oder Abgabe die Sitzung des falschen Kontos.
class _MemberMarker extends InheritedWidget {
  const _MemberMarker({required this.member, required super.child});

  final FamilyMember member;

  @override
  bool updateShouldNotify(_MemberMarker old) => old.member != member;
}

/// Alle Konten des Geräts, aktives zuerst nach Kontoreihenfolge sortiert.
class FamilyData extends InheritedWidget {
  const FamilyData({
    super.key,
    required this.members,
    required super.child,
    this.selectedAccount,
    this.onSelect,
    this.showAll = true,
    this.onSelectAll,
    this.failures = const [],
    this.onRetry,
  });

  final List<FamilyMember> members;

  /// Weitere Konten, deren Anmeldung fehlschlug (Passwort abgelehnt, Sperre
  /// des Portals, keine Verbindung …), mit „Erneut versuchen“ ([onRetry]).
  /// Ursache (Rückmeldung 19.10.26): Vorher fehlte ein solches Kind einfach,
  /// ohne Hinweis.
  final List<FamilyFailure> failures;
  final void Function(int accountId)? onRetry;

  /// Gewähltes Kind (Konto) für Kalender, Unterricht, Nachrichten und Mehr –
  /// EINE Wahl für alle Reiter. Ursache (Rückmeldung 17.10.26): Jeder
  /// Bereich merkte sich seine eigene Wahl; nach dem Reiterwechsel stand
  /// wieder das erste Kind da. Grenze: gilt bis zum Neustart der App.
  final int? selectedAccount;
  final void Function(int accountId)? onSelect;

  /// „Alle“ gewählt – gilt für jeden Bereich, der „Alle“ anbietet (Heute,
  /// Unterricht, Nachrichten, Kalender-Termine); Bereiche ohne „Alle“
  /// zeigen dann [selectedAccount] bzw. das erste Kind. Wer ein Kind wählt
  /// ([onSelect]), beendet „Alle“ überall. Ursache (Rückmeldung 20.10.26):
  /// „Alle“ merkte sich jeder Bereich selbst und begann neu mit „Alle“ –
  /// beim Reiterwechsel sprang die Wahl zwischen „Alle“ und den Kindern.
  final bool showAll;
  final VoidCallback? onSelectAll;

  /// Leer, solange nichts geladen ist (oder in Tests ohne Familie).
  static List<FamilyMember> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FamilyData>()?.members ??
      const [];

  static FamilyData? scopeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FamilyData>();

  @override
  bool updateShouldNotify(FamilyData old) => true;
}

/// Lädt neben dem aktiven Konto alle weiteren Konten des Geräts und stellt
/// sie als [FamilyData] bereit.
///
/// Ursache (Rückmeldung 17.10.26): Mit zwei Konten (Elternkonto Schule A,
/// Schülerkonto Schule B) zeigte die App nur das zuletzt angelegte; das
/// andere war nur über „Konto wechseln“ erreichbar. Gewünscht ist eine
/// gemeinsame Ansicht aller Kinder.
///
/// Wie: liblanis führt je ProviderContainer genau ein angemeldetes Konto
/// (activeAccountProvider/sessionProvider). Für jedes weitere Konto entsteht
/// ein eigener Container mit derselben Datenbank (eine Verbindung,
/// lanisDatabaseProvider.overrideWithValue) und eigener Sitzung samt
/// Cookie-Speicher (LanisSession.jar). Darin läuft ein unsichtbares
/// [LiveDataScope] – dieselbe Ladelogik wie für das aktive Konto.
///
/// Grenze: Jedes Konto meldet sich beim Start selbst an (einige Sekunden
/// mehr); scheitert die Anmeldung (Passwort geändert, offline), fehlt dieses
/// Kind, bis die App neu startet – vermerkt im Fehlerprotokoll („family“).
class FamilyScope extends ConsumerStatefulWidget {
  const FamilyScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FamilyScope> createState() => _FamilyScopeState();
}

/// Fehlgeschlagene Anmeldung eines weiteren Kontos.
class FamilyFailure {
  const FamilyFailure({required this.account, required this.error});

  final AccountSummary account;
  final Object error;
}

class _FamilyScopeState extends ConsumerState<FamilyScope> {
  final _containers = <int, ProviderContainer>{};

  /// Konten, deren Anmeldung fehlschlug – bis „Erneut versuchen“ kein neuer
  /// Versuch. Ursache (Fund 19.10.26): Ein fehlgeschlagenes Konto fiel aus
  /// [_containers] und galt beim nächsten Aufbau (der ständig vorkommt)
  /// wieder als neu – die App meldete sich in schneller Folge immer wieder
  /// falsch an, und das Portal sperrte das Konto mit wachsender Wartezeit,
  /// auch für die Webseite.
  final _failed = <int, Object>{};
  final _hosts = <int, Widget>{};
  final _snaps = <int, LiveSnapshot>{};
  int? _selected;

  /// „Alle“ (FamilyData.showAll); zu Beginn an wie bisher je Bereich.
  bool _all = true;

  @override
  void initState() {
    super.initState();
    // Farbe in den Einstellungen gewählt oder Eingaben übernommen.
    settingsRevision.addListener(_onSettings);
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    settingsRevision.removeListener(_onSettings);
    for (final id in [..._containers.keys]) {
      _drop(id);
    }
    super.dispose();
  }

  /// Container eines Kontos freigeben. [logout] nur, wenn das Konto
  /// gelöscht wurde oder die App schließt: Ist es gerade zum aktiven Konto
  /// geworden, meldet sich der App-Container eben selbst an – ein Abmelden
  /// der alten Sitzung könnte dann (je nach Portal) auch die neue beenden.
  void _drop(int id, {bool logout = true}) {
    final c = _containers.remove(id);
    _hosts.remove(id);
    _snaps.remove(id);
    if (c == null) return;
    if (!logout) {
      c.dispose();
      return;
    }
    c
        .read(sessionProvider.notifier)
        .deAuthenticate()
        .catchError((_) {})
        .whenComplete(c.dispose);
  }

  /// Erneut anmelden (Knopf): auf ausdrücklichen Wunsch, darf also auch ein
  /// schon abgelehntes Passwort noch einmal versuchen (login_guard.dart).
  void _retry(int id) {
    setState(() => _failed.remove(id));
    _start(id, user: true);
  }

  Future<void> _start(int id, {bool user = false}) async {
    final c = ProviderContainer(
      overrides: [
        ...bootstrapOverrides,
        lanisDatabaseProvider.overrideWithValue(
          ref.read(lanisDatabaseProvider),
        ),
      ],
    );
    _containers[id] = c;
    final db = ref.read(lanisDatabaseProvider);
    try {
      final before = (await db.getAccount(id))?.lastLogin;
      await c.read(activeAccountProvider.notifier).select(id);
      final account = c.read(activeAccountProvider);
      await guardedLogin(
        TypedSettings.account(db, id),
        account?.password ?? '',
        () => c.read(sessionProvider.notifier).authenticate(),
        userInitiated: user,
      );
      // Anmelden setzt last_login; die App startet mit dem Konto mit dem
      // jüngsten Wert (getPreferredStartupAccount). Ohne Zurücksetzen wäre
      // nach jedem Start ein anderes Konto „aktiv“ (Einstellungen, Abmelden).
      if (before == null) {
        await db.clearLastLogin(id);
      } else {
        await db.updateLastLogin(id, at: before);
      }
    } catch (e, st) {
      ErrorLog.instance.record('family', e, st);
      if (_containers[id] == c) {
        _containers.remove(id);
        c.dispose();
      }
      if (mounted) setState(() => _failed[id] = e);
      return;
    }
    if (!mounted || _containers[id] != c) {
      c.dispose();
      return;
    }
    setState(() {
      _hosts[id] = UncontrolledProviderScope(
        container: c,
        child: LiveDataScope(child: _Report(onSnapshot: (s) => _report(id, s))),
      );
    });
  }

  void _report(int id, LiveSnapshot s) {
    if (!mounted || !_containers.containsKey(id)) return;
    if (identical(_snaps[id], s)) return;
    setState(() => _snaps[id] = s);
  }

  @override
  Widget build(BuildContext context) {
    // .value statt asData: Beim Neuladen der Kontoliste (nach jeder
    // Anmeldung, Session.authenticate) bleibt der alte Stand sichtbar –
    // sonst würden kurz alle weiteren Konten verworfen und neu angemeldet.
    final loaded = ref.watch(accountsProvider).value;
    final accounts = loaded ?? const <AccountSummary>[];
    final activeId = ref.watch(activeAccountProvider)?.localId;
    final others = {
      for (final a in accounts)
        if (a.localId != activeId) a.localId,
    };
    // Nicht mehr benötigte Container (gelöscht oder jetzt aktiv) freigeben,
    // neue anstoßen – nach dem Bauen, nie währenddessen.
    final stale = _containers.keys.where((id) => !others.contains(id)).toList();
    final fresh = others
        .where((id) => !_containers.containsKey(id) && !_failed.containsKey(id))
        .toList();
    // Fehlschläge vergessen, wenn das Konto weg oder jetzt aktiv ist.
    _failed.removeWhere((id, _) => !others.contains(id));
    if (loaded != null && (stale.isNotEmpty || fresh.isNotEmpty)) {
      final gone = {
        for (final id in stale)
          if (!accounts.any((a) => a.localId == id)) id,
      };
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final id in stale) {
          _drop(id, logout: gone.contains(id));
        }
        for (final id in fresh) {
          if (!_containers.containsKey(id)) _start(id);
        }
        if (stale.isNotEmpty) setState(() {});
      });
    }

    final main = LiveData.of(context);
    final members = <FamilyMember>[];
    // Reihenfolge und Farbe nach Anlage des Kontos (localId), nicht nach
    // der Kontoliste: Die sortiert nach letzter Anmeldung (liblanis
    // listAccounts) – nach dem Wechseln tauschten die Kinder Platz und Farbe
    // (Bildschirmfoto 17.10.26). Auch nicht nach Ladereihenfolge.
    final ordered = [...accounts]
      ..sort((a, b) => a.localId.compareTo(b.localId));
    // Feste Farbe je Konto (kid_colors.dart); neue Konten bekommen die erste
    // freie und behalten sie.
    final db = ref.read(lanisDatabaseProvider);
    final assigned = assignKidColors(
      [for (final a in ordered) a.localId],
      {
        for (final a in ordered)
          a.localId: storedKidColor(TypedSettings.account(db, a.localId)),
      },
    );
    for (final e in assigned.fresh.entries) {
      storeKidColor(TypedSettings.account(db, e.key), e.value);
    }
    for (final a in ordered) {
      final color = assigned.colors[a.localId]!;
      if (a.localId == activeId) {
        if (main != null) {
          members.add(
            FamilyMember(
              accountId: a.localId,
              snapshot: main,
              colorIndex: color,
            ),
          );
        }
      } else if (_snaps[a.localId] case final s?) {
        members.add(
          FamilyMember(
            accountId: a.localId,
            snapshot: s,
            colorIndex: color,
            container: _containers[a.localId],
          ),
        );
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FamilyData(
          members: members,
          selectedAccount: _selected,
          onSelect: (id) => setState(() {
            _selected = id;
            _all = false;
          }),
          showAll: _all,
          onSelectAll: () => setState(() => _all = true),
          failures: [
            for (final a in ordered)
              if (_failed[a.localId] case final e?)
                FamilyFailure(account: a, error: e),
          ],
          onRetry: _retry,
          child: widget.child,
        ),
        // Zwischengespeicherte Widgets: Ein Neuaufbau hier baut die weiteren
        // Konten nicht neu (sonst neuer Stand → _report → Neuaufbau …).
        for (final h in _hosts.values) Offstage(child: h),
      ],
    );
  }
}

/// Meldet den Stand eines weiteren Kontos nach oben.
class _Report extends StatelessWidget {
  const _Report({required this.onSnapshot});

  final void Function(LiveSnapshot s) onSnapshot;

  @override
  Widget build(BuildContext context) {
    final s = LiveData.of(context);
    if (s != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onSnapshot(s));
    }
    return const SizedBox.shrink();
  }
}

/// Bei mehreren Konten: Auswahl des Kindes oben, darunter [builder] im
/// Rahmen dieses Kontos ([FamilyMember.scope]). Für Bereiche, die je Kind
/// getrennt bleiben (Unterricht, Nachrichten, Mehr).
///
/// Ursache: Kurse und Unterhaltungen zweier Schulen in einer Liste wären
/// unübersichtlich, und Schreiben braucht ohnehin ein Konto. Die Wahl
/// (Kind oder „Alle“) gilt für alle Bereiche gemeinsam (FamilyData).
/// Grenze: bis zum Neustart.
class FamilySwitch extends StatefulWidget {
  const FamilySwitch({super.key, required this.child, this.kidName, this.all});

  /// Seite mit echten Daten (liest LiveData.of und ref).
  final Widget child;

  /// Ansicht über alle Kinder (Pille „Alle“ vorn, voreingestellt); null =
  /// nur einzelne Kinder. Ursache (Wunsch 18.10.26, Nachrichten): Wer
  /// mehrere Kinder hat, will neue Nachrichten an einer Stelle sehen. Die
  /// Wahl „Alle“ ist Teil der gemeinsamen Kindwahl (FamilyData.showAll).
  final Widget Function(BuildContext context, List<FamilyMember> members)? all;

  /// Name eines Kontos für die Auswahl (Standard: Vorname aus dem Stand).
  final String Function(FamilyMember m)? kidName;

  @override
  State<FamilySwitch> createState() => _FamilySwitchState();
}

class _FamilySwitchState extends State<FamilySwitch> {
  /// Nur ohne FamilyScope (Tests): eigene Wahl.
  int? _account;
  late bool _ownAll = widget.all != null;

  @override
  Widget build(BuildContext context) {
    final scope = FamilyData.scopeOf(context);
    final members = scope?.members ?? const <FamilyMember>[];
    if (members.length < 2) return widget.child;
    final shared = scope?.onSelect != null;
    // „Alle“ gemeinsam für alle Bereiche (FamilyData.showAll), nur hier
    // angeboten, wenn der Bereich eine Ansicht dafür hat.
    final all =
        widget.all != null &&
        (shared && scope?.onSelectAll != null ? scope!.showAll : _ownAll);
    final wanted = shared ? scope?.selectedAccount : _account;
    final sel =
        members.where((m) => m.accountId == wanted).firstOrNull ??
        members.first;
    return PinnedKidChips(
      chips: KidChips(
        allLabel: widget.all == null ? null : context.t.forEveryone,
        kids: [
          for (final m in members)
            (
              name: widget.kidName?.call(m) ?? kidLabel(m.snapshot),
              color: m.colorIndex,
            ),
        ],
        selected: all ? -1 : members.indexOf(sel),
        onSelect: (i) {
          if (i < 0) {
            final pickAll = scope?.onSelectAll;
            if (shared && pickAll != null) {
              pickAll();
            } else {
              setState(() => _ownAll = true);
            }
            return;
          }
          final id = members[i].accountId;
          final pick = scope?.onSelect;
          if (pick != null) {
            pick(id);
          } else {
            setState(() {
              _ownAll = false;
              _account = id;
            });
          }
        },
      ),
      child: all
          ? KeyedSubtree(
              key: const ValueKey('family-all'),
              child: widget.all!(context, members),
            )
          : KeyedSubtree(
              key: ValueKey('family-${sel.accountId}'),
              child: sel.scope(widget.child),
            ),
    );
  }
}

/// Anzeigename eines Kontos: Vorname des Kindes, sonst die Schule.
String kidLabel(LiveSnapshot s) {
  final n = s.firstName.trim();
  return n.isNotEmpty ? n : s.schoolName;
}

/// Kind wählen (Blatt von unten mit den Kind-Pillen), null = abgebrochen.
/// Gemeinsam für „Alle“-Ansichten (Nachrichten: Schreiben, Unterricht:
/// Archiv), die eine Aktion nur für ein Konto ausführen können.
Future<FamilyMember?> pickFamilyMember(
  BuildContext context,
  List<FamilyMember> members, {
  required String title,
}) => showModalBottomSheet<FamilyMember>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  backgroundColor: Kit.of(context).p.card,
  builder: (sheet) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, Sp.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Kit.of(sheet).sheetTitle),
          const SizedBox(height: Sp.m),
          KidChips(
            kids: [
              for (final m in members)
                (name: kidLabel(m.snapshot), color: m.colorIndex),
            ],
            selected: -1,
            onSelect: (i) => Navigator.of(sheet).pop(members[i]),
          ),
        ],
      ),
    ),
  ),
);
