import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart'
    show AccountType, sharedOverAccountSettingsProvider;

import 'package:lanis/fork/absence/absence_view.dart';

import '../../l10n/l10n.dart';
import '../live/family.dart';
import '../live/live_data.dart';
import '../live/stale_notice.dart';
import '../plan/plan_from_lanis.dart' show subjectFullName;
import '../plan/plan_model.dart';
import 'today_from_lanis.dart';
import 'today_model.dart';
import '../settings/class_sheet.dart';
import 'class_prompt_card.dart';
import 'auto_report_prompt.dart';
import '../../demo/demo_entry.dart';
import 'hint_card.dart';
import '../portal_link.dart';
import 'login_failure_card.dart';
import '../../mensa_store.dart';
import '../../demo/demo_mode.dart' show demoActive;
import '../../notify/summary.dart';
import '../mensa/meal_refresh.dart';
import '../courses/homework_due.dart' show liveOpenHomework;
import '../mensa/meal_week_page.dart';
import 'kid_hints.dart' show nextSchoolDay;
import 'today_page.dart';
import '../nav.dart';

/// Essen des Kindes in der App öffnen. Ohne Adresse
/// geschieht nichts – die Oberfläche bietet dann „eintragen“ an.
///
/// Öffnet immer die eigene Ansicht „Essen“ (MealWeekPage). Bis 9420 ging
/// es bei MealEntry.unreadable gleich zur Seite des Caterers; dann war der
/// Abrufverlauf (MealTrace, „Details zum Abruf“) nicht erreichbar und ein
/// einmal gescheiterter Abruf wurde nie wieder versucht (Bildschirmfoto
/// 27.10.26). Grenze: Für einen unbekannten Caterer ein Tipp mehr
/// („Bestellen oder ändern“).
Future<void> openMensa(
  BuildContext context,
  LiveSnapshot s,
  String kid, {
  String? name,
  int colorIndex = 0,
}) async {
  final url = s.mensa.of(kid);
  if (url == null) return;
  final owner = s.mensaOwner(kid);
  await pushFullScreen<void>(
    context,
    (_) => MealWeekPage(
      url: url,
      owner: owner,
      childName: name,
      colorIndex: colorIndex,
    ),
  );
}

/// Erster Tag, an den jetzt erinnert wird (mealReminderDays, mit den
/// eingeschalteten Wochentagen); null sonst oder wenn das Kind nie bestellt.
DateTime? mealUnorderedDay(
  MealEntry? e,
  DateTime now, {
  Set<int> weekdays = const {1, 2, 3, 4, 5},
}) {
  final days = mealReminderDays(e, now, weekdays: weekdays);
  return days.isEmpty ? null : days.first;
}

/// Krankmeldung über der neuen Oberfläche öffnen.
Future<void> openAbsence(BuildContext context) =>
    pushFullScreen<void>(context, (_) => const AbsencePage());

/// „Heute“ mit echten Daten des angemeldeten Kontos (LiveDataScope).
///
/// Fehlt Vertretungsplan oder Kalender (nicht freigeschaltet, offline,
/// Fehler), zeigt die Seite den Rest – der Stundenplan allein ist schon
/// nützlich. Mehrere Konten (zweite Schule): eine Karte je Konto
/// ([FamilyData]). Grenze: Im Elternkonto erscheint wie bisher nur das Kind,
/// dessen Stundenplan das Portal liefert.
class LiveTodayPage extends StatefulWidget {
  const LiveTodayPage({
    super.key,
    this.onOpenCalendar,
    this.onOpenHomework,
    this.onOpenMessages,
    this.onOpenDay,
    this.onlyAccount,
  });

  /// Nur dieses Konto zeigen (Kind oben gewählt, FamilySwitch); null =
  /// alle Kinder. Ursache (Rückmeldung 20.10.26): Heute hatte als einziger
  /// Reiter keine Auswahl „Alle | Kind“.
  final int? onlyAccount;

