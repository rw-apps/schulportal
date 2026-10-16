import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart'
    show TypedSettings, sharedOverAccountSettingsProvider, AccountType;

import 'package:lanis/applets/conversations/definition.dart';
import 'package:lanis/applets/external_definitions.dart';
import 'package:lanis/applets/lessons/definition.dart';
import 'package:lanis/utils/deep_link.dart';

import '../../school_links.dart';
import '../kit.dart';
import '../live/live_data.dart';
import '../more/more_page.dart';
import '../plan/live_plan_page.dart';
import '../plan/plan_model.dart' show GroupChoice;
import '../plan/plan_page.dart';
import '../today/live_today_page.dart';
import '../today/today_model.dart';
import '../today/today_page.dart';
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
  const PreviewShell({super.key, this.liveData = false});

  /// Echte Daten des angemeldeten Kontos. Tests und Bildschirmfotos: false
  /// (Beispieldaten, ohne Portal und ohne ProviderScope).
  final bool liveData;

  @override
  State<PreviewShell> createState() => _PreviewShellState();
}

class _PreviewShellState extends State<PreviewShell> {
  ShellTab _tab = ShellTab.today;
  KitFontStep _font = KitFontStep.normal;

  /// Geräteweit (nicht je Konto): Die Schriftgröße ist eine Frage des
  /// Handys und der Augen, nicht des Schulkontos.
  static const _fontKey = 'fork-ui/font-step';

  TypedSettings? _deviceSettings() {
    if (!widget.liveData) return null;
    try {
      return ProviderScope.containerOf(
        context,
        listen: false,
      ).read(sharedOverAccountSettingsProvider);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stored = _deviceSettings()?.getString(_fontKey);
      if (stored != null && mounted) {
        setState(() => _font = KitFontStep.parse(stored));
      }
    });
  }

  void _setFont(KitFontStep step) {
    setState(() => _font = step);
    _deviceSettings()?.setString(_fontKey, step.name);
  }

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

  /// In eine bisherige Lanis-Ansicht wechseln. Die neue Oberfläche liegt
  /// (noch) als eigene Seite über dem Router; erst schließen, dann dorthin.
  void _goOld(String path) {
    final router = GoRouter.maybeOf(context);
    Navigator.of(context).maybePop();
    router?.go(path);
  }

  void _select(ShellTab t) => setState(() => _tab = t);

  static const _dest = [
    (Icons.home_outlined, Icons.home, 'Heute'),
    (Icons.calendar_month_outlined, Icons.calendar_month, 'Kalender'),
    (Icons.menu_book_outlined, Icons.menu_book, 'Unterricht'),
    (Icons.chat_bubble_outline, Icons.chat_bubble, 'Nachrichten'),
    (Icons.more_horiz, Icons.more_horiz, 'Mehr'),
  ];

  List<MoreEntry> _liveEntries(BuildContext context, LiveSnapshot? s) {
    if (s == null) return const [];
    final mensa = mensaUrlFor(s.schoolId);
    return [
      if (s.offers('abwesenheitsmeldung.php'))
        MoreEntry(
          icon: Icons.thermostat,
          label: 'Krank melden',
          detail: 'Vorerst nur beim Portal prüfen',
          onTap: () => openAbsence(context),
        ),
      if (mensa != null)
        MoreEntry(
          icon: Icons.restaurant_menu,
          label: 'Essen bestellen',
          detail: 'Bestellseite der Mensa im Browser',
          onTap: () => openMensa(context, mensa),
        ),
      if (offersMoodle(s.session.travelMenu))
        MoreEntry(
          icon: Icons.school_outlined,
          label: 'Lernplattform (Moodle)',
          onTap: () => _goOld(SettingsDeepLinks.moodle),
        ),
      if (s.offers('kalender.php'))
        MoreEntry(
          icon: Icons.event_available_outlined,
          label: 'Termine in eigenen Kalender',
          detail: 'Schultermine abonnieren',
          onTap: () => _goOld(SettingsDeepLinks.calendarExport),
        ),
      MoreEntry(
        icon: Icons.open_in_browser,
        label: 'Schulportal im Browser',
        onTap: () => openLanisDefinition.action?.call(context),
      ),
      MoreEntry(
        icon: Icons.apps,
        label: 'Alle Funktionen',
        detail: 'Bisherige Ansicht',
        onTap: () => Navigator.of(context).maybePop(),
      ),
      MoreEntry(
        icon: Icons.settings_outlined,
        label: 'Einstellungen',
        onTap: () => _goOld(SettingsDeepLinks.home),
      ),
    ];
  }

  Widget _liveBody(BuildContext context) {
    final s = LiveData.of(context);
    final type = s?.session.accountTypeOrNull ?? AccountType.parent;
    return switch (_tab) {
      ShellTab.today => LiveTodayPage(
        onOpenCalendar: () => _select(ShellTab.calendar),
        onOpenHomework: () => _select(ShellTab.courses),
        onOpenMessages: () => _select(ShellTab.messages),
      ),
      ShellTab.calendar => const LiveCalendarPage(),
      ShellTab.courses => _Placeholder(
        label: 'Unterricht',
        text: 'Hausaufgaben und Kurse im neuen Stil folgen.',
        actionLabel: 'Bisherige Ansicht öffnen',
        onAction: () => _goOld(lessonsDefinition.homePath(type)),
      ),
      ShellTab.messages => _Placeholder(
        label: 'Nachrichten',
        text: 'Nachrichten im neuen Stil folgen.',
        actionLabel: 'Bisherige Ansicht öffnen',
        onAction: () => _goOld(conversationsDefinition.homePath(type)),
      ),
      ShellTab.more => MorePage(
        font: _font,
        onFont: _setFont,
        entries: _liveEntries(context, s),
      ),
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
    ShellTab.more => MorePage(font: _font, onFont: _setFont),
    _ => _Placeholder(label: _dest[_tab.index].$3, text: 'Folgt.'),
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
        items: _dest,
        onSelect: (i) => _select(ShellTab.values[i]),
      ),
    );
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(system * _font.factor)),
      child: Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: kitFont),
        ),
        child: widget.liveData ? LiveDataScope(child: scaffold) : scaffold,
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

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.label,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: k.pageTitle),
            const SizedBox(height: Sp.l),
            Text(text, style: k.meta),
            if (actionLabel != null) ...[
              const SizedBox(height: Sp.l),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.open_in_new),
                label: Text(actionLabel!, style: k.button(k.p.ink)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
