import 'package:flutter/material.dart';

/// Design-Kit der neuen Oberfläche („Schulportal“-Fork).
///
/// Regel: Neue Seiten setzen KEINE Schriftgrößen, Farben, Abstände oder Radien
/// von Hand, sondern nehmen sie nur von hier ([Sp], [Sz], [Rad], [Kit]).
/// Ursache: Die Lanis-Seiten mischen handgesetzte Werte, das ergab das
/// uneinheitliche Bild aus den Screenshots vom 16.10.26. Grenze: Die
/// übernommenen Lanis-Seiten bleiben vorerst, wie sie sind; das Kit gilt für
/// alles, was der Fork neu baut.
///
/// Stil: Entwurf „A + C“ (Stilrichtungen „Heute“, abgenommen 16.10.26):
/// ruhige neutrale Flächen, weiße bzw. dunkle Karten mit großem Radius,
/// Schrift Manrope (fest eingebaut, fonts/manrope), je Kind eine feste
/// Farbfamilie ([KidTone]) und zwei Signalfarben ([SignalTone]) für
/// Vertretung/Raumwechsel und Ausfall. Bewusst NICHT aus der Schulfarbe des
/// App-Themas abgeleitet: Kinder- und Signalfarben müssen auf jeder Fläche
/// gleich unterscheidbar bleiben, egal welche Farbe in Lanis eingestellt ist.

const kitFont = 'Manrope';

/// Abstände (logische Pixel).
abstract final class Sp {
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double ml = 14;
  static const double l = 16;
  static const double lx = 18;
  static const double xl = 24;
  static const double xxl = 32;

  /// Seitenrand links/rechts.
  static const double page = 16;
}

/// Feste Größen von Bausteinen.
abstract final class Sz {
  static const double icon = 18;
  static const double navIcon = 22;
  static const double avatar = 44;
  static const double dot = 8;
  static const double dotSmall = 6;

  /// Höhe der Tagesleiste je Kind.
  static const double dayBar = 10;

  /// Spalte für „3.–4.“ in der aufgeklappten Tagesliste.
  static const double slotColumn = 52;

  /// Breite einer Termin-Kachel unter „Demnächst“. 160 statt 136 aus dem
  /// Entwurf: Bei Systemschrift ×1,15 brach „Klassenarbeit“ sonst mitten
  /// im Wort um (Flutter trennt nicht nach Silben).
  static const double tileWidth = 160;

  static const double button = 56;
  static const double buttonSmall = 44;

  /// Schwebende untere Leiste: Höhe und Abstand zum Rand.
  static const double navHeight = 68;
  static const double navMargin = 16;
  static const double navBottom = 24;

  // ---- Stundenplan ------------------------------------------------------
  /// Höhe einer Stunde im Wochenraster; Doppelstunden = 2 × + Abstand.
  static const double gridRow = 54;

  /// Spalte links im Wochenraster („1.“, „08:00“).
  static const double gridLabel = 40;

  /// Fortschrittsstrich unter der laufenden Stunde (Tagesansicht).
  static const double progress = 4;

  /// Rahmen um geänderte bzw. laufende Zellen.
  static const double cellBorder = 2;
}

/// Eckenradien.
abstract final class Rad {
  static const double card = 28;
  static const double panel = 20;
  static const double tile = 22;
  static const double box = 24;
  static const double signal = 18;
  static const double button = 18;
  static const double buttonSmall = 14;
  static const double row = 12;
  static const double day = 16;
  static const double bar = 6;
  static const double nav = 34;
  static const double navItem = 22;
  static const double cell = 12;
  static const double pill = 20;
}

/// Fläche und Schrift eines Fachs im Wochenraster.
class FachTone {
  const FachTone(this.bg, this.ink);
  final Color bg;
  final Color ink;
}

/// Farbfamilie eines Kindes.
class KidTone {
  const KidTone({
    required this.accent,
    required this.tint,
    required this.onTint,
    required this.label,
    required this.meta,
    required this.barDone,
    required this.barRest,
  });

  /// Avatar, Punkte, Fortschritt.
  final Color accent;

  /// Fläche „Jetzt“ und laufende Zeile.
  final Color tint;

  /// Fachname auf [tint].
  final Color onTint;

  /// Marke „JETZT …“ auf [tint].
  final Color label;

  /// Uhrzeit/Raum auf [tint].
  final Color meta;

  /// Tagesleiste: erledigte bzw. kommende Abschnitte.
  final Color barDone;
  final Color barRest;
}

/// Signalfarbe (Vertretung/Raumwechsel bzw. Ausfall).
class SignalTone {
  const SignalTone({
    required this.bg,
    required this.ink,
    required this.strong,
    required this.bar,
    required this.dot,
  });