  /// Kalender in der Ansicht „Tag“ für diesen Tag (Tagesleiste angetippt;
  /// nach Schulschluss der nächste Schultag); das Kind ist dann schon
  /// gewählt (FamilyData.onSelect).
  final ValueChanged<DateTime>? onOpenDay;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenHomework;
  final VoidCallback? onOpenMessages;

  @override
  State<LiveTodayPage> createState() => _LiveTodayPageState();
}

class _LiveTodayPageState extends State<LiveTodayPage> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // „Jetzt“ und Restminuten werden aus der Uhrzeit berechnet
    // (today_model.dayStatus); ohne Takt stünde „noch 30 Min.“ still.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Karte eines Kontos; null, solange dessen Stundenplan fehlt.
  ///
  /// [day] statt heute: Karte für den nächsten Schultag (nextSchoolDay),
  /// die die Kinderkarte nach Schulschluss zeigt (Abnahme 26.10.26). Grenze:
  /// Ferien kennt nextSchoolDay nicht; ist der Tag laut Kalender frei,
  /// trägt die Karte freeLabel und KidCard bleibt bei „Unterricht vorbei“.
  ChildToday? _kidOf(FamilyMember m, DateTime now, {DateTime? day}) {
    final at = day ?? now;
    final s = m.snapshot;
    if (!s.offers('stundenplan.php')) return null;
    final live = livePlanOf(
      s,
      fallbackName: context.t.yourChild,
      colorIndex: m.colorIndex,
    );
    if (live == null) return null;
    final className = liveClassName(s);
    final meals = s.mensaUrl == null
        ? null
        : MealCache.instance.of(s.mensaOwner(s.mensaKid));
    final courses = s.courseNames;
    final events = s.calendar.content ?? const [];
    return childTodayFromLanis(
      plan: live.plan,
      choice: effectiveChoice(live.auto, s.userChoice),
      // Dieselbe Quelle wie der Kalender, ab heute (Prüfung 27.10.26).
      substitutions: s.substitutionDaysFromToday(now),
      now: at,
      school: shortSchoolName(s.schoolName),
      t: context.t,
      className: className,
      canReportAbsence: s.offers('abwesenheitsmeldung.php'),
      subjectName: (code) => subjectFullName(code, courses),
      mealHint: mealHintFor(events, at, t: context.t, className: className),
      mensaUrl: s.mensaUrl,
      openHomework: liveOpenHomework(s),
      unreadMessages: liveUnreadMessages(s),
      photo: s.photo,
      free: s.offers('kalender.php')
          ? freeDaysFrom(events, at, className: className, days: freeDaysAhead)
          : const {},
      lunch: meals?.dayOf(at)?.ordered?.name,
      mealUnordered: day == null
          ? mealUnorderedDay(
              meals,
              now,
              weekdays: mealRemindDays(
                MealCache.instance.settings,
                s.mensaOwner(s.mensaKid),
              ),
            )
          : null,
      lowBalance: day == null ? lowMealBalance(meals) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Neu gelesene Essenswochen (MealCache) erneuern die Karten.
    return ValueListenableBuilder(
      valueListenable: MealCache.instance.notifier,
      builder: (context, _, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    return LiveGate(
      builder: (context, active) {
        final now = DateTime.now();
        // Familienansicht (family.dart): eine Karte je Konto mit Plan. Ohne
        // FamilyScope (Tests) nur das aktive Konto.
        final family = FamilyData.of(context);
        final members = family.isEmpty
            ? [FamilyMember(accountId: -1, snapshot: active, colorIndex: 0)]
            : [
                for (final m in family)
                  if (widget.onlyAccount == null ||
                      m.accountId == widget.onlyAccount)
                    m,
              ];
        final shown = <(FamilyMember, ChildToday)>[
          for (final m in members)
            if (_kidOf(m, now) case final kid?) (m, kid),
        ];
        final kids = [for (final x in shown) x.$2];
        final nextDay = nextSchoolDay(now);
        FamilyMember memberOf(ChildToday c) =>
            shown[kids.indexOf(c).clamp(0, shown.length - 1)].$1;
        // Nach Tag zusammenführen; innerhalb eines Tages bleibt die
        // Reihenfolge je Konto (Uhrzeit) erhalten – Dart sortiert nicht
        // stabil, daher die Position als zweiter Schlüssel.
        final merged =
            [
              for (final (i, (m, _)) in shown.indexed)
                ...withCourseExams(
                  weekItemsFromCalendar(
                    m.snapshot.calendar.content ?? const [],
                    now,
                    childIndex: i,
                    className: liveClassName(m.snapshot),
                    skipHolidays: true,
                  ),
                  m.snapshot.courseScan,
                  now,
                  childIndex: i,
                ),
            ].indexed.toList()..sort((a, b) {
              final d = a.$2.day.compareTo(b.$2.day);
              return d != 0 ? d : a.$1.compareTo(b.$1);
            });
        final week = [for (final x in merged) x.$2];
        // Ältester Stand der angezeigten Pläne – ehrlicher als der neueste.
        DateTime? updated;
        for (final (m, _) in shown) {
          for (final at in [
            m.snapshot.timetable.fetchedAt,
            m.snapshot.substitutions.fetchedAt,
          ]) {
            if (at != null && (updated == null || at.isBefore(updated))) {
              updated = at;
            }
          }
        }
        // Vor dem Wechsel in einen anderen Reiter das Kind der Karte wählen
        // (gemeinsame Kindwahl), damit dort gleich das richtige Kind steht.
        void select(ChildToday c) =>
            FamilyData.scopeOf(context)?.onSelect?.call(memberOf(c).accountId);
        final scope = FamilyData.scopeOf(context);
        // Alter Stand (stale_notice.dart): Hinweis oben.
        final stale = staleNotice(
          context,
          feeds: [
            for (final (m, _) in shown) ...[
              m.snapshot.timetable,
              m.snapshot.substitutions,
            ],
          ],
          now: now,
          onRetry: () {
            for (final (m, _) in shown) {
              m.snapshot.refresh();
            }
          },
        );
        final page = TodayPage(
          notices: [
            ?demoNotice(context),
            ?stale,
            // Zustimmung zum automatischen Melden (auto_report_prompt.dart).
            if (autoReportPromptDue(
              ProviderScope.containerOf(
                context,
              ).read(sharedOverAccountSettingsProvider),
            ))
              const AutoReportPrompt(),
            for (final f in scope?.failures ?? const <FamilyFailure>[])
              LoginFailureCard(
                failure: f,
                onRetry: scope?.onRetry == null
                    ? null
                    : () => scope!.onRetry!(f.account.localId),
              ),
            for (final (m, kid) in shown)
              if (m.snapshot.classExpired &&
                  m.snapshot.classChoice == null &&
                  detectedClassName(m.snapshot).isEmpty)
                ClassPromptCard(
                  kidName: kid.firstName,
                  onEnter: m.snapshot.setClass == null
                      ? null
                      : () async {
                          final r = await showClassSheet(
                            context,
                            kidName: kid.firstName,
                            school: shortSchoolName(m.snapshot.schoolName),
                            colorIndex: m.colorIndex,
                            hasEntry: true,
                          );
                          if (r != null) m.snapshot.setClass!(r.name);
                        },
                ),
            // Offene Wahl im Wahltool (portal_extras.dart, Wunsch 20.10.26).
            for (final (m, kid) in shown)
              if (m.snapshot.electionOpen)
                HintCard(
                  icon: Icons.how_to_vote_outlined,
                  title: kid.firstName.isEmpty
                      ? context.t.electionTitlePlain
                      : context.t.electionTitle(kid.firstName),
                  text: context.t.electionText,
                  action: context.t.electionAction,
                  onAction: () => openPortalFor(context, m.snapshot.session),
                ),
          ],
          data: FamilyToday(
            now: now,
            kids: kids,
            week: week,
            updatedAt: updated,
            next: [for (final (m, _) in shown) _kidOf(m, now, day: nextDay)],
            nextDate: nextDay,
          ),
          onOpenDay: widget.onOpenDay == null
              ? null
              : (c, day) {
                  select(c);
                  widget.onOpenDay!(day);
                },
          onReportAbsence: kids.any((k) => k.canReportAbsence)
              ? (c) {
                  final m = memberOf(c);
                  pushFullScreen<void>(
                    context,
                    (_) => m.scope(const AbsencePage()),
                  );
                }
              : null,
          onOrderMeal: kids.any((k) => k.mensaUrl != null)
              ? (c) {
                  final s = memberOf(c).snapshot;
                  openMensa(
                    context,
                    s,
                    s.mensaKid,
                    name: kids.length > 1 || s.kids.length > 1
                        ? c.firstName
                        : null,
                    colorIndex: c.colorIndex,
                  );
                }
              : null,
          onOpenCalendar: widget.onOpenCalendar,
          onOpenHomework: widget.onOpenHomework == null
              ? null
              : (c) {
                  select(c);
                  widget.onOpenHomework!();
                },
          onOpenMessages: widget.onOpenMessages == null
              ? null
              : (c) {
                  select(c);
                  widget.onOpenMessages!();
                },
          onRefresh: () async {
            await Future.wait([for (final m in members) m.snapshot.refresh()]);
          },
        );
        // Sammel-Benachrichtigung mit dem Stand der offenen App abgleichen
        // (summary.dart). Nur Geladenes (Prüfung 27.10.26: sonst leerte ein
        // App-Start die Zeilen, und der nächste Hintergrundlauf meldete sie
        // mit Ton als neu). Name nach summaryName (mehrere Konten oder
        // Elternkonto) – dieselbe Regel wie im Hintergrund.
        final shared = MealCache.instance.settings;
        if (shared != null && !demoActive) {
          final t = context.t;
          final next = nextSchoolDay(now);
          final sources = <String, List<SummaryItem>>{};
          for (final (m, kid) in shown) {
            if (m.accountId < 0) continue;
            final s = m.snapshot;
            final name = summaryName(
              kid.firstName,
              multiAccount: family.length > 1,
              parent: s.session.accountTypeOrNull == AccountType.parent,
            );
            if (s.substitutions.content != null) {
              sources['${m.accountId}/plan'] = changeSummaryItems(
                scope: '${m.accountId}',
                name: name,
                changes: kid.changes,
                now: now,
                next: next,
                t: t,
                endOf: {
                  for (final l in kid.lessons)
                    l.slot: hasTime(l) ? minutesOf(l.end).minutes : 24 * 60,
                },
              );
            }
            if (s.mensaUrl != null) {
              final owner = s.mensaOwner(s.mensaKid);
              sources['${m.accountId}/meals'] = mealSummaryItems(
                name: name,
                owner: owner,
                days: mealReminderDays(
                  MealCache.instance.of(owner),
                  now,
                  weekdays: mealRemindDays(shared, owner),
                ),
                t: t,
              );
            }
            if (s.conversations.content != null && liveUnreadMessages(s) == 0) {
              sources['${m.accountId}/messages'] = const [];
            }
          }
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => syncSummaryFromApp(shared, t, sources),
          );
        }
        // Essen im Hintergrund lesen (meal_refresh.dart).
        return MealRefresh(
          targets: [
            for (final (m, _) in shown)
              if (m.snapshot.mensaUrl case final url?)
                (owner: m.snapshot.mensaOwner(m.snapshot.mensaKid), url: url),
          ],
          now: now,
          child: page,
        );
      },
    );
  }
}
