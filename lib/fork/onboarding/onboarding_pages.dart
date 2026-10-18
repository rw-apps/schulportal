import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/l10n.dart';
import '../ui/kit.dart';
import 'onboarding_kit.dart';

/// 1 – Willkommen (ersetzt die sechs Einführungsseiten der Vorlage).
///
/// Ursache: Jene nannten den Namen der Vorlage und „von Schülern entwickelt“
/// – beides trifft auf diese App nicht zu, und sechs Seiten bis zur Anmeldung
/// sind zu viel. Jetzt eine Seite: was die App kann, dann „Anmelden“.
class ForkWelcomePage extends StatelessWidget {
  const ForkWelcomePage({super.key, required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    return PopScope(
      canPop: false,
      child: OnbPage(
        top: [
          const SizedBox(height: Sp.l),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: Sz.button,
              height: Sz.button,
              decoration: BoxDecoration(
                color: k.p.strong,
                borderRadius: BorderRadius.circular(Rad.tile),
              ),
              child: Icon(
                Icons.school_outlined,
                color: k.p.onStrong,
                size: Sz.navIcon + Sp.s,
              ),
            ),
          ),
          const SizedBox(height: Sp.l),
          Text(t.onbAppName, style: k.greeting),
          const SizedBox(height: Sp.s),
          Text(t.onbIntro, style: k.body),
          const SizedBox(height: Sp.xl),
          OnbFeature(
            icon: Icons.wb_sunny_outlined,
            title: t.navToday,
            text: t.onbToday,
            bg: k.subjectAt(0).bg,
            ink: k.subjectAt(0).ink,
          ),
          OnbFeature(
            icon: Icons.calendar_month_outlined,
            title: t.navCalendar,
            text: t.onbCalendar,
            bg: k.subjectAt(1).bg,
            ink: k.subjectAt(1).ink,
          ),
          OnbFeature(
            icon: Icons.menu_book_outlined,
            title: t.navCourses,
            text: t.onbCourses,
            bg: k.subjectAt(2).bg,
            ink: k.subjectAt(2).ink,
          ),
          OnbFeature(
            icon: Icons.chat_bubble_outline,
            title: t.navMessages,
            text: t.onbMessages,
            bg: k.subjectAt(3).bg,
            ink: k.subjectAt(3).ink,
          ),
        ],
        bottom: [
          Text(t.onbFamilyHint, style: k.meta, textAlign: TextAlign.center),
          const SizedBox(height: Sp.l),
          OnbButton(label: t.onbLogin, onPressed: onLogin),
        ],
      ),
    );
  }
}

/// 3 – Konto eingerichtet: bisherige Konten und „Weiteres Konto
/// hinzufügen“ (ersetzt das Dialogfenster). Gibt true zurück = weiteres.
class AccountAddedPage extends StatelessWidget {
  const AccountAddedPage({super.key, required this.accounts});

  /// „Schule · Benutzer“ je eingerichtetem Konto.
  final List<String> accounts;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    return PopScope(
      canPop: false,
      child: OnbPage(
        step: t.onbStep(1, 2),
        top: [
          const SizedBox(height: Sp.l),
          Text(
            accounts.length == 1 ? t.onbAccountReady : t.onbAccountsReady,
            style: k.pageTitle,
          ),
          const SizedBox(height: Sp.l),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.l,
              vertical: Sp.s,
            ),
            decoration: BoxDecoration(
              color: k.p.card,
              borderRadius: BorderRadius.circular(Rad.box),
              boxShadow: k.cardShadow,
            ),
            child: Column(
              children: [
                for (final (i, a) in accounts.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Sp.s),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: k.kid(i).accent,
                          size: Sz.navIcon,
                        ),
                        const SizedBox(width: Sp.m),
                        Expanded(child: Text(a, style: k.body)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Sp.xl),
          Container(
            padding: const EdgeInsets.all(Sp.l),
            decoration: BoxDecoration(
              color: k.p.inset,
              borderRadius: BorderRadius.circular(Rad.panel),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.family_restroom, color: k.p.ink),
                const SizedBox(width: Sp.m),
                Expanded(child: Text(t.onbAnotherHint, style: k.body)),
              ],
            ),
          ),
        ],
        bottom: [
          OnbButton(
            label: t.addAnotherAccount,
            icon: Icons.add,
            strong: false,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: Sp.m),
          OnbButton(
            label: t.onbContinue,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

/// 4 – Benachrichtigungen: erst erklären, dann fragen.
///
/// Ursache: Bisher kam die Frage von Android gleich beim ersten Start
/// (StartupScreen.requestPermissions), bevor man wusste, wofür. Grenze: Sagt
/// man hier „Später“, fragt die App nicht von selbst wieder; einschalten geht
/// in den Einstellungen unter „Benachrichtigungen“.
class NotifyIntroPage extends StatelessWidget {
  const NotifyIntroPage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    return PopScope(
      canPop: false,
      child: OnbPage(
        step: t.onbStep(2, 2),
        top: [
          const SizedBox(height: Sp.l),
          Text(t.onbNotifyTitle, style: k.pageTitle),
          const SizedBox(height: Sp.s),
          Text(t.onbNotifyIntro, style: k.meta),
          const SizedBox(height: Sp.xl),
          OnbFeature(
            icon: Icons.event_busy,
            title: t.onbNotifyChanges,
            text: t.onbNotifyChangesText,
            bg: k.p.cancel.bg,
            ink: k.p.cancel.ink,
          ),
          OnbFeature(
            icon: Icons.grading_outlined,
            title: t.onbNotifyGrades,
            text: t.onbNotifyGradesText,
            bg: k.subjectAt(4).bg,
            ink: k.subjectAt(4).ink,
          ),
          OnbFeature(
            icon: Icons.campaign_outlined,
            title: t.onbNotifyEvents,
            text: t.onbNotifyEventsText,
            bg: k.p.change.bg,
            ink: k.p.change.ink,
          ),
        ],
        bottom: [
          Text(t.onbNotifyLater, style: k.meta, textAlign: TextAlign.center),
          const SizedBox(height: Sp.l),
          OnbButton(
            label: t.onbNotifyAllow,
            icon: Icons.notifications_active_outlined,
            onPressed: () async {
              await Permission.notification.request();
              onDone();
            },
          ),
          const SizedBox(height: Sp.s),
          Center(
            child: TextButton(
              onPressed: onDone,
              child: Text(t.later, style: k.link),
            ),
          ),
        ],
      ),
    );
  }
}
