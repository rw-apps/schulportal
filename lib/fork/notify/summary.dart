import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:liblanis/liblanis.dart' show TypedSettings;
import 'package:lanis/background_service.dart' show notificationChannelId;

import '../l10n/l10n.dart';
import '../ui/today/today_model.dart';
import '../ui/today/today_page.dart' show dayDiff, relativeDay;

/// Eine Sammel-Benachrichtigung „Das Wichtigste“ statt vieler einzelner
/// (Wunsch 27.10.26, statt eines Widgets).
///
/// Ursache: Gewünscht war ein Widget, das nur bei Wichtigem erscheint und
/// auch auf dem Sperrbildschirm steht. Android-Widgets bleiben dauerhaft
/// und sind auf dem Sperrbildschirm von Handys nicht erlaubt; eine
/// Benachrichtigung erscheint nur bei Bedarf, steht auf dem Sperrbildschirm
/// und verschwindet wieder. Inhalt nur: Ausfall, Vertretung, neue
/// Nachrichten, nicht bestelltes Essen, dazu Raumwechsel (Entscheidung
/// 27.10.26: „Ja“ – sie kamen vorher als Einzelmeldung).
///
/// Aufbau: Jede Quelle (`<Konto>/plan`, `<Konto>/messages`,
/// `<Konto>/meals`) legt ihren AKTUELLEN Stand ab ([putSummaryItems]);
/// [showSummary] fasst alle zusammen. Erledigtes fällt so von selbst weg,
/// vergangene Tage ebenfalls ([SummaryItem.day]).
///
/// Ton (unabhängige Prüfung 27.10.26): nur, wenn ein neuer Eintrag
/// dazukommt ([summaryAlertedKey]); sonst `silent`. Hat man die Meldung
/// weggewischt und kommt nichts Neues, wird sie nicht wieder gezeigt.
///
/// Grenze: Aktualisiert im Hintergrund (alle 15–60 Minuten, Android) und
/// beim Öffnen von Heute; dazwischen kann ein Eintrag veraltet sein.
enum SummaryKind { cancelled, substitution, room, message, meal }

class SummaryItem {
  const SummaryItem({
    required this.key,
    required this.kind,
    required this.name,
    required this.text,
    this.day,
  });

  /// Gleichbleibende Kennung (gleicher Eintrag = gleicher Schlüssel).
  final String key;
  final SummaryKind kind;

  /// Kind („Jonas“) oder leer.
  final String name;

  /// „3. Musik – fällt aus“, „Essen noch nicht bestellt“.
  final String text;

  /// Betroffener Tag; null = ohne Tag (Nachricht). Die Tagesangabe
  /// („Heute“, „Morgen“) entsteht erst beim Anzeigen ([line]) – sonst stünde
  /// nach Mitternacht noch „Morgen“ für heute da.
  final DateTime? day;

  /// „Jonas · Morgen: 3. Musik – fällt aus“.
  String line(ForkL10n t, DateTime now) {
    final head = [
      if (name.trim().isNotEmpty) name.trim(),
      if (day != null) relativeDay(t, day!, now),
    ].join(' · ');
    return head.isEmpty ? text : '$head: $text';
  }

  Map<String, dynamic> toJson() => {
    'k': key,
    't': kind.name,
    'n': name,
    'x': text,
    if (day != null) 'd': '${day!.year}-${day!.month}-${day!.day}',
  };

  static SummaryItem? fromJson(Object? j) {
    if (j is! Map || j['k'] is! String || j['x'] is! String) return null;
    final kind = SummaryKind.values.where((x) => x.name == j['t']);
    if (kind.isEmpty) return null;
    DateTime? day;
    final p = '${j['d'] ?? ''}'.split('-').map(int.tryParse).toList();
    if (p.length == 3 && !p.contains(null)) {
      day = DateTime(p[0]!, p[1]!, p[2]!);
    }
    return SummaryItem(
      key: j['k'],
      kind: kind.first,
      name: '${j['n'] ?? ''}',
      text: j['x'],
      day: day,
    );
  }
}

