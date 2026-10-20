import '../../data_storage.dart' show offersStorage;
import '../storage/storage_page.dart';
import '../nav.dart' show pushFullScreen;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:go_router/go_router.dart';

import 'package:lanis/applets/external_definitions.dart';
import 'package:lanis/fork/start.dart';
import 'package:lanis/utils/deep_link.dart';

import '../../l10n/l10n.dart';
import '../../school_links.dart';
import '../courses/course_detail_page.dart';
import '../courses/courses_page.dart';
import '../courses/live_courses_page.dart';
import '../kit.dart';
import '../live/family.dart';
import '../live/live_data.dart';
import '../messages/live_messages_page.dart';
import '../messages/messages_page.dart';
import '../more/more_page.dart';
import '../plan/live_plan_page.dart';
import '../settings/settings_page.dart';
import '../plan/plan_model.dart' show GroupChoice, effectiveChoice;
import '../today/today_from_lanis.dart'
    show applySubstitutions, shortSchoolName;
import '../plan/plan_page.dart';
import '../today/live_today_page.dart';
import '../today/today_model.dart';
import '../today/today_page.dart';
import 'demo_courses.dart';
import 'demo_family.dart';
import 'demo_plan.dart';

/// Bereiche der Leiste (Konzept 17.10.26, Variante A): jedes Ding hat genau
/// eine Heimat – Kalender (alles mit Datum: Stunden, Vertretungen, Termine),
/// Unterricht (alles am Kurs), Nachrichten, Mehr (Dienste). „Heute“ besitzt
/// nichts Eigenes, es zeigt nur Auszüge, die in ihre Heimat führen.
enum ShellTab { today, calendar, courses, messages, more }

/// Neue Oberfläche.
///
/// Ursache: Gestaltung braucht Abnahme auf dem Gerät (Pixel 9a). Grenze: Aus
/// den Einstellungen geöffnet zeigt sie echte Daten ([LiveDataScope]), in
/// Tests erfundene ([demoFamily], [demoPlans]).
class PreviewShell extends StatefulWidget {
  const PreviewShell({super.key, this.liveData = false, this.asRoot = false});

  /// Echte Daten des angemeldeten Kontos. Tests und Bildschirmfotos: false
  /// (Beispieldaten, ohne Portal und ohne ProviderScope).
  final bool liveData;

  /// Als Startseite (Route [forkHomePath]) statt über den Einstellungen
  /// geöffnet: bisherige Bereiche werden darüber gelegt (push), statt die
  /// neue Oberfläche zu schließen.
  final bool asRoot;

  @override
  State<PreviewShell> createState() => _PreviewShellState();
}

class _PreviewShellState extends State<PreviewShell> {
  ShellTab _tab = ShellTab.today;

  /// Ein Navigator je Reiter (Entscheidung 17.10.26: Leiste auch auf
  /// Unterseiten). Ursache: Mit einem gemeinsamen Navigator lag jede
  /// Unterseite über der Leiste. Jetzt öffnen Lese-Seiten im Reiter, der sich
  /// seinen Verlauf merkt; Eingabe-Seiten gehen über die ganze App
  /// (nav.dart, pushFullScreen). Grenze: Ein Reiter wird erst beim ersten
  /// Besuch gebaut ([_visited]), damit der Start nicht alle Bereiche lädt.
  final _navKeys = {
    for (final t in ShellTab.values) t: GlobalKey<NavigatorState>(),
  };
  final _visited = <ShellTab>{ShellTab.today};
  int _revision = 0;

  /// „Alle Termine“ auf Heute: Kalender in der Ansicht „Termine“ öffnen
  /// (PlanPage.viewRequest).
  final _calendarView = ValueNotifier<PlanView?>(null);

  @override
  void dispose() {
    _calendarView.dispose();
    super.dispose();
  }

  void _openDay() {
    _calendarView.value = PlanView.day;
    _navKeys[ShellTab.calendar]!.currentState?.popUntil((r) => r.isFirst);
    _select(ShellTab.calendar);
  }

  void _openEvents() {
    _calendarView.value = PlanView.events;
    _navKeys[ShellTab.calendar]!.currentState?.popUntil((r) => r.isFirst);
    _select(ShellTab.calendar);
  }

  /// Nur Tests/Beispieldaten: eigene Schriftstufe. Mit echten Daten setzt
  /// sie die App für alle Seiten (fork/ui/font_step.dart).
  final KitFontStep _font = KitFontStep.normal;

  final FamilyToday _data = demoFamily();
  final _plans = demoPlans();
  Map<int, GroupChoice> _choices = {};

