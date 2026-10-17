import 'dart:async';

import 'package:flutter/material.dart';

import 'package:lanis/fork/absence/absence_view.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import '../../l10n/l10n.dart';
import '../live/live_data.dart';
import '../plan/plan_from_lanis.dart' show subjectFullName;
import '../plan/plan_model.dart';
import 'today_from_lanis.dart';
import 'today_model.dart';
import 'today_page.dart';

/// Mensa-Seite im Browser öffnen (Grenze bei mensaLinks).
Future<void> openMensa(BuildContext context, String url) => safeLaunchUrl(
  Uri.parse(url),
  context: context,
  mode: LaunchMode.externalApplication,
);

/// Krankmeldung über der neuen Oberfläche öffnen.
Future<void> openAbsence(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const AbsencePage()));

/// „Heute“ mit echten Daten des angemeldeten Kontos (LiveDataScope).
///
/// Fehlt Vertretungsplan oder Kalender (nicht freigeschaltet, offline,
/// Fehler), zeigt die Seite den Rest – der Stundenplan allein ist schon
/// nützlich. Grenze: ein Kind je Konto; die Familienansicht über mehrere
/// Konten (zweite Schule) folgt, wenn deren Zugang geklärt ist.
class LiveTodayPage extends StatefulWidget {
  const LiveTodayPage({
    super.key,
    this.onOpenCalendar,
    this.onOpenHomework,
    this.onOpenMessages,
  });

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

  @override
  Widget build(BuildContext context) {
    return LiveGate(
      builder: (context, s) {
        final (:plan, :auto) = livePlanOf(s)!;
        final now = DateTime.now();
        final className = liveClassName(s);
        final courses = s.courseNames;
        final events = s.calendar.content ?? const [];
        final mensa = s.mensaUrl;
        final kid = childTodayFromLanis(
          plan: plan,
          choice: effectiveChoice(auto, s.userChoice),
          substitutions: s.substitutions.content?.days ?? const [],
          now: now,
          school: shortSchoolName(s.schoolName),
          t: context.t,
          className: className,
          canReportAbsence: s.offers('abwesenheitsmeldung.php'),
          subjectName: (code) => subjectFullName(code, courses),
          mealHint: mealHintFor(
            events,
            now,
            t: context.t,
            className: className,
          ),
          mensaUrl: mensa,
          openHomework: liveOpenHomework(s),
          unreadMessages: liveUnreadMessages(s),
        );
        return TodayPage(
          data: FamilyToday(
            now: now,
            kids: [kid],
            week: weekItemsFromCalendar(
              events,
              now,
              childIndex: 0,
              className: className,
            ),
          ),
          onReportAbsence: kid.canReportAbsence
              ? (_) => openAbsence(context)
              : null,
          onOrderMeal: mensa == null ? null : (_) => openMensa(context, mensa),
          onOpenCalendar: widget.onOpenCalendar,
          onOpenHomework: widget.onOpenHomework == null
              ? null
              : (_) => widget.onOpenHomework!(),
          onOpenMessages: widget.onOpenMessages == null
              ? null
              : (_) => widget.onOpenMessages!(),
          onRefresh: s.refresh,
        );
      },
    );
  }
}
