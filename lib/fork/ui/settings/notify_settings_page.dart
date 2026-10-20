import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import '../../l10n/l10n.dart';
import '../kit.dart';
import '../live/family.dart';
import 'settings_widgets.dart';

/// Schlüssel der Benachrichtigungen (wie background_service.dart sie liest):
/// je Konto an/aus und je Bereich, für alle Konten das Zeitfenster.
const notifyAllowKey = 'notifications-allow';
String notifyAreaKey(String php) => 'notification-$php';
const notifyStartKey = 'notifications-start-time';
const notifyEndKey = 'notifications-end-time';

List<int> notifyTime(TypedSettings shared, String key, List<int> fallback) => [
  for (final v in shared.getJsonList(key) ?? fallback) v as int,
];

String hourMinute(List<int> v) => '${v[0]}:${v[1].toString().padLeft(2, '0')}';

/// Konten, für die es Einstellungen gibt: die Familie, sonst das aktive.
List<(int id, String name, LanisSession? session, Set<String> offered)>
notifyAccounts(BuildContext context, WidgetRef ref) {
  final members = FamilyData.of(context);
  if (members.isNotEmpty) {
    return [
      for (final m in members)
        (
          m.accountId,
          kidLabel(m.snapshot),
          m.snapshot.session,
          {
            for (final php in const ['vertretungsplan.php', 'nachrichten.php'])
              if (m.snapshot.offers(php)) php,
          },
        ),
    ];
  }
  final account = ref.watch(activeAccountProvider);
  if (account == null) return const [];
  return [
    (
      account.localId,
      '',
      ref.watch(sessionProvider).asData?.value,
      ref.watch(supportedAppletPhpUrlsProvider),
    ),
  ];
}

/// „Was und wann“ (Entwurf 20.10.26 „verdichtet“): Zeitfenster und je Kind
/// die Bereiche.
///
/// Ursache für „je Kind“: Vorher galten die Schalter nur für das oben
/// aktive Konto; die übrigen Kinder ließen sich nicht einstellen, obwohl
/// der Hintergrund für jedes Konto eigene Werte liest.
class NotifySettingsPage extends ConsumerStatefulWidget {
  const NotifySettingsPage({super.key});

  @override
  ConsumerState<NotifySettingsPage> createState() => _NotifySettingsPageState();
}

class _NotifySettingsPageState extends ConsumerState<NotifySettingsPage> {
  Future<void> _pickTime(
    TypedSettings shared,
    String key,
    List<int> cur,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur[0], minute: cur[1]),
    );
    if (picked == null || !mounted) return;
    shared.setJsonList(key, [picked.hour, picked.minute]);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final shared = ref.watch(sharedOverAccountSettingsProvider);
    final db = ref.read(lanisDatabaseProvider);
    final start = notifyTime(shared, notifyStartKey, const [6, 0]);
    final end = notifyTime(shared, notifyEndKey, const [21, 0]);
    final accounts = notifyAccounts(context, ref);
    return SettingsScaffold(
      title: t.notifyWhatWhen,
      children: [
        SettingsSection(
          title: t.timeWindow,
          children: [
            SettingsRow(
              icon: Icons.schedule,
              label: t.timeWindow,
              detail: t.timeWindowDetail,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => _pickTime(shared, notifyStartKey, start),
                    child: Text(hourMinute(start), style: k.link),
                  ),
                  Text('–', style: k.meta),
                  TextButton(
                    onPressed: () => _pickTime(shared, notifyEndKey, end),
                    child: Text(hourMinute(end), style: k.link),
                  ),
                ],
              ),
            ),
          ],
        ),
        for (final (id, name, _, offered) in accounts)
          if (offered.isNotEmpty)
            Builder(
              builder: (context) {
                final s = TypedSettings.account(db, id);
                final allow = s.getBool(notifyAllowKey) ?? true;
                bool area(String php) => s.getBool(notifyAreaKey(php)) ?? true;
                return SettingsSection(
                  title: name.isEmpty ? t.sectionNotifications : name,
                  children: [
                    if (offered.contains('vertretungsplan.php'))
                      SettingsSwitchRow(
                        label: t.notifySubstitutions,
                        detail: t.notifySubstitutionsDetail,
                        value: allow && area('vertretungsplan.php'),
                        onChanged: allow
                            ? (v) => setState(
                                () => s.setBool(
                                  notifyAreaKey('vertretungsplan.php'),
                                  v,
                                ),
                              )
                            : null,
                      ),
                    if (offered.contains('nachrichten.php'))
                      SettingsSwitchRow(
                        label: t.notifyMessages,
                        value: allow && area('nachrichten.php'),
                        onChanged: allow
                            ? (v) => setState(
                                () => s.setBool(
                                  notifyAreaKey('nachrichten.php'),
                                  v,
                                ),
                              )
                            : null,
                      ),
                  ],
                );
              },
            ),
      ],
    );
  }
}