  final Color bg;
  final Color ink;
  final Color strong;
  final Color bar;
  final Color dot;
}

/// Flächen und Schriftfarben einer Helligkeit.
class KitPalette {
  const KitPalette({
    required this.bg,
    required this.card,
    required this.inset,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.line,
    required this.strong,
    required this.onStrong,
    required this.navBg,
    required this.navSelected,
    required this.onNavSelected,
    required this.shadow,
    required this.kids,
    required this.change,
    required this.cancel,
    required this.subjects,
  });

  /// Fachfarben fürs Wochenraster. Bewusst ohne Rot und Gelb, damit kein
  /// Fach wie eine Vertretung oder ein Ausfall aussieht.
  final List<FachTone> subjects;

  final Color bg;
  final Color card;

  /// Knöpfe und Felder innerhalb einer Karte.
  final Color inset;
  final Color ink;
  final Color muted;

  /// Erledigtes (durchgestrichene Stunden).
  final Color faint;
  final Color line;

  /// Betonter Knopf („Krank melden“), gewählter Tag.
  final Color strong;
  final Color onStrong;
  final Color navBg;
  final Color navSelected;
  final Color onNavSelected;
  final Color shadow;
  final List<KidTone> kids;
  final SignalTone change;
  final SignalTone cancel;

  /// Werte aus dem Entwurf A + C (hell).
  static const light = KitPalette(
    bg: Color(0xFFF2F4F7),
    card: Color(0xFFFFFFFF),
    inset: Color(0xFFF2F4F7),
    ink: Color(0xFF101828),
    muted: Color(0xFF5B6474),
    faint: Color(0xFF98A2B3),
    line: Color(0xFFEAECF0),
    strong: Color(0xFF101828),
    onStrong: Color(0xFFFFFFFF),
    navBg: Color(0xFFFFFFFF),
    navSelected: Color(0xFFE6EEFE),
    onNavSelected: Color(0xFF1D4ED8),
    shadow: Color(0x1F101828),
    kids: [
      KidTone(
        accent: Color(0xFF2563EB),
        tint: Color(0xFFE6EEFE),
        onTint: Color(0xFF0B1F4D),
        label: Color(0xFF1D4ED8),
        meta: Color(0xFF344A7A),
        barDone: Color(0xFF93B4F8),
        barRest: Color(0xFFD6E2FC),
      ),
      KidTone(
        accent: Color(0xFF0F8A7E),
        tint: Color(0xFFDDF3EF),
        onTint: Color(0xFF08332E),
        label: Color(0xFF0B6B61),
        meta: Color(0xFF2D5A54),
        barDone: Color(0xFF8FD6CB),
        barRest: Color(0xFFCDEDE8),
      ),
      KidTone(
        accent: Color(0xFF7C3AED),
        tint: Color(0xFFEFE7FE),
        onTint: Color(0xFF2E1065),
        label: Color(0xFF6D28D9),
        meta: Color(0xFF4C3A75),
        barDone: Color(0xFFC4A8F8),
        barRest: Color(0xFFE4D8FD),
      ),
      KidTone(
        accent: Color(0xFF4D7C0F),
        tint: Color(0xFFE9F5D6),
        onTint: Color(0xFF1F3305),
        label: Color(0xFF3F6212),
        meta: Color(0xFF44562A),
        barDone: Color(0xFFB5D67F),
        barRest: Color(0xFFD7EBB5),
      ),
    ],
    change: SignalTone(
      bg: Color(0xFFFEF0C7),
      ink: Color(0xFF7A2E0E),
      strong: Color(0xFF93370D),
      bar: Color(0xFFFDD68A),
      dot: Color(0xFFF5B000),
    ),
    cancel: SignalTone(
      bg: Color(0xFFFEE4E2),
      ink: Color(0xFF912018),
      strong: Color(0xFF912018),
      bar: Color(0xFFFDA29B),
      dot: Color(0xFFD92D20),
    ),
    subjects: [
      FachTone(Color(0xFFE0EAFF), Color(0xFF1E3A8A)),
      FachTone(Color(0xFFD5F2EC), Color(0xFF134E48)),
      FachTone(Color(0xFFECE4FF), Color(0xFF4C1D95)),
      FachTone(Color(0xFFE4F2D3), Color(0xFF365314)),
      FachTone(Color(0xFFDCF0FA), Color(0xFF0C4A6E)),
      FachTone(Color(0xFFE6E9EF), Color(0xFF334155)),
      FachTone(Color(0xFFE8E7FF), Color(0xFF3730A3)),
      FachTone(Color(0xFFEEF0D8), Color(0xFF4A5216)),
    ],
  );

