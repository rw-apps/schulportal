import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/background_service.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/fork/kid_name.dart';

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
  for (final unreadMessage in unreadMessages) {
    await toolkit.sendMessage(
      id: (unreadMessage.id.hashCode & 0x7fffffff) % 10000,
      title: kid.isEmpty
          ? unreadMessage.fullName
          : '${unreadMessage.fullName} · $kid',
      message: unreadMessage.title,
      avoidDuplicateSending: true,
      importance: Importance.high,
    );
  }
}
