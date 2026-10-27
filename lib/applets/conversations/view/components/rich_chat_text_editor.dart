import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lanis/applets/conversations/view/send.dart';
import 'package:lanis/fork/l10n/l10n.dart';

/// Fork: true = gesendet (Editor wird geleert), false = nicht gesendet
/// (Text bleibt stehen, siehe Senden-Knopf).
typedef SendMessageCallback = Future<bool> Function(String message);
typedef EditorSizeChangeCallback = void Function(double height);

class RichChatTextEditor extends StatefulWidget {
  final String tooltip;
  final bool sending;
  final SendMessageCallback sendMessage;
  final VoidCallback scrollToBottom;
  final EditorSizeChangeCallback editorSizeChangeCallback;

  const RichChatTextEditor({
    super.key,
    required this.tooltip,
    required this.sending,
    required this.sendMessage,
    required this.scrollToBottom,
    required this.editorSizeChangeCallback,
  });

  @override
  State<RichChatTextEditor> createState() => _RichChatTextEditorState();
}

class _RichChatTextEditorState extends State<RichChatTextEditor> {
  final QuillController quillController = QuillController.basic();
  StreamSubscription<DocChange>? _changesSub;
  bool showToolbar = false;

  /// Fork: Senden läuft – Knopf gesperrt, damit derselbe Text nicht zweimal
  /// geht (der Editor wird erst nach Erfolg geleert).
  bool _sending = false;
  int editorlineCount = 1;
  final GlobalKey _widgetKey = GlobalKey();

  void onEditorChange() {
    if (!mounted) return;
    final text = quillController.document.toPlainText();
    setState(() {
      editorlineCount = '\n'.allMatches(text).length + 1;
    });

    _notifyHeightChange();
  }

  void _notifyHeightChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final RenderBox? renderBox =
          _widgetKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final height = renderBox.size.height;
        widget.editorSizeChangeCallback(height);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _changesSub = quillController.changes.listen((_) {
      onEditorChange();
    });
  }

  @override
  void dispose() {
    _changesSub?.cancel();
    quillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: _widgetKey,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 2.0,
                  left: 4.0,
                  right: 4.0,
                ),
                child: Material(
                  elevation: 2.0,
                  borderRadius: BorderRadius.circular((kToolbarHeight / 1.5)),
                  child: IconButton(
                    iconSize: kToolbarHeight / 1.5,
                    onPressed: () {
                      setState(() {
                        showToolbar = !showToolbar;
                      });
                      _notifyHeightChange();
                    },
                    icon: Icon(Icons.format_textdirection_l_to_r_outlined),
                    color: Theme.of(context).colorScheme.onSecondary,
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: kToolbarHeight,
                    maxHeight: 150,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.0),
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.shadow.withAlpha(90),
                        blurRadius: 3.0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: QuillEditor.basic(
                          controller: quillController,
                          config: QuillEditorConfig(
                            placeholder: widget.tooltip,
                            customStyles: DefaultStyles(
                              placeHolder: DefaultTextBlockStyle(
                                // Fork: onSurfaceVariant statt onSurface mit
                                // Alpha 80 (≈31 %). Ursache (Prüfung
                                // 27.10.26): Der Platzhalter lag auf
                                // surfaceContainerHigh deutlich unter 4,5:1.
                                // Grenze: Material-3-Paare sind für
                                // Text-Kontrast ausgelegt, nicht nachgemessen
                                // für jede dynamische Farbe.
                                TextStyle(
                                  fontSize: 18,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                HorizontalSpacing.zero,
                                VerticalSpacing(0, 0),
                                VerticalSpacing(0, 0),
                                null,
                              ),
                              paragraph: DefaultTextBlockStyle(
                                TextStyle(
                                  fontSize: 18,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                                HorizontalSpacing.zero,
                                VerticalSpacing(0, 0),
                                VerticalSpacing(0, 0),
                                null,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 2.0,
                  left: 4.0,
                  right: 6.0,
                ),
                child: Material(
                  elevation: 2.0,
                  borderRadius: BorderRadius.circular((kToolbarHeight / 1.5)),
                  child: IconButton(
                    iconSize: kToolbarHeight / 1.5,
                    // Fork: erst nach Erfolg leeren. Ursache (Prüfung
                    // 27.10.26): Der Editor wurde vor dem Senden geleert –
                    // scheiterte replyToConversation (chat.dart, sendMessage),
                    // war der Text verloren; nur Leerzeichen gingen als leere
                    // Antwort raus. Grenze: Was während des Sendens getippt
                    // wird, leert der Erfolg mit.
                    tooltip: context.t.send,
                    onPressed: _sending
                        ? null
                        : () async {
                            final String text =
                                ConversationMessageText.parseText(
                                  quillController.document.toDelta(),
                                );
                            if (ConversationMessageText.isBlank(text)) return;

                            setState(() => _sending = true);
                            final bool sent;
                            try {
                              sent = await widget.sendMessage(text);
                            } finally {
                              if (mounted) setState(() => _sending = false);
                            }
                            if (!mounted) return;
                            if (sent) quillController.clear();
                            widget.scrollToBottom();
                          },
                    icon: Icon(Icons.send),
                    color: quillController.document.isEmpty()
                        ? Theme.of(context).colorScheme.onTertiary.withAlpha(80)
                        : Theme.of(context).colorScheme.onTertiary,
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          onEnd: () => _notifyHeightChange(),
          child: showToolbar
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          QuillToolbarHistoryButton(
                            isUndo: true,
                            controller: quillController,
                          ),
                          QuillToolbarHistoryButton(
                            isUndo: false,
                            controller: quillController,
                          ),
                          QuillToolbarClearFormatButton(
                            controller: quillController,
                          ),
                          QuillToolbarToggleStyleButton(
                            options:
                                const QuillToolbarToggleStyleButtonOptions(),
                            controller: quillController,
                            attribute: Attribute.bold,
                          ),
                          QuillToolbarToggleStyleButton(
                            options:
                                const QuillToolbarToggleStyleButtonOptions(),
                            controller: quillController,
                            attribute: Attribute.italic,
                          ),
                          QuillToolbarToggleStyleButton(
                            controller: quillController,
                            attribute: Attribute.underline,
                          ),
                          QuillToolbarToggleStyleButton(
                            controller: quillController,
                            attribute: Attribute.strikeThrough,
                          ),
                          QuillToolbarToggleStyleButton(
                            controller: quillController,
                            attribute: Attribute.inlineCode,
                          ),
                          QuillToolbarToggleStyleButton(
                            controller: quillController,
                            attribute: Attribute.ul,
                          ),
                          QuillToolbarToggleStyleButton(
                            controller: quillController,
                            attribute: Attribute.superscript,
                          ),
                          QuillToolbarToggleStyleButton(
                            controller: quillController,
                            attribute: Attribute.subscript,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
