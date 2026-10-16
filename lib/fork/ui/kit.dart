import 'package:flutter/material.dart';

/// Design-Kit der neuen Oberfläche („Schulportal“-Fork).
///
/// Regel: Neue Seiten setzen KEINE Schriftgrößen, Farben, Abstände oder Radien
/// von Hand, sondern nehmen sie nur von hier ([Sp], [Rad], [Kit]). Ursache:
/// Die Lanis-Seiten mischen handgesetzte Werte (z. B. Stundenplan-Kacheln mit
/// eigenen Schriftgrößen), das ergab das uneinheitliche Bild aus den
/// Screenshots vom 16.10.26. Grenze: Die übernommenen Lanis-Seiten bleiben
/// vorerst, wie sie sind; das Kit gilt für alles, was der Fork neu baut.
///
/// Farben leiten sich aus dem App-Farbschema ab (hell/dunkel, AMOLED,
/// Schulfarbe), dazu je Kind eine eigene Farbfamilie ([Kit.child]) und zwei
/// Signalfarben für Änderungen ([Kit.change], [Kit.cancel]).

/// Abstände (logische Pixel).
abstract final class Sp {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Seitenrand links/rechts.
  static const double page = 16;
}

/// Feste Größen von Bausteinen.
abstract final class Sz {
  /// Symbole in Zeilen und Hinweisen.
  static const double icon = 18;

  /// Radius des Kind-Avatars auf der Karte.
  static const double avatar = 20;

  /// Breite der linken Marken-Spalte („JETZT“, „Mo 26.10.“), damit Inhalte
  /// untereinander bündig stehen. 76 statt 64: Bei Systemschrift ×1,15
  /// (Pixel-Screenshots 16.10.26) brach „Mo 26.10.“ in zwei Zeilen um.
  static const double tagColumn = 76;

  /// Breite des Farbbalkens eines Kindes.
  static const double bar = 4;
}

/// Eckenradien.
abstract final class Rad {
  static const double chip = 10;
  static const double card = 20;
  static const double tile = 14;
}

/// Farbfamilie für ein Kind oder ein Signal: kräftige Farbe für Punkt/Balken,
/// Container mit passender Schrift für Flächen.
class KitTone {
  const KitTone({
    required this.accent,
    required this.container,
    required this.onContainer,
  });

  final Color accent;
  final Color container;
  final Color onContainer;

  factory KitTone.fromSeed(Color seed, Brightness b) {
    final s = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    return KitTone(
      accent: s.primary,
      container: s.primaryContainer,
      onContainer: s.onPrimaryContainer,
    );
  }
}

/// Zugriff auf Kit-Formate und -Farben im aktuellen Kontext.
class Kit {
  Kit._(this._theme);

  factory Kit.of(BuildContext context) => Kit._(Theme.of(context));

  final ThemeData _theme;

  ColorScheme get cs => _theme.colorScheme;
  TextTheme get _t => _theme.textTheme;
  Brightness get _b => _theme.brightness;

  // ---- Farben je Kind ----------------------------------------------------

  /// Grundtöne der Kinder, in dieser Reihenfolge vergeben. Gewählt für
  /// deutlichen Abstand untereinander und zu den Signalfarben (kein Rot,
  /// kein Bernstein), damit „Kind“ und „Änderung“ nie verwechselt werden.
  static const childSeeds = <Color>[
    Color(0xFF1E88E5), // Blau
    Color(0xFF00897B), // Petrol
    Color(0xFF8E24AA), // Violett
    Color(0xFF7CB342), // Grün
  ];

  KitTone child(int index) =>
      KitTone.fromSeed(childSeeds[index % childSeeds.length], _b);

  // ---- Signalfarben ------------------------------------------------------

  /// Vertretung / Raumwechsel: findet statt, aber anders.
  KitTone get change => KitTone.fromSeed(const Color(0xFFFFA000), _b);

  /// Ausfall: findet nicht statt.
  KitTone get cancel => KitTone(
    accent: cs.error,
    container: cs.errorContainer,
    onContainer: cs.onErrorContainer,
  );

  // ---- Flächen -----------------------------------------------------------

  Color get pageBg => cs.surface;
  Color get cardBg => cs.surfaceContainerLow;
  Color get insetBg => cs.surfaceContainerHigh;
  Color get divider => cs.outlineVariant;

  // ---- Textformate -------------------------------------------------------
  // Benannt nach Aufgabe, nicht nach Größe. Neue Formate hier ergänzen.

  /// Seitentitel in der Kopfzeile („Heute“).
  TextStyle get pageTitle => _t.headlineSmall!.copyWith(
    fontWeight: FontWeight.w600,
    color: cs.onSurface,
  );

  /// Zeile unter dem Seitentitel (Datum).
  TextStyle get pageSub => _t.bodyMedium!.copyWith(color: cs.onSurfaceVariant);

  /// Abschnittsüberschrift („Diese Woche“).
  TextStyle get section => _t.titleSmall!.copyWith(
    fontWeight: FontWeight.w600,
    color: cs.onSurfaceVariant,
    letterSpacing: 0.4,
  );

  /// Name auf einer Karte.
  TextStyle get cardTitle => _t.titleMedium!.copyWith(
    fontWeight: FontWeight.w600,
    color: cs.onSurface,
  );

  /// Meta-Zeile (Schule · Klasse, Uhrzeit, Raum).
  TextStyle get meta => _t.bodySmall!.copyWith(color: cs.onSurfaceVariant);

  /// Hauptinhalt einer Zeile („Mathematik“).
  TextStyle get body => _t.bodyLarge!.copyWith(color: cs.onSurface);

  /// Hervorgehobener Inhalt („Jetzt: Mathematik“).
  TextStyle get bodyStrong =>
      body.copyWith(fontWeight: FontWeight.w600);

  /// Kleine Marke vor einer Zeile („JETZT“, „DANACH“).
  TextStyle get tag => _t.labelSmall!.copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: cs.onSurfaceVariant,
  );

  /// Text in Hinweis-Flächen (Vertretung, Ausfall).
  TextStyle signal(KitTone tone) =>
      _t.bodyMedium!.copyWith(color: tone.onContainer);

  TextStyle signalStrong(KitTone tone) =>
      signal(tone).copyWith(fontWeight: FontWeight.w700);

  /// Zähler-Chips („2 Hausaufgaben“).
  TextStyle get chip => _t.labelLarge!.copyWith(color: cs.onSurface);
}
