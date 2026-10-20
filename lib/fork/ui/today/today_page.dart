import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../kit.dart';
import '../../class_choice.dart' show classLabel;
import 'kind_icons.dart';
import 'today_model.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Abstand in Kalendertagen. Über UTC gerechnet, weil `difference` in
/// Ortszeit über die Zeitumstellung (z. B. 25.10.26) 23 Stunden ergibt und
/// `inDays` dann einen Tag zu wenig liefert.
int dayDiff(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// „DIENSTAG, 20. OKTOBER“ (Muster [ForkL10n.dateLong] der Sprache).
String dateCaps(ForkL10n t, DateTime d) =>
    upperFor(t, formatDate(t, t.dateLong, d));

/// Begrüßung nach Tageszeit.
String greetingFor(ForkL10n t, DateTime now) => now.hour < 11
    ? t.greetingMorning
    : (now.hour < 18 ? t.greetingDay : t.greetingEvening);

/// „Heute“, „Morgen“ oder „Do 22.10.“ relativ zu [now].
String relativeDay(ForkL10n t, DateTime day, DateTime now) {
  final diff = dayDiff(now, day);
  if (diff == 0) return t.dayToday;
  if (diff == 1) return t.dayTomorrow;
  return formatDate(t, t.dateShort, day);
}

/// Kurzer Wochentag („Mo“) – Standalone-Form „ccc“, ohne Punkt.
String weekdayShort(ForkL10n t, DateTime d) => formatDate(t, 'ccc', d);

/// Kurzform der Stunde für die schmale Spalte der Tagesliste: „2. Block“ →
/// „2.“, „1.–2. Block“ → „1.–2.“. Ursache: Mit echten Daten von Schule A brach
/// „Block“ in der Spalte (Sz.slotColumn) in eine zweite Zeile um
/// (Bildschirmfoto 16.10.26). Überschrift und Kasten behalten das Wort.
String listSlot(String slot) =>
    slot.replaceAll(RegExp(r'\s+(Block|Stunde|Std\.?)$'), '');

/// Montag bis Freitag der laufenden Woche; am Wochenende die nächste.
/// Mit dem DateTime-Konstruktor statt Duration gerechnet: Duration zählt
/// 24 Stunden und landete über die Zeitumstellung bei 23:00 am Vortag
/// (Test: Samstag 24.10.26 → Montag 26.10.26).
List<DateTime> schoolWeek(DateTime now) {
  final shift = now.weekday >= DateTime.saturday ? 7 : 0;
  final mondayDay = now.day - (now.weekday - 1) + shift;
  return [
    for (var i = 0; i < 5; i++) DateTime(now.year, now.month, mondayDay + i),
  ];
}

/// Seite „Heute“ (Entwurf A + C, abgenommen 16.10.26; kompakt nach
/// Entwurf 18.10.26: „möglichst wenig scrollen, maximale Übersicht“).
///
/// Kopf in einer Zeile (Datum, Stand) statt Datum plus Begrüßung; Kasten nur
/// für morgen (heute steht an der Karte); Karten je Kind; „Demnächst“ als
/// Liste. Ab [Sz.wideLayout] Breite (Tablet) Kinder links, Termine rechts.
class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.data,
    this.onReportAbsence,
    this.onOpenHomework,
    this.onOpenMessages,
    this.onOpenCalendar,
    this.onOpenDay,
    this.onOrderMeal,
    this.onRefresh,
    this.notices = const [],
  });

  /// Hinweise oben (z. B. Konto nicht angemeldet, login_failure_card.dart).
  final List<Widget> notices;

  final FamilyToday data;
  final void Function(ChildToday child)? onReportAbsence;
  final void Function(ChildToday child)? onOpenHomework;
  final void Function(ChildToday child)? onOpenMessages;
  final VoidCallback? onOpenCalendar;

  /// Tagesleiste angetippt: den Tag des Kindes im Kalender öffnen (ersetzt
  /// „Ganzen Tag zeigen“ an der Karte).
  final void Function(ChildToday child)? onOpenDay;
  final void Function(ChildToday child)? onOrderMeal;

  /// Ziehen zum Aktualisieren; null = ohne (Beispieldaten).
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    // Enthält bei Scaffold(extendBody: true) die Höhe der schwebenden Leiste.
    final bottom = MediaQuery.paddingOf(context).bottom;
    final wide = MediaQuery.sizeOf(context).width >= Sz.wideLayout;
    final updated = data.updatedAt;

    final head = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // Verkleinern statt umbrechen (wie der Titel im Kalender).
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatDate(t, t.dateLong, data.now),
              style: k.pageTitle,
              maxLines: 1,
            ),
          ),
        ),
        if (updated != null) ...[
          const SizedBox(width: Sp.s),
          Text(
            t.asOf(
              '${updated.hour.toString().padLeft(2, '0')}:'
              '${updated.minute.toString().padLeft(2, '0')}',
            ),
            style: k.meta,
          ),
        ],
      ],
    );

    final kids = <Widget>[
      for (final (i, kid) in data.kids.indexed) ...[
        if (i > 0) const SizedBox(height: Sp.m),
        KidCard(
          kid: kid,
          now: data.now,
          onReportAbsence: onReportAbsence,
          onOpenHomework: onOpenHomework,
          onOpenMessages: onOpenMessages,
          onOrderMeal: onOrderMeal,
          onOpenDay: onOpenDay,
        ),
      ],
    ];
    final upcoming = data.week.isEmpty
        ? null
        : UpcomingList(
            data: data,
            max: wide ? 10 : 5,
            onOpenAll: onOpenCalendar,
          );

    final view = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        Sp.page,
        MediaQuery.paddingOf(context).top + Sp.l,
        Sp.page,
        bottom + Sp.xl,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
          child: head,
        ),
        for (final n in notices)
          Padding(
            padding: const EdgeInsets.only(top: Sp.m),
            child: n,
          ),
        if (tomorrowItems(data).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Sp.m),
            child: ImportantBox(data: data),
          ),
        if (data.isDemo)
          Padding(
            padding: const EdgeInsets.only(top: Sp.m),
            child: Text(t.demoNote, style: k.meta, textAlign: TextAlign.center),
          ),
        const SizedBox(height: Sp.m),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: kids,
                ),
              ),
              const SizedBox(width: Sp.l),
              Expanded(flex: 10, child: upcoming ?? const SizedBox.shrink()),
            ],
          )
        else ...[
          ...kids,
          if (upcoming != null) ...[const SizedBox(height: Sp.l), upcoming],
        ],
      ],
    );
    final refresh = onRefresh;
    if (refresh == null) return view;
    return RefreshIndicator(onRefresh: refresh, child: view);
  }
}

