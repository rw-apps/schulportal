import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../mensa_store.dart';
import '../kit.dart';
import '../settings/settings_widgets.dart';

/// Blatt „Essens-Erinnerung“ (Wunsch 27.10.26): Erinnerung an nicht
/// bestelltes Essen für alle oder einzelne Wochentage abschalten – gilt für
/// die Sammel-Benachrichtigung und den gelben Hinweis auf Heute
/// (mealRemindDays). Ursache: An Tagen, an denen ein Kind ohnehin nicht in
/// der Mensa isst, wäre die Erinnerung jede Woche falsch.
Future<void> showMealRemindSheet(BuildContext context, String owner) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Kit.of(context).p.bg,
      builder: (_) => _MealRemindSheet(owner: owner),
    );

class _MealRemindSheet extends StatefulWidget {
  const _MealRemindSheet({required this.owner});

  final String owner;

  @override
  State<_MealRemindSheet> createState() => _MealRemindSheetState();
}

class _MealRemindSheetState extends State<_MealRemindSheet> {
  final _s = MealCache.instance.settings;
  late Set<int> _days = mealRemindDays(_s, widget.owner);

  void _set(Set<int> d) {
    setState(() => _days = d);
    final s = _s;
    if (s != null) {
      setMealRemindDays(s, widget.owner, d);
      // Heute und Sammelmeldung gleich nachziehen (Prüfung 27.10.26).
      MealCache.instance.touch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    // Montag einer beliebigen Woche: Wochentagsnamen in der App-Sprache.
    final monday = DateTime(2026, 10, 26);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, Sp.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.mealRemindTitle, style: k.sheetTitle),
            const SizedBox(height: Sp.s),
            Text(t.mealRemindText, style: k.meta),
            const SizedBox(height: Sp.l),
            SettingsGroup(
              children: [
                SettingsSwitchRow(
                  label: t.mealRemindAll,
                  icon: Icons.notifications_active_outlined,
                  value: _days.isNotEmpty,
                  onChanged: (v) => _set(v ? {1, 2, 3, 4, 5} : {}),
                ),
              ],
            ),
            if (_days.isNotEmpty) ...[
              const SizedBox(height: Sp.m),
              SettingsGroup(
                children: [
                  for (var i = 1; i <= 5; i++)
                    SettingsSwitchRow(
                      label: formatDate(
                        t,
                        'EEEE',
                        monday.add(Duration(days: i - 1)),
                      ),
                      value: _days.contains(i),
                      onChanged: (v) =>
                          _set(v ? {..._days, i} : ({..._days}..remove(i))),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
