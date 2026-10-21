import 'package:flutter/material.dart';

import 'live/family.dart';

/// Lese-Seite im Navigator des Reiters öffnen (Leiste bleibt sichtbar), im
/// Rahmen des öffnenden Kontos.
///
/// Ursache: siehe FamilyMember.around – neue Routen erben den Rahmen des
/// Navigators, nicht den der öffnenden Seite. Grenze: Einstellungen öffnen
/// bewusst OHNE diesen Rahmen (sie gehören zum aktiven Konto, samt Abmelden).
///
/// [kidChips]: Kind-Pillen oben (SubpageKidChips) – für Lese-Seiten eines
/// Kindes. [member]: Konto der Seite, wenn der Aufrufer nicht in dessen
/// Rahmen liegt (Ansichten „Alle“).
Future<T?> pushInTab<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool kidChips = false,
  FamilyMember? member,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<T>(
      builder: _once(context, builder, kidChips: kidChips, member: member),
    ),
  );
}

/// Seite zum Eingeben über der ganzen App öffnen – ohne Leiste unten, im
/// Rahmen des öffnenden Kontos.
///
/// Ursache (Entscheidung 17.10.26): Lese-Seiten (Kursseite, Unterhaltung,
/// Einstellungen) öffnen im Navigator ihres Reiters, die Leiste bleibt
/// sichtbar (preview_shell.dart, _TabNavigator). Bei Eingabe-Seiten (Neue
/// Nachricht, Krankmeldung, Abgabe, Mensa-Bestellseite) kostete die Leiste
/// Platz neben der Tastatur, und ein versehentlicher Reiterwechsel ließe den
/// angefangenen Text im Hintergrund liegen. Grenze: Auch hier gilt
/// Android-Zurück bzw. „Schließen“ oben – ein Reiterwechsel ist von dort
/// bewusst nicht möglich.
Future<T?> pushFullScreen<T>(BuildContext context, WidgetBuilder builder) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<T>(builder: _once(context, builder)));
}

/// Baut die Seite genau einmal und im Rahmen des öffnenden Kontos.
///
/// Ursache (Absturz 17.10.26, 9349, „Using ref when a widget … has been
/// unmounted“, symbolisiert: LiveCoursesPage._detail → ref.read): Eine
/// Route ruft ihren builder bei jedem Neuaufbau erneut auf (z. B. wenn sich
/// FamilyData ändert). Die Aufrufer lesen darin `ref` der öffnenden Seite –
/// die ist nach einem Kindwechsel schon entsorgt. Jetzt entsteht die Seite
/// beim ersten Aufbau direkt nach dem Öffnen und bleibt dieselbe. Grenze:
/// Was die Seite von außen bekam, aktualisiert sie nur über ihre eigenen
/// Daten (Kursseite, Unterhaltung laden selbst).
///
/// Die Kind-Pillen liegen INNERHALB des Rahmens, damit sie das Kind der
/// Seite kennen; ob „Alle“ angeboten wird, gilt wie im öffnenden Bereich
/// (FamilyArea, beim Öffnen gelesen).
WidgetBuilder _once(
  BuildContext context,
  WidgetBuilder builder, {
  bool kidChips = false,
  FamilyMember? member,
}) {
  final scoped = member ?? FamilyMember.around(context);
  final withAll = FamilyArea.withAllOf(context);
  Widget page(BuildContext c) => kidChips
      ? SubpageKidChips(withAll: withAll, child: builder(c))
      : builder(c);
  Widget? built;
  return (c) => built ??= scoped?.scope(page(c)) ?? page(c);
}
