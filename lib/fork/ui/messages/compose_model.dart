import 'package:liblanis/liblanis.dart';

import '../courses/courses_model.dart' show courseTitle;
import '../plan/plan_model.dart' show portalNameToDisplay;

/// Eine Lehrkraft aus dem Unterricht des Kindes als mögliche Empfängerin.
class RecipientCandidate {
  const RecipientCandidate({
    required this.kuerzel,
    required this.display,
    required this.lastName,
    required this.subjects,
    this.firstName,
  });

  final String kuerzel;

  /// „Anna Alt“
  final String display;
  final String lastName;
  final String? firstName;

  /// „Mathematik, Training“ – woher das Kind sie kennt.
  final List<String> subjects;
}

/// Lehrkräfte aus „Mein Unterricht“, je Kürzel einmal, mit ihren Fächern.
///
/// Ursache (Konzept 17.10.26): Statt das Lehrerverzeichnis der ganzen Schule
/// zu durchsuchen, wählt man aus dem Unterricht des eigenen Kindes
/// („Mathematik – Herr …“). Grenze: Wer keinen Kurs in „Mein Unterricht“
/// hat (Schule A: Ästhetik), fehlt hier – dafür bleibt die freie Suche.
List<RecipientCandidate> candidatesFrom(Lessons lessons) {
  final byK = <String, RecipientCandidate>{};
  final order = <String>[];
  // Kleinste Teamgröße je Kürzel: Wer nur in großen Teams vorkommt (Schule A:
  // Ganztagsangebot mit sechs Lehrkräften, Export 16.10.26), kommt ans Ende –
  // die Fachlehrkräfte sollen oben stehen.
  final team = <String, int>{};
  for (final l in lessons) {
    for (final t in l.teachers) {
      final k = t.teacherKuerzel?.trim() ?? '';
      final n = l.teachers.length;
      if ((team[k] ?? 1 << 30) > n) team[k] = n;
    }
  }
  for (final l in lessons) {
    final subject = courseTitle(l.name);
    for (final t in l.teachers) {
      final k = t.teacherKuerzel?.trim();
      final raw = t.teacher?.trim();
      if (k == null || k.isEmpty || raw == null || raw.isEmpty) continue;
      final had = byK[k];
      if (had != null) {
        if (!had.subjects.contains(subject)) had.subjects.add(subject);
        continue;
      }
      final parts = raw.split(',');
      byK[k] = RecipientCandidate(
        kuerzel: k,
        display: portalNameToDisplay(raw),
        lastName: parts.first.trim(),
        firstName: parts.length > 1 ? parts.sublist(1).join(',').trim() : null,
        subjects: [subject],
      );
      order.add(k);
    }
  }
  final big = <String>[
    for (final k in order)
      if ((team[k] ?? 0) > 3) k,
  ];
  return [
    for (final k in order)
      if (!big.contains(k)) byK[k]!,
    for (final k in big) byK[k]!,
  ];
}

/// Kommt [word] in [text] als ganzes Wort vor (Groß-/Kleinschreibung egal)?
///
/// Wortgrenze ist alles außer Buchstaben, Ziffern und Bindestrich. Ursache
/// (Prüfung 27.10.26): Mit `contains` traf der Nachname „Alt“ auch „Altmann“
/// und „Walther“. Der Bindestrich zählt zum Wort, damit „Alt“ nicht den
/// Doppelnamen „Bau-Alt“ trifft. Grenze: Mehrteilige Namen („von Alt“)
/// müssen als Ganzes in derselben Schreibweise (Leerzeichen) vorkommen.
bool _hasWord(String text, String word) {
  final w = word.trim();
  if (w.isEmpty) return false;
  return RegExp(
    '(^|[^\\p{L}\\p{N}-])${RegExp.escape(w)}(\$|[^\\p{L}\\p{N}-])',
    caseSensitive: false,
    unicode: true,
  ).hasMatch(text);
}

/// Nachname des Portal-Treffers stimmt mit dem der Lehrkraft überein.
///
/// Steht ein Komma im Treffer, gilt die Form „Nachname, Vorname“ des Portals
/// (Lehrkraft im Unterricht: „Alt, Anna“, candidatesFrom): Dann muss der Teil
/// VOR dem Komma der ganze Nachname sein – sonst träfe „Alt“ auch „Bau, Alt“
/// (Vorname Alt). Ohne Komma („Anna Alt“) reicht der Nachname als ganzes Wort.
bool _lastNameMatches(String portal, String lastName) {
  final comma = portal.indexOf(',');
  if (comma >= 0) {
    return portal.substring(0, comma).trim().toLowerCase() ==
        lastName.trim().toLowerCase();
  }
  return _hasWord(portal, lastName);
}

/// Vorname (erster Teil) oder Kürzel der Lehrkraft als ganzes Wort im
/// Portal-Treffer.
bool _firstOrCodeMatches(String portal, RecipientCandidate c) {
  final first = c.firstName?.trim().split(RegExp(r'\s+')).first ?? '';
  return (first.isNotEmpty && _hasWord(portal, first)) ||
      _hasWord(portal, c.kuerzel);
}

/// Passende Einträge der Portal-Suche (nachrichten.php?a=searchRecipt) zu
/// einer Lehrkraft.
///
/// Gesucht wird mit dem Nachnamen; die Treffer kommen als Text, dessen Form
/// das Portal vorgibt (nicht dokumentiert). Lehrkraft (`isTeacher`), der
/// Nachname als ganzes Wort ([_lastNameMatches]) und – bei mehreren – Vorname
/// oder Kürzel. Grenze: Ob ein einzelner Treffer ohne Rückfrage genommen
/// wird, entscheidet [isSureReceiver]; nie raten.
List<ReceiverEntry> matchReceivers(
  List<ReceiverEntry> results,
  RecipientCandidate c,
) {
  final teachers = [
    for (final r in results)
      if (r.isTeacher && _lastNameMatches(r.name, c.lastName)) r,
  ];
  if (teachers.length <= 1) return teachers;
  final narrowed = [
    for (final r in teachers)
      if (_firstOrCodeMatches(r.name, c)) r,
  ];
  return narrowed.isEmpty ? teachers : narrowed;
}

/// Darf [hit] ohne Rückfrage als Empfänger für [c] gelten?
///
/// Ursache (Prüfung 27.10.26): Der einzige Treffer wurde bisher immer
/// genommen – fand das Portal nur „Alt, Bernd“, ging die Nachricht an ihn
/// statt an Anna Alt. Jetzt nur, wenn neben dem Nachnamen auch der Vorname
/// (oder das Kürzel) passt; kennt der Unterricht keinen Vornamen, reicht der
/// ganze Nachname. Sonst fragt die Seite nach (compose_page.dart, _choose)
/// und zeigt den Namen, wie das Portal ihn nennt.
bool isSureReceiver(ReceiverEntry hit, RecipientCandidate c) {
  if (!hit.isTeacher || !_lastNameMatches(hit.name, c.lastName)) return false;
  final first = c.firstName?.trim() ?? '';
  if (first.isEmpty) return true;
  return _firstOrCodeMatches(hit.name, c);
}
