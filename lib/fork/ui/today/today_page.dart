import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../kit.dart';
import '../pinned_page.dart';
import '../../class_choice.dart' show classLabel;
import 'kid_hints.dart';
import 'kind_icons.dart';
import 'today_model.dart';

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
/// Kopf in einer Zeile (Datum, Stand) statt Datum plus Begrüßung; Karten je
/// Kind mit Hinweisen für heute und den nächsten Schultag (KidCard, seit
/// 21.10.26 statt eines eigenen Kastens für morgen); „Demnächst“ als Liste.
/// Ab [Sz.wideLayout] Breite (Tablet) Kinder links, Termine rechts.
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

    // Kopf (Datum, Stand) fest, Inhalt scrollt darunter (PinnedPage).
    return PinnedPage(
      headerPadding: const EdgeInsets.fromLTRB(
        Sp.page + Sp.xs,
        Sp.l,
        Sp.page + Sp.xs,
        Sp.s,
      ),
      onRefresh: onRefresh,
      header: [head],
      children: [
        for (final (i, n) in notices.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? Sp.s : Sp.m),
            child: n,
          ),
        if (data.isDemo)
          Padding(
            padding: const EdgeInsets.only(top: Sp.m),
            child: Text(t.demoNote, style: k.meta, textAlign: TextAlign.center),
          ),
        const SizedBox(height: Sp.s),
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
  }
}

/// Farbpunkt (Kind) in „Demnächst“.
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

// ---- Karte je Kind ----------------------------------------------------------

/// Karte je Kind: Kopf, „Hinweise“, „Stundenplan“, Aktionen.
///
/// Aufbau nach Abnahme 21.10.26: Was vom Plan abweicht, steht farbig
/// gefüllt unter „Hinweise“ (kid_hints.dart); der reguläre Plan steht
/// schlicht (ohne Kinderfarbe) in einem Rahmen unter „Stundenplan“. Ursache
/// (Rückmeldung 21.10.26): Ausfall und Vertretung waren zu klein, und mit
/// dem bunten Plan fielen Signalfarben nicht auf. Die Kinderfarbe bleibt
/// nur am Bild bzw. Anfangsbuchstaben.
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
    final hints = kidHints(kid, now, t);
    final openDay = onOpenDay == null ? null : () => onOpenDay!(kid);

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
          // Ohne Hinweise entfallen Überschrift und Abschnitt ganz.
          if (hints.isNotEmpty) ...[
            const SizedBox(height: Sp.l),
            _SectionHead(text: t.hintsTitle),
            for (final (i, h) in hints.indexed) ...[
              if (i > 0) const SizedBox(height: Sp.s),
              _HintRow(hint: h),
            ],
          ],
          const SizedBox(height: Sp.l),
          // „Ganzer Tag ›“ macht sichtbar, dass Antippen den Tag im Kalender
          // öffnet (die Leiste allein verriet das nicht, Mockup 21.10.26).
          _SectionHead(
            text: t.timetableTitle,
            link: t.wholeDay,
            onTap: openDay,
          ),
          // Rahmen statt Fläche: gefüllt = Hinweis, umrandet = Plan. Die
          // ganze umrandete Fläche öffnet den Tag (alle Stunden, Pausen).
          Material(
            color: k.p.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Rad.row),
              side: BorderSide(color: k.p.faint, width: Sz.frame),
            ),
            child: InkWell(
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Rad.row),
              ),
              onTap: openDay,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Sp.m,
                  Sp.s + Sp.xxs,
                  Sp.m,
                  Sp.m,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _NowPanel(kid: kid, status: status),
                    // Ohne stattfindende Stunde (alle fallen aus, schulfrei)
                    // keine Leiste: Sie hätte nur rote bzw. keine Abschnitte.
                    if (kid.lessons.any((x) => !x.cancelled)) ...[
                      const SizedBox(height: Sp.m),
                      _DayBar(kid: kid, status: status, now: now),
                    ],
                  ],
                ),
              ),
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
          label: t.homeworkShort(kid.openHomework),
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
          label: t.orderMealShort,
          onTap: onOrderMeal == null ? null : () => onOrderMeal!(kid),
        ),
      if (kid.canReportAbsence)
        _ActionButton(
          icon: Icons.thermostat,
          label: t.reportSick,
          onTap: onReportAbsence == null ? null : () => onReportAbsence!(kid),
        ),
    ];
    if (items.isEmpty) return const [];
    // Eine ruhige Leiste: alle Knöpfe gleich breit in EINER Zeile, Symbol
    // oben, Beschriftung darunter (höchstens zwei Zeilen). Ursache
    // (Rückmeldung 20.10.26: „ruhiger, weniger Umbruch“): Als umbrechende
    // Pillen stand bei großer Schrift fast jeder Knopf in einer eigenen
    // Zeile; nebeneinander mit schrumpfender Schrift wurden lange
    // Beschriftungen ungleich klein. Grenze: höchstens vier Aktionen.
    return [
      const SizedBox(height: Sp.m),
      // Gleich hoch, auch wenn eine Beschriftung zweizeilig ist.
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (j, b) in items.indexed) ...[
              if (j > 0) const SizedBox(width: Sp.s),
              Expanded(child: b),
            ],
          ],
        ),
      ),
    ];
  }
}

/// Überschrift „Hinweise“ bzw. „Stundenplan“ in der Karte; rechts optional
/// ein Verweis („Ganzer Tag ›“).
class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.text, this.link, this.onTap});

  final String text;
  final String? link;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final link = this.link;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(text, style: k.cardSection)),
          if (link != null && onTap != null)
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(Rad.bar),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(link, style: k.link),
                  Icon(Icons.chevron_right, size: Sz.icon, color: k.link.color),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Ein Hinweis als gefüllte Fläche: Titel („Ev. Religion fällt aus“) fett,
