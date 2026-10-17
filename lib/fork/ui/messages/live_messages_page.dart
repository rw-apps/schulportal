import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/applets/conversations/chat_pages.dart'
    show ConversationChatPage;

import '../../l10n/l10n.dart';
import '../kit.dart';
import '../live/live_data.dart';
import 'compose_model.dart';
import 'compose_page.dart';
import 'messages_page.dart';

/// „Nachrichten“ mit echten Daten. Lesen und Antworten laufen über die
/// bewährte Unterhaltungsseite der bisherigen Ansicht (ConversationChatPage),
/// neu ist die Liste und das Schreiben in drei Schritten (ComposePage).
class LiveMessagesPage extends ConsumerWidget {
  const LiveMessagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LiveGate(
      needsTimetable: false,
      builder: (context, s) {
        final k = Kit.of(context);
        final t = context.t;
        if (!s.offers('nachrichten.php')) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Sp.xl),
              child: Text(t.noMessagesOffered, style: k.meta),
            ),
          );
        }
        if (s.conversations.failed) {
          return LiveMessage(
            text: t.messagesFailed,
            style: k.meta,
            action: TextButton(
              onPressed: s.refresh,
              child: Text(t.retry, style: k.link),
            ),
          );
        }
        final entries = s.conversations.content ?? const <OverviewEntry>[];
        final items = [
          for (final e in entries)
            if (!e.hidden)
              MessageItem(
                id: e.id,
                subject: e.title,
                sender: e.fullName,
                date: e.date,
                unread: e.unread,
              ),
        ];
        // Über den gemeinsamen Lader: Fehler landen im Feed („Erneut
        // versuchen“) statt unbehandelt, und kein zweiter Durchgang läuft
        // parallel (Prüfbefund 17.10.26).
        final reload = s.refreshMessages;
        return MessagesPage(
          items: items,
          loading: s.conversations.content == null,
          onRefresh: reload,
          onOpen: (m) async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ConversationChatPage(id: m.id, title: m.subject),
              ),
            );
            await reload();
          },
          // Eingabe-Seite über der ganzen App (nav.dart, pushFullScreen).
          onCompose: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<bool>(
              builder: (_) => ComposePage(
                candidates: candidatesFrom(s.lessons.content ?? const []),
                backend: portalBackend(ref),
              ),
            ),
          ),
        );
      },
    );
  }
}
