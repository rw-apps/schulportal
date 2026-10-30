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

/// Zeitpunkt eines Datenstands: heute „09:27“, gestern „gestern 21:40“,
/// sonst „Di 20.10. 21:40“. Ursache (21.10.26): Seit bei einem Ausfall der
/// gespeicherte Stand erscheint, kann „Stand“ vom Vortag sein – die bloße
/// Uhrzeit hätte ihn wie heute aussehen lassen.
String standLabel(ForkL10n t, DateTime at, DateTime now) {
  final hm =
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
  final diff = dayDiff(at, now);
  if (diff == 0) return hm;
  if (diff == 1) return '${lowerFor(t, t.dayYesterday)} $hm';
  return '${formatDate(t, t.dateShort, at)} $hm';
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
/// Tablet (Entwurf A, abgenommen 30.10.26): ab [Sz.wideLayout] Breite
/// stehen ab zwei Kindern je zwei Karten nebeneinander, „Demnächst“
/// darunter in voller Breite; ab [Sz.wideLandscape] (quer) rechts daneben,
/// bei zwei Kindern also drei Spalten. Ein Kind: Karte links, Termine
/// rechts. Ursache (Bildschirmfoto Tablet 30.10.26): Kinder untereinander in
/// einer schmalen Spalte – das zweite Kind war abgeschnitten, „Demnächst“
/// brach Titel mitten im Wort um und ließ darunter viel Fläche frei.
class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.data,
    this.onReportAbsence,
    this.onOpenHomework,
    this.onOpenExams,
    this.onOpenMessages,
    this.onOpenCalendar,
    this.onOpenDay,
    this.onOrderMeal,
    this.onRefresh,
    this.notices = const [],
    this.title,
  });

  /// Seitentitel statt des Datums (Entwurf 26.10.26, Variante B).
  final String? title;

  /// Hinweise oben (z. B. Konto nicht angemeldet, login_failure_card.dart).
  final List<Widget> notices;

  final FamilyToday data;
  final void Function(ChildToday child)? onReportAbsence;
  final void Function(ChildToday child)? onOpenHomework;

  /// „Arbeiten & Noten“ des Kindes (Arbeits-Hinweis, Rückmeldung 30.10.26).
  final void Function(ChildToday child)? onOpenExams;
  final void Function(ChildToday child)? onOpenMessages;
  final VoidCallback? onOpenCalendar;

  /// Tagesleiste angetippt: den Tag des Kindes im Kalender öffnen (ersetzt
  /// „Ganzen Tag zeigen“ an der Karte).
  /// Tag eines Kindes im Kalender öffnen: heute bzw. – nach Schulschluss –
  /// den nächsten Schultag, den die Karte gerade zeigt.
  final void Function(ChildToday child, DateTime day)? onOpenDay;
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
              title ?? formatDate(t, t.dateLong, data.now),
              style: k.pageTitle,
              maxLines: 1,
            ),
          ),
        ),
        if (updated != null) ...[
          const SizedBox(width: Sp.s),
          Text(t.asOf(standLabel(t, updated, data.now)), style: k.meta),
        ],
      ],
    );

    final width = MediaQuery.sizeOf(context).width;
    final cards = <Widget>[
      for (final (i, kid) in data.kids.indexed)
        KidCard(
          kid: kid,
          now: data.now,
          onReportAbsence: onReportAbsence,
          onOpenHomework: onOpenHomework,
          onOpenExams: onOpenExams,
          onOpenMessages: onOpenMessages,
          onOrderMeal: onOrderMeal,
          onOpenDay: onOpenDay,
          nextDay: i < data.next.length ? data.next[i] : null,
          nextDate: data.nextDate,
          exams: examsFor(data.week, i, data.kids.length),
        ),
    ];
    final kids = <Widget>[
      for (final (i, c) in cards.indexed) ...[
        if (i > 0) const SizedBox(height: Sp.m),
        c,
      ],
    ];
    // Je zwei Karten nebeneinander (Tablet, ab zwei Kindern); eine dritte
    // steht links in der nächsten Reihe. Oben bündig statt gleich hoch:
    // IntrinsicHeight verträgt die LayoutBuilder in den Karten nicht.
    final pairs = <Widget>[
      for (var i = 0; i < cards.length; i += 2) ...[
        if (i > 0) const SizedBox(height: Sp.l),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[i]),
            const SizedBox(width: Sp.l),
            Expanded(
              child: i + 1 < cards.length
                  ? cards[i + 1]
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    ];
    final paired = wide && cards.length > 1;
    final side = !paired || width >= Sz.wideLandscape;
    final upcoming =
        upcomingWithoutHints(data.week, data.now, data.kids.length).isEmpty
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
        if (wide && side)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                // Zwei Kinder nebeneinander + Termine: drei gleiche Spalten.
                flex: paired ? 20 : 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: paired ? pairs : kids,
                ),
              ),
              const SizedBox(width: Sp.l),
              Expanded(flex: 10, child: upcoming ?? const SizedBox.shrink()),
            ],
          )
        else if (wide) ...[
          ...pairs,
          if (upcoming != null) ...[const SizedBox(height: Sp.l), upcoming],
        ] else ...[
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
/// nur am Bild bzw. Anfangsbuchstaben. Seit 30.10.26 (Entwurf B) stehen
/// die Hinweise als einzeilige Zeilen je Tag gruppiert (_HintGroup); die
/// Signalfarbe trägt das Feld ums Symbol und das Art-Wort.
class KidCard extends StatelessWidget {
  const KidCard({
    super.key,
    required this.kid,
    required this.now,
    this.onReportAbsence,
    this.onOpenHomework,
    this.onOpenExams,
    this.onOpenMessages,
    this.onOrderMeal,
    this.onOpenDay,
    this.nextDay,
    this.nextDate,
    this.exams = const [],
  });

  /// Arbeiten dieses Kindes (FamilyToday.week); heute und am nächsten
  /// Schultag erscheinen sie als Hinweis (Vorschlag 5, Entwurf 26.10.26).
  final List<WeekItem> exams;

  final ChildToday kid;
  final DateTime now;

  /// Plan des nächsten Schultags; nach Schulschluss steht er im Abschnitt
  /// „Stundenplan“ statt „Unterricht vorbei“ (Vorschlag 4, Entwurf
  /// 26.10.26) – mit blauem Band „Morgen“ bzw. „Nächster Schultag“ und
  /// Datum (_NextDayBand).
  final ChildToday? nextDay;
  final DateTime? nextDate;
  final void Function(ChildToday child)? onReportAbsence;
  final void Function(ChildToday child)? onOpenHomework;

  /// „Arbeiten & Noten“ des Kindes (Arbeits-Hinweis, Rückmeldung 30.10.26).
  final void Function(ChildToday child)? onOpenExams;
  final void Function(ChildToday child)? onOpenMessages;
  final void Function(ChildToday child)? onOrderMeal;

  /// Tag eines Kindes im Kalender öffnen: heute bzw. – nach Schulschluss –
  /// den nächsten Schultag, den die Karte gerade zeigt.
  final void Function(ChildToday child, DateTime day)? onOpenDay;

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
    final hints = kidHints(kid, now, t, exams: exams);
    // Nach Schulschluss bzw. an freien Tagen: nächster Schultag.
    final next = nextDay;
    final showNext =
        next != null &&
        nextDate != null &&
        next.lessons.any((x) => !x.cancelled) &&
        (status.phase == DayPhase.over || status.phase == DayPhase.noLessons);
    final planKid = showNext ? next : kid;
    // Uhrzeit vor Schulbeginn: Leiste ohne „erledigt“, oben die erste Stunde.
    final planNow = showNext ? DateTime(now.year, now.month, now.day) : now;
    final planStatus = showNext ? dayStatus(next.lessons, planNow) : status;
    final doneAt = status.phase == DayPhase.over
        ? kid.lessons.lastWhere((x) => !x.cancelled).end
        : null;
    // Nach Schulschluss steht der nächste Schultag als Kopf über Hinweisen
    // und Plan (_NextDayHead). Heutige Hinweise (Essen, Arbeit heute) sind
    // dann erledigt und entfallen; es bleibt eine Gruppe mit diesem Tag
    // (groupHints), deren Kopf dem Kartenkopf nicht widerspricht.
    final shownDay = showNext ? nextDate! : now;
    final openDay = onOpenDay == null ? null : () => onOpenDay!(kid, shownDay);
    final shown = !showNext
        ? hints
        : [
            for (final h in hints)
              // Guthaben (ohne Tag) gilt unabhängig vom Tag und bleibt.
              if (h.day == null || dayDiff(now, h.day!) > 0) h,
          ];
    // Antippen einer Zeile: der Tag im Kalender (wie „Ganzer Tag“), dort
    // stehen Lehrkraft und Zeiten, die die Zeile weglässt; Guthaben und
    // „nicht bestellt“ öffnen die Essensbestellung.
    // Arbeit: „Arbeiten & Noten“ des Kindes statt des Tages (Rückmeldung
    // 30.10.26); ohne diesen Weg wie bisher der Tag.
    VoidCallback? tapHint(KidHint h, DateTime day) => h.toMeal
        ? (onOrderMeal == null ? null : () => onOrderMeal!(kid))
        : h.kind == HintKind.exam && onOpenExams != null
        ? () => onOpenExams!(kid)
        : (onOpenDay == null ? null : () => onOpenDay!(kid, day));

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
          if (showNext) ...[
            const SizedBox(height: Sp.m),
            _NextDayHead(
              day: nextDate!,
              now: now,
              doneAt: doneAt,
              freeLabel: kid.freeLabel,
            ),
          ],
          if (shown.isNotEmpty) ...[
            const SizedBox(height: Sp.l),
            _SectionHead(text: t.hintsTitle),
            for (final (i, g) in groupHints(shown, shownDay).indexed) ...[
              if (i > 0) const SizedBox(height: Sp.s),
              _HintGroup(
                caption: hintDayCaption(t, g.day, now),
                block: kid.lessons.any((l) => l.slot.contains('Block')),
                hints: g.hints,
                onTap: (h) => tapHint(h, g.day),
              ),
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
                    _NowPanel(kid: planKid, status: planStatus),
                    // Ohne stattfindende Stunde (alle fallen aus, schulfrei)
                    // keine Leiste: Sie hätte nur rote bzw. keine Abschnitte.
                    if (planKid.lessons.any((x) => !x.cancelled)) ...[
                      const SizedBox(height: Sp.m),
                      _DayBar(kid: planKid, status: planStatus, now: planNow),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (planKid.lunch case final dish?) ...[
            const SizedBox(height: Sp.s),
            InkWell(
              onTap: onOrderMeal == null ? null : () => onOrderMeal!(kid),
              borderRadius: BorderRadius.circular(Rad.bar),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Sp.xs),
                child: Row(
                  children: [
                    Icon(Icons.restaurant, size: Sz.icon, color: k.p.muted),
                    const SizedBox(width: Sp.s),
                    Expanded(child: Text(t.mealLunch(dish), style: k.meta)),
                  ],
                ),
              ),
            ),
          ],
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
    //
    // Vier Aktionen (Entwurf 27.10.26): In einer Zeile brachen „3 Aufgaben“
    // und „1 Nachricht“ mitten im Wort um („Aufga|ben“). Ab vier deshalb
    // zwei Zeilen zu je zwei Knöpfen; bis drei bleibt es eine Zeile.
    Widget row(List<Widget> bs) => IntrinsicHeight(
      // Gleich hoch, auch wenn eine Beschriftung zweizeilig ist.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (j, b) in bs.indexed) ...[
            if (j > 0) const SizedBox(width: Sp.s),
            Expanded(child: b),
          ],
        ],
      ),
    );
    if (items.length <= 3) return [const SizedBox(height: Sp.m), row(items)];
    return [
      const SizedBox(height: Sp.m),
      row(items.sublist(0, 2)),
      const SizedBox(height: Sp.s),
      row(items.sublist(2)),
    ];
  }
}

