import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/bridge/lanis_bootstrap.dart' show bootstrapOverrides;

import '../../error_log.dart';
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
  Widget scope(Widget child) {
    final data = LiveData(
      snapshot: snapshot,
      child: _MemberMarker(member: this, child: child),
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
  });

  final List<FamilyMember> members;

  /// Gewähltes Kind (Konto) für Kalender, Unterricht, Nachrichten und Mehr –
  /// EINE Wahl für alle Reiter. Ursache (Rückmeldung 17.10.26): Jeder
  /// Bereich merkte sich seine eigene Wahl; nach dem Reiterwechsel stand
  /// wieder das erste Kind da. Grenze: gilt bis zum Neustart der App.
  final int? selectedAccount;
  final void Function(int accountId)? onSelect;

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

class _FamilyScopeState extends ConsumerState<FamilyScope> {
  final _containers = <int, ProviderContainer>{};
  final _hosts = <int, Widget>{};
  final _snaps = <int, LiveSnapshot>{};
  int? _selected;

  @override
  void dispose() {
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

  Future<void> _start(int id) async {
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
      await c.read(sessionProvider.notifier).authenticate();
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
    final fresh = others.where((id) => !_containers.containsKey(id)).toList();
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
    for (final (i, a) in ordered.indexed) {
      final color = i;
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
          onSelect: (id) => setState(() => _selected = id),
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
/// unübersichtlich, und Schreiben braucht ohnehin ein Konto. Grenze: Die
/// Wahl gilt je Bereich und bis zum Neustart.
class FamilySwitch extends StatefulWidget {
  const FamilySwitch({super.key, required this.child, this.kidName});

  /// Seite mit echten Daten (liest LiveData.of und ref).
  final Widget child;

  /// Name eines Kontos für die Auswahl (Standard: Vorname aus dem Stand).
  final String Function(FamilyMember m)? kidName;

  @override
  State<FamilySwitch> createState() => _FamilySwitchState();
}

class _FamilySwitchState extends State<FamilySwitch> {
  /// Nur ohne FamilyScope (Tests): eigene Wahl.
  int? _account;

  @override
  Widget build(BuildContext context) {
    final scope = FamilyData.scopeOf(context);
    final members = scope?.members ?? const <FamilyMember>[];
    if (members.length < 2) return widget.child;
    final wanted = scope?.onSelect == null ? _account : scope?.selectedAccount;
    final sel =
        members.where((m) => m.accountId == wanted).firstOrNull ??
        members.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Sp.page, Sp.m, Sp.page, 0),
            child: KidChips(
              kids: [
                for (final m in members)
                  (
                    name: widget.kidName?.call(m) ?? kidLabel(m.snapshot),
                    color: m.colorIndex,
                  ),
              ],
              selected: members.indexOf(sel),
              onSelect: (i) {
                final id = members[i].accountId;
                final pick = scope?.onSelect;
                if (pick != null) {
                  pick(id);
                } else {
                  setState(() => _account = id);
                }
              },
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: KeyedSubtree(
              key: ValueKey('family-${sel.accountId}'),
              child: sel.scope(widget.child),
            ),
          ),
        ),
      ],
    );
  }
}

/// Anzeigename eines Kontos: Vorname des Kindes, sonst die Schule.
String kidLabel(LiveSnapshot s) {
  final n = s.firstName.trim();
  return n.isNotEmpty ? n : s.schoolName;
}
