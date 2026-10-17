import 'package:flutter/material.dart';

/// Seite zum Eingeben über der ganzen App öffnen – ohne Leiste unten.
///
/// Ursache (Entscheidung 17.10.26): Lese-Seiten (Kursseite, Unterhaltung,
/// Einstellungen) öffnen im Navigator ihres Reiters, die Leiste bleibt
/// sichtbar (preview_shell.dart, _TabNavigator). Bei Eingabe-Seiten (Neue
/// Nachricht, Krankmeldung, Abgabe, Mensa-Bestellseite) kostete die Leiste
/// Platz neben der Tastatur, und ein versehentlicher Reiterwechsel ließe den
/// angefangenen Text im Hintergrund liegen. Grenze: Auch hier gilt
/// Android-Zurück bzw. „Schließen“ oben – ein Reiterwechsel ist von dort
/// bewusst nicht möglich.
Future<T?> pushFullScreen<T>(BuildContext context, WidgetBuilder builder) =>
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<T>(builder: builder));
