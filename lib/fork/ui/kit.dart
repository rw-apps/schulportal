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

/// Grund eingebetteter Webseiten (MensaPage): Weiß wie im Browser, auch im
/// dunklen Modus, weil die Seiten selbst hell gestaltet sind. Ursache
/// (Bildschirmfoto 27.10.26): Solange die Seite noch lud, war die Fläche
/// schwarz und wirkte wie ein Absturz.
const kitWebCanvas = Color(0xFFFFFFFF);

/// Schriftstufe der neuen Oberfläche, zusätzlich zur Systemschrift.
///
/// Ursache: „Die Schriftgröße ist noch zu klein“ (Pixel, 16.10.26). „Normal“
/// liegt deshalb schon ~2 pt über den Kit-Größen (Fach 16 → 18, Meta 13 →
/// 14,5). Wirkt als Faktor auf MediaQuery.textScaler (PreviewShell), damit
/// alle Kit-Formate gleichmäßig wachsen. Grenze: Feste Höhen (Knöpfe, Leiste,
/// Rasterzeilen) wachsen nicht mit; dort verkleinern FittedBox bzw. das
/// Raster scrollt ab der Mindesthöhe.
enum KitFontStep {
  small(0.98),
  normal(1.11),
  large(1.26);

  // Ursache der Werte (Rückmeldung 17.10.26: „Normal ist schon groß“): Jede
  // Stufe liegt etwa 2 Punkte unter der bisherigen nächsthöheren – bei 14 pt
  // Grundschrift 13,7 / 15,5 / 17,6 statt 15,7 / 17,5 / 19,6. Normal bleibt
  // damit fast wie bisher (1,12 → 1,11), Klein ist neu, „Sehr groß“ (1,4)
  // entfällt. Beschriftung in den Sprachdateien (fontSmall/-Normal/-Large).
  const KitFontStep(this.factor);
  final double factor;