/// Name des Kindes in den Zeilen der Sammelmeldung: nur bei mehreren
/// Konten auf dem Gerät ([multiAccount]) oder beim Elternkonto ([parent]);
/// allein auf dem eigenen Handy (Schülerkonto) ohne Namen. EINE Regel für
/// die offene App (live_today_page.dart) und den Hintergrund
/// (notify_task.dart, Nachrichten in conversations/background.dart).
/// Ursache (Prüfung 27.10.26): Die App nannte den Namen nur bei mehreren
/// Karten, der Hintergrund auch beim Elternkonto – jeder Lauf schrieb die
/// Zeilen des anderen um („Lena · Heute: …“ ↔ „Heute: …“).
String summaryName(
  String name, {
  required bool multiAccount,
  required bool parent,
}) => multiAccount || parent ? name.trim() : '';

const summaryItemsKey = 'fork-summary/items';
const summaryAlertedKey = 'fork-summary/alerted';

/// Konten und Themen, für die Benachrichtigungen erlaubt sind (gesetzt vom
/// Hintergrund bzw. beim Einrichten, background_service.dart):
/// {Konto: ["plan", "messages", "meals"]}. Die offene App gleicht nur
/// diese ab (Prüfung 27.10.26: sonst kam die Meldung trotz Abschalten).
const summaryAllowedKey = 'fork-summary/allowed';

/// Feste Kennung der Sammel-Benachrichtigung. Negativ, damit sie nie mit
/// den Kennungen der Aufgaben (BackgroundTaskToolkit, ≥ 0) zusammenfällt.
const summaryNotificationId = -1001;

Map<String, dynamic> _read(TypedSettings s, String key) {
  try {
    final raw = s.getString(key);
    final v = raw == null ? null : jsonDecode(raw);
    if (v is Map<String, dynamic>) return v;
  } catch (_) {}
  return {};
}

/// Aktuellen Stand einer Quelle ablegen (ersetzt den vorigen).
void putSummaryItems(
  TypedSettings shared,
  String source,
  List<SummaryItem> items,
) {
  final all = _read(shared, summaryItemsKey);
  if (items.isEmpty) {
    all.remove(source);
  } else {
    all[source] = [for (final i in items) i.toJson()];
  }
  shared.setString(summaryItemsKey, jsonEncode(all));
}

Map<String, Set<String>> readSummaryAllowed(TypedSettings shared) => {
  for (final e in _read(shared, summaryAllowedKey).entries)
    e.key: {for (final x in (e.value as List? ?? const [])) '$x'},
};

void writeSummaryAllowed(TypedSettings shared, Map<String, Set<String>> a) =>
    shared.setString(
      summaryAllowedKey,
      jsonEncode({for (final e in a.entries) e.key: e.value.toList()}),
    );

/// Nur Quellen erlaubter Konten und Themen behalten (gelöschte Konten,
/// abgeschaltete Benachrichtigungen).
void pruneSummarySources(
  TypedSettings shared,
  Map<String, Set<String>> allowed,
) {
  final all = _read(shared, summaryItemsKey);
  all.removeWhere((k, _) {
    final parts = k.split('/');
    return parts.length != 2 ||
        !(allowed[parts[0]]?.contains(parts[1]) ?? false);
  });
  shared.setString(summaryItemsKey, jsonEncode(all));
}