  void _notYet(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$what – in der Vorschau noch ohne Funktion')),
      );
  }

  /// In eine bisherige Lanis-Ansicht wechseln. Als Startseite: darüber
  /// legen, „Zurück“ führt hierher. Aus den Einstellungen geöffnet (eigene
  /// Seite über dem Router): erst schließen, dann dorthin.
  void _goOld(String path) {
    final router = GoRouter.maybeOf(context);
    if (widget.asRoot) {
      router?.push(path);
      return;
    }
    Navigator.of(context).maybePop();
    router?.go(path);
  }

  /// Reiter wählen; erneutes Antippen des aktiven führt an seinen Anfang.
  void _select(ShellTab t) {
    if (t == _tab) {
      _navKeys[t]!.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() {
      _tab = t;
      _visited.add(t);
    });
  }

  /// Android-Zurück: erst im Reiter zurück, dann nach „Heute“, dann aus der
  /// App. Ursache: Als Startseite gibt es darunter nichts; ein Zurück aus
  /// „Kalender“ hätte die App sonst sofort geschlossen.
  void _back() {
    final nav = _navKeys[_tab]!.currentState;
    if (nav != null && nav.canPop()) {
      nav.maybePop();
    } else if (_tab != ShellTab.today) {
      _select(ShellTab.today);
    } else if (widget.asRoot) {
      SystemNavigator.pop();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Widget _tabNavigator(ShellTab t) => _TabNavigator(
    navKey: _navKeys[t]!,
    // Builder mit Abhängigkeit von _ShellRevision: Die Startseite des
    // Reiters wird bei jedem Neuaufbau der Leiste neu gebaut. Ursache: Eine
    // Route baut ihren Inhalt sonst nur einmal – „Mehr“ und die Beispiel-
    // daten hingen dann am ersten Stand.
    root: Builder(
      builder: (c) {
        _ShellRevision.watch(c);
        return widget.liveData ? _liveBody(c, t) : _demoBody(t);
      },
    ),
  );

  static List<NavDest> _dest(ForkL10n t, [NavBadges b = const NavBadges()]) => [
    NavDest(Icons.home_outlined, Icons.home, t.navToday, alert: b.todayAlert),
    NavDest(Icons.calendar_month_outlined, Icons.calendar_month, t.navCalendar),
    NavDest(
      Icons.menu_book_outlined,
      Icons.menu_book,
      t.navCourses,
      count: b.homework,
    ),
    NavDest(
      Icons.chat_bubble_outline,
      Icons.chat_bubble,
      t.navMessages,
      count: b.unread,
    ),
    NavDest(Icons.more_horiz, Icons.more_horiz, t.navMore),
  ];

  void _saveMensa(LiveSnapshot s, String kid, String raw) {
    final ok = raw.trim().isEmpty || normalizeMensaUrl(raw) != null;
    if (ok) {
      s.setMensaUrl(kid, raw);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t.invalidUrl)));
  }

  String _mensaDetail(
    ForkL10n t,
    LiveSnapshot s,
    String kid, {
    required bool several,
  }) {
    final url = s.mensa.of(kid);
    if (url == null) return t.orderMealSetup;
    final host = Uri.parse(url).host;
    return several && !s.mensa.ownFor(kid)
        ? '$host · ${t.mensaInherited}'
        : host;
  }

  Future<(String, String?)?> _chooseKid(
    BuildContext context,
    List<(String, String?)> kids,
  ) {
    final k = Kit.of(context);
    return showModalBottomSheet<(String, String?)>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: k.p.card,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.l),
          children: [
            Text(context.t.chooseChild, style: k.sheetTitle),
            const SizedBox(height: Sp.m),
            for (final x in kids)
              ListTile(
                title: Text(x.$2 ?? '', style: k.planSubject(k.p.ink)),
                onTap: () => Navigator.of(context).pop(x),
              ),
          ],
        ),
      ),
    );
  }

  List<MoreEntry> _liveEntries(BuildContext context, LiveSnapshot? s) {
    if (s == null) return const [];
    final t = context.t;
    // Ein Eintrag je Kind (Wunsch 17.10.26); Schülerkonto bzw. Kinder noch
    // nicht geladen: ein Eintrag ohne Namen.
    final kids = <(String, String?)>[
      if (s.kids.isEmpty) ('', null),
      for (final k in s.kids)
        (k.pupilId, s.kids.length > 1 ? k.firstName : null),
    ];
    final anyMensa = kids.any((k) => s.mensa.of(k.$1) != null);
    return [
      if (s.offers('abwesenheitsmeldung.php'))
        MoreEntry(
          icon: Icons.thermostat,
          label: t.reportSick,
          detail: t.reportSickDetail,
          onTap: () => openAbsence(context),
        ),
      for (final (kid, name) in kids)
        MoreEntry(
          icon: Icons.restaurant_menu,
          label: name == null ? t.orderMeal : t.orderMealFor(name),
          detail: _mensaDetail(t, s, kid, several: kids.length > 1),
          onTap: () async {
            if (s.mensa.of(kid) != null) {
              await openMensa(context, s, kid, name: name);
              return;
            }
            final url = await askMensaUrl(
              context,
              null,
              childName: name,
              suggestion: mensaSuggestion(s.session.travelMenu),
            );
            if (url != null && mounted) _saveMensa(s, kid, url);
          },
        ),
      if (anyMensa)
        MoreEntry(
          icon: Icons.edit_outlined,
          label: t.mensaChange,
          onTap: () async {
            final pick = kids.length == 1
                ? kids.single
                : await _chooseKid(context, kids);
            if (pick == null || !mounted) return;
            final url = await askMensaUrl(
              this.context,
              s.mensa.of(pick.$1),
              childName: pick.$2,
            );
            if (url != null && mounted) _saveMensa(s, pick.$1, url);
          },
        ),
      // Dateispeicher der Schule (data_storage.dart); öffnet im Rahmen des
      // gewählten Kontos (pushFullScreen), also auch für weitere Kinder.
      if (offersStorage(s.session.travelMenu))
        MoreEntry(
          icon: Icons.folder_copy_outlined,
          label: t.storageTitle,
          detail: t.storageDetail,
          onTap: () => pushFullScreen<void>(
            context,
            (_) => LiveStoragePage(subtitle: shortSchoolName(s.schoolName)),
          ),
        ),
      // Moodle öffnet über den Router, also immer im aktiven Konto.
      if (offersMoodle(s.session.travelMenu) &&
          (FamilyMember.around(context)?.active ?? true))
        MoreEntry(
          icon: Icons.school_outlined,
          label: t.learningPlatform,
          onTap: () => _goOld(SettingsDeepLinks.moodle),
        ),
      MoreEntry(
        icon: Icons.open_in_browser,
        label: t.portalInBrowser,
        onTap: () => openLanisDefinition.action?.call(context),
      ),
      MoreEntry(
        icon: Icons.settings_outlined,
        label: t.settings,
        detail: t.settingsDetail,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ForkSettingsPage()),
        ),
      ),
    ];
  }

  Widget _today(int? only) => LiveTodayPage(
    onlyAccount: only,
    onOpenCalendar: _openEvents,
    onOpenDay: _openDay,
    onOpenHomework: () => _select(ShellTab.courses),
    onOpenMessages: () => _select(ShellTab.messages),
  );

  Widget _liveBody(BuildContext context, ShellTab tab) {
    return switch (tab) {
      // „Alle“ vorn wie in Unterricht und Nachrichten (Rückmeldung
      // 20.10.26); ein Kind gewählt: nur dessen Karte und Termine.
      ShellTab.today => FamilySwitch(
        all: (_, _) => _today(null),
        child: Builder(
          builder: (c) => _today(FamilyMember.around(c)?.accountId),
        ),
      ),
      ShellTab.calendar => LiveCalendarPage(viewRequest: _calendarView),
      // Je Kind getrennt; bei mehreren Konten mit Auswahl oben (family.dart).
      // „Alle“ vorn (Entwurf 20.10.26): Hausaufgaben, Arbeiten, Fehlstunden
      // aller Kinder; Fächer und Noten je Kind.
      ShellTab.courses => FamilySwitch(
        all: (context, members) => LiveAllCoursesPage(members: members),
        child: const LiveCoursesPage(),
      ),
      // „Alle“ vorn: Nachrichten aller Kinder in einer Liste (Wunsch 18.10.26).
      ShellTab.messages => FamilySwitch(
        all: (_, members) => LiveAllMessagesPage(members: members),
        child: const LiveMessagesPage(),
      ),
      ShellTab.more => FamilySwitch(
        child: Builder(
          builder: (c) => MorePage(entries: _liveEntries(c, LiveData.of(c))),
        ),
      ),
    };
  }

  Widget _demoBody(ShellTab tab) => switch (tab) {
    ShellTab.today => TodayPage(
      data: _data,
      onReportAbsence: (c) => _notYet('Krankmeldung für ${c.firstName}'),
      onOpenHomework: (_) => _select(ShellTab.courses),
      onOpenMessages: (_) => _select(ShellTab.messages),
      onOpenCalendar: _openEvents,
    ),
    ShellTab.calendar => PlanPage(
      plans: _plans,
      now: _data.now,
      initialChoices: _choices,
      onChoicesChanged: (c) => _choices = {
        for (final e in c.entries) e.key: {...e.value},
      },
      events: _data.week,
      viewRequest: _calendarView,
    ),
    ShellTab.courses => Builder(
      builder: (c) => CoursesPage(
        items: demoCourses(),
        firstName: 'Lena',
        onOpen: (i) => Navigator.of(c).push(
          MaterialPageRoute<void>(
            builder: (_) => CourseDetailPage(
              course: CourseContext(
                title: i.title,
                fullName: i.fullName,
                teachers: [for (final n in i.teachers) ('', n)],
                colorSlot: i.colorSlot ?? 0,
              ),
              load: ({required bool firstHalf}) async => demoDetailedLesson(i),
              onWrite: (_) {},
            ),
          ),
        ),
      ),
    ),
    ShellTab.messages => MessagesPage(
      items: demoMessages(),
      onCompose: () => _notYet('Neue Nachricht'),
    ),
    ShellTab.more => const MorePage(),
  };

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    // Schrift des Kits auch für Material-Bausteine (SnackBar, Knöpfe).
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final system = mq.textScaler.scale(14) / 14;
    final scaffold = Scaffold(
      backgroundColor: k.p.bg,
      // Inhalt endet ÜBER der Leiste (kein extendBody). Ursache: Lief er
      // darunter weiter, schnitt die Pille beim Scrollen Stunden an
      // (Rückmeldung 16.10.26 zur Tagesansicht).
      extendBody: false,
      body: _ShellRevision(
        revision: ++_revision,
        child: IndexedStack(
          index: _tab.index,
          children: [
            for (final t in ShellTab.values)
              _visited.contains(t) ? _tabNavigator(t) : const SizedBox.shrink(),
          ],
        ),
      ),
      // Builder: liegt unter LiveDataScope (siehe unten), damit die Marken
      // die geladenen Daten lesen können.
      bottomNavigationBar: Builder(
        builder: (c) => FloatingNavBar(
          selected: _tab.index,
          items: _dest(
            c.t,
            widget.liveData ? familyBadges(c) : const NavBadges(),
          ),
          onSelect: (i) => _select(ShellTab.values[i]),
        ),
      ),
    );
    return MediaQuery(
      data: widget.liveData
          ? mq
          : mq.copyWith(textScaler: TextScaler.linear(system * _font.factor)),
      child: Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: kitFont),
        ),
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back();
          },
          child: widget.liveData
              ? LiveDataScope(child: FamilyScope(child: scaffold))
              : scaffold,
        ),
      ),
    );
  }
}