  /// Gespeicherter Name → Stufe. Grenze: Das frühere „xlarge“ wird zu
  /// [large], der größten verbliebenen Stufe.
  static KitFontStep parse(String? name) => name == 'xlarge'
      ? KitFontStep.large
      : KitFontStep.values.firstWhere(
          (s) => s.name == name,
          orElse: () => KitFontStep.normal,
        );
}

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

  /// Punkt mit Anfangsbuchstabe im Kopf der Kinderkarte (kompakt, 18.10.26).
  static const double avatarSmall = 32;

  /// Ab dieser Breite Tablet-Aufbau auf Heute: ein Kind links, Termine
  /// rechts; ab zwei Kindern je zwei nebeneinander (TodayPage).
  static const double wideLayout = 700;

  /// Ab dieser Breite (Tablet quer) stehen die Termine auch bei mehreren
  /// Kindern rechts daneben statt darunter – bei zwei Kindern drei Spalten.
  static const double wideLandscape = 1100;

  /// Höchstbreite der unteren Leiste (Tablet): mittig statt über die ganze
  /// Breite, fünf Ziele à ~110 dp wie auf dem Telefon.
  static const double navMaxWidth = 560;
  static const double dot = 8;
  static const double dotSmall = 6;

  /// Höhe der Tagesleiste je Kind.
  static const double dayBar = 10;

  /// Symbol vor einem Hinweis an der Kinderkarte (Ausfall, Vertretung,
  /// Essen): etwas größer als [icon], weil der Hinweistext 16 statt 14 ist.
  static const double hintIcon = 20;

  /// Hinweiszeile an der Kinderkarte (Abnahme 30.10.26): Feld in der
  /// Signalfläche um das Lagebild und das Symbol darin – kleiner als
  /// [hintIcon], weil die Zeile nur noch 13er Schrift trägt.
  static const double hintBadge = 30;
  static const double hintBadgeIcon = 17;

  /// Knopf „Beenden“ im schmalen Demo-Band auf Heute (demo_entry.dart):
  /// zwischen [buttonTiny] und [buttonSmall], damit das Band einzeilig bleibt.
  static const double bandButton = 36;

  /// Rahmen um den Stundenplan an der Kinderkarte. Farbe der Nebenschrift
  /// (KitPalette.faint) statt der Trennlinie: Ein hellgrauer Rahmen war
  /// schon im Prüfbild kaum zu sehen (Abnahme 21.10.26), bei Sonnenlicht
  /// gar nicht (wie die Knöpfe, Rückmeldung 20.10.26).
  static const double frame = 1;

  /// Spalte für „3.–4.“ in der aufgeklappten Tagesliste.
  static const double slotColumn = 52;

  /// Breite einer Termin-Kachel unter „Demnächst“. 160 statt 136 aus dem
  /// Entwurf: Bei Systemschrift ×1,15 brach „Klassenarbeit“ sonst mitten
  /// im Wort um (Flutter trennt nicht nach Silben).
  static const double tileWidth = 160;

  static const double button = 56;
  static const double buttonSmall = 44;

  /// Kleiner Knopf in einer Karte („✓ Erledigt“, homework_section.dart):
  /// sichtbare Höhe und Symbol. Ursache (Rückmeldung 20.10.26): Mit der
  /// Standardgröße wirkte der Knopf neben dem Aufgabentext zu wuchtig.
  /// Grenze: Trefferfläche 28 dp (shrinkWrap), damit die Zeile nicht höher
  /// wird als der Text.
  static const double buttonTiny = 28;
  static const double iconSmall = 14;

  /// Schwebende untere Leiste: Höhe und Abstand zum Rand.
  // 64 statt 68 (Entwurf Leiste 17.10.26): Platz für Marken ohne mehr Höhe.
  static const double navHeight = 64;
  static const double navMargin = 16;
  static const double navBottom = 24;

  // ---- Stundenplan ------------------------------------------------------
  /// Mindesthöhe einer Stunde im Wochenraster. Sonst teilt das Raster die
  /// freie Höhe auf alle Stunden auf, damit die Woche ohne Scrollen auf
  /// einen Bildschirm passt (Rückmeldung 16.10.26: „Platz verschenkt“).
  static const double gridRowMin = 46;

  /// Höchsthöhe einer Stunde. Ursache: Mit nur 4 Blöcken (Schule A) wurden die
  /// Zellen beim Füllen der Höhe ~150 dp hoch („zu luftig“, Rückmeldung
  /// 16.10.26). Darüber bleibt unten Platz frei.
  static const double gridRowMax = 72;

  /// Abstand zwischen Zellen; an Pausen ab 15 Min. der größere.
  static const double gridGap = 3;
  static const double gridBreak = 10;

  /// Spalte links im Wochenraster („1.“, „08:00“).
  static const double gridLabel = 32;

  /// Jetzt-Linie in der heutigen Spalte.
  static const double nowLine = 2;

  /// Fortschrittsstrich unter der laufenden Stunde (Tagesansicht).
  static const double progress = 4;

  /// Rahmen um geänderte bzw. laufende Zellen.
  static const double cellBorder = 2;

  /// Rahmen der laufenden Stunde in der Tagesansicht – kräftiger als
  /// [cellBorder] (Rückmeldung 21.10.26: „fette Umrandung“). Im
  /// Wochenraster bleibt es bei [cellBorder]; die Zellen sind dort nur
  /// etwa 60 dp breit.
  static const double runningBorder = 3;
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

  /// Feld um das Lagebild einer Hinweiszeile (Sz.hintBadge).
  static const double badge = 9;

  /// Weiße Liste der Hinweiszeilen in der grauen Tagesgruppe ([panel]).
  static const double hintList = 14;
  static const double nav = 34;
  static const double navItem = 22;
  static const double cell = 12;
  static const double pill = 20;
}

