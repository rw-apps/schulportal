/// Klick-Ziele des Startbildschirm-Widgets (Entwurf 10, Vorschlag 6,
/// Abnahme 30.10.26): Name → Heute dieses Kindes, Arbeit → „Arbeiten &
/// Noten“, Aufgaben → Unterricht, Essen → Bestellung.
///
/// Ursache: Bisher öffnete jeder Tipp nur die App; wer die Arbeit sah, musste
/// Kind und Seite selbst suchen. Kotlin (SchoolWidget.kt) hängt je Element
/// eine Adresse `schulportal-widget://open?account=<id>&target=<ziel>` an
/// (home_widget: HomeWidgetLaunchIntent), die hier ankommt – beim Start
/// über [HomeWidget.initiallyLaunchedFromHomeWidget], bei laufender App über
/// [HomeWidget.widgetClicked].
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../demo/demo_mode.dart' show demoActive;
import '../ui/live/family.dart';

/// Wohin ein Tipp im Widget führt.
enum WidgetTarget { today, exams, homework, meal }

/// Ein Tipp im Widget: Kind (localId, null = keines) und Ziel.
class WidgetLaunch {
  const WidgetLaunch({required this.target, this.account});

  final int? account;
  final WidgetTarget target;

  /// Adresse aus Kotlin lesen; null, wenn sie nicht vom Widget stammt.
  /// Unbekanntes Ziel → Heute (ältere/neuere Widget-Stände bleiben
  /// bedienbar).
  static WidgetLaunch? parse(Uri? u) {
    if (u == null || u.scheme != 'schulportal-widget') return null;
    final target =
        WidgetTarget.values
            .where((t) => t.name == u.queryParameters['target'])
            .firstOrNull ??
        WidgetTarget.today;
    return WidgetLaunch(
      target: target,
      account: int.tryParse(u.queryParameters['account'] ?? ''),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WidgetLaunch &&
      other.account == account &&
      other.target == target;

  @override
  int get hashCode => Object.hash(account, target);

  @override
  String toString() => 'WidgetLaunch($account, ${target.name})';
}

/// Hört auf Tipps im Widget und führt sie aus: erst das Kind wählen
/// (FamilyData.onSelect – wie die Kind-Pillen), dann [onTarget] (Reiter
/// bzw. Seite öffnen, preview_shell.dart).
///
/// Liegt unter FamilyScope, damit es die Familie kennt. Grenze: Nicht in
/// der Demo (erfundene Kinder haben andere Konten) und nur auf Android.
class WidgetLaunchHandler extends StatefulWidget {
  const WidgetLaunchHandler({
    super.key,
    required this.onTarget,
    required this.child,
  });

  final void Function(BuildContext context, WidgetLaunch launch) onTarget;
  final Widget child;

  @override
  State<WidgetLaunchHandler> createState() => _WidgetLaunchHandlerState();
}

class _WidgetLaunchHandlerState extends State<WidgetLaunchHandler> {
  StreamSubscription<Uri?>? _sub;

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid || demoActive) return;
    try {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(
        _handle,
        onError: (_) {},
      );
      _sub = HomeWidget.widgetClicked.listen(_handle, onError: (_) {});
    } catch (_) {
      // Ohne Plattform (Tests) gibt es keine Tipps.
    }
  }

  void _handle(Uri? u) {
    final l = WidgetLaunch.parse(u);
    if (l == null) return;
    // Nach dem nächsten Bild: Beim Kaltstart baut die Familie gerade erst.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final id = l.account;
      if (id != null) FamilyData.scopeOf(context)?.onSelect?.call(id);
      widget.onTarget(context, l);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