/// Kopf der Karte nach Schulschluss: kurz „HEUTE · Unterricht vorbei“,
/// Trennlinie, dann als Überschrift „MORGEN · Dienstag, 27. Oktober“ bzw.
/// „NÄCHSTER SCHULTAG · Montag, 2. November“. Hinweise und Plan darunter
/// gelten diesem Tag (eine Hinweisgruppe mit seinem Datum, KidCard.shown).
///
/// Ursache (Abnahme 26.10.26, drei Runden): „Stundenplan · Morgen“ war zu
/// leise, ein Band im Planrahmen galt nicht für die Hinweise, ein blaues
/// Band über beiden wirkte wie ein Hinweis und verschwieg, dass heute schon
/// Schluss ist. Jetzt trennen Linie und gleich gebaute Marken
/// („HEUTE“/„MORGEN“, dateCaps) die beiden Tage; der nächste Tag steht in
/// Abschnittsgröße (k.section) über „Hinweise“ und „Stundenplan“.
class _NextDayHead extends StatelessWidget {
  const _NextDayHead({
    required this.day,
    required this.now,
    this.doneAt,
    this.freeLabel,
  });

  final DateTime day;
  final DateTime now;

  /// Ende der letzten Stunde heute; null = heute kein Unterricht.
  final String? doneAt;
  final String? freeLabel;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final done = doneAt;
    final tomorrow = dayDiff(now, day) == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(upperFor(t, t.dayToday), style: k.dateCaps),
        const SizedBox(height: Sp.xs),
        Row(
          children: [
            Icon(Icons.check_circle_outline, color: k.p.muted, size: Sz.icon),
            const SizedBox(width: Sp.s),
            Expanded(
              child: Text(
                done == null
                    ? (freeLabel ?? t.noLessons)
                    : t.schoolOverSince(done),
                style: k.meta,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Sp.l),
          child: Container(height: Sz.frame, color: k.p.line),
        ),
        Text(
          upperFor(t, tomorrow ? t.dayTomorrow : t.nextSchoolDayLabel),
          style: k.dateCaps,
        ),
        const SizedBox(height: Sp.xxs),
        Text(formatDate(t, t.dateLong, day), style: k.section),
      ],
    );
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

/// Hinweise eines Tages (Abnahme 30.10.26, Entwurf B „Zeilen nach Tag“):
/// graue Fläche mit Kopf („HEUTE“, „MONTAG, 2. NOV.“) und Anzahl, darin
/// eine weiße Liste mit je einer Zeile ([_HintLine]) und feinen Linien.
///
/// Ursache (Rückmeldung 30.10.26): Je Hinweis eine eigene, zweizeilige
/// Signalfläche – bei sieben Hinweisen rutschte der Stundenplan unter den
/// ersten Bildschirm. Grenze: Die Signalfarbe trägt jetzt nur noch das Feld
/// um das Symbol und das Art-Wort; die Zeile selbst ist weiß.
///
/// Rechts im Kopf „STUNDE“ (bzw. „BLOCK“) über den Marken, sobald eine
/// Zeile eine Stundennummer trägt; die frühere Anzahl entfällt. Ursache
/// (Rückmeldung 30.10.26): Eine Marke „3.“ las sich wie eine Note, die
/// Anzahl „1“ neben „HEUTE“ war unverständlich. Im Kopf statt in jeder
/// Marke („3. Std.“), damit die Marken schmal bleiben und lange Fächer
/// nicht umbrechen. Grenze: Marken mit Uhrzeit (Arbeit „09:50“) erklären
/// sich selbst; ohne Stundennummer bleibt der Kopf rechts leer.
class _HintGroup extends StatelessWidget {
  const _HintGroup({
    required this.caption,
    required this.hints,
    required this.onTap,
    this.block = false,
  });

