import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../ui/kit.dart';
import 'demo_mode.dart';

/// Blatt „Demo ansehen“: Eltern oder Schüler wählen, dann startet die App
/// als Demo neu (demo_mode.dart, restartApp).
///
/// Ursache (Entscheidung 26.10.26, „sichtbar“): Neue sollen die App vor der
/// Anmeldung ausprobieren können; deshalb auf der Willkommensseite und in
/// den Einstellungen, nicht versteckt.
Future<void> showDemoChooser(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Kit.of(context).p.card,
      builder: (sheet) {
        final k = Kit.of(sheet);
        final t = sheet.t;
        Future<void> start(DemoChoice c) async {
          Navigator.of(sheet).pop();
          await restartApp?.call(demo: c);
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.demoTitle, style: k.sheetTitle),
                const SizedBox(height: Sp.s),
                Text(t.demoIntro, style: k.body),
                const SizedBox(height: Sp.l),
                _Choice(
                  icon: Icons.family_restroom,
                  title: t.demoParent,
                  text: t.demoParentText,
                  onTap: () => start(DemoChoice.parent),
                ),
                const SizedBox(height: Sp.s),
                _Choice(
                  icon: Icons.backpack_outlined,
                  title: t.demoStudent,
                  text: t.demoStudentText,
                  onTap: () => start(DemoChoice.student),
                ),
              ],
            ),
          ),
        );
      },
    );

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Material(
      color: k.p.bg,
      borderRadius: BorderRadius.circular(Rad.row),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.row),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Sp.m),
          child: Row(
            children: [
              Container(
                width: Sz.avatar,
                height: Sz.avatar,
                decoration: BoxDecoration(
                  color: k.plainTone.bg,
                  borderRadius: BorderRadius.circular(Rad.row),
                ),
                child: Icon(icon, color: k.plainTone.ink, size: Sz.navIcon),
              ),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: k.planSubject(k.p.ink)),
                    Text(text, style: k.meta),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: k.p.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Schmales Band oben auf Heute, solange die Demo läuft: Symbol, „Demo ·
/// Senden gesperrt“, Knopf „Beenden“.
///
/// Ursache (Abnahme 30.10.26, Entwurf `_demoBand`): Die graue Hinweiskarte
/// (HintCard mit Titel und Satz) kostete so viel Höhe wie zwei
/// Hinweiszeilen und drückte die Kinderkarte nach unten. Grenze: Der
/// ausführliche Satz (demoRunningText) steht nur noch in den Einstellungen
/// neben „Demo beenden“ (settings_page.dart).
Widget? demoNotice(BuildContext context) {
  if (!demoActive) return null;
  return const _DemoBand();
}

class _DemoBand extends StatelessWidget {
  const _DemoBand();

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.m, Sp.s, Sp.s, Sp.s),
      decoration: BoxDecoration(
        color: k.p.card,
        borderRadius: BorderRadius.circular(Rad.pill),
      ),
      child: Row(
        children: [
          Icon(Icons.play_circle_outline, size: Sz.icon, color: k.p.muted),
          const SizedBox(width: Sp.s),
          Expanded(
            child: Text(
              t.demoBand,
              style: k.hintSubject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Sp.s),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: k.p.strong,
              foregroundColor: k.p.onStrong,
              minimumSize: const Size(0, Sz.bandButton),
              padding: const EdgeInsets.symmetric(horizontal: Sp.m),
            ),
            onPressed: () => restartApp?.call(),
            child: Text(t.demoEndShort),
          ),
        ],
      ),
    );
  }
}

/// In der Demo gesperrte Aktion (Senden, Hochladen, Löschen): Hinweis
/// zeigen und true liefern. Ursache (Abnahme 26.10.26): Statt der
/// normalen Fehlermeldung („ließ sich nicht senden“) ein klarer Satz, dass
/// es an der Demo liegt. Grenze: Nur Aktionen, die ans Portal gehen; was
/// die App selbst speichert (Hausaufgabe abhaken), geht auch in der Demo.
bool blockedInDemo(BuildContext context) {
  if (!demoActive) return false;
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(context.t.demoBlocked)));
  return true;
}
