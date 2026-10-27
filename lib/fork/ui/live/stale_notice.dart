import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../today/hint_card.dart';
import '../today/today_page.dart' show standLabel;
import 'live_data.dart';

/// Zeigt die Seite einen alten Stand? Ja, wenn Inhalt da ist, der aus der
/// Ablage stammt ([Feed.offline]) oder dessen letzter Abruf scheiterte.
bool isStale(Feed<Object?> f) =>
    f.content != null && (f.offline || f.error != null);

/// Hinweis „Portal nicht erreichbar · Gespeicherter Stand von …“ – EIN
/// Baustein für Heute, Kalender und Unterricht.
///
/// Ursache (Rückmeldung 21.10.26): Seit 9401 zeigen alle drei bei einem
/// Ausfall den gespeicherten Stand; der Hinweis stand nur auf Heute, in
/// Kalender und Unterricht sah ein alter Stand aus wie ein aktueller.
/// Der Zeitpunkt ist der älteste der betroffenen Quellen (ehrlicher als der
/// neueste). Grenze: Ohne Zeitpunkt (nie geladen) kein Hinweis – dann gibt
/// es auch keinen alten Stand, nur die Fehlermeldung der Seite.
Widget? staleNotice(
  BuildContext context, {
  required Iterable<Feed<Object?>> feeds,
  required DateTime now,
  required VoidCallback onRetry,
}) {
  DateTime? oldest;
  for (final f in feeds) {
    if (!isStale(f)) continue;
    final at = f.fetchedAt;
    if (at != null && (oldest == null || at.isBefore(oldest))) oldest = at;
  }
  if (oldest == null) return null;
  final t = context.t;
  return HintCard(
    icon: Icons.cloud_off_outlined,
    title: t.staleTitle,
    text: t.staleText(standLabel(t, oldest, now)),
    action: t.staleRetry,
    onAction: onRetry,
  );
}

/// Hinweis „Der Vertretungsplan ließ sich nicht laden“ für Heute, wenn
/// [substitutions] nie geladen wurde (kein gespeicherter Stand, Abruf
/// gescheitert – Feed.failed).
///
/// Ursache (Prüfung 27.10.26): [staleNotice] meldet nur alte Stände; ohne
/// jeden Stand sah Heute dann wie ein normaler Tag aus – ein Ausfall fehlte
/// ohne Warnung. Grenze: Nur Konten, die den Vertretungsplan anbieten
/// (Aufrufer); während des Ladens kein Hinweis.
Widget? substitutionsMissingNotice(
  BuildContext context, {
  required Iterable<Feed<Object?>> substitutions,
  required VoidCallback onRetry,
}) {
  if (!substitutions.any((f) => f.failed)) return null;
  final t = context.t;
  return HintCard(
    icon: Icons.cloud_off_outlined,
    title: t.substitutionsFailedTitle,
    text: t.substitutionsFailedText,
    action: t.staleRetry,
    onAction: onRetry,
  );
}