/// Farbpunkt (Kind bzw. Änderungsart) in Kasten „Wichtig“ und „Demnächst“.
class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: Sz.dot,
    height: Sz.dot,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

// ---- Kasten „Wichtig heute und morgen“ -------------------------------------

/// Änderungen aller Kinder für heute und morgen, nach Tag sortiert.
List<(ChildToday, ChangeItem)> importantItems(FamilyToday data) {
  final today = _day(data.now);
  final items = <(ChildToday, ChangeItem)>[
    for (final kid in data.kids)
      for (final c in kid.changes)
        if (dayDiff(today, c.day) case 0 || 1) (kid, c),
  ];
  items.sort((a, b) => a.$2.day.compareTo(b.$2.day));
  return items;
}

/// Nur morgen – die heutigen Änderungen stehen an der Karte des Kindes
/// (KidCard, Entwurf 18.10.26).
List<(ChildToday, ChangeItem)> tomorrowItems(FamilyToday data) => [
  for (final x in importantItems(data))
    if (dayDiff(data.now, x.$2.day) == 1) x,
];

/// Kasten mit den Änderungen für morgen, eine Zeile je Änderung, ohne
/// Überschrift (Entwurf 18.10.26: „Morgen“ steht in jeder Zeile).
class ImportantBox extends StatelessWidget {
  const ImportantBox({super.key, required this.data});

