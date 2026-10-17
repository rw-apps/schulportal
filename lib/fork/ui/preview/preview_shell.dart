import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:lanis/applets/external_definitions.dart';
import 'package:lanis/fork/start.dart';
import 'package:lanis/utils/deep_link.dart';

import '../../l10n/l10n.dart';
import '../../school_links.dart';
import '../courses/courses_page.dart';
import '../courses/live_courses_page.dart';
import '../kit.dart';
import '../live/live_data.dart';
import '../messages/live_messages_page.dart';
import '../messages/messages_page.dart';
import '../more/more_page.dart';
import '../plan/live_plan_page.dart';
import '../settings/settings_page.dart';
import '../plan/plan_model.dart' show GroupChoice;
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

  void _select(ShellTab t) => setState(() => _tab = t);

  static List<(IconData, IconData, String)> _dest(ForkL10n t) => [
    (Icons.home_outlined, Icons.home, t.navToday),
    (Icons.calendar_month_outlined, Icons.calendar_month, t.navCalendar),
    (Icons.menu_book_outlined, Icons.menu_book, t.navCourses),
    (Icons.chat_bubble_outline, Icons.chat_bubble, t.navMessages),
    (Icons.more_horiz, Icons.more_horiz, t.navMore),
  ];

  void _saveMensa(LiveSnapshot s, String raw) {
    final ok = raw.trim().isEmpty || normalizeMensaUrl(raw) != null;
    if (ok) {
      s.setMensaUrl(raw);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t.invalidUrl)));
  }

  List<MoreEntry> _liveEntries(BuildContext context, LiveSnapshot? s) {
    if (s == null) return const [];
    final mensa = s.mensaUrl;
    final t = context.t;
    return [
      if (s.offers('abwesenheitsmeldung.php'))
        MoreEntry(
          icon: Icons.thermostat,
          label: t.reportSick,
          detail: t.reportSickDetail,
          onTap: () => openAbsence(context),
        ),
      MoreEntry(
        icon: Icons.restaurant_menu,
        label: t.orderMeal,
        detail: mensa == null ? t.orderMealSetup : Uri.parse(mensa).host,
        onTap: () async {
          if (mensa != null) {
            await openMensa(context, mensa);
            return;
          }
          final url = await askMensaUrl(context, null);
          if (url != null) _saveMensa(s, url);
        },
      ),
      if (mensa != null)
        MoreEntry(
          icon: Icons.edit_outlined,
          label: t.mensaChange,
          onTap: () async {
            final url = await askMensaUrl(context, mensa);
            if (url != null) _saveMensa(s, url);
          },
        ),
      if (offersMoodle(s.session.travelMenu))
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

  Widget _liveBody(BuildContext context) {
    final s = LiveData.of(context);
    return switch (_tab) {
      ShellTab.today => LiveTodayPage(
        onOpenCalendar: () => _select(ShellTab.calendar),
        onOpenHomework: () => _select(ShellTab.courses),
        onOpenMessages: () => _select(ShellTab.messages),
      ),
      ShellTab.calendar => const LiveCalendarPage(),
      ShellTab.courses => const LiveCoursesPage(),
      ShellTab.messages => const LiveMessagesPage(),
      ShellTab.more => MorePage(entries: _liveEntries(context, s)),
    };
  }

  Widget _demoBody() => switch (_tab) {
    ShellTab.today => TodayPage(
      data: _data,
      onReportAbsence: (c) => _notYet('Krankmeldung für ${c.firstName}'),
      onOpenHomework: (_) => _select(ShellTab.courses),
      onOpenMessages: (_) => _select(ShellTab.messages),
      onOpenCalendar: () => _select(ShellTab.calendar),
    ),
    ShellTab.calendar => PlanPage(
      plans: _plans,
      now: _data.now,
      initialChoices: _choices,
      onChoicesChanged: (c) => _choices = {
        for (final e in c.entries) e.key: {...e.value},
      },
      events: _data.week,
    ),
    ShellTab.courses => CoursesPage(items: demoCourses(), firstName: 'Lena'),
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
      body: widget.liveData ? Builder(builder: _liveBody) : _demoBody(),
      bottomNavigationBar: FloatingNavBar(
        selected: _tab.index,
        items: _dest(context.t),
        onSelect: (i) => _select(ShellTab.values[i]),
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
        // „Zurück“ führt erst nach „Heute“, dann aus der App. Ursache: Als
        // Startseite gibt es darunter nichts; ein Zurück aus „Kalender“
        // hätte die App sonst sofort geschlossen.
        child: PopScope(
          canPop: _tab == ShellTab.today,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _select(ShellTab.today);
          },
          child: widget.liveData ? LiveDataScope(child: scaffold) : scaffold,
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
  final List<(IconData, IconData, String)> items;
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
              for (final (i, (icon, iconSel, label)) in items.indexed)
                Expanded(
                  child: _NavItem(
                    icon: i == selected ? iconSel : icon,
                    label: label,
                    selected: i == selected,
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
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

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
              Icon(icon, size: Sz.navIcon, color: fg),
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