/// Alle offenen Einträge: Ausfall, Vertretung, Nachrichten, Essen
/// (innerhalb einer Art in Ablage-Reihenfolge); vergangene Tage und doppelte
/// Schlüssel fallen weg.
List<SummaryItem> allSummaryItems(TypedSettings shared, DateTime now) {
  final seen = <String>{};
  final out = <(int, SummaryItem)>[];
  final today = DateTime(now.year, now.month, now.day);
  for (final v in _read(shared, summaryItemsKey).values) {
    if (v is! List) continue;
    for (final j in v) {
      final i = SummaryItem.fromJson(j);
      if (i == null || !seen.add(i.key)) continue;
      if (i.day != null && i.day!.isBefore(today)) continue;
      out.add((out.length, i));
    }
  }
  // Stabil: Art, dann Ablage-Reihenfolge.
  out.sort((a, b) {
    final c = a.$2.kind.index.compareTo(b.$2.kind.index);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final x in out) x.$2];
}

/// Höchstens so viele Zeilen; der Rest als „+ n weitere“.
const summaryMaxLines = 7;

/// Benachrichtigung zeigen, still aktualisieren oder entfernen.
/// [alert] false: nie Ton (offene App, Nachtruhe).
Future<void> showSummary(
  TypedSettings shared,
  ForkL10n t, {
  DateTime? now,
  bool alert = true,
  FlutterLocalNotificationsPlugin? plugin,
}) async {
  final at = now ?? DateTime.now();
  final p = plugin ?? FlutterLocalNotificationsPlugin();
  final items = allSummaryItems(shared, at);
  final keys = {for (final i in items) i.key};
  final alerted = {
    for (final k in (_read(shared, summaryAlertedKey)['k'] as List? ?? []))
      '$k',
  };
  try {
    if (items.isEmpty) {
      await p.cancel(id: summaryNotificationId);
      shared.setString(summaryAlertedKey, jsonEncode({'k': []}));
      return;
    }
    final fresh = keys.difference(alerted).isNotEmpty;
    if (!fresh) {
      // Weggewischt und nichts Neues: nicht wieder zeigen.
      var active = false;
      try {
        active = (await p.getActiveNotifications()).any(
          (n) => n.id == summaryNotificationId,
        );
      } catch (_) {}
      if (!active) {
        shared.setString(summaryAlertedKey, jsonEncode({'k': keys.toList()}));
        return;
      }
    }
    final lines = [
      for (final i in items.take(summaryMaxLines)) i.line(t, at),
      if (items.length > summaryMaxLines)
        t.summaryMore(items.length - summaryMaxLines),
    ];
    final title = t.summaryTitle(items.length);
    final loud = alert && fresh;
    await p.show(
      id: summaryNotificationId,
      title: title,
      body: lines.first,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          notificationChannelId,
          'Schulportal',
          channelDescription: 'Applet notifications',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: InboxStyleInformation(lines, contentTitle: title),
          silent: !loud,
          onlyAlertOnce: !loud,
          // Vertraulich wie die übrigen Hinweise: Auf dem Sperrbildschirm
          // zeigt Android den Inhalt nur, wenn „sensible Inhalte“ nicht
          // ausgeblendet sind; sonst nur „Schulportal“.
          visibility: NotificationVisibility.private,
        ),
      ),
    );
    shared.setString(summaryAlertedKey, jsonEncode({'k': keys.toList()}));
  } catch (_) {
    // Ohne Benachrichtigungsrecht bleibt es still.
  }
}

