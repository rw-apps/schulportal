import 'package:flutter/material.dart';

import 'live/family.dart';

/// Lese-Seite im Navigator des Reiters öffnen (Leiste bleibt sichtbar), im
/// Rahmen des öffnenden Kontos.
///
/// Ursache: siehe FamilyMember.around – neue Routen erben den Rahmen des
/// Navigators, nicht den der öffnenden Seite. Grenze: Einstellungen öffnen
/// bewusst OHNE diesen Rahmen (sie gehören zum aktiven Konto, samt Abmelden).
Future<T?> pushInTab<T>(BuildContext context, WidgetBuilder builder) {
  final member = FamilyMember.around(context);
  return Navigator.of(context).push(
    MaterialPageRoute<T>(
      builder: (c) => member?.scope(builder(c)) ?? builder(c),
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
  final member = FamilyMember.around(context);
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<T>(
      builder: (c) => member?.scope(builder(c)) ?? builder(c),
    ),
  );
}
