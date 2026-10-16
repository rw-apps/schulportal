import 'package:flutter/material.dart';

import '../kit.dart';
import '../today/today_model.dart';
import '../today/today_page.dart';
import 'demo_family.dart';

/// Vorschau der neuen Oberfläche, erreichbar über Einstellungen.
///
/// Ursache: Gestaltung braucht Abnahme auf dem Gerät (Pixel 9a), bevor die
/// echte Anbindung gebaut wird. Grenze: Nur „Heute“ ist entworfen, mit
/// erfundenen Daten ([demoFamily]); die übrigen Ziele der Leiste zeigen
/// einen Platzhalter, Antippen löst nichts im Portal aus.
class PreviewShell extends StatefulWidget {
  const PreviewShell({super.key});

  @override
  State<PreviewShell> createState() => _PreviewShellState();
}

class _PreviewShellState extends State<PreviewShell> {
  int _index = 0;
  final FamilyToday _data = demoFamily();

  void _notYet(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$what – im Entwurf noch ohne Funktion')),
      );
  }

  static const _dest = [
    (Icons.today_outlined, Icons.today, 'Heute'),
    (Icons.view_week_outlined, Icons.view_week, 'Plan'),
    (Icons.chat_bubble_outline, Icons.chat_bubble, 'Nachrichten'),
    (Icons.event_outlined, Icons.event, 'Termine'),
    (Icons.more_horiz, Icons.more_horiz, 'Mehr'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_index) {
        0 => TodayPage(
          data: _data,
          onReportAbsence: (c) => _notYet('Krankmeldung für ${c.firstName}'),
          onOpenHomework: (c) => _notYet('Hausaufgaben von ${c.firstName}'),
          onOpenMessages: (c) => _notYet('Nachrichten von ${c.firstName}'),
        ),
        _ => _Placeholder(label: _dest[_index].$3),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final (icon, selected, label) in _dest)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selected),
              label: label,
            ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.label});

  final String label;

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
            Text(
              'Entwurf folgt, sobald „Heute“ abgenommen ist.',
              style: k.pageSub,
            ),
            const SizedBox(height: Sp.l),
            TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close),
              label: const Text('Vorschau schließen'),
            ),
          ],
        ),
      ),
    );
  }
}
