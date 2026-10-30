import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import 'package:lanis/background_service.dart' show refreshBackgroundService;
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/fork_identity.dart';
import 'package:lanis/fork/start.dart' show firstSupportedHomePath;
import 'package:lanis/utils/safe_launch.dart';
import 'package:lanis/utils/theme_settings.dart';

import '../../account_removal.dart';
import '../../calendar_subscribe.dart';
import '../../class_choice.dart';
import '../../kid_colors.dart';
import '../../demo/demo_entry.dart';
import '../../demo/demo_mode.dart';
import '../../error_log.dart';
import '../../l10n/l10n.dart';
import '../font_step.dart';
import '../language.dart';
import '../kit.dart';
import '../live/family.dart';
import '../live/live_data.dart'
    show
        LiveData,
        LiveSnapshot,
        detectedClassName,
        settingsRevision,
        showPhotosSetting;
import 'class_sheet.dart';
import '../today/today_from_lanis.dart' show shortSchoolName;
import 'about_page.dart';
import '../../notify/notify_keys.dart';
import '../../widget/home_widget_data.dart' show widgetAccounts;
import '../../widget/widget_legend.dart';
import '../../widget/home_widget_sync.dart'
    show storeWidgetKidSelection, widgetKidSelection;
import 'notify_settings_page.dart';
import 'settings_widgets.dart';
import 'device_transfer_page.dart';

/// Einstellungen im Stil der neuen Oberfläche (Entscheidung 17.10.26).
///
/// Ursache: Die Lanis-Einstellungen sahen anders aus als der Rest und
/// enthielten für Eltern Überflüssiges (Farbschemata, Moodle, Mitwirkende,
/// Stundenplan-Anpassung). Geblieben ist: Konto, Benachrichtigungen,
/// Darstellung, Daten, Über die App, Fehlersuche. Grenze: Der Debug-Export
/// öffnet weiter die bisherige Seite – er ist ein Werkzeug für Rückfragen,
/// kein Alltagsteil.
class ForkSettingsPage extends ConsumerStatefulWidget {
  const ForkSettingsPage({super.key});

  @override
  ConsumerState<ForkSettingsPage> createState() => _ForkSettingsPageState();
}

class _ForkSettingsPageState extends ConsumerState<ForkSettingsPage> {
  PermissionStatus? _permission;

  @override
  void initState() {
    super.initState();
    // Ohne Plattform (Tests) wirft das; die Seite nimmt die Erlaubnis dann
    // als erteilt an.
    Permission.notification.status
        .then((s) {
          if (mounted) setState(() => _permission = s);
        })
        .catchError((Object _) {});
  }

  static String? _typeOf(ForkL10n t, AccountType? type) => switch (type) {
    AccountType.parent => t.parentAccount,
    AccountType.student => t.studentAccount,
    AccountType.teacher => t.teacherAccount,
    _ => null,
  };

  // ---- Konto ---------------------------------------------------------------

  /// Klasse ändern (class_sheet.dart); null ohne Daten oder für Lehrkräfte.
  VoidCallback? _classTap(FamilyMember? m) {
    final s = m?.snapshot;
    if (m == null ||
        s == null ||
        s.setClass == null ||
        s.session.accountTypeOrNull == AccountType.teacher) {
      return null;
    }
    return () async {
      final t = context.t;
      final r = await showClassSheet(
        context,
        kidName: s.firstName.isEmpty ? t.yourChild : s.firstName,
        school: shortSchoolName(s.schoolName),
        colorIndex: m.colorIndex,
        detected: detectedClassName(s),
        current: s.classChoice?.name ?? '',
        hasEntry: s.classChoice != null,
      );
      if (r == null || !mounted) return;
      s.setClass!(r.name);
    };
  }