  /// Dunkle Fassung derselben Familie (Töne aus Entwurf B/C abgeleitet).
  static const dark = KitPalette(
    bg: Color(0xFF0E1116),
    card: Color(0xFF171B22),
    inset: Color(0xFF222833),
    ink: Color(0xFFF2F4F8),
    muted: Color(0xFF9AA3B2),
    faint: Color(0xFF5F6878),
    line: Color(0xFF2A303A),
    strong: Color(0xFFF2F4F8),
    onStrong: Color(0xFF0E1116),
    navBg: Color(0xFF1B2029),
    navSelected: Color(0xFF26324A),
    onNavSelected: Color(0xFFA9C9FF),
    shadow: Color(0x66000000),
    kids: [
      KidTone(
        accent: Color(0xFF6EA2FF),
        tint: Color(0xFF1A2741),
        onTint: Color(0xFFE6EEFE),
        label: Color(0xFF8AB6FF),
        meta: Color(0xFFB9CBEA),
        barDone: Color(0xFF3E5F99),
        barRest: Color(0xFF26324A),
      ),
      KidTone(
        accent: Color(0xFF2DD4BF),
        tint: Color(0xFF12302C),
        onTint: Color(0xFFDDF3EF),
        label: Color(0xFF5EEAD4),
        meta: Color(0xFFA8DCD5),
        barDone: Color(0xFF1F6F66),
        barRest: Color(0xFF1B3B37),
      ),
      KidTone(
        accent: Color(0xFFA78BFA),
        tint: Color(0xFF2A1F45),
        onTint: Color(0xFFEFE7FE),
        label: Color(0xFFC4B5FD),
        meta: Color(0xFFCFC3EE),
        barDone: Color(0xFF5B45A0),
        barRest: Color(0xFF352A55),
      ),
      KidTone(
        accent: Color(0xFFA3E635),
        tint: Color(0xFF22301A),
        onTint: Color(0xFFECF5D8),
        label: Color(0xFFBEF264),
        meta: Color(0xFFCFE3B0),
        barDone: Color(0xFF5E7F2A),
        barRest: Color(0xFF2F3F22),
      ),
    ],
    change: SignalTone(
      bg: Color(0xFF2A2208),
      ink: Color(0xFFFDE7A8),
      strong: Color(0xFFF5C451),
      bar: Color(0xFF8A6A12),
      dot: Color(0xFFE0A100),
    ),
    cancel: SignalTone(
      bg: Color(0xFF3A1414),
      ink: Color(0xFFFECACA),
      strong: Color(0xFFFCA5A5),
      bar: Color(0xFF7F2A2A),
      dot: Color(0xFFF87171),
    ),
    subjects: [
      FachTone(Color(0xFF1E2A47), Color(0xFFC7D7FE)),
      FachTone(Color(0xFF15332F), Color(0xFFBDEDE4)),
      FachTone(Color(0xFF2B2245), Color(0xFFDDD3FE)),
      FachTone(Color(0xFF22301A), Color(0xFFD4EBB5)),
      FachTone(Color(0xFF152F3D), Color(0xFFC3E6F7)),
      FachTone(Color(0xFF262C36), Color(0xFFD5DBE5)),
      FachTone(Color(0xFF24234A), Color(0xFFD0CFFD)),
      FachTone(Color(0xFF2B2E1A), Color(0xFFE0E4B8)),
    ],
  );
}

/// Zugriff auf Kit-Farben und -Textformate im aktuellen Kontext.
class Kit {
  Kit._(this.p);

  factory Kit.of(BuildContext context) => Kit._(
    Theme.of(context).brightness == Brightness.dark
        ? KitPalette.dark
        : KitPalette.light,
  );

  final KitPalette p;

  KidTone kid(int index) => p.kids[index % p.kids.length];