  final FamilyToday data;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final items = tomorrowItems(data);
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.l, Sp.m, Sp.l, Sp.m),
      decoration: BoxDecoration(
        color: k.p.change.bg,
        borderRadius: BorderRadius.circular(Rad.signal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, (kid, c)) in items.indexed) ...[
            if (i > 0) const SizedBox(height: Sp.xs + Sp.xxs),
            _ImportantRow(kid: kid, item: c, now: data.now),
          ],
        ],
      ),
    );
  }
}

class _ImportantRow extends StatelessWidget {
  const _ImportantRow({
    required this.kid,
    required this.item,
    required this.now,
  });

  final ChildToday kid;
  final ChangeItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final tone = item.kind == ChangeKind.cancelled ? k.p.cancel : k.p.change;
    final what = switch (item.kind) {
      ChangeKind.cancelled => t.lessonCancelled,
      ChangeKind.roomChange => '${t.changeRoom} ${item.detail ?? ''}'.trim(),
      ChangeKind.substitution =>
        '${t.changeSubstitution} ${item.detail ?? ''}'.trim(),
    };
    final when = lowerFor(t, relativeDay(t, item.day, now));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Sp.xxs),
          child: Icon(changeIcon(item.kind), size: Sz.icon, color: tone.ink),
        ),
        const SizedBox(width: Sp.s),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${kid.firstName} · $when ${item.slot} ${item.subject}',
                  style: k.boxStrong(tone),
                ),
                TextSpan(text: ' – $what', style: k.boxText(tone)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---- Karte je Kind ----------------------------------------------------------

class KidCard extends StatelessWidget {
  const KidCard({
    super.key,
    required this.kid,
    required this.now,
    this.onReportAbsence,
    this.onOpenHomework,
    this.onOpenMessages,
    this.onOrderMeal,
    this.onOpenDay,
  });

  final ChildToday kid;
  final DateTime now;
  final void Function(ChildToday child)? onReportAbsence;
  final void Function(ChildToday child)? onOpenHomework;
  final void Function(ChildToday child)? onOpenMessages;
  final void Function(ChildToday child)? onOrderMeal;
  final void Function(ChildToday child)? onOpenDay;

  /// Heutige Änderungen an Stunden, die noch kommen oder laufen.
  List<DayLesson> _changesLeft() => [
    for (final x in kid.lessons)
      if (x.change != null && !lessonDone(x, now)) x,
  ];

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final tone = k.kid(kid.colorIndex);
    final status = dayStatus(kid.lessons, now);
    final meta = [
      kid.school,
      classLabel(kid.className),
    ].where((s) => s.isNotEmpty).join(' · ');
    final changes = _changesLeft();

    return Container(
      padding: const EdgeInsets.all(Sp.l),
      decoration: BoxDecoration(
        color: k.p.card,
        borderRadius: BorderRadius.circular(Rad.box),
        boxShadow: k.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kopf: Bild bzw. Anfangsbuchstabe, daneben Name und darunter
          // Schule · Klasse. Ursache (Bildschirmfoto 20.10.26): In einer
          // Zeile wurde die Schule bei großer Schrift abgeschnitten.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: Sz.avatar,
                height: Sz.avatar,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: tone.accent,
                  shape: BoxShape.circle,
                ),
                // Foto aus dem Portal statt Buchstabe (Wunsch 20.10.26).
                child: kid.photo != null
                    ? Image.memory(
                        kid.photo!,
                        width: Sz.avatar,
                        height: Sz.avatar,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      )
                    : Text(
                        // Leerer Name (offline, unbekannt) darf nicht abstürzen.
                        kid.firstName.isEmpty
                            ? '?'
                            : kid.firstName.characters.first,
                        style: k.avatarLetter.copyWith(color: k.p.card),
                      ),
              ),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kid.firstName,
                      style: k.cardName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: k.cardMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.m),
          _NowPanel(kid: kid, status: status, tone: tone),
          if (kid.lessons.isNotEmpty) ...[
            const SizedBox(height: Sp.m),
            // Antippen öffnet den Tag im Kalender (alle Stunden, Pausen).
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onOpenDay == null ? null : () => onOpenDay!(kid),
                borderRadius: BorderRadius.circular(Rad.bar),
                child: _DayBar(kid: kid, status: status, tone: tone, now: now),
              ),
            ),
          ],
          for (final x in changes)
            Padding(
              padding: const EdgeInsets.only(top: Sp.s),
              child: _ChangeLine(lesson: x),
            ),
          if (kid.mealHint != null)
            Padding(
              padding: const EdgeInsets.only(top: Sp.s),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.restaurant, size: Sz.icon, color: k.p.muted),
                  const SizedBox(width: Sp.s),
                  Expanded(child: Text(kid.mealHint!, style: k.cardMeta)),
                ],
              ),
            ),
          ..._actions(t),
        ],
      ),
    );
  }

  List<Widget> _actions(ForkL10n t) {
    final items = <Widget>[
      if (kid.openHomework > 0)
        _ActionButton(
          icon: Icons.menu_book_outlined,
          label: t.homeworkCount(kid.openHomework),
          onTap: onOpenHomework == null ? null : () => onOpenHomework!(kid),
        ),
      if (kid.unreadMessages > 0)
        _ActionButton(
          icon: Icons.mail_outline,
          label: t.unreadCount(kid.unreadMessages),
          onTap: onOpenMessages == null ? null : () => onOpenMessages!(kid),
        ),
      if (kid.mensaUrl != null)
        _ActionButton(
          icon: Icons.restaurant_menu,
          label: t.orderMeal,
          onTap: onOrderMeal == null ? null : () => onOrderMeal!(kid),
        ),
      if (kid.canReportAbsence)
        _ActionButton(
          icon: Icons.thermostat,
          label: t.reportSick,
          strong: true,
          onTap: onReportAbsence == null ? null : () => onReportAbsence!(kid),
        ),
    ];
    if (items.isEmpty) return const [];
    // Zwei Knöpfe je Zeile, gleich breit; die Beschriftung schrumpft eher,
    // als umzubrechen. Ursache (Bildschirmfoto 20.10.26): Als umbrechende
    // Pillen stand bei großer Schrift jeder Knopf in einer eigenen Zeile.
    // Ein einzelner letzter Knopf nimmt die ganze Breite.
    return [
      const SizedBox(height: Sp.m),
      for (var i = 0; i < items.length; i += 2) ...[
        if (i > 0) const SizedBox(height: Sp.s),
        Row(
          children: [
            Expanded(child: items[i]),
            if (i + 1 < items.length) ...[
              const SizedBox(width: Sp.s),
              Expanded(child: items[i + 1]),
            ],
          ],
        ),
      ],
    ];
  }
}

