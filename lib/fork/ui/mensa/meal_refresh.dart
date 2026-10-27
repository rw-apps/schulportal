import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart' show sharedOverAccountSettingsProvider;

import '../../mensa.dart' show isoWeek, mensaUrlForWeek;
import '../../mensa_store.dart';
import '../today/today_page.dart' show schoolWeek;
import '../kit.dart';
import 'meal_fetcher.dart';

/// Liest auf Heute die Essenswochen der Kinder nach (laufende und nächste
/// Woche), wenn der gespeicherte Stand älter als [mealRefreshEvery] ist –
/// je Kind nacheinander, unsichtbar hinter der Seite (MealFetcher).
///
/// Ursache (Wunsch 26.10.26): Die Karte soll das bestellte Essen nennen und
/// warnen, wenn für morgen nichts bestellt ist, ohne dass man vorher
/// „Essen“ öffnen muss. Grenzen: Ist die Anmeldung beim Caterer abgelaufen,
/// bleibt der alte Stand stehen (MealEntry.unreadable); ein erneuter
/// Versuch folgt erst nach [mealRefreshEvery].
class MealRefresh extends ConsumerStatefulWidget {
  const MealRefresh({
    super.key,
    required this.targets,
    required this.now,
    required this.child,
  });

  final List<({String owner, String url})> targets;
  final DateTime now;
  final Widget child;

  @override
  ConsumerState<MealRefresh> createState() => _MealRefreshState();
}

class _MealRefreshState extends ConsumerState<MealRefresh> {
  final _cache = MealCache.instance;

  /// In dieser Sitzung schon versucht (auch ohne Ergebnis).
  final _tried = <String>{};
  ({String owner, String url})? _current;

  @override
  void initState() {
    super.initState();
    try {
      _cache.attach(ref.read(sharedOverAccountSettingsProvider));
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  @override
  void didUpdateWidget(MealRefresh old) {
    super.didUpdateWidget(old);
    if (_current == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
    }
  }

  void _pick() {
    // Demo: feste Wochen (demo_meals.dart), nichts zu lesen – sonst lud eine
    // eingebettete Ansicht die erfundene Caterer-Adresse (Demo-Prüfung
    // 27.10.26, Bildschirmtest der Demo).
    if (!mounted || _current != null || _cache.demo != null) return;
    for (final t in widget.targets) {
      if (_tried.contains(t.owner)) continue;
      final e = _cache.of(t.owner);
      if (e != null && widget.now.difference(e.at) < mealRefreshEvery) {
        continue;
      }
      _tried.add(t.owner);
      setState(() => _current = t);
      return;
    }
  }

  /// Abruf in voller Größe HINTER der Seite (hiddenWebView,
  /// meal_fetcher.dart); die Seite liegt deckend darüber.
  @override
  Widget build(BuildContext context) {
    final c = _current;
    final k = Kit.of(context);
    return Stack(
      children: [
        if (c != null)
          Positioned.fill(
            child: MealFetcher(
              key: ValueKey(c.owner),
              url: mensaUrlForWeek(
                mealBaseUrl(c.url, _cache.of(c.owner)),
                isoWeek(schoolWeek(widget.now).first),
              ),
              owner: c.owner,
              want: schoolWeek(widget.now).first,
              onWeek: (w) => _cache.put(c.owner, [w]),
              onUnreadable: () => _cache.markUnreadable(c.owner),
              onDone: () {
                if (!mounted) return;
                setState(() => _current = null);
                WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
              },
            ),
          ),
        // Schlüssel: Die Seite behält ihren Zustand, wenn der Abruf
        // davor hinzukommt oder wegfällt.
        ColoredBox(
          key: const ValueKey('page'),
          color: k.p.bg,
          child: widget.child,
        ),
      ],
    );
  }
}
