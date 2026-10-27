import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:lanis/fork/demo/demo_entry.dart' show blockedInDemo;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:dart_date/dart_date.dart';
import 'package:html/parser.dart';
import 'package:lanis/applets/conversations/view/chat_app_bar.dart';
import 'package:lanis/applets/conversations/view/chat_intro_header.dart';
import 'package:lanis/applets/conversations/view/chat_scroll_to_bottom_fab.dart';
import 'package:lanis/applets/conversations/view/chat_triangle_pattern.dart';
import 'package:lanis/applets/conversations/view/components/date_header_widget.dart';
import 'package:lanis/applets/conversations/view/components/message_widget.dart';
import 'package:lanis/applets/conversations/view/components/rich_chat_text_editor.dart';
import 'package:lanis/applets/conversations/view/conversation_date.dart';
import 'package:lanis/generated/l10n.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../../../utils/fetch_more_indicator.dart';
import '../../../utils/logger.dart';
import '../../../widgets/error_view.dart';
import 'shared.dart';

// Fork: fromEntry, hidden und newSettings (Neue-Unterhaltung-Weg) entfernt.
// Ursache (Prüfung 27.10.26): Einziger Aufrufer ist ConversationChatPage
// (chat_pages.dart) mit id und title; newSettings wurde nirgends gesetzt.
class ConversationsChat extends ConsumerStatefulWidget {
  final String id;
  final String title;
  final VoidCallback? onSidebarChanged;

  const ConversationsChat({
    super.key,
    required this.title,
    required this.id,
    this.onSidebarChanged,
  });

  @override
  ConsumerState<ConversationsChat> createState() => _ConversationsChatState();
}