  /// Konto des Kindes [m] abmelden und vom Gerät entfernen.
  Future<void> _logout(FamilyMember m) async {
    final k = Kit.of(context);
    final t = context.t;
    final account = m.snapshot.session.account;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.logoutQuestion, style: k.sheetTitle),
        content: Text(t.logoutText, style: k.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel, style: k.link),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.logout, style: k.link),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // Wie die bisherige Ansicht (home_page.dart, _logout).
    final router = GoRouter.of(context);
    // Fork (Sicherheitsprüfung 17.10.26): Auf geteilten Familiengeräten
    // sollen nach dem Abmelden keine Dateien und keine Moodle-Anmeldung
    // dieses Kontos zurückbleiben. Seit der Prüfung 27.10.26 ein Weg für
    // alle Stellen (removeAccountFromDevice, fork/account_removal.dart).
    await removeAccountFromDevice(ref, account.localId);
    if (!mounted) return;
    final phase = ref.read(authControllerProvider).phase;
    router.go(
      phase == AuthPhase.authenticated
          ? firstSupportedHomePath(ref)
          : '/welcome',
    );
  }

  void _openUserData(LanisSession session) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _UserDataPage(data: session.userData),
      ),
    );
  }

  // ---- Benachrichtigungen ---------------------------------------------------

  Future<void> _askPermission() async {
    final s = await Permission.notification.request();
    if (s.isPermanentlyDenied) await openAppSettings();
    final now = await Permission.notification.status;
    // Fork: siehe setupBackgroundService (Prüfung 27.10.26).
    if (now.isGranted) unawaited(refreshBackgroundService());
    if (mounted) setState(() => _permission = now);
  }

  // ---- Termine abonnieren -----------------------------------------------------

  Future<void> _calendarLink() async {
    final k = Kit.of(context);
    final t = context.t;
    final parser = ref.read(calendarParserProvider);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.subscribeEvents, style: k.sheetTitle),
        content: FutureBuilder(
          future: parser.getExports(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text(t.subscribeFailed, style: k.body);
            }
            final link = snap.data?.subscriptionLink;
            if (link == null) {
              return const SizedBox(
                height: Sz.button,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.subscribeText, style: k.meta),
                const SizedBox(height: Sp.m),
                SelectableText(link, style: k.body),
                const SizedBox(height: Sp.m),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    safeLaunchUrl(
                      googleCalendarSubscribeUrl(link),
                      context: this.context,
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: Text(t.openInGoogleCalendar, style: k.link),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.copy),
                  label: Text(t.copyAddress, style: k.link),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.close, style: k.link),
          ),
        ],
      ),
    );
  }

  // ---- Kind -----------------------------------------------------------------

  Widget _avatar(Kit k, FamilyMember m, double size) {
    final photo = m.snapshot.photo;
    final name = kidLabel(m.snapshot);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: k.kid(m.colorIndex).accent,
        shape: BoxShape.circle,
      ),
      child: photo != null
          ? Image.memory(
              photo,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            )
          : Text(
              name.isEmpty ? '?' : name.characters.first,
              style: k.avatarLetter.copyWith(color: k.p.card),
            ),
    );
  }

  /// Blatt je Kind (Entwurf 20.10.26 s2): Farbe, Klasse, Benutzerdaten,
  /// Abmelden. Ursache: Konto, Klasse und Farbe standen vorher in drei
  /// getrennten Bereichen und galten teils nur für das aktive Konto.
  Future<void> _openKid(FamilyMember m, List<FamilyMember> kids) async {
    final s = m.snapshot;
    final teacher = s.session.accountTypeOrNull == AccountType.teacher;
    final classTap = _classTap(m);
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Kit.of(context).p.card,
      builder: (sheet) {
        var color = m.colorIndex;
        return StatefulBuilder(
          builder: (sheet, setSheet) {
            final k = Kit.of(sheet);
            final t = sheet.t;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, Sp.l),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Sp.l),
                      child: Row(
                        children: [
                          _avatar(
                            k,
                            FamilyMember(
                              accountId: m.accountId,
                              snapshot: s,
                              colorIndex: color,
                            ),
                            Sz.avatar,
                          ),
                          const SizedBox(width: Sp.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(kidLabel(s), style: k.sheetTitle),
                                Text(
                                  [
                                    ?_typeOf(t, s.session.accountTypeOrNull),
                                    shortSchoolName(s.schoolName),
                                  ].join(' · '),
                                  style: k.cardMeta,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (kids.length > 1) ...[
                      const SizedBox(height: Sp.l),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Sp.l),
                        child: Text(t.kidColor, style: k.planMeta(k.p.muted)),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Sp.l - Sp.xs,
                          Sp.xs,
                          Sp.l,
                          Sp.xs,
                        ),
                        child: Row(
                          children: [
                            for (var c = 0; c < kidColorCount; c++)
                              Semantics(
                                selected: c == color,
                                button: true,
                                label: t.kidColorPick('${c + 1}'),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  // Belegte Farbe: beide Kinder tauschen.
                                  onTap: () {
                                    final db = ref.read(lanisDatabaseProvider);
                                    final next = pickKidColor(
                                      {
                                        for (final x in kids)
                                          x.accountId:
                                              x.accountId == m.accountId
                                              ? color
                                              : x.colorIndex,
                                      },
                                      m.accountId,
                                      c,
                                    );
                                    for (final e in next.entries) {
                                      storeKidColor(
                                        TypedSettings.account(db, e.key),
                                        e.value,
                                      );
                                    }
                                    settingsRevision.value++;
                                    setSheet(() => color = c);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(Sp.xs),
                                    child: Container(
                                      width: Sz.buttonSmall,
                                      height: Sz.buttonSmall,
                                      decoration: BoxDecoration(
                                        color: k.kid(c).accent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: c == color
                                          ? Icon(Icons.check, color: k.p.card)
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: Sp.s),
                    if (!teacher)
                      SettingsRow(
                        icon: Icons.school_outlined,
                        label: _classLabel(t, s),
                        detail: _classSource(t, s),
                        onTap: classTap == null
                            ? null
                            : () => Navigator.of(sheet).pop('class'),
                      ),
                    if (s.session.userData.isNotEmpty)
                      SettingsRow(
                        icon: Icons.badge_outlined,
                        label: t.userData,
                        detail: t.userDataDetail,
                        onTap: () => Navigator.of(sheet).pop('data'),
                      ),
                    SettingsRow(
                      icon: Icons.logout,
                      label: t.logoutRemove,
                      detail: t.logoutDetail,
                      ink: k.p.cancel.ink,
                      chevron: false,
                      onTap: () => Navigator.of(sheet).pop('logout'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted) return;
    switch (action) {
      case 'class':
        classTap?.call();
      case 'data':
        _openUserData(s.session);
      case 'logout':
        await _logout(m);
    }
  }

  static String _classLabel(ForkL10n t, LiveSnapshot s) {
    final c = s.classChoice?.name ?? detectedClassName(s);
    return c.isEmpty ? t.classUnknown : t.classLine(classLabel(c));
  }

  static String? _classSource(ForkL10n t, LiveSnapshot s) {
    final own = s.classChoice;
    if (own != null) return t.classManualUntil(classUntilLabel(own.until));
    return detectedClassName(s).isEmpty ? null : t.classDetected;
  }

  // ---- Sprache ----------------------------------------------------------------

  Future<void> _pickLanguage(String current) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: Kit.of(context).p.card,
    builder: (sheet) {
      final k = Kit.of(sheet);
      final t = sheet.t;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.l, 0, Sp.l, Sp.s),
              child: Text(t.language, style: k.sheetTitle),
            ),
            // Sprachnamen stehen in ihrer eigenen Sprache (so findet man die
            // eigene auch in einer fremden Oberfläche); nur „Wie das Gerät“
            // wird übersetzt.
            for (final (v, l) in _languages(t))
              SettingsChoiceRow(
                label: l,
                selected: current == v,
                onTap: () {
                  ref.read(languageProvider.notifier).set(v);
                  Navigator.of(sheet).pop();
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.l, Sp.s, Sp.l, Sp.l),
              child: Text(t.languageNote, style: k.planMeta(k.p.muted)),
            ),
          ],
        ),
      );
    },
  );

  // ---- Startbildschirm-Widget -------------------------------------------------

  /// Kinder des Startbildschirm-Widgets wählen (widgetKidsSetting,
  /// home_widget_sync.dart) – Blatt wie die Sprachwahl, aber mit Mehrfachwahl;
  /// darunter, wie man das Widget hinzufügt. Ursache (Abnahme 28.10.26,
  /// Entwurf 5): Das Widget zeigt alle Kinder der Familie, wer will, blendet
  /// einzelne aus. Grenze: Das letzte gewählte Kind lässt sich nicht
  /// abwählen (ein leeres Widget wäre nutzlos); mit nur einem Konto gibt es
  /// nichts zu wählen, das Blatt erklärt dann nur das Hinzufügen.
  Future<void> _pickWidgetKids(
    TypedSettings shared,
    List<FamilyMember> kids,
  ) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: Kit.of(context).p.card,
    // Die Legende macht das Blatt lang: scrollbar statt abgeschnitten.
    isScrollControlled: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheet) {
        final k = Kit.of(sheet);
        final t = sheet.t;
        final ids = [for (final m in kids) m.accountId];
        final shown = widgetAccounts(ids, widgetKidSelection(shared)).toSet();
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.l, 0, Sp.l, Sp.s),
                  child: Text(
                    kids.length > 1 ? t.widgetSettingPick : t.widgetSetting,
                    style: k.sheetTitle,
                  ),
                ),
                if (kids.length > 1)
                  for (final m in kids)
                    SettingsChoiceRow(
                      label: kidLabel(m.snapshot),
                      selected: shown.contains(m.accountId),
                      onTap: () {
                        final next = {...shown};
                        if (!next.remove(m.accountId)) next.add(m.accountId);
                        if (next.isEmpty) return;
                        // Alle gewählt = Vorgabe (null): Später hinzugefügte
                        // Kinder erscheinen dann von selbst.
                        storeWidgetKidSelection(
                          shared,
                          next.length == ids.length ? null : next,
                        );
                        // FamilyScope baut neu, HomeWidgetSync schreibt sofort.
                        settingsRevision.value++;
                        setSheet(() {});
                      },
                    ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.l, Sp.s, Sp.l, Sp.s),
                  child: Text(
                    t.widgetSettingHowTo(forkAppName),
                    style: k.planMeta(k.p.muted),
                  ),
                ),
                const WidgetLegend(),
              ],
            ),
          ),
        );
      },
    ),
  );

  static List<(String, String)> _languages(ForkL10n t) => [
    (languageSystem, t.likePhone),
    ('de', 'Deutsch'),
    ('en', 'English'),
    ('tr', 'Türkçe'),
  ];

  // ---- Seite ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final account = ref.watch(activeAccountProvider);
    final shared = ref.watch(sharedOverAccountSettingsProvider);
    final supported = ref.watch(supportedAppletPhpUrlsProvider);
    final errors = ErrorLog.instance.records.length;
    final theme = ref.watch(themeSettingsProvider)['theme'] as String;
    final font = ref.watch(fontStepProvider);
    final language = ref.watch(languageProvider);
    final db = ref.read(lanisDatabaseProvider);
    final granted = _permission?.isGranted ?? true;

    // Kinder: die Familie (family.dart), ohne sie das aktive Konto.
    final members = FamilyData.of(context);
    final live = LiveData.of(context);
    final kids = members.isNotEmpty
        ? members
        : [
            if (live != null)
              FamilyMember(
                accountId: live.session.account.localId,
                snapshot: live,
                colorIndex: 0,
              ),
          ];

    // Benachrichtigungen: Schalter für alle Konten, Zusammenfassung.
    final accounts = notifyAccounts(context, ref);
    final allowed = [
      for (final a in accounts)
        if (TypedSettings.account(db, a.$1).getBool(notifyAllowKey) ?? true) a,
    ];
    bool anyArea(String php) => allowed.any(
      (a) =>
          a.$4.contains(php) &&
          (TypedSettings.account(db, a.$1).getBool(notifyAreaKey(php)) ?? true),
    );
    final start = notifyTime(shared, notifyStartKey, const [6, 0]);
    final end = notifyTime(shared, notifyEndKey, const [21, 0]);
    final on = granted && allowed.isNotEmpty;
    final summary = !on
        ? t.notifyOff
        : [
            [
              if (anyArea('vertretungsplan.php')) t.notifyShortSubs,
              // Seit 9429 eigene Schalter (notify_keys.dart); ohne sie sah
              // ein Konto mit nur Terminen wie ausgeschaltet aus (Prüfung
              // 27.10.26).
              if (allowed.any(
                (a) =>
                    a.$4.contains('vertretungsplan.php') &&
                    notifyEventsOn(TypedSettings.account(db, a.$1)),
              ))
                t.notifyEvents,
              if (anyArea('nachrichten.php')) t.notifyShortMessages,
            ].join(', '),
            '${hourMinute(start)}–${hourMinute(end)}',
            if (notifyNightMessages(shared)) t.notifyNight,
          ].where((x) => x.isNotEmpty).join(' · ');

    final langName =
        {for (final (v, l) in _languages(t)) v: l}[language] ?? t.likePhone;
    // Dieselbe Wahl wie HomeWidgetSync (widgetAccounts): gewählte Kinder,
    // Vorgabe alle.
    final widgetIds = widgetAccounts([
      for (final m in kids) m.accountId,
    ], widgetKidSelection(shared)).toSet();
    final widgetKids = widgetIds.length == kids.length
        ? t.widgetAllKids
        : [
            for (final m in kids)
              if (widgetIds.contains(m.accountId)) kidLabel(m.snapshot),
          ].join(', ');

    return SettingsScaffold(
      title: t.settings,
      children: [
        SettingsSection(
          title: t.sectionKids,
          children: [
            for (final m in kids)
              SettingsRow(
                lead: _avatar(k, m, Sz.avatarSmall),
                label: kidLabel(m.snapshot),
                detail: [
                  ?_typeOf(t, m.snapshot.session.accountTypeOrNull),
                  shortSchoolName(m.snapshot.schoolName),
                  if (m.snapshot.session.accountTypeOrNull !=
                      AccountType.teacher)
                    _classLabel(t, m.snapshot),
                ].join(' · '),
                onTap: () => _openKid(m, kids),
              ),
            if (kids.isEmpty && account != null)
              SettingsRow(
                icon: Icons.person_outline,
                label: account.username,
                detail: shortSchoolName(account.schoolName),
              ),
            SettingsRow(
              icon: Icons.person_add_alt,
              label: t.switchAccount,
              onTap: () => GoRouter.of(context).push('/accounts'),
            ),
          ],
        ),
        SettingsSection(
          title: t.sectionNotifications,
          children: [
            if (!granted)
              SettingsRow(
                icon: Icons.notifications_off_outlined,
                label: t.allowNotifications,
                detail: t.notificationsBlocked,
                onTap: _askPermission,
              ),
            SettingsSwitchRow(
              icon: Icons.notifications_outlined,
              label: t.sectionNotifications,
              detail: summary,
              value: on,
              onChanged: granted && accounts.isNotEmpty
                  ? (v) {
                      setState(() {
                        for (final a in accounts) {
                          TypedSettings.account(
                            db,
                            a.$1,
                          ).setBool(notifyAllowKey, v);
                        }
                      });
                      // Fork: Abfrage stoppen bzw. wieder einrichten
                      // (setupBackgroundService, Prüfung 27.10.26).
                      unawaited(refreshBackgroundService());
                    }
                  : null,
            ),
            SettingsRow(
              icon: Icons.tune,
              label: t.notifyWhatWhen,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotifySettingsPage(),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
        SettingsSection(
          title: t.sectionAppearance,
          children: [
            SettingsSegmentsRow(
              label: t.themeLabel,
              labels: [t.themeSystemShort, t.themeLight, t.themeDark],
              selected: const [
                'system',
                'light',
                'dark',
              ].indexOf(theme).clamp(0, 2),
              onChanged: (i) {
                shared.setString('theme', const ['system', 'light', 'dark'][i]);
                notifyThemeChanged(ref);
              },
            ),
            SettingsSegmentsRow(
              label: t.fontSize,
              labels: [t.fontSmall, t.fontNormal, t.fontLarge],
              selected: KitFontStep.values.indexOf(font),
              onChanged: (i) => ref
                  .read(fontStepProvider.notifier)
                  .set(KitFontStep.values[i]),
            ),
            SettingsRow(
              icon: Icons.translate,
              label: t.language,
              detail: langName,
              onTap: () => _pickLanguage(language),
            ),
            // Nur Android: Das Startbildschirm-Widget gibt es nur dort
            // (SchoolWidget.kt; writeHomeWidget schreibt sonst nichts).
            // Ursache (Prüfung 28.10.26): Auf dem iPhone stand die Zeile mit
            // einer Anleitung, die dort ins Leere führt. Grenze: In Tests auf
            // dem Rechner (Linux) fehlt die Zeile ebenso.
            if (kids.isNotEmpty && Platform.isAndroid)
              SettingsRow(
                icon: Icons.widgets_outlined,
                label: t.widgetSetting,
                detail: kids.length > 1 ? widgetKids : null,
                onTap: () => _pickWidgetKids(shared, kids),
              ),
            // Profilfoto statt Anfangsbuchstabe (portal_extras.dart); wirkt
            // sofort über settingsRevision (live_data.dart).
            SettingsSwitchRow(
              icon: Icons.portrait_outlined,
              label: t.showPhotos,
              detail: t.showPhotosDetail,
              value: shared.getBool(showPhotosSetting) ?? true,
              onChanged: (v) {
                shared.setBool(showPhotosSetting, v);
                settingsRevision.value++;
                setState(() {});
              },
            ),
          ],
        ),
        SettingsSection(
          title: t.sectionData,
          children: [
            SettingsRow(
              icon: Icons.qr_code_2,
              label: t.devTitle,
              detail: t.devDetail,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DeviceTransferPage(),
                ),
              ),
            ),
            if (supported.contains('kalender.php'))
              SettingsRow(
                icon: Icons.event_available_outlined,
                label: t.subscribeEvents,
                detail: t.subscribeEventsDetail,
                onTap: _calendarLink,
              ),
          ],
        ),
        SettingsSection(
          title: t.sectionAbout,
          children: [
            if (errors > 0)
              errorsRow(context, errors, () {
                if (mounted) setState(() {});
              }),
            // Demo (fork/demo): ansehen bzw. beenden.
            if (demoActive)
              SettingsRow(
                icon: Icons.stop_circle_outlined,
                label: t.demoEnd,
                detail: t.demoRunningText,
                onTap: () => restartApp?.call(),
              )
            else
              SettingsRow(
                icon: Icons.play_circle_outline,
                label: t.demoTitle,
                detail: t.demoSettingDetail,
                onTap: () => showDemoChooser(context),
              ),
            SettingsRow(
              icon: Icons.info_outline,
              label: forkAppName,
              detail: t.aboutSummary,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AboutSettingsPage(),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Benutzerdaten des Portals, so wie es sie führt (nur lesen).
class _UserDataPage extends StatelessWidget {
  const _UserDataPage({required this.data});

  final Map<String, String> data;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    String label(String key) => key.isEmpty
        ? key
        : '${key[0].toUpperCase()}${key.substring(1)}'.replaceAll('_', ' ');
    // Kopf wie alle Unterseiten fest (SettingsScaffold → PinnedPage).
    return SettingsScaffold(
      title: context.t.userData,
      children: [
        const SizedBox(height: Sp.s),
        Text(context.t.userDataNote, style: k.meta),
        const SizedBox(height: Sp.l),
        for (final e in data.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.s),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Sp.l,
                vertical: Sp.m,
              ),
              decoration: BoxDecoration(
                color: k.p.card,
                borderRadius: BorderRadius.circular(Rad.signal),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label(e.key), style: k.planMeta(k.p.muted)),
                  SelectableText(e.value, style: k.body),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
