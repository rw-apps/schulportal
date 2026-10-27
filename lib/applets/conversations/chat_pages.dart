import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/applets/conversations/view/chat.dart';
import 'package:lanis/applets/conversations/view/components/statistic_widget.dart';
import 'package:lanis/applets/conversations/view/shared.dart';
import 'package:lanis/utils/logger.dart';
import 'package:lanis/widgets/error_view.dart';
import 'package:liblanis/liblanis.dart';

/// Unterhaltung und ihre Teilnehmer-Statistik – die einzigen Seiten des
/// Lanis-Bereichs „Nachrichten“, die die neue Oberfläche noch öffnet
/// (fork/ui/messages/live_messages_page.dart, Kursseite). Früher in
/// routes.dart zusammen mit Liste, Tablet-Ansicht und Routen.

class ConversationChatPage extends ConsumerWidget {
  final String id;
  final String title;

  // Fork: newSettings entfernt – kein Aufrufer setzte es (chat.dart).
  const ConversationChatPage({
    super.key,
    required this.id,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConversationsChat(
      key: ValueKey(id),
      id: id,
      title: title,
      // Fork: Fehler protokollieren statt unbehandelt (wie chat.dart,
      // _notifySidebar; Prüfung 27.10.26).
      onSidebarChanged: () {
        ref
            .read(conversationsParserProvider)
            .fetchData(forceRefresh: true)
            .catchError((Object e) {
              logger.w('Refreshing conversation list failed: $e');
            });
      },
    );
  }
}

class ConversationStatsPage extends ConsumerStatefulWidget {
  final String id;
  final String title;

  const ConversationStatsPage({
    super.key,
    required this.id,
    required this.title,
  });

  @override
  ConsumerState<ConversationStatsPage> createState() =>
      _ConversationStatsPageState();
}

class _ConversationStatsPageState extends ConsumerState<ConversationStatsPage> {
  late final Future<Conversation> _future;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(conversationsParserProvider)
        .getSingleConversation(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Conversation>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final err = snapshot.error;
          return Scaffold(
            appBar: AppBar(),
            body: AppletErrorView(
              error: err is Exception ? err : Exception(err.toString()),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final chat = snapshot.data!;
        return StatisticWidget(
          statistics: ParticipationStatistics(
            countParents: chat.countParents,
            countStudents: chat.countStudents,
            countTeachers: chat.countTeachers,
            knownParticipants: chat.knownParticipants,
          ),
          conversationTitle: widget.title.isNotEmpty
              ? widget.title
              : chat.parent.author,
        );
      },
    );
  }
}