class _ConversationsChatState extends ConsumerState<ConversationsChat>
    with SingleTickerProviderStateMixin {
  late Future<void> _conversationFuture = _loadConversation();
  Timer? _refreshTimer;
  int _lastRefresh = 0;

  /// Fork: IDs aller angezeigten Nachrichten (Vorlage: nur die in dieser
  /// Sitzung gesendeten). Ursache (Prüfung 27.10.26): Kam ein Abgleich
  /// während des Sendens zurück, war die eigene ID noch nicht bekannt – die
  /// Nachricht stand doppelt da (lokal + vom Server). Grenze: Nachrichten
  /// ohne ID (leer) werden nicht entdoppelt.
  final Set<String> _renderedMessageIds = {};

  /// Fork: erste Ladung gelungen – erst dann läuft der 20-s-Abgleich.
  bool _loaded = false;

  /// Fork: ein Abgleich läuft (Zeitgeber oder Ziehen) – kein zweiter.
  bool _refreshInFlight = false;

  late final AppLifecycleListener _lifecycle;

  final ScrollController scrollController = ScrollController();

  final ValueNotifier<bool> isSendVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isScrollToBottomVisible = ValueNotifier<bool>(
    false,
  );

  final IndicatorController refreshIndicatorController = IndicatorController();

  final Map<String, TextStyle> textStyles = {};

  late ConversationSettings settings;
  late ParticipationStatistics? statistics;

  double richTextEditorSize = 74.0;

  bool refreshing = false;

  final List<dynamic> chat = [];

  /// Fork: Abgleich alle 20 s nur nach erfolgreicher erster Ladung und nur
  /// im Vordergrund. Ursache (Prüfung 27.10.26): Der Zeitgeber startete in
  /// initState vor der ersten Ladung (dauerte sie über 20 s, las
  /// refreshConversation das noch nicht gesetzte `late settings` →
  /// LateInitializationError, still geschluckt), lief hinter der
  /// Fehlerseite und im Hintergrund weiter und
  /// stapelte Abrufe, wenn einer länger als 20 s brauchte. Grenze: Zurück im
  /// Vordergrund kommt der erste Abgleich erst nach 20 s.
  void initRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!mounted || _refreshInFlight) return;
      setState(() {
        refreshing = true;
      });
      await refreshConversation(scrollToEnd: false);
      if (!mounted) return;
      setState(() {
        refreshing = false;
      });
    });
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _onLifecycleChange(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_loaded && _refreshTimer == null) initRefreshTimer();
    } else {
      _stopRefreshTimer();
    }
  }

  /// Fork: erste Ladung (und „Erneut versuchen“); startet danach den
  /// Abgleich (initRefreshTimer).
  Future<void> _loadConversation() async {
    _stopRefreshTimer();
    _loaded = false;
    await initConversation();
    if (!mounted) return;
    _loaded = true;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
      initRefreshTimer();
    }
  }

  @override
  void initState() {
    super.initState();
    scrollController.addListener(toggleScrollToBottomFab);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChange);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _lifecycle.dispose();
    scrollController.dispose();
    // Fork: Ursache (Prüfung 27.10.26): Benachrichtiger und Controller
    // wurden nie freigegeben (Speicher bleibt bis zum Prozessende).
    isSendVisible.dispose();
    isScrollToBottomVisible.dispose();
    refreshIndicatorController.dispose();
    super.dispose();
  }

  void toggleScrollToBottomFab() {
    if (!scrollController.hasClients) return;
    final currentScrollPosition = scrollController.position.pixels;
    isScrollToBottomVisible.value = currentScrollPosition > 100;
  }

  void _notifySidebar() {
    if (widget.onSidebarChanged != null) {
      widget.onSidebarChanged!();
      return;
    }
    // Fork: Fehler protokollieren statt unbehandelt. Ursache (Prüfung
    // 27.10.26): unawaited ohne catchError – warf fetchData (z. B. nach
    // dispose des Parsers „Cannot add event after closing“), landete das
    // als unbehandelter Fehler in der Zone. Grenze: Anmeldefehler meldet
    // liblanis 0.1.4 (AppletParser.fetchData) selbst als Fehlerzustand im
    // Datenstrom; hier geht nichts verloren.
    unawaited(
      ref
          .read(conversationsParserProvider)
          .fetchData(forceRefresh: true)
          .catchError((Object e) {
            logger.w('Refreshing conversation list failed: $e');
          }),
    );
  }

  Future<void> refreshConversation({bool scrollToEnd = true}) async {
    // Fork: ein Abgleich zur Zeit (Zeitgeber + Ziehen), erst nach der ersten
    // Ladung (settings ist sonst nicht gesetzt).
    if (!_loaded || _refreshInFlight) return;
    _refreshInFlight = true;
    try {
      final result = await ref
          .read(conversationsParserProvider)
          .refreshConversation(widget.id, _lastRefresh);

      if (!mounted) return;

      _lastRefresh = result.lastRefresh;
      for (final UnparsedMessage message in result.messages) {
        // Fork: entdoppeln über alle angezeigten IDs (_renderedMessageIds).
        if (_renderedMessageIds.contains(message.id)) {
          continue;
        }
        setState(() {
          _renderSingleMessage(message);
        });
      }
      if (result.messages.isNotEmpty) {
        _notifySidebar();
      }

      // Update send button visibility
      if (settings.own) {
        isSendVisible.value = true;
      } else {
        isSendVisible.value = !settings.noReply;
      }

      // Scroll to bottom after refresh
      if (scrollToEnd) scrollToBottom();
    } on NoConnectionException {
      if (mounted) showNoInternetDialog();
    } catch (e) {
      logger.w(
        "Error while refreshing conversation. This can happen, when the user tuns off their phone or suspends the app.",
      );
    } finally {
      _refreshInFlight = false;
    }
  }

  void scrollToBottom({Duration initDelay = Duration.zero}) {
    Future.delayed(initDelay, () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastEaseInToSlowEaseOut,
        );
      }
    });
  }

  void showNoInternetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.wifi_off),
        title: Text(AppLocalizations.of(context).noInternetConnection2),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context).back),
          ),
        ],
      ),
    );
  }

  void addAuthorTextStyles(final List<String> authors) {
    final ThemeData theme = Theme.of(context);
    for (final String author in authors) {
      textStyles[author] = BubbleStyle.getAuthorTextStyle(theme, author);
    }
  }

  /// Fork: true = gesendet; false lässt den Text im Editor stehen
  /// (rich_chat_text_editor.dart).
  Future<bool> sendMessage(String text) async {
    // Fork: in der Demo nichts senden (fork/demo/demo_entry.dart).
    if (blockedInDemo(context)) return false;
    MessageState state = MessageState.first;
    if (chat.isNotEmpty && chat.last is Message) {
      DateTime date = chat.last.date;
      if (date.isToday) {
        state = MessageState.series;
      }
    }

    final textMessage = Message(
      text: text,
      own: true,
      date: DateTime.now(),
      author: null,
      state: state,
      status: MessageStatus.sending,
    );

    setState(() {
      // Fork: DateHeader und Message tragen beide `date`; leere Liste →
      // Kopfzeile.
      final DateTime? lastMessageDate = chat.isEmpty ? null : chat.last.date;
      if (lastMessageDate != null && lastMessageDate.isToday) {
        chat.add(textMessage);
      } else {
        chat.addAll([DateHeader(date: DateTime.now()), textMessage]);
      }
    });

    late final ReplyToConversationResult result;
    try {
      result = await ref
          .read(conversationsParserProvider)
          .replyToConversation(
            settings.id,
            settings.replyTo,
            settings.groupChat ? "ja" : "nein",
            settings.onlyPrivateAnswers ? "ja" : "nein",
            text,
          );
    } catch (_) {
      _notifySidebar();
      if (!mounted) return false;
      setState(() {
        textMessage.status = MessageStatus.error;
      });
      showSnackbar(
        context,
        AppLocalizations.of(context).errorSendingMessage,
        seconds: 4,
      );
      return false;
    }

    _notifySidebar();
    if (!mounted) return result.success;
    // Fork: Status an der gesendeten Nachricht (textMessage) statt an
    // chat.last. Ursache (Prüfung 27.10.26): Brachte ein Abgleich während des
    // Sendens neue Nachrichten, bekam die fremde letzte Nachricht den Status
    // (oder es krachte, wenn chat.last eine DateHeader-Kopfzeile war).
    // Fehler-Hinweis 4 s statt 1 s (Vorgabe showSnackbar) – in 1 s nicht
    // lesbar. Grenze: Kam die eigene Nachricht schon per Abgleich, wird die
    // lokale Kopie entfernt (die Server-Fassung bleibt).
    setState(() {
      if (result.success) {
        if (!_renderedMessageIds.add(result.messageId)) {
          chat.remove(textMessage);
        }
        textMessage.status = MessageStatus.sent;
      } else {
        textMessage.status = MessageStatus.error;
        showSnackbar(
          context,
          AppLocalizations.of(context).errorSendingMessage,
          seconds: 4,
        );
      }
    });
    return result.success;
  }

  Message addMessage(UnparsedMessage message, MessageState position) {
    final contentParsed = parse(message.content);
    final content = contentParsed.body!.text;

    return Message(
      text: content,
      own: message.own,
      author: message.author,
      date: parseConversationDate(message.date),
      state: position,
      status: MessageStatus.sent,
    );
  }

  List<String> authors = [];

  void _renderSingleMessage(UnparsedMessage message) {
    _renderedMessageIds.add(message.id);
    final DateTime messageDate = parseConversationDate(message.date);
    final String messageAuthor = message.author;
    MessageState position = MessageState.first;

    // Check if this message should be part of a series by examining the last message in chat
    if (chat.isNotEmpty && chat.last is Message) {
      Message lastMessage = chat.last;
      if (messageAuthor == lastMessage.author &&
          messageDate.isSameDay(lastMessage.date)) {
        position = MessageState.series;
      }
    }

    // Add message to appropriate authors list for styling
    if (message.own != true) {
      authors.add(messageAuthor);
    }

    // Add message to chat with appropriate date header if needed
    if (chat.isEmpty ||
        (chat.last is Message && !messageDate.isSameDay(chat.last.date))) {
      chat.addAll([
        DateHeader(date: messageDate),
        addMessage(message, position),
      ]);
    } else {
      chat.add(addMessage(message, position));
    }
  }

  void renderMessages(Conversation unparsedMessages) {
    chat.clear(); // Clear existing messages for refresh capability
    authors.clear(); // Clear existing authors
    _renderedMessageIds
      ..clear()
      ..add(unparsedMessages.parent.id);

    // Process parent message
    final DateTime parentDate = parseConversationDate(
      unparsedMessages.parent.date,
    );
    final String parentAuthor = unparsedMessages.parent.author;

    if (unparsedMessages.parent.own != true) {
      authors.add(parentAuthor);
    }

    // Add parent message with initial date header
    chat.addAll([
      DateHeader(date: parentDate),
      addMessage(unparsedMessages.parent, MessageState.first),
    ]);

    // Process all replies
    for (UnparsedMessage reply in unparsedMessages.replies) {
      _renderSingleMessage(reply);
    }

    addAuthorTextStyles(authors.toList());
  }

  Future<void> initConversation() async {
    Conversation result = await ref
        .read(conversationsParserProvider)
        .getSingleConversation(widget.id);
    _lastRefresh = result.msgLastRefresh;
    logger.d("last refresh: $_lastRefresh");

    settings = ConversationSettings(
      id: widget.id,
      groupChat: result.groupChat,
      onlyPrivateAnswers: result.onlyPrivateAnswers,
      noReply: result.noReply,
      author: result.parent.author,
      own: result.parent.own,
      sender: result.sender,
    );

    statistics = ParticipationStatistics(
      countParents: result.countParents,
      countStudents: result.countStudents,
      countTeachers: result.countTeachers,
      knownParticipants: result.knownParticipants,
    );

    renderMessages(result);

    if (settings.own) {
      isSendVisible.value = true;
    } else {
      isSendVisible.value = !settings.noReply;
    }
  }

  String get tooltipMessage {
    if (settings.onlyPrivateAnswers && !settings.own) {
      return AppLocalizations.of(context).replyToPerson(settings.author!);
    } else if (settings.groupChat == false &&
        settings.onlyPrivateAnswers == false &&
        settings.noReply == false) {
      return AppLocalizations.of(context).openChatWarning;
    } else {
      return AppLocalizations.of(context).sendMessagePlaceholder;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: ChatScrollToBottomFab(
        isVisible: isScrollToBottomVisible,
        onPressed: () =>
            scrollToBottom(initDelay: const Duration(milliseconds: 50)),
      ),
      // Horizontal SafeArea insets leave a blank scaffold strip on devices with
      // landscape cutouts (e.g. Pixel 6). Keep only vertical insets so the
      // tablet detail pane / full-width chat can paint to the side edges.
      body: SafeArea(
        left: false,
        right: false,
        child: FutureBuilder(
          future: _conversationFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.waiting) {
              // Error content
              if (snapshot.hasError) {
                final error = snapshot.error is LanisException
                    ? snapshot.error as LanisException
                    : UnknownException(snapshot.error.toString());
                return AppletErrorView(
                  error: error,
                  showAppBar: true,
                  retry: () {
                    setState(() {
                      _conversationFuture = _loadConversation();
                    });
                  },
                );
              }

              return Column(
                children: [
                  ConversationsChatAppBar(
                    title: widget.title,
                    refreshing: refreshing,
                    settings: settings,
                    statistics: statistics,
                    conversationId: widget.id,
                  ),
                  Container(
                    width: double.infinity,
                    height: 1,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          width: 1,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.surfaceBright
                              : Theme.of(context).colorScheme.surfaceDim,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ChatTrianglePattern(
                          lineColor: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.07),
                        ),
                        GestureDetector(
                          onTap: () => SystemChannels.textInput.invokeMethod(
                            'TextInput.hide',
                          ),
                          behavior: HitTestBehavior.deferToChild,
                          child: NotificationListener<ScrollMetricsNotification>(
                            onNotification: (_) {
                              toggleScrollToBottomFab();
                              return false;
                            },
                            child: FetchMoreIndicator(
                              controller: refreshIndicatorController,
                              onAction: refreshConversation,
                              child: CustomScrollView(
                                controller: scrollController,
                                reverse: true,
                                physics: const AlwaysScrollableScrollPhysics(),
                                slivers: [
                                  SliverToBoxAdapter(
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      curve: Curves.easeInOut,
                                      height: richTextEditorSize + 10,
                                    ),
                                  ),
                                  SliverList.builder(
                                    itemCount: chat.length,
                                    itemBuilder: (context, index) {
                                      // Reverse the index to show messages in correct order
                                      final reversedIndex =
                                          chat.length - 1 - index;
                                      if (chat[reversedIndex] is Message) {
                                        return MessageWidget(
                                          message: chat[reversedIndex],
                                          textStyle:
                                              textStyles[chat[reversedIndex]
                                                  .author],
                                        );
                                      } else {
                                        return DateHeaderWidget(
                                          header: chat[reversedIndex],
                                        );
                                      }
                                    },
                                  ),
                                  SliverToBoxAdapter(
                                    child: ChatIntroHeader(
                                      title: widget.title,
                                      settings: settings,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Visibility(
                          visible: settings.own || !settings.noReply,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: RichChatTextEditor(
                              scrollToBottom: scrollToBottom,
                              sendMessage: sendMessage,
                              tooltip: tooltipMessage,
                              sending: isSendVisible.value,
                              editorSizeChangeCallback: (height) {
                                bool wasScrolledToBottom =
                                    scrollController.position.pixels <= 40;
                                setState(() {
                                  richTextEditorSize = height;
                                });
                                if (wasScrolledToBottom &&
                                    scrollController.position.pixels != 0) {
                                  scrollController.animateTo(
                                    0,
                                    duration: Duration(milliseconds: 100),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            // Waiting content
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}
