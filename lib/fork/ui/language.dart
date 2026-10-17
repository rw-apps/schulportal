import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart' show sharedOverAccountSettingsProvider;

import '../l10n/l10n.dart';

/// Sprache der App: 'system' (wie das Handy), 'de', 'en' oder 'tr',
/// geräteweit gespeichert unter [languageKey].
///
/// Wirkt auf die ganze App (main.dart, MaterialApp.locale) – neue Oberfläche
/// (lib/fork/l10n) und übernommene Lanis-Seiten (lib/l10n) – und auf die
/// Hintergrund-Benachrichtigungen (notify_task.dart liest denselben
/// Schlüssel). Grenze: Inhalte aus dem Portal (Fächer, Termine, Nachrichten,
/// Hinweise der Schule) bleiben, wie die Schule sie schreibt.
const languageKey = 'fork-ui/language';

const languageSystem = 'system';

class LanguageNotifier extends Notifier<String> {
  @override
  String build() {
    try {
      final v = ref
          .watch(sharedOverAccountSettingsProvider)
          .getString(languageKey);
      return forkLanguages.contains(v) ? v! : languageSystem;
    } catch (_) {
      return languageSystem;
    }
  }

  void set(String language) {
    state = forkLanguages.contains(language) ? language : languageSystem;
    try {
      ref.read(sharedOverAccountSettingsProvider).setString(languageKey, state);
    } catch (_) {}
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, String>(
  LanguageNotifier.new,
);

/// Für MaterialApp.locale: null = wie das Handy.
Locale? localeFor(String language) =>
    forkLanguages.contains(language) ? Locale(language) : null;

/// Angebotene Sprachen, Ausweichsprache zuerst (MaterialApp nimmt bei einer
/// nicht angebotenen Handysprache den ersten Eintrag, [fallbackLanguage]).
const appLocales = [Locale('en'), Locale('de'), Locale('tr')];
