import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/background_service.dart';
import 'package:liblanis/liblanis.dart';
import 'dart:ui' show PlatformDispatcher;

import 'package:lanis/fork/kid_name.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/notify/summary.dart';
import 'package:lanis/fork/ui/language.dart' show languageKey;

Future<void> conversationsBackgroundTask(
  ProviderContainer container,
  AccountType accountType,
  BackgroundTaskToolkit toolkit,
) async {
  final data = await container.read(conversationsParserProvider).getHome();
  // Fork: ausgeblendete Unterhaltungen nicht melden – wie Liste, Zähler am
  // Reiter und Heute (unread && !hidden). Ursache (Prüfung 20.10.26): Der
  // Hinweis kam auch für ausgeblendete Unterhaltungen.
  final unreadMessages = data.where((e) => e.unread && !e.hidden).toList();
  // Fork: Kind im Titel („Frau Muster · Lena“), wie die übrigen Hinweise
  // („… bei Lena“). Ursache (Wunsch 20.10.26): Bei zwei Konten war nicht
  // zu sehen, welches Kind die Nachricht betrifft. Name aus kid_name.dart.
  // Allein auf dem eigenen Handy (Schülerkonto) ohne Namen.
  final kid = toolkit.multiAccount || accountType == AccountType.parent
      ? storedKidName(toolkit.settings)
      : '';
  // Fork: statt einer Meldung je Nachricht eine Zeile in der
  // Sammel-Benachrichtigung (summary.dart, Wunsch 27.10.26) – aktueller
  // Stand: Gelesenes fällt beim nächsten Lauf heraus.
  final shared = container.read(sharedOverAccountSettingsProvider);
  String? chosen;
  try {
    chosen = shared.getString(languageKey);
  } catch (_) {}
  final t = forkL10nFor(
    resolveLanguage(chosen, PlatformDispatcher.instance.locale.languageCode),
  );
  putSummaryItems(
    shared,
    '${toolkit.accountId}/messages',
    messageSummaryItems(
      scope: '${toolkit.accountId}',
      name: kid,
      unread: [
        for (final m in unreadMessages)
          (id: m.id, from: m.fullName, subject: m.title),
      ],
      t: t,
    ),
  );
}