/// Heutige Änderung als Zeile: „5. Std. Deutsch – Vertretung Tim Sommer“.
class _ChangeLine extends StatelessWidget {
  const _ChangeLine({required this.lesson});

  final DayLesson lesson;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final x = lesson;
    final tone = x.cancelled ? k.p.cancel : k.p.change;
    final what = switch (x.change!) {
      ChangeKind.cancelled => t.lessonCancelled,
      ChangeKind.roomChange => '${t.changeRoom} ${x.changeDetail ?? ''}'.trim(),
      ChangeKind.substitution =>
        '${t.changeSubstitution} ${x.changeDetail ?? ''}'.trim(),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Sp.xxs),
          child: Icon(changeIcon(x.change!), size: Sz.icon, color: tone.ink),
        ),
        const SizedBox(width: Sp.s),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${x.slot} ${x.subject}',
                  style: k.boxStrong(tone),
                ),
                TextSpan(text: ' – $what', style: k.boxText(tone)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Fläche „JETZT · 3./4. STD. · NOCH 30 MIN.“, Fach und Raum in einem
/// Absatz (bricht nur um, wenn es nicht passt).
class _NowPanel extends StatelessWidget {
  const _NowPanel({
    required this.kid,
    required this.status,
    required this.tone,
  });

  final ChildToday kid;
  final DayStatus status;
  final KidTone tone;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final l = kid.lessons;
    String label;
    String title;
    String? meta;

    // Innerhalb einer Angabe geschützte Leerzeichen: umbrochen wird nur
    // zwischen Uhrzeit, Raum und Lehrkraft, nie mitten im Namen. Ursache
    // (Rückmeldung 20.10.26): „Jan / Wolf“ stand auf zwei Zeilen. Grenze:
    // Ist ein Name allein breiter als die Fläche, bricht Flutter ihn doch.
    String keep(String v) => v.replaceAll(' ', '\u00A0');
    String details(DayLesson x) => [
      keep(hasTime(x) ? '${x.start}–${x.end}' : x.slot),
      if (x.room != null) keep(x.room!),
      if (x.teacher != null) keep(x.teacher!),
    ].join(' · ');

    switch (status.phase) {
      case DayPhase.running:
        final x = l[status.current!];
        label = upperFor(t, t.nowRunning(x.slot, status.minutesLeft!));
        title = x.subject;
        meta = details(x);
      case DayPhase.before:
      case DayPhase.gap:
        final x = l[status.next!];
        label = upperFor(
          t,
          status.phase == DayPhase.before
              ? t.nowFirst(x.slot, x.start)
              : t.nowNext(x.slot, x.start),
        );
        title = x.subject;
        meta = details(x);
      case DayPhase.over:
        final last = l.lastWhere((x) => !x.cancelled);
        label = upperFor(t, t.schoolOverLabel);
        title = t.schoolOverTitle;
        meta = t.lastLessonEnded(last.end);
      case DayPhase.noLessons:
        label = upperFor(t, t.dayToday);
        title = t.noLessons;
        meta = null;
      case DayPhase.untimed:
        final x = l[status.next!];
        label = upperFor(t, t.todayFromSlot(x.slot));
        title = x.subject;
        meta = details(x);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Sp.m,
        vertical: Sp.s + Sp.xxs,
      ),
      decoration: BoxDecoration(
        color: tone.tint,
        borderRadius: BorderRadius.circular(Rad.row),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: k.nowLabel(tone)),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: title, style: k.nowSubject(tone)),
                if (meta != null && meta.isNotEmpty)
                  TextSpan(text: '   $meta', style: k.nowMeta(tone)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tagesleiste: ein Abschnitt je (Doppel-)Stunde, Breite nach Dauer.
class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.kid,
    required this.status,
    required this.tone,
    required this.now,
  });

  final ChildToday kid;
  final DayStatus status;
  final KidTone tone;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final l = kid.lessons;

    Color colorFor(int i) {
      final x = l[i];
      if (x.cancelled) return k.p.cancel.bar;
      if (x.change != null && !lessonDone(x, now)) return k.p.change.bar;
      if (lessonDone(x, now)) return tone.barDone;
      return tone.barRest;
    }

    // „Danach“ an der Leiste: die Stunde nach der, die oben steht. Ursache
    // (Bildschirmfoto 20.10.26): Vor Schulbeginn und in Pausen zeigt die
    // Fläche oben schon die nächste Stunde („Gleich … Englisch 11:30“);
    // die Leiste wiederholte sie („Danach 11:30 Englisch“).
    int? afterShown() {
      final n = status.next;
      if (n == null) return null;
      if (status.phase != DayPhase.before && status.phase != DayPhase.gap) {
        return n;
      }
      for (var i = n + 1; i < l.length; i++) {
        if (!l[i].cancelled) return i;
      }
      return null;
    }

    final after = afterShown();
    final next = after == null ? null : l[after];
    final t = context.t;
    // Ohne Uhrzeiten (DayPhase.untimed): Leiste ohne Zeitbeschriftung.
    final timed = status.phase != DayPhase.untimed;
    final center = next == null || !timed
        ? ''
        : t.barThen(next.start, next.subject);
    final lastEnd = l.lastWhere((x) => !x.cancelled, orElse: () => l.last).end;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: Sz.dayBar,
          child: Row(
            children: [
              for (var i = 0; i < l.length; i++) ...[
                if (i > 0) const SizedBox(width: Sp.xs),
                Expanded(
                  flex: lessonMinutes(l[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Rad.bar),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: colorFor(i)),
                        if (status.current == i)
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: status.progress.clamp(0, 1),
                            child: ColoredBox(color: tone.accent),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Sp.xs + Sp.xxs),
        Row(
          children: [
            Text(timed ? l.first.start : '', style: k.barLabel),
            Expanded(
              child: Text(
                center,
                style: k.barLabel,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(timed ? t.barUntil(lastEnd) : '', style: k.barLabel),
          ],
        ),
      ],
    );
  }
}

/// Aktion als Pille (Höhe wie die Kinderwahl, Sz.buttonSmall).
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.strong = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final fg = strong ? k.p.onStrong : k.p.ink;
    // Feiner Rahmen um die hellen Knöpfe (Rückmeldung 20.10.26: „Felder
    // umrahmen“) – Grau auf Weiß hob sich bei Sonnenlicht kaum ab.
    return Material(
      color: strong ? k.p.strong : k.p.inset,
      shape: StadiumBorder(
        side: strong ? BorderSide.none : BorderSide(color: k.p.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.pill),
        onTap: onTap,
        child: Container(
          height: Sz.buttonSmall,
          padding: const EdgeInsets.symmetric(horizontal: Sp.m),
          alignment: Alignment.center,
          // Volle Breite der Spalte (Kinderkarte: zwei je Zeile); passt die
          // Beschriftung nicht, wird sie kleiner statt abgeschnitten.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: Sz.icon, color: fg),
                const SizedBox(width: Sp.s),
                Text(label, style: k.button(fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Demnächst --------------------------------------------------------------

/// „Demnächst“ als Liste über die volle Breite: Tag, Titel mit Uhrzeit bzw.
/// Art, Kind. Ursache (Rückmeldung 18.10.26): Die seitlich scrollenden
/// Kacheln nutzten den Platz nicht und schnitten Termine ab.
class UpcomingList extends StatelessWidget {
  const UpcomingList({
    super.key,
    required this.data,
    this.max = 5,
    this.onOpenAll,
  });

  final FamilyToday data;
  final int max;
  final VoidCallback? onOpenAll;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final items = [...data.week]..sort((a, b) => a.day.compareTo(b.day));
    final shown = items.take(max).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Sp.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(t.upcoming, style: k.section)),
              if (onOpenAll != null)
                TextButton(
                  onPressed: onOpenAll,
                  child: Text(t.allEvents, style: k.link),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.l,
            vertical: Sp.xs,
          ),
          decoration: BoxDecoration(
            color: k.p.card,
            borderRadius: BorderRadius.circular(Rad.box),
            boxShadow: k.cardShadow,
          ),
          child: Column(
            children: [
              for (final (i, w) in shown.indexed) ...[
                if (i > 0) Divider(height: 1, color: k.p.line),
                _UpcomingRow(item: w, data: data),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.item, required this.data});

  final WeekItem item;
  final FamilyToday data;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final ci = item.childIndex;
    final kid = ci == null || ci >= data.kids.length ? null : data.kids[ci];
    final color = kid == null ? k.p.muted : k.kid(kid.colorIndex).accent;
    final kind = switch (item.kind) {
      WeekKind.exam => t.kindExam,
      WeekKind.free => t.kindFree,
      WeekKind.deadline => t.kindDeadline,
      WeekKind.meal => t.kindMeal,
      WeekKind.event => null,
    };
    final meta = [
      ?item.time,
      if (item.until != null)
        t.barUntil(formatDate(t, t.dateShort, item.until!)),
      ?kind,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.s + Sp.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: Sz.slotColumn + Sp.l,
            child: Text(
              relativeDay(t, item.day, data.now),
              style: k.tileCaption,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: Sp.xxs, right: Sp.s),
            child: Icon(
              weekIcon(item.kind),
              size: Sz.icon,
              color: item.kind == WeekKind.exam ? k.p.cancel.ink : k.p.muted,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: k.tileTitle),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: k.planMeta(
                      item.kind == WeekKind.exam ? k.p.cancel.ink : k.p.muted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Sp.s),
          Padding(
            padding: const EdgeInsets.only(top: Sp.xs),
            child: _Dot(color: color),
          ),
          const SizedBox(width: Sp.xs + Sp.xxs),
          Text(kid?.firstName ?? t.forEveryone, style: k.tileKid(color)),
        ],
      ),
    );
  }
}