/// Ausfälle und Vertretungen von heute (Stunde noch nicht vorbei, [endOf]
/// Minuten nach Mitternacht je Stunde) und vom nächsten Schultag.
/// Schlüssel aus Konto, Tag, Stunde und Art – ohne Fachnamen: App und
/// Hintergrund nennen Fächer teils verschieden (Kürzel ohne Kursliste),
/// der Eintrag bleibt derselbe. Raumwechsel gehören dazu (Entscheidung
/// 27.10.26).
List<SummaryItem> changeSummaryItems({
  required String scope,
  required String name,
  required List<ChangeItem> changes,
  required DateTime now,
  required DateTime next,
  required ForkL10n t,
  Map<String, int> endOf = const {},
}) {
  final nowMin = now.hour * 60 + now.minute;
  final out = <SummaryItem>[];
  for (final c in changes) {
    final today = dayDiff(now, c.day) == 0;
    final tomorrow = dayDiff(next, c.day) == 0;
    if (!today && !tomorrow) continue;
    if (today && (endOf[c.slot] ?? 24 * 60) <= nowMin) continue;
    final kind = switch (c.kind) {
      ChangeKind.cancelled => SummaryKind.cancelled,
      ChangeKind.substitution || ChangeKind.unclear => SummaryKind.substitution,
      ChangeKind.roomChange => SummaryKind.room,
    };
    final what = switch (c.kind) {
      ChangeKind.cancelled => t.lessonCancelled,
      ChangeKind.unclear => '${t.changeUnclear} ${c.detail ?? ''}'.trim(),
      ChangeKind.roomChange => '${t.changeRoom} ${c.detail ?? ''}'.trim(),
      _ => '${t.changeSubstitution} ${c.detail ?? ''}'.trim(),
    };
    out.add(
      SummaryItem(
        key:
            'c|$scope|${c.day.year}-${c.day.month}-${c.day.day}|${c.slot}|${kind.name}',
        kind: kind,
        name: name,
        text: '${c.slot} ${c.subject} – $what',
        day: DateTime(c.day.year, c.day.month, c.day.day),
      ),
    );
  }
  return out;
}

/// Ungelesene Nachrichten: je Unterhaltung eine Zeile; Schlüssel mit Konto
/// (dieselbe Rundnachricht an zwei Geschwister = zwei Zeilen).
List<SummaryItem> messageSummaryItems({
  required String scope,
  required String name,
  required List<({String id, String from, String subject})> unread,
  required ForkL10n t,
}) => [
  for (final m in unread)
    SummaryItem(
      key: 'm|$scope|${m.id}',
      kind: SummaryKind.message,
      name: name,
      text: t.summaryMessage(m.from, m.subject),
    ),
];

/// Nicht bestelltes Essen (mealReminderDays).
List<SummaryItem> mealSummaryItems({
  required String name,
  required String owner,
  required List<DateTime> days,
  required ForkL10n t,
}) => [
  for (final d in days)
    SummaryItem(
      key: 'e|$owner|${d.year}-${d.month}-${d.day}',
      kind: SummaryKind.meal,
      name: name,
      text: t.summaryMealOpen,
      day: d,
    ),
];

String? _lastAppSync;

/// Aus der offenen App (Heute): Stand der Quellen übernehmen und die
/// Benachrichtigung still aktualisieren – so verschwindet z. B. „Essen
/// noch nicht bestellt“ gleich nach dem Bestellen, nicht erst beim nächsten
/// Hintergrundlauf. Nur erlaubte Konten/Themen ([summaryAllowedKey]); nur
/// bei Änderung. [sources]: Quelle → Einträge (leer = Quelle leeren).
Future<void> syncSummaryFromApp(
  TypedSettings shared,
  ForkL10n t,
  Map<String, List<SummaryItem>> sources,
) async {
  try {
    final allowed = readSummaryAllowed(shared);
    final ok = {
      for (final e in sources.entries)
        if (allowed[e.key.split('/').first]?.contains(e.key.split('/').last) ??
            false)
          e.key: e.value,
    };
    final sig = jsonEncode({
      'a': {for (final e in allowed.entries) e.key: e.value.toList()},
      for (final e in ok.entries) e.key: [for (final i in e.value) i.toJson()],
    });
    if (sig == _lastAppSync) return;
    for (final e in ok.entries) {
      putSummaryItems(shared, e.key, e.value);
    }
    pruneSummarySources(shared, allowed);
    await showSummary(shared, t, alert: false);
    _lastAppSync = sig;
  } catch (_) {
    // Nächster Aufbau versucht es erneut (_lastAppSync bleibt alt).
  }
}
