import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/widgets/combined_applet_builder.dart';

import '../../lessons_parent.dart';
import '../kit.dart';
import 'plan_from_lanis.dart';
import 'plan_model.dart';
import 'plan_page.dart';

/// Schlüssel der Gruppenwahl in den Einstellungen des Kontos (unter
/// `stundenplan.php/…`, getrennt von den Lanis-Schlüsseln wie
/// `hidden-lessons`).
const groupChoiceSetting = 'fork-group-choice';

/// Von Hand eingetragene Lehrernamen (Kürzel → Name), ebenfalls je Konto.
/// Bewusst nur auf dem Gerät: Echte Namen gehören nicht ins öffentliche
/// Repository (Entscheidung 16.10.26).
const teacherNamesSetting = 'fork-teacher-names';

/// „Plan“ mit echten Daten des angemeldeten Kontos.
///
/// Stundenplan über timetableParserProvider (wie die Lanis-Ansicht, mit deren
/// Zwischenspeicher und Neuanmeldung), Lehrernamen und Kursnamen über den
/// Unterricht (lessonsStudentParserProvider, für Eltern der Fork-Parser).
/// Grenze: Bei mehreren Kindern an EINER Schule zeigt das Portal unter
/// stundenplan.php nur ein Kind; das zweite folgt mit der Familienansicht.
class LivePlanPage extends ConsumerWidget {
  const LivePlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return CombinedAppletBuilder<TimeTable>(
      parser: ref.watch(timetableParserProvider),
      phpUrl: 'stundenplan.php',
      settingsDefaults: const {
        groupChoiceSetting: <String, dynamic>{},
        teacherNamesSetting: <String, dynamic>{},
      },
      accountType: type,
      builder: (context, tt, _, settings, updateSetting, _) {
        final raw = settings[groupChoiceSetting];
        Map<String, String> strings(Object? m) => <String, String>{
          if (m is Map)
            for (final e in m.entries)
              if (e.value is String) e.key.toString(): e.value as String,
        };
        final choice = strings(raw);
        final ownNames = strings(settings[teacherNamesSetting]);
        return _WithLessons(
          enabled: supported.contains('meinunterricht.php'),
          builder: (lessons, kids) {
            final names = <String, String>{};
            for (final l in lessons) {
              for (final t in l.teachers) {
                final kz = t.teacherKuerzel;
                final n = t.teacher;
                if (kz != null && n != null && n.isNotEmpty) {
                  names[kz] = portalNameToDisplay(n);
                }
              }
            }
            final firstName = kids.isNotEmpty
                ? kids.first.firstName
                : (session.userData['vorname'] ?? 'Plan');
            final plan = kidPlanFromTimetable(
              tt,
              firstName: firstName,
              colorIndex: 0,
              teacherNames: names,
              courseNames: [for (final l in lessons) l.name],
              schoolId: session.account.schoolID.toString(),
            );
            final auto = autoGroupChoice(plan, [
              for (final l in lessons)
                (
                  name: l.name,
                  teachers: {for (final t in l.teachers) ?t.teacherKuerzel},
                ),
            ]);
            return PlanPage(
              plans: [plan],
              now: DateTime.now(),
              initialChoices: {0: choice},
              onChoicesChanged: (c) =>
                  updateSetting(groupChoiceSetting, c[0] ?? const {}),
              autoChoices: {0: auto},
              initialNames: {0: ownNames},
              onNamesChanged: (n) =>
                  updateSetting(teacherNamesSetting, n[0] ?? const {}),
            );
          },
        );
      },
    );
  }
}

/// Lädt den Unterricht (für Lehrer- und Kursnamen) und baut [builder] auch
/// schon vorher – dann eben mit Kürzeln, die sich nachträglich füllen.
class _WithLessons extends ConsumerStatefulWidget {
  const _WithLessons({required this.enabled, required this.builder});

  final bool enabled;
  final Widget Function(Lessons lessons, List<ChildLessons> kids) builder;

  @override
  ConsumerState<_WithLessons> createState() => _WithLessonsState();
}

class _WithLessonsState extends ConsumerState<_WithLessons> {
  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(lessonsStudentParserProvider).fetchData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.builder(const [], const []);
    final parser = ref.watch(lessonsStudentParserProvider);
    return StreamBuilder<FetcherResponse<Lessons>>(
      stream: parser.stream,
      initialData: parser.latestResponse,
      builder: (context, snap) {
        final lessons = snap.data?.content ?? const <Lesson>[];
        final kids = parser is LessonsParentAwareParser
            ? parser.lastKids
            : const <ChildLessons>[];
        return widget.builder(lessons, kids);
      },
    );
  }
}
