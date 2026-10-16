import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/fork/absence/absence_view.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';

import '../kit.dart';
import '../plan/live_plan_page.dart';
import '../plan/plan_from_lanis.dart' show subjectFullName;
import '../plan/plan_model.dart';
import 'today_from_lanis.dart';
import 'today_model.dart';
import 'today_page.dart';

/// „Heute“ mit echten Daten des angemeldeten Kontos.
///
/// Quellen: Stundenplan (mit Gruppenwahl und eigenen Lehrernamen aus
/// „Plan“, gleiche Einstellungen unter `stundenplan.php/…`), Unterricht
/// (Lehrer- und Kursnamen, Klasse), Vertretungsplan und Kalender. Fehlt
/// Vertretungsplan oder Kalender (nicht freigeschaltet, offline, Fehler),
/// zeigt die Seite den Rest – der Stundenplan allein ist schon nützlich.
///
/// Grenze: ein Kind je Konto. Die Familienansicht über mehrere Konten
/// (Schule B) folgt, wenn deren Zugang geklärt ist.
class LiveTodayPage extends ConsumerStatefulWidget {
  const LiveTodayPage({super.key, this.onOpenCalendar});

  final VoidCallback? onOpenCalendar;

  @override
  ConsumerState<LiveTodayPage> createState() => _LiveTodayPageState();
}

class _LiveTodayPageState extends ConsumerState<LiveTodayPage> {
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
    final k = Kit.of(context);
    final session = ref.watch(sessionProvider).asData?.value;
    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final supported = ref.watch(supportedAppletPhpUrlsProvider);
    if (!supported.contains('stundenplan.php')) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Sp.xl),
          child: Text(
            'Die Schule bietet für dieses Konto keinen Stundenplan an.',
            style: k.meta,
          ),
        ),
      );
    }
    final type =
        session.accountTypeOrNull ??
        ref.read(activeAccountProvider)?.accountType ??
        AccountType.student;
    final schoolId = session.account.schoolID.toString();
    final school = shortSchoolName(session.account.schoolName);
    final canReport = supported.contains('abwesenheitsmeldung.php');

    return CombinedAppletBuilder<TimeTable>(
      parser: ref.watch(timetableParserProvider),
      phpUrl: 'stundenplan.php',
      settingsDefaults: const {
        groupChoiceSetting: <String, dynamic>{},
        teacherNamesSetting: <String, dynamic>{},
      },
      accountType: type,
      builder: (context, tt, _, settings, _, _) {
        final userChoice = settingStrings(settings[groupChoiceSetting]);
        final ownNames = settingStrings(settings[teacherNamesSetting]);
        return WithLessons(
          enabled: supported.contains('meinunterricht.php'),
          builder: (lessons, kids) {
            final firstName = kids.isNotEmpty
                ? kids.first.firstName
                : (session.userData['vorname'] ?? 'Kind');
            final (:plan, :auto) = livePlan(
              tt: tt,
              lessons: lessons,
              firstName: firstName,
              schoolId: schoolId,
            );
            final named = plan.withTeacherNames(ownNames);
            final choice = effectiveChoice(auto, userChoice);
            final courseNames = [for (final l in lessons) l.name];
            final className =
                session.userData['klasse'] ?? classFromCourses(courseNames);
            return _Feed<SubstitutionPlan>(
              parser: ref.watch(substitutionsParserProvider),
              enabled: supported.contains('vertretungsplan.php'),
              builder: (subs) => _Feed<List<CalendarEvent>>(
                parser: ref.watch(calendarParserProvider),
                enabled: supported.contains('kalender.php'),
                builder: (events) {
                  final now = DateTime.now();
                  final kid = childTodayFromLanis(
                    plan: named,
                    choice: choice,
                    substitutions: subs?.days ?? const [],
                    now: now,
                    school: school,
                    className: className,
                    canReportAbsence: canReport,
                    subjectName: (code) =>
                        subjectFullName(code, courseNames, schoolId: schoolId),
                  );
                  return TodayPage(
                    data: FamilyToday(
                      now: now,
                      kids: [kid],
                      week: weekItemsFromCalendar(
                        events ?? const [],
                        now,
                        childIndex: 0,
                        className: className,
                      ),
                    ),
                    onReportAbsence: canReport
                        ? (_) => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AbsencePage(),
                            ),
                          )
                        : null,
                    onOpenCalendar: widget.onOpenCalendar,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// Lädt eine Zusatzquelle und baut [builder] sofort – mit `null`, solange
/// nichts da ist oder die Quelle fehlt. Der letzte gute Stand bleibt beim
/// Neuladen stehen. Ursache: Ein Fehler im Vertretungsplan darf „Heute“
/// nicht leeren (CombinedAppletBuilder hätte eine Fehlerseite gezeigt).
class _Feed<T> extends StatefulWidget {
  const _Feed({
    required this.parser,
    required this.enabled,
    required this.builder,
  });

  final AppletParser<T> parser;
  final bool enabled;
  final Widget Function(T? content) builder;

  @override
  State<_Feed<T>> createState() => _FeedState<T>();
}

class _FeedState<T> extends State<_Feed<T>> {
  T? _last;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.parser.fetchData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.builder(null);
    return StreamBuilder<FetcherResponse<T>>(
      stream: widget.parser.stream,
      initialData: widget.parser.latestResponse,
      builder: (context, snap) {
        final c = snap.data?.content;
        if (c != null) _last = c;
        return widget.builder(_last);
      },
    );
  }
}