/// darunter klein Stunde und Folge bzw. Lehrkraft. Rot für Ausfall, Gelb
/// für Vertretung, Raumwechsel und Essen.
class _HintRow extends StatelessWidget {
  const _HintRow({required this.hint});

  final KidHint hint;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final h = hint;
    final tone = h.cancelled ? k.p.cancel : k.p.change;
    final icon = switch (h.kind) {
      HintKind.cancelled => changeIcon(ChangeKind.cancelled),
      HintKind.substitution => changeIcon(ChangeKind.substitution),
      HintKind.roomChange => changeIcon(ChangeKind.roomChange),
      HintKind.meal => Icons.restaurant,
    };
    final detail = h.detail;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Sp.m,
        vertical: Sp.s + Sp.xxs,
      ),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(Rad.row),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: Sp.xxs),
            child: Icon(icon, size: Sz.hintIcon, color: tone.strong),
          ),
          const SizedBox(width: Sp.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.title, style: k.hintTitle(tone)),
                if (h.when != null || (detail != null && detail.isNotEmpty))
                  Text.rich(
                    TextSpan(
                      children: [
                        if (h.when != null)
                          TextSpan(
                            text: detail == null || detail.isEmpty
                                ? h.when
                                : '${h.when} · ',
                            style: k.hintWhen(tone),
                          ),
                        if (detail != null && detail.isNotEmpty)
                          TextSpan(text: detail, style: k.hintDetail(tone)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// „JETZT · 3./4. STD. · NOCH 30 MIN.“, Fach und Raum in einem Absatz
/// (bricht nur um, wenn es nicht passt). Schlicht ohne eigene Fläche; der
/// Rahmen um den Stundenplan (KidCard) grenzt ab.
class _NowPanel extends StatelessWidget {
  const _NowPanel({required this.kid, required this.status});

  final ChildToday kid;
  final DayStatus status;

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
    String keep(String v) => v.replaceAll(' ', ' ');
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
        // Schulfrei laut Kalender (ChildToday.freeLabel): „Schulfrei ·
        // Herbstferien“ statt nur „Kein Unterricht“.
        label = upperFor(t, t.dayToday);
        title = kid.freeLabel == null ? t.noLessons : t.kindFree;
        meta = kid.freeLabel;
      case DayPhase.untimed:
        final x = l[status.next!];
        label = upperFor(t, t.todayFromSlot(x.slot));
        title = x.subject;
        meta = details(x);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: k.planNowLabel),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: title, style: k.planNowSubject),
              if (meta != null && meta.isNotEmpty)
                TextSpan(text: '   $meta', style: k.planNowMeta),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tagesleiste: ein Abschnitt je (Doppel-)Stunde, Breite nach Dauer;
/// schlicht grau, farbig nur Ausfall (rot) und Vertretung (gelb).
///
/// Die Leiste beginnt bei der ersten und endet bei der letzten Stunde, die
/// stattfindet. Ursache (Bildschirmfoto 21.10.26): Fielen die 1.–2. Stunde
/// aus, stand links „08:00“, obwohl der Tag erst um 09:45 begann. Ausfälle
/// am Rand nennt der Hinweis mit Folge („Beginn erst 09:45“, kid_hints.dart);
/// Ausfälle mitten am Tag bleiben als roter Abschnitt sichtbar.
class _DayBar extends StatelessWidget {
  const _DayBar({required this.kid, required this.status, required this.now});

  final ChildToday kid;
  final DayStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final l = kid.lessons;
    // Aufrufer (KidCard) zeigt die Leiste nur mit stattfindender Stunde.
    final first = l.indexWhere((x) => !x.cancelled);
    final last = l.lastIndexWhere((x) => !x.cancelled);

    Color colorFor(int i) {
      final x = l[i];
      if (x.cancelled) return k.p.cancel.bar;
      if (x.change != null && !lessonDone(x, now)) return k.p.change.bar;
      if (lessonDone(x, now)) return k.p.faint;
      return k.p.barNeutral;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: Sz.dayBar,
          child: Row(
            children: [
              for (var i = first; i <= last; i++) ...[
                if (i > first) const SizedBox(width: Sp.xs),
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
                            child: ColoredBox(color: k.p.muted),
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
            Text(timed ? l[first].start : '', style: k.barLabel),
            Expanded(
              child: Text(
                center,
                style: k.barLabel,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(timed ? t.barUntil(l[last].end) : '', style: k.barLabel),
          ],
        ),
      ],
    );
  }
}

/// Aktion als Pille (Höhe wie die Kinderwahl, Sz.buttonSmall).
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final fg = k.p.ink;
    // Hell mit feinem Rahmen (Rückmeldung 20.10.26: „Felder umrahmen“,
    // „ruhiger“) – Grau auf Weiß hob sich bei Sonnenlicht kaum ab; alle
    // Knöpfe gleich, keiner sticht hervor.
    return Material(
      color: k.p.inset,
      // Rahmen kräftiger (Rückmeldung 20.10.26): die Farbe der Nebenschrift
      // und 1,5 px statt der feinen Trennlinie.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Rad.buttonSmall),
        side: BorderSide(color: k.p.faint, width: 1.5),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rad.buttonSmall),
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.xs,
            vertical: Sp.s,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: Sz.navIcon, color: fg),
              const SizedBox(height: Sp.xs),
              Text(
                label,
                style: k.chipLabel(false, fg),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