/// Schwebende Leiste (Pille) aus dem Entwurf A + C.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.selected,
    required this.items,
    required this.onSelect,
  });

  final int selected;
  final List<NavDest> items;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final inset = MediaQuery.paddingOf(context).bottom;
    // Fläche um die Pille in Seitenfarbe, damit nichts durchscheint.
    return ColoredBox(
      color: k.p.bg,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Sz.navMargin,
          Sp.s,
          Sz.navMargin,
          Sz.navBottom + inset,
        ),
        child: Container(
          height: Sz.navHeight,
          padding: const EdgeInsets.symmetric(horizontal: Sp.s),
          decoration: BoxDecoration(
            color: k.p.navBg,
            borderRadius: BorderRadius.circular(Rad.nav),
            boxShadow: k.navShadow,
          ),
          // Jedes Ziel bekommt ein Fünftel der Breite. Ursache: Mit freier
          // Breite lief die Leiste bei großer Systemschrift um bis zu 220 px
          // über („Nachrichten“, Test today_page_test, Schrift ×1,3).
          child: Row(
            children: [
              for (final (i, d) in items.indexed)
                Expanded(
                  child: _NavItem(
                    icon: i == selected ? d.iconSelected : d.icon,
                    label: d.label,
                    selected: i == selected,
                    count: d.count,
                    alert: d.alert,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count = 0,
    this.alert = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int count;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final fg = selected ? k.p.onNavSelected : k.p.muted;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.navItem),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.xs,
            vertical: Sp.xs + Sp.xxs,
          ),
          decoration: BoxDecoration(
            color: selected ? k.p.navSelected : null,
            borderRadius: BorderRadius.circular(Rad.navItem),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: Sz.navIcon, color: fg),
                  if (alert || count > 0)
                    Positioned(
                      right: -Sp.s - 1,
                      top: -Sp.xs - 1,
                      child: _Badge(text: alert ? '!' : '$count', alert: alert),
                    ),
                ],
              ),
              const SizedBox(height: Sp.xxs),
              // Zu lange Beschriftung wird verkleinert, nie abgeschnitten
              // oder umgebrochen („Stundenpla-n“ im Lanis-Original).
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, maxLines: 1, style: k.navLabel(selected)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ein Ziel der unteren Leiste mit optionaler Marke.
class NavDest {
  const NavDest(
    this.icon,
    this.iconSelected,
    this.label, {
    this.count = 0,
    this.alert = false,
  });

  final IconData icon;
  final IconData iconSelected;
  final String label;

  /// Zahl an der Marke (0 = keine).
  final int count;

  /// Rote Marke „!“ statt Zahl.
  final bool alert;
}

/// Marken der unteren Leiste (Entwurf 17.10.26): offene Hausaufgaben an
/// „Unterricht“, ungelesene Nachrichten an „Nachrichten“, „!“ an „Heute“
/// bei Ausfall heute oder morgen.
class NavBadges {
  const NavBadges({
    this.homework = 0,
    this.unread = 0,
    this.todayAlert = false,
  });

  final int homework;
  final int unread;
  final bool todayAlert;
}

/// Marken aus den geladenen Daten. Grenze: Der Ausfall zählt nur für die
/// Stunden des Kindes (applySubstitutions, wie „Heute“); ohne Stundenplan
/// gibt es kein „!“.
/// Marken über alle Konten der Familie (FamilyData); ohne Familie nur das
/// aktive Konto.
NavBadges familyBadges(BuildContext c) {
  final members = FamilyData.of(c);
  if (members.isEmpty) return navBadgesOf(LiveData.of(c), c.t);
  var homework = 0, unread = 0;
  var alert = false;
  for (final m in members) {
    final b = navBadgesOf(m.snapshot, c.t);
    homework += b.homework;
    unread += b.unread;
    alert = alert || b.todayAlert;
  }
  return NavBadges(homework: homework, unread: unread, todayAlert: alert);
}

NavBadges navBadgesOf(LiveSnapshot? s, ForkL10n t) {
  if (s == null) return const NavBadges();
  var alert = false;
  final live = s.offers('stundenplan.php') && s.timetable.content != null
      ? livePlanOf(s)
      : null;
  if (live != null) {
    final now = DateTime.now();
    final r = applySubstitutions(
      plan: live.plan,
      choice: effectiveChoice(live.auto, s.userChoice),
      days: s.substitutions.content?.days ?? const [],
      now: now,
      t: t,
    );
    // Wie Heute: heute nur Ausfälle von Stunden, die noch kommen oder
    // laufen (Karte des Kindes, lessonDone), morgen alle (Kasten „Morgen“).
    // Ursache (Prüfung 20.10.26): Das „!“ zählte auch heutige Ausfälle, die
    // schon vorbei waren – auf Heute war dann nichts zu sehen.
    final today = DateTime(now.year, now.month, now.day);
    alert =
        r.today.any((l) => l.cancelled && !lessonDone(l, now)) ||
        r.changes.any(
          (c) => c.kind == ChangeKind.cancelled && dayDiff(today, c.day) == 1,
        );
  }
  return NavBadges(
    homework: liveOpenHomework(s),
    unread: liveUnreadMessages(s),
    todayAlert: alert,
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.alert});

  final String text;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: Sp.l),
      height: Sp.l,
      padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: alert ? k.p.cancel.dot : k.p.strong,
        borderRadius: BorderRadius.circular(Sp.s),
      ),
      child: Text(text, style: k.cellTeacher(k.p.onStrong)),
    );
  }
}

/// Navigator eines Reiters mit seiner Startseite.
class _TabNavigator extends StatefulWidget {
  const _TabNavigator({required this.navKey, required this.root});

  final GlobalKey<NavigatorState> navKey;
  final Widget root;

  @override
  State<_TabNavigator> createState() => _TabNavigatorState();
}

class _TabNavigatorState extends State<_TabNavigator> {
  // Eigener HeroController: Den der App darf nur ein Navigator benutzen
  // (sonst Assertion „can not be shared by multiple Navigators“).
  final _hero = MaterialApp.createMaterialHeroController();

  @override
  void dispose() {
    _hero.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HeroControllerScope(
    controller: _hero,
    child: Navigator(
      key: widget.navKey,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => widget.root,
      ),
    ),
  );
}

/// Meldet jeden Neuaufbau der Leiste an die Startseiten der Reiter.
class _ShellRevision extends InheritedWidget {
  const _ShellRevision({required this.revision, required super.child});

  final int revision;

  static void watch(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<_ShellRevision>();

  @override
  bool updateShouldNotify(_ShellRevision old) => old.revision != revision;
}