  /// Feste Fachfarbe aus dem Kürzel (gleiches Fach = gleiche Farbe, über
  /// Tage und Wochen hinweg). Eigene Summe statt String.hashCode, weil
  /// dessen Wert zwischen Dart-Versionen nicht garantiert gleich bleibt.
  FachTone subject(String short) {
    var h = 0;
    for (final c in short.toUpperCase().codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return p.subjects[h % p.subjects.length];
  }

  TextStyle _s(double size, FontWeight w, Color c, {double ls = 0}) =>
      TextStyle(
        fontFamily: kitFont,
        fontSize: size,
        fontWeight: w,
        color: c,
        letterSpacing: ls,
        height: 1.3,
      );

  // ---- Kopf -------------------------------------------------------------
  /// „DIENSTAG, 20. OKTOBER“
  TextStyle get dateCaps => _s(12, FontWeight.w700, p.muted, ls: 1.2);

  /// „Guten Morgen“
  TextStyle get greeting => _s(32, FontWeight.w800, p.ink, ls: -0.6);

  /// Seitentitel auf Unterseiten (Platzhalter).
  TextStyle get pageTitle => _s(28, FontWeight.w800, p.ink, ls: -0.4);

  // ---- Wochenleiste -----------------------------------------------------
  TextStyle weekDay(bool selected) =>
      _s(12, FontWeight.w600, selected ? p.onStrong : p.muted);
  TextStyle weekNum(bool selected) => _s(
    18,
    selected ? FontWeight.w800 : FontWeight.w700,
    selected ? p.onStrong : p.ink,
  );

  // ---- Kasten „Wichtig“ -------------------------------------------------
  TextStyle get boxTitle =>
      _s(12, FontWeight.w800, p.change.strong, ls: 1.2);
  TextStyle boxText(SignalTone t) => _s(14, FontWeight.w500, t.ink);
  TextStyle boxStrong(SignalTone t) => _s(14, FontWeight.w800, t.ink);

  // ---- Karte ------------------------------------------------------------
  TextStyle get cardName => _s(19, FontWeight.w800, p.ink);
  TextStyle get cardMeta => _s(13, FontWeight.w500, p.muted);
  TextStyle get avatarLetter => _s(18, FontWeight.w800, p.onStrong);

  TextStyle nowLabel(KidTone t) => _s(11, FontWeight.w800, t.label, ls: 1);
  TextStyle nowSubject(KidTone t) => _s(22, FontWeight.w800, t.onTint);
  TextStyle nowMeta(KidTone t) => _s(13, FontWeight.w500, t.meta);

  TextStyle get barLabel => _s(11, FontWeight.w600, p.muted);

  // Aufgeklappte Tagesliste
  TextStyle rowSlot(Color c) => _s(12, FontWeight.w700, c);
  TextStyle rowSubject(Color c, {bool strong = false}) =>
      _s(15, strong ? FontWeight.w800 : FontWeight.w600, c);
  TextStyle rowTime(Color c) => _s(12, FontWeight.w500, c);
  TextStyle get rowPause => _s(12, FontWeight.w600, p.faint);

  TextStyle button(Color c) => _s(14, FontWeight.w700, c);

  // ---- Demnächst --------------------------------------------------------
  TextStyle get section => _s(18, FontWeight.w800, p.ink);
  TextStyle get link => _s(14, FontWeight.w700, p.onNavSelected);
  TextStyle get tileCaption => _s(12, FontWeight.w700, p.muted);
  TextStyle get tileTitle => _s(15, FontWeight.w800, p.ink);
  TextStyle tileKid(Color c) => _s(12, FontWeight.w700, c);

  // ---- Leiste unten -----------------------------------------------------
  TextStyle navLabel(bool selected) => _s(
    11,
    selected ? FontWeight.w800 : FontWeight.w700,
    selected ? p.onNavSelected : p.muted,
  );

  // ---- Stundenplan ------------------------------------------------------
  TextStyle chipLabel(bool selected, Color selectedInk) => _s(
    14,
    FontWeight.w700,
    selected ? selectedInk : p.ink,
  );
  TextStyle get timeStart => _s(13, FontWeight.w800, p.ink);
  TextStyle get timeEnd => _s(12, FontWeight.w500, p.faint);
  TextStyle planSubject(Color c) => _s(16, FontWeight.w800, c);
  TextStyle planMeta(Color c) => _s(13, FontWeight.w500, c);
  TextStyle get planSlot => _s(12, FontWeight.w700, p.muted);
  TextStyle cellShort(Color c) => _s(13, FontWeight.w800, c);
  TextStyle cellRoom(Color c) => _s(10, FontWeight.w600, c);
  TextStyle get gridSlot => _s(11, FontWeight.w700, p.muted);
  TextStyle get gridTime => _s(10, FontWeight.w500, p.faint);
  TextStyle get sheetTitle => _s(20, FontWeight.w800, p.ink);

  // ---- Allgemein --------------------------------------------------------
  TextStyle get body => _s(15, FontWeight.w500, p.ink);
  TextStyle get meta => _s(13, FontWeight.w500, p.muted);

  List<BoxShadow> get cardShadow => [
    BoxShadow(color: p.shadow.withValues(alpha: 0.3), blurRadius: 2,
        offset: const Offset(0, 1)),
  ];
  List<BoxShadow> get navShadow => [
    BoxShadow(color: p.shadow, blurRadius: 24, offset: const Offset(0, 8)),
  ];
}
