import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:liblanis/liblanis.dart' show TypedSettings;

import 'mensa_week.dart';

/// Zuletzt gelesene Essenswochen je Kind (`konto:kind`, MensaPage.owner),
/// geräteweit gespeichert.
///
/// Ursache (Wunsch 26.10.26): Die Heute-Karte soll das bestellte Essen
/// nennen und warnen, wenn für morgen nichts bestellt ist. Die Seite des
/// Caterers lässt sich nur mit der Anmeldung der eingebetteten Ansicht
/// lesen (meal_fetcher.dart); deshalb merkt sich die App das Ergebnis und
/// zeigt es, bis es erneuert ist.
///
/// Grenzen:
/// - Stand = letzter Abruf ([MealEntry.at]); ändert jemand die Bestellung
///   anderswo, sieht die App das erst beim nächsten Abruf (spätestens nach
///   [mealRefreshEvery] beim Öffnen von Heute).
/// - [MealEntry.unreadable]: Die Seite ließ sich nicht lesen (anderer
///   Caterer, abgemeldet). Dann öffnet „Essen“ gleich die Seite selbst.
class MealEntry {
  const MealEntry({
    required this.at,
    this.weeks = const [],
    this.unreadable = false,
    this.balance,
  });

  /// Guthaben beim letzten Abruf („18,00“); null = unbekannt.
  final String? balance;

  final DateTime at;
  final List<MealWeek> weeks;
  final bool unreadable;

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    if (unreadable) 'unreadable': true,
    'balance': ?balance,
    'weeks': [for (final w in weeks) w.toJson()],
  };

  static MealEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final at = DateTime.tryParse('${j['at']}');
    if (at == null) return null;
    return MealEntry(
      at: at,
      unreadable: j['unreadable'] == true,
      balance: j['balance'] as String?,
      weeks: [
        for (final w in (j['weeks'] as List? ?? const []))
          if (MealWeek.fromJson(w) case final x?) x,
      ],
    );
  }

  /// Tag [day] aus den gespeicherten Wochen; null = unbekannt.
  MealDay? dayOf(DateTime day) {
    for (final w in weeks) {
      for (final d in w.days) {
        if (d.day.year == day.year &&
            d.day.month == day.month &&
            d.day.day == day.day) {
          return d;
        }
      }
    }
    return null;
  }

  /// Ist in den gespeicherten Wochen etwas bestellt? Nur dann warnt Heute
  /// vor fehlender Bestellung – wer nie bestellt, bekommt keine tägliche
  /// Erinnerung (Abnahme 26.10.26).
  bool get ordersAtAll =>
      weeks.any((w) => w.days.any((d) => d.state == MealState.ordered));
}

const mealCacheKey = 'fork-mensa/weeks';

/// Adresse, von der aus die App die Wochen liest: die zuletzt gelesene
/// Wochenseite (MealWeek.url), sonst die eingetragene Adresse.
///
/// Ursache (Bildschirmfoto 27.10.26): Eingetragen ist oft die Startseite
/// des Caterers (Anmeldung). Nach der Anmeldung landet man dort auf einer
/// Hinweisseite; die Wochen kommen erst über „Kundenbereich“. Mit der
/// gemerkten Wochenseite (…/2026/46/) setzt mensaUrlForWeek die Woche
/// direkt ein. Grenze: Vor dem ersten erfolgreichen Lesen gilt die
/// eingetragene Adresse; dann hilft mealNavJs weiter.
String mealBaseUrl(String stored, MealEntry? e) {
  MealWeek? best;
  for (final w in e?.weeks ?? const <MealWeek>[]) {
    if (w.url == null) continue;
    if (best == null || w.start.isAfter(best.start)) best = w;
  }
  return best?.url ?? stored;
}

/// Sucht auf einer Seite ohne Woche (Start- oder Hinweisseite) den Link
/// zur Essensbestellung („Essenbestellung“, „Speiseplan“, „Kundenbereich“,
/// „Menübestellung“) und gibt seine Adresse zurück, sonst ''. Grenze: nur
/// sichtbare Linktexte dieser Art; andere Wörter erkennt es nicht.
const mealNavJs = r'''
(function () {
  var re = /(essen\s*bestellung|essenbestellung|essensbestellung|speiseplan|kundenbereich|men(ü|ue)\s*bestellung)/i;
  var as = document.querySelectorAll('a[href]');
  for (var k = 0; k < 2; k++) {
    for (var i = 0; i < as.length; i++) {
      var a = as[i], t = (a.textContent || '').trim();
      if (!re.test(t)) continue;
      // Erst die direkte Bestellung, dann der Kundenbereich.
      if (k === 0 && /kundenbereich/i.test(t)) continue;
      var h = a.href || '';
      if (h.indexOf('http') === 0 && h.indexOf('#') !== h.length - 1) return h;
    }
  }
  return '';
})()
''';

