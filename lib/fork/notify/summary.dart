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
/// Nachrichten, nicht bestelltes Essen.
///
/// Aufbau: Jede Quelle (`<Konto>/plan`, `<Konto>/messages`,
/// `<Konto>/meals`) legt ihren AKTUELLEN Stand ab ([putSummaryItems]);
/// [showSummary] fasst alle zusammen. Erledigtes fällt so von selbst weg.
/// Ton/Vibration nur, wenn ein neuer Eintrag dazukommt
/// ([summaryAlertedKey]); sonst wird still aktualisiert. Ist nichts mehr
/// offen, wird die Benachrichtigung entfernt.
///
/// Grenze: Aktualisiert im Hintergrund (alle 15–60 Minuten, Android) und
/// beim Öffnen von Heute; dazwischen kann ein Eintrag veraltet sein.
enum SummaryKind { cancelled, substitution, message, meal }

class SummaryItem {
  const SummaryItem({
    required this.key,
    required this.line,
    required this.kind,
  });

  /// Gleichbleibende Kennung (gleicher Eintrag = gleicher Schlüssel).
  final String key;
  final String line;
  final SummaryKind kind;

  Map<String, dynamic> toJson() => {'k': key, 'l': line, 't': kind.name};

  static SummaryItem? fromJson(Object? j) {
    if (j is! Map || j['k'] is! String || j['l'] is! String) return null;
    final kind = SummaryKind.values.where((x) => x.name == j['t']);
    if (kind.isEmpty) return null;
    return SummaryItem(key: j['k'], line: j['l'], kind: kind.first);
  }
}

const summaryItemsKey = 'fork-summary/items';
const summaryAlertedKey = 'fork-summary/alerted';

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

/// Quellen gelöschter Konten entfernen ([accounts] = gültige Konto-IDs).
void pruneSummarySources(TypedSettings shared, Set<String> accounts) {
  final all = _read(shared, summaryItemsKey);
  all.removeWhere((k, _) => !accounts.contains(k.split('/').first));
  shared.setString(summaryItemsKey, jsonEncode(all));
}

/// Alle Einträge: Ausfall, Vertretung, Nachrichten, Essen; doppelte
/// Schlüssel nur einmal.
List<SummaryItem> allSummaryItems(TypedSettings shared) {
  final seen = <String>{};
  final out = <SummaryItem>[];
  final all = _read(shared, summaryItemsKey);
  for (final v in all.values) {
    if (v is! List) continue;
    for (final j in v) {
      final i = SummaryItem.fromJson(j);
      if (i != null && seen.add(i.key)) out.add(i);
    }
  }
  out.sort((a, b) => a.kind.index.compareTo(b.kind.index));
  return out;
}

/// Höchstens so viele Zeilen; der Rest als „+ n weitere“.
const summaryMaxLines = 7;

/// Benachrichtigung zeigen, still aktualisieren oder entfernen.
/// [alert] false: nie Ton (Aufruf aus der offenen App).
Future<void> showSummary(
  TypedSettings shared,
  ForkL10n t, {
  bool alert = true,
  FlutterLocalNotificationsPlugin? plugin,
}) async {
  final p = plugin ?? FlutterLocalNotificationsPlugin();
  final items = allSummaryItems(shared);
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
    final lines = [
      for (final i in items.take(summaryMaxLines)) i.line,
      if (items.length > summaryMaxLines)
        t.summaryMore(items.length - summaryMaxLines),
    ];
    final title = t.summaryTitle(items.length);
    await p.show(
      id: summaryNotificationId,
      title: title,
      body: items.first.line,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          notificationChannelId,
          'Schulportal',
          channelDescription: 'Applet notifications',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: InboxStyleInformation(lines, contentTitle: title),
          // Nur bei neuem Eintrag Ton/Vibration (Abnahme 27.10.26).
          onlyAlertOnce: !(alert && fresh),
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

String _prefix(String name, String text) =>
    name.trim().isEmpty ? text : '$name: $text';

/// Ausfälle und Vertretungen von heute (Stunde noch nicht vorbei, [endOf]
/// Minuten nach Mitternacht je Stunde) und vom nächsten Schultag. [scope]
/// (Konto) gehört in den Schlüssel, nicht der Name – App und Hintergrund
/// nennen das Kind teils verschieden, der Eintrag bleibt derselbe.
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
      ChangeKind.roomChange => null,
    };
    if (kind == null) continue;
    final what = switch (c.kind) {
      ChangeKind.cancelled => t.lessonCancelled,
      ChangeKind.unclear => '${t.changeUnclear} ${c.detail ?? ''}'.trim(),
      _ => '${t.changeSubstitution} ${c.detail ?? ''}'.trim(),
    };
    out.add(
      SummaryItem(
        key:
            'c|$scope|${c.day.year}-${c.day.month}-${c.day.day}|${c.slot}|${c.subject}|${c.kind.name}',
        line: _prefix(
          name,
          '${relativeDay(t, c.day, now)} ${c.slot} ${c.subject} – $what',
        ),
        kind: kind,
      ),
    );
  }
  return out;
}

/// Ungelesene Nachrichten: je Unterhaltung eine Zeile.
List<SummaryItem> messageSummaryItems({
  required String name,
  required List<({String id, String from, String subject})> unread,
  required ForkL10n t,
}) => [
  for (final m in unread)
    SummaryItem(
      key: 'm|${m.id}',
      line: _prefix(name, t.summaryMessage(m.from, m.subject)),
      kind: SummaryKind.message,
    ),
];

/// Nicht bestelltes Essen (mealReminderDays).
List<SummaryItem> mealSummaryItems({
  required String name,
  required String owner,
  required List<DateTime> days,
  required DateTime now,
  required ForkL10n t,
}) => [
  for (final d in days)
    SummaryItem(
      key: 'e|$owner|${d.year}-${d.month}-${d.day}',
      line: _prefix(name, t.summaryMeal(relativeDay(t, d, now))),
      kind: SummaryKind.meal,
    ),
];

String? _lastAppSync;

/// Aus der offenen App (Heute): Stand der Quellen übernehmen und die
/// Benachrichtigung still aktualisieren – so verschwindet z. B. „Essen
/// noch nicht bestellt“ gleich nach dem Bestellen, nicht erst beim nächsten
/// Hintergrundlauf. Nur bei Änderung (Vergleich mit dem letzten Aufruf).
/// [sources]: Quelle → Einträge (leer = Quelle leeren).
Future<void> syncSummaryFromApp(
  TypedSettings shared,
  ForkL10n t,
  Map<String, List<SummaryItem>> sources,
) async {
  final sig = jsonEncode({
    for (final e in sources.entries)
      e.key: [for (final i in e.value) i.toJson()],
  });
  if (sig == _lastAppSync) return;
  _lastAppSync = sig;
  for (final e in sources.entries) {
    putSummaryItems(shared, e.key, e.value);
  }
  await showSummary(shared, t, alert: false);
}