/// Fläche und Schrift ohne Signalbedeutung ([Kit.plainTone]): Köpfe der
/// Bereiche auf der Fachseite, Merkmale im Einstieg.
class PlainTone {
  const PlainTone(this.bg, this.ink);
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
    required this.todo,
    required this.barNeutral,
  });

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

  /// Offene Aufgabe (Hausaufgabe, Abgabe): dezent grau statt Gelb. Ursache
  /// (Rückmeldung 21.10.26): Gelb heißt Vertretung, Raumwechsel oder Essen;
  /// eine offene Hausaufgabe ist keine Abweichung, soll aber auffallen.
  final SignalTone todo;

  /// Kommende Abschnitte der schlichten Tagesleiste (Kinderkarte).
  /// Erledigte nehmen [faint], die laufende Stunde füllt sich mit [muted].
  /// Ursache (Rückmeldung 21.10.26): Mit der Kinderfarbe war der reguläre
  /// Plan so bunt, dass Ausfall und Vertretung nicht mehr auffielen; jetzt
  /// tragen nur Signalfarben Farbe.
  final Color barNeutral;

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
      ),
      KidTone(
        accent: Color(0xFF0F8A7E),
        tint: Color(0xFFDDF3EF),
        onTint: Color(0xFF08332E),
        label: Color(0xFF0B6B61),
        meta: Color(0xFF2D5A54),
      ),
      KidTone(
        accent: Color(0xFF7C3AED),
        tint: Color(0xFFEFE7FE),
        onTint: Color(0xFF2E1065),
        label: Color(0xFF6D28D9),
        meta: Color(0xFF4C3A75),
      ),
      KidTone(
        accent: Color(0xFF4D7C0F),
        tint: Color(0xFFE9F5D6),
        onTint: Color(0xFF1F3305),
        label: Color(0xFF3F6212),
        meta: Color(0xFF44562A),
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
    todo: SignalTone(
      bg: Color(0xFFE4E7EC),
      ink: Color(0xFF101828),
      strong: Color(0xFF344054),
      bar: Color(0xFFD0D5DD),
      dot: Color(0xFF667085),
    ),
    barNeutral: Color(0xFFD0D5DD),
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
      ),
      KidTone(
        accent: Color(0xFF2DD4BF),
        tint: Color(0xFF12302C),
        onTint: Color(0xFFDDF3EF),
        label: Color(0xFF5EEAD4),
        meta: Color(0xFFA8DCD5),
      ),
      KidTone(
        accent: Color(0xFFA78BFA),
        tint: Color(0xFF2A1F45),
        onTint: Color(0xFFEFE7FE),
        label: Color(0xFFC4B5FD),
        meta: Color(0xFFCFC3EE),
      ),
      KidTone(
        accent: Color(0xFFA3E635),
        tint: Color(0xFF22301A),
        onTint: Color(0xFFECF5D8),
        label: Color(0xFFBEF264),
        meta: Color(0xFFCFE3B0),
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
    todo: SignalTone(
      bg: Color(0xFF262C36),
      ink: Color(0xFFF2F4F8),
      strong: Color(0xFFD0D5DD),
      bar: Color(0xFF3A414D),
      dot: Color(0xFF9AA3B2),
    ),
    barNeutral: Color(0xFF3A414D),
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

  /// Neutrale Fläche statt Fachfarbe. Ursache (Rückmeldung 21.10.26: „die
  /// App soll überall konsistent sein“): Farbe tragen nur noch Abweichungen
  /// (Ausfall, Vertretung) und das Kind; die acht Fachfarben (Wochenraster,
  /// Fächerliste, Fachseite, Noten) sind entfallen.
  PlainTone get plainTone => PlainTone(p.inset, p.ink);

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

  // ---- Signalflächen (Hinweise, Hinweiskarten) --------------------------
  TextStyle boxText(SignalTone t) => _s(14, FontWeight.w500, t.ink);
  TextStyle boxStrong(SignalTone t) => _s(14, FontWeight.w800, t.ink);

  // ---- Karte ------------------------------------------------------------
  TextStyle get cardName => _s(19, FontWeight.w800, p.ink);
  TextStyle get cardMeta => _s(13, FontWeight.w500, p.muted);
  TextStyle get avatarLetter => _s(18, FontWeight.w800, p.onStrong);

  TextStyle get barLabel => _s(11, FontWeight.w600, p.muted);

  // Kinderkarte ab 21.10.26: „Hinweise“ farbig gefüllt, „Stundenplan“
  // schlicht und umrandet (Abnahme 21.10.26).
  /// Überschrift „Hinweise“ bzw. „Stundenplan“ in der Karte.
  TextStyle get cardSection => _s(15, FontWeight.w800, p.ink);

  /// „Ev. Religion fällt aus“: größer als boxStrong (14), weil Ausfall und
  /// Vertretung wichtiger sind als der reguläre Plan (Rückmeldung 21.10.26).
  TextStyle hintTitle(SignalTone t) => _s(16, FontWeight.w800, t.ink);
  TextStyle hintDetail(SignalTone t) => _s(13, FontWeight.w500, t.ink);

  /// „Morgen“ vor der Stunde eines Hinweises für den nächsten Schultag.
  // hintTitle/hintDetail/hintWhen: seit 30.10.26 nicht mehr an der Karte
  // (Zeilen statt Flächen, hintSubject/hintKind/hintSlot); bleiben für den
  // abgenommenen Entwurf (Variante A in test/_local) stehen.
  TextStyle hintWhen(SignalTone t) => _s(13, FontWeight.w800, t.ink);

  /// Hinweis als eine Zeile (Abnahme 30.10.26, Entwurf B): Fach fett in
  /// Schriftfarbe, Art in der kräftigen Signalfarbe, rechts die Stunde als
  /// Marke – alle in der Größe von cardMeta (13), damit Fach, Art und Marke
  /// auch bei Systemschrift ×1,3 in eine Zeile passen.
  TextStyle get hintSubject => _s(13, FontWeight.w800, p.ink);
  TextStyle hintKind(SignalTone t) => _s(13, FontWeight.w700, t.strong);
  TextStyle get hintSlot => _s(13, FontWeight.w700, p.ink);

  /// Schlichter Plan: Zeile „JETZT · 3.–4. STD.“, Fach, Zeit/Raum/Lehrkraft.
  TextStyle get planNowLabel => _s(11, FontWeight.w800, p.muted, ls: 1);
  TextStyle get planNowSubject => _s(22, FontWeight.w800, p.ink);
  TextStyle get planNowMeta => _s(13, FontWeight.w500, p.muted);

  // Aufgeklappte Tagesliste
  TextStyle rowSubject(Color c, {bool strong = false}) =>
      _s(15, strong ? FontWeight.w800 : FontWeight.w600, c);
  TextStyle get rowPause => _s(12, FontWeight.w600, p.faint);

  TextStyle button(Color c) => _s(14, FontWeight.w700, c);
  TextStyle buttonTiny(Color c) => _s(12, FontWeight.w700, c);

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
  TextStyle chipLabel(bool selected, Color selectedInk) =>
      _s(14, FontWeight.w700, selected ? selectedInk : p.ink);
  TextStyle get timeStart => _s(13, FontWeight.w800, p.ink);
  TextStyle get timeEnd => _s(12, FontWeight.w500, p.faint);
  TextStyle planSubject(Color c) => _s(16, FontWeight.w800, c);
  TextStyle planMeta(Color c) => _s(13, FontWeight.w500, c);

  /// Lehrkraft in der Tagesansicht: kräftiger als Raum/Zeit („mehr Kontur“,
  /// Rückmeldung 16.10.26).
  TextStyle planTeacher(Color c) => _s(14, FontWeight.w700, c);
  TextStyle cellShort(Color c) => _s(13, FontWeight.w800, c);
  TextStyle cellRoom(Color c) => _s(11, FontWeight.w600, c);
  TextStyle cellTeacher(Color c) => _s(10, FontWeight.w700, c);
  TextStyle get gridSlot => _s(12, FontWeight.w800, p.ink);
  TextStyle get gridTime => _s(10, FontWeight.w500, p.faint);
  TextStyle gridHead(bool today) =>
      _s(13, FontWeight.w800, today ? p.onStrong : p.ink);
  TextStyle gridHeadDate(bool today) =>
      _s(11, FontWeight.w600, today ? p.onStrong : p.muted);
  TextStyle get sheetTitle => _s(20, FontWeight.w800, p.ink);

  // ---- Allgemein --------------------------------------------------------
  TextStyle get body => _s(15, FontWeight.w500, p.ink);
  TextStyle get meta => _s(13, FontWeight.w500, p.muted);

  /// Technischer Verlauf zur Fehlersuche (z. B. MealTrace): klein,
  /// gleichbreit, damit Zeitspalten untereinander stehen.
  TextStyle get trace => _s(
    11,
    FontWeight.w500,
    p.muted,
  ).copyWith(fontFamily: 'monospace', height: 1.35);

  List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: p.shadow.withValues(alpha: 0.3),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];
  List<BoxShadow> get navShadow => [
    BoxShadow(color: p.shadow, blurRadius: 24, offset: const Offset(0, 8)),
  ];
}