/// Unter diesem Guthaben (Euro) warnt Heute „bitte Geld überweisen“
/// (Wunsch 27.10.26: „ab weniger als 15 EUR ein Hinweis“).
const mealLowBalance = 15.0;

/// Guthaben, wenn es unter [mealLowBalance] liegt und das Kind überhaupt
/// bestellt (sonst wäre der Hinweis Dauerrauschen); null sonst.
String? lowMealBalance(MealEntry? e) {
  final v = parseEuro(e?.balance);
  if (e == null || v == null || !e.ordersAtAll || v >= mealLowBalance) {
    return null;
  }
  return e.balance;
}

/// Abruf nach so langer Zeit erneuern (beim Öffnen von Heute).
const mealRefreshEvery = Duration(hours: 3);

/// Gemeinsamer Speicher; [attach] einmal mit den geräteweiten Einstellungen.
class MealCache {
  MealCache._();
  static final instance = MealCache._();

  TypedSettings? _settings;

  /// Demo (demo_meals.dart): fester Stand für jedes Kind, nichts wird
  /// gespeichert oder neu gelesen. null = echte Daten.
  MealEntry Function(String owner)? demo;

  final notifier = ValueNotifier<Map<String, MealEntry>>(const {});

  void attach(TypedSettings s) {
    if (identical(s, _settings)) return;
    _settings = s;
    final out = <String, MealEntry>{};
    try {
      final raw = s.getString(mealCacheKey);
      final v = raw == null ? null : jsonDecode(raw);
      if (v is Map) {
        for (final e in v.entries) {
          if (MealEntry.fromJson(e.value) case final x?) out['${e.key}'] = x;
        }
      }
    } catch (_) {
      // Unlesbar – wie leer; der nächste Abruf schreibt neu.
    }
    // Aufruf aus initState (MealRefresh, MealWeekPage) fällt in den Aufbau;
    // Heute hört auf [notifier] – erst nach dem Bild melden, sonst
    // „setState() called during build“ (Demo-Test 27.10.26).
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => notifier.value = out,
      );
    } else {
      notifier.value = out;
    }
  }

  MealEntry? of(String owner) => demo?.call(owner) ?? notifier.value[owner];

  /// Neue Wochen übernehmen: gleiche Woche ersetzt, höchstens drei Wochen
  /// (die jüngsten) je Kind.
  void put(String owner, List<MealWeek> weeks, {DateTime? at}) {
    final old = of(owner);
    final byStart = <DateTime, MealWeek>{
      for (final w in old?.weeks ?? const <MealWeek>[]) w.start: w,
      for (final w in weeks) w.start: w,
    };
    final keep = byStart.values.toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    _store(
      owner,
      MealEntry(
        at: at ?? DateTime.now(),
        balance:
            [
              for (final w in weeks)
                if (w.balance != null) w.balance!,
            ].lastOrNull ??
            old?.balance,
        weeks: (keep.take(3).toList()
          ..sort((a, b) => a.start.compareTo(b.start))),
      ),
    );
  }

  /// Seite ließ sich nicht lesen; gespeicherte Wochen bleiben erhalten.
  void markUnreadable(String owner, {DateTime? at}) => _store(
    owner,
    MealEntry(
      at: at ?? DateTime.now(),
      weeks: of(owner)?.weeks ?? const [],
      unreadable: true,
      balance: of(owner)?.balance,
    ),
  );

  void _store(String owner, MealEntry e) {
    if (demo != null) return;
    final next = {...notifier.value, owner: e};
    notifier.value = next;
    try {
      _settings?.setString(
        mealCacheKey,
        jsonEncode({for (final x in next.entries) x.key: x.value.toJson()}),
      );
    } catch (_) {}
  }

  @visibleForTesting
  void reset() {
    _settings = null;
    notifier.value = const {};
  }
}
