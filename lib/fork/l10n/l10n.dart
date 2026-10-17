import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'gen/fork_l10n.dart';

export 'gen/fork_l10n.dart';

/// Texte der neuen Oberfläche: `context.t.navToday`.
///
/// Die Sprachdaten stehen in lib/fork/l10n/fork_{de,en,tr}.arb (Vorlage
/// Deutsch); daraus erzeugt `flutter pub get` die Klasse [ForkL10n] in
/// lib/fork/l10n/gen (nicht im Repository, wie lib/generated der Lanis-Texte).
/// Code enthält keine sichtbaren Texte mehr, nur Schlüssel.
extension ForkL10nContext on BuildContext {
  ForkL10n get t => ForkL10n.of(this);
}

/// Sprachen der neuen Oberfläche, in der Reihenfolge der Auswahl.
const forkLanguages = ['de', 'en', 'tr'];

/// Sprache, wenn das Handy eine nicht angebotene nutzt (z. B. Französisch).
///
/// Englisch statt Deutsch, wie zuvor bei Lanis (main_locale en): Wer das
/// Handy nicht auf Deutsch stellt, liest Englisch eher. Gilt gleich für die
/// Oberfläche (main.dart supportedLocales, erster Eintrag) und für
/// [forkL10nFor].
const fallbackLanguage = 'en';

/// Gewählte Sprache: [setting] aus den Einstellungen ('de', 'en', 'tr'), sonst
/// (leer oder 'system') die des Handys, sonst [fallbackLanguage].
String resolveLanguage(String? setting, String deviceLanguage) =>
    forkLanguages.contains(setting)
    ? setting!
    : (forkLanguages.contains(deviceLanguage)
          ? deviceLanguage
          : fallbackLanguage);

/// Texte ohne BuildContext – für reine Datenfunktionen in Tests und für die
/// Hintergrund-Benachrichtigungen (dort gibt es keinen Widget-Baum).
ForkL10n forkL10nFor(String? languageCode) => lookupForkL10n(
  Locale(
    forkLanguages.contains(languageCode) ? languageCode! : fallbackLanguage,
  ),
);

/// Datum nach dem Muster der Sprachdatei, z. B. [ForkL10n.dateLong].
///
/// Ursache für Muster in der ARB statt fester Skelette: Deutsch soll genau
/// „Dienstag, 20. Oktober“ und „Do 22.10.“ bleiben (abgenommene Ansicht),
/// das Skelett MEd ergäbe „Do., 22.10.“. Grenze: Braucht die Datumsdaten der
/// Sprache (main.dart initializeDateFormatting; in Tests
/// test/flutter_test_config.dart).
String formatDate(ForkL10n t, String pattern, DateTime d) =>
    DateFormat(pattern, t.localeName).format(d);

/// Großschreibung je Sprache. Ursache: `toUpperCase` kennt kein Türkisch und
/// macht aus „Ekim“ „EKIM“ statt „EKİM“ (i mit Punkt → İ, ı → I). Grenze:
/// Nur Türkisch braucht die Sonderregel; Deutsch/Englisch wie bisher.
String upperFor(ForkL10n t, String s) =>
    (t.localeName == 'tr' ? s.replaceAll('i', 'İ') : s).toUpperCase();

/// Kleinschreibung je Sprache (Gegenstück zu [upperFor]: I → ı, İ → i).
String lowerFor(ForkL10n t, String s) =>
    (t.localeName == 'tr' ? s.replaceAll('I', 'ı').replaceAll('İ', 'i') : s)
        .toLowerCase();
