import 'package:flutter/material.dart';

import '../kit.dart';

/// Eine Unterhaltung für die Liste (Auszug aus OverviewEntry).
class MessageItem {
  const MessageItem({
    required this.id,
    required this.subject,
    required this.sender,
    required this.date,
    this.unread = false,
  });

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
    final bottom = MediaQuery.paddingOf(context).bottom;
    final unread = items.where((i) => i.unread).length;
    final view = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Sp.page + Sp.xs,
              Sp.xl,
              Sp.page,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nachrichten', style: k.pageTitle),
                  Text(
                    unread == 0
                        ? 'Alles gelesen'
                        : (unread == 1 ? '1 ungelesen' : '$unread ungelesen'),
                    style: k.meta,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onCompose != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Sp.page, Sp.l, Sp.page, 0),
            sliver: SliverToBoxAdapter(
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
                            'Neue Nachricht',
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
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(Sp.page, Sp.l, Sp.page, bottom + Sp.xl),
          sliver: items.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: Sp.xs),
                    child: Text(
                      loading ? 'Wird geladen …' : 'Keine Nachrichten.',
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
        ),
      ],
    );
    final r = onRefresh;
    return r == null ? view : RefreshIndicator(onRefresh: r, child: view);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, this.onTap});

  final MessageItem item;
  final void Function(MessageItem)? onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final tone = k.kid(0);
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
                      item.subject.isEmpty ? '(ohne Betreff)' : item.subject,
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