  /// Schule zählt in Blöcken (Stundenplan „3. Block“).
  final bool block;

  final String caption;
  final List<KidHint> hints;
  final VoidCallback? Function(KidHint h) onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final numbered = hints.any((h) => RegExp(r'^\d+\.').hasMatch(h.slot ?? ''));
    final right = numbered
        ? upperFor(t, block ? t.hintUnitBlock : t.hintUnitLesson)
        : null;
    return Container(
      padding: const EdgeInsets.all(Sp.s),
      decoration: BoxDecoration(
        color: k.p.inset,
        borderRadius: BorderRadius.circular(Rad.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.xxs, Sp.xs, Sp.s),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    caption,
                    style: k.dateCaps,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (right != null) ...[
                  const SizedBox(width: Sp.s),
                  Text(right, style: k.dateCaps),
                ],
              ],
            ),
          ),
          Material(
            color: k.p.card,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(Rad.hintList),
            child: Column(
              children: [
                for (final (i, h) in hints.indexed) ...[
                  if (i > 0)
                    Divider(
                      height: Sz.frame,
                      thickness: Sz.frame,
                      // Linie erst ab dem Text, nicht unter dem Symbol.
                      indent: Sp.s + Sz.hintBadge + Sp.m,
                      color: k.p.line,
                    ),
                  _HintLine(hint: h, onTap: onTap(h)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ein Hinweis als EINE Zeile: Lagebild im Feld der Signalfläche (Rot =
/// Ausfall, Gelb = Vertretung/Raum/Essen/Guthaben, Grau = Arbeit), Fach fett,
/// Art in der kräftigen Signalfarbe, rechts die Stunde als Marke.
///
/// Was nicht mehr in die Zeile passt (Lehrkraft, „Schluss 11:20“, „Beginn
/// erst …“), steht in [KidHint.detail]: für den Bildschirmleser im
/// Semantics-Text und nach dem Antippen im Kalendertag. Grenze: Ohne
/// [onTap] (Beispielseite ohne Rückruf) sieht man es nur im Kalender.
class _HintLine extends StatelessWidget {
  const _HintLine({required this.hint, this.onTap});

  final KidHint hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final h = hint;
    // Arbeit: grau wie die übrigen Hinweise ohne Planänderung (Farbregel:
    // Rot = Ausfall, Gelb = Vertretung/Raum/Essen).
    final tone = h.cancelled
        ? k.p.cancel
        : h.kind == HintKind.exam
        ? k.p.todo
        : k.p.change;
    final icon = switch (h.kind) {
      HintKind.cancelled => changeIcon(ChangeKind.cancelled),
      HintKind.substitution => changeIcon(ChangeKind.substitution),
      HintKind.roomChange => changeIcon(ChangeKind.roomChange),
      HintKind.unclear => changeIcon(ChangeKind.unclear),
      HintKind.meal => Icons.restaurant,
      HintKind.exam => weekIcon(WeekKind.exam),
      HintKind.balance => Icons.account_balance_wallet_outlined,
    };
    final slot = h.slot;
    final detail = h.detail;
    return Semantics(
      button: onTap != null,
      excludeSemantics: true,
      label: [
        ?h.when,
        h.title,
        if (detail != null && detail.isNotEmpty)
          detail.replaceAll('\u00A0', ' '),
      ].join(', '),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Sp.s),
          child: Row(
            children: [
              Container(
                width: Sz.hintBadge,
                height: Sz.hintBadge,
                decoration: BoxDecoration(
                  color: tone.bg,
                  borderRadius: BorderRadius.circular(Rad.badge),
                ),
                child: Icon(icon, size: Sz.hintBadgeIcon, color: tone.strong),
              ),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: h.what.isEmpty ? h.subject : '${h.subject}  ',
                        style: k.hintSubject,
                      ),
                      if (h.what.isNotEmpty)
                        TextSpan(text: h.what, style: k.hintKind(tone)),
                    ],
                  ),
                  // Zwei Zeilen statt „Naturwissenschaften Lernkon…“
                  // (Bildschirmfoto 30.10.26); die Art muss lesbar bleiben.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (slot != null && slot.isNotEmpty) ...[
                const SizedBox(width: Sp.s),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Sp.s,
                    vertical: Sp.xxs + 1,
                  ),
                  decoration: BoxDecoration(
                    color: k.p.inset,
                    borderRadius: BorderRadius.circular(Rad.pill),
                  ),
                  child: Text(slot, style: k.hintSlot, maxLines: 1),
                ),
              ],
            ],
          ),
        ),
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
    final items = upcomingWithoutHints(data.week, data.now, data.kids.length)
      ..sort((a, b) => a.day.compareTo(b.day));
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
