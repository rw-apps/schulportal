import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../kit.dart';
import '../pinned_page.dart';

/// Eine Unterhaltung für die Liste (Auszug aus OverviewEntry).
class MessageItem {
  const MessageItem({
    required this.id,
    required this.subject,
    required this.sender,
    required this.date,
    this.unread = false,
    this.kidName,
    this.kidColor,
  });

  /// Kind der Nachricht in der Ansicht „Alle“ (Wunsch 18.10.26); null =
  /// Ansicht eines Kindes, ohne Zeile.
  final String? kidName;
  final int? kidColor;

  final String id;
  final String subject;
  final String sender;

  /// So, wie das Portal es liefert („heute 08:12“, „16.10.2026 12:30“).
  final String date;
  final bool unread;
}

/// Bereich „Nachrichten“: nur der Austausch mit der Schule (Konzept
/// 17.10.26). Oben „Neue Nachricht“, darunter die Unterhaltungen,
/// ungelesene fett mit Punkt.
class MessagesPage extends StatelessWidget {
  const MessagesPage({
    super.key,
    required this.items,
    this.onOpen,
    this.onCompose,
    this.onRefresh,
    this.loading = false,
  });

  final List<MessageItem> items;
  final void Function(MessageItem item)? onOpen;
  final VoidCallback? onCompose;
  final Future<void> Function()? onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final unread = items.where((i) => i.unread).length;
    // Überschrift und „Neue Nachricht“ fest, die Liste scrollt darunter
    // (PinnedPage).
    return PinnedPage(
      onRefresh: onRefresh,
      bodyPadding: const EdgeInsets.fromLTRB(Sp.page, Sp.xs, Sp.page, Sp.xl),
      header: [
        Padding(
          padding: const EdgeInsets.only(left: Sp.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.navMessages, style: k.pageTitle),
              Text(
                unread == 0 ? t.allRead : t.unreadShort(unread),
                style: k.meta,
              ),
            ],
          ),
        ),
        if (onCompose != null)
          Padding(
            padding: const EdgeInsets.only(top: Sp.l),
            child: Material(
              color: k.p.strong,
              borderRadius: BorderRadius.circular(Rad.button),
              child: InkWell(
                borderRadius: BorderRadius.circular(Rad.button),
                onTap: onCompose,
                child: SizedBox(
                  height: Sz.button,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: Sz.icon,
                        color: k.p.onStrong,
                      ),
                      const SizedBox(width: Sp.s),
                      Flexible(
                        child: Text(
                          t.newMessage,
                          style: k.button(k.p.onStrong),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
      slivers: [
        items.isEmpty
            ? SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: Sp.xs),
                  child: Text(
                    loading ? t.loading : t.noMessages,
                    style: k.meta,
                  ),
                ),
              )
            : SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: Sp.s),
                itemBuilder: (context, i) =>
                    _Row(item: items[i], onTap: onOpen),
              ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, this.onTap});

  final MessageItem item;
  final void Function(MessageItem)? onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final tone = k.kid(item.kidColor ?? 0);
    return Material(
      color: item.unread ? tone.tint : k.p.card,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.signal),
        onTap: onTap == null ? null : () => onTap!(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: Sp.s, right: Sp.m),
                child: Container(
                  width: Sz.dot,
                  height: Sz.dot,
                  decoration: BoxDecoration(
                    color: item.unread ? tone.accent : null,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.subject.isEmpty ? context.t.noSubject : item.subject,
                      style: item.unread
                          ? k.planSubject(tone.onTint)
                          : k.rowSubject(k.p.ink),
                    ),
                    Text(
                      [
                        if (item.sender.isNotEmpty) item.sender,
                        item.date,
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: k.planMeta(item.unread ? tone.meta : k.p.muted),
                    ),
                    if (item.kidName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Sp.xxs),
                        child: Row(
                          children: [
                            Container(
                              width: Sz.dot,
                              height: Sz.dot,
                              decoration: BoxDecoration(
                                color: tone.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: Sp.xs + Sp.xxs),
                            Flexible(
                              child: Text(
                                item.kidName!,
                                style: k.tileKid(tone.accent),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
