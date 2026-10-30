import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import '../../demo/demo_mode.dart' show demoActive;
import '../../error_log.dart';
import '../../l10n/l10n.dart';
import '../../report_relay.dart';
import '../kit.dart';
import 'hint_card.dart';

String reportOs() {
  try {
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  } catch (_) {
    return '';
  }
}

/// Soll Heute fragen, ob Fehler automatisch gemeldet werden dürfen? Nur
/// mit eingerichtetem Dienst, noch nicht entschieden und erst, wenn es
/// etwas zu melden gibt. Ursache (Entwurf 26.10.26): Eine Frage ohne
/// Anlass wirkt wie Werbung; mit einem erkannten Fehler ist sie verständlich.
///
/// Nicht in der Demo. Ursache (Bildschirmfoto 30.10.26): Die Frage
/// erschien in der Schüler-Demo, weil das Fehlerprotokoll der echten App
/// Einträge hatte – in einer erfundenen Schule wirkt sie fehl am Platz.
bool autoReportPromptDue(TypedSettings settings, {ErrorLog? log}) =>
    !demoActive &&
    relayConfigured &&
    settings.getBool(autoReportKey) == null &&
    (log ?? ErrorLog.instance).records.isNotEmpty;

/// Karte „Fehler automatisch melden?“ mit „Erlauben“ und „Nicht jetzt“
/// (abgenommen 26.10.26). Beides wird gespeichert; ändern lässt es sich
/// unter Über die App → Fehlersuche.
class AutoReportPrompt extends ConsumerStatefulWidget {
  const AutoReportPrompt({super.key});

  @override
  ConsumerState<AutoReportPrompt> createState() => _AutoReportPromptState();
}

class _AutoReportPromptState extends ConsumerState<AutoReportPrompt> {
  bool _done = false;

  void _decide(bool allow) {
    final s = ref.read(sharedOverAccountSettingsProvider);
    s.setBool(autoReportKey, allow);
    setState(() => _done = true);
    if (allow) flushErrorReports(s, os: reportOs());
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();
    final t = context.t;
    final k = Kit.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HintCard(
          icon: Icons.outgoing_mail,
          title: t.autoReportTitle,
          text: t.autoReportText,
          action: t.autoReportAllow,
          onAction: () => _decide(true),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _decide(false),
            child: Text(t.autoReportLater, style: k.link),
          ),
        ),
      ],
    );
  }
}
