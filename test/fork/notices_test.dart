import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/notify/notices.dart';
import 'package:lanis/fork/ui/today/today_model.dart';
import 'package:liblanis/liblanis.dart';

final de = forkL10nFor('de');

CalendarEvent _ev(String title, DateTime a, {String? cat}) => CalendarEvent(
  startTime: a,
  endTime: a.add(const Duration(hours: 1)),
  secret: false,
  id: title,
  isNew: false,
  public: true,
  private: false,
  allDay: false,
  category: cat == null
      ? null
      : CalendarEventCategory(id: 1, colorArgb: 0, name: cat),
  description: '',
  title: title,
);

void main() {
  // Montag 19.10.26; Dienstag mit großen Terminen.
  final ev = [
    _ev('Lernkontrolle NaWi', DateTime(2026, 10, 20, 9), cat: 'Arbeiten'),
    _ev('Elternabend 6', DateTime(2026, 10, 20, 19)),
    _ev('Präsentation Prüfung', DateTime(2026, 10, 20, 8)),
  ];

  List<Notice> at(
    DateTime now, {
    Set<String> sent = const {},
    List<CalendarEvent>? events,
    String name = 'Kind',
    bool parent = false,
  }) => buildNotices(
    t: de,
    events: events ?? ev,
    now: now,
    sent: sent,
    name: name,
    parent: parent,
  );

  // Das Zeitfenster prüft background_service.dart (isTaskWithinConstraints);
  // buildNotices selbst sperrt keine Uhrzeit mehr.
  test('keine feste Ruhezeit in buildNotices', () {
    expect(at(DateTime(2026, 10, 19, 21, 30)), isNotEmpty);
  });

  test('Vorabend ab 19 Uhr für den nächsten Schultag: große Termine', () {
    expect(at(DateTime(2026, 10, 19, 18, 59)), isEmpty);
    final n = at(DateTime(2026, 10, 19, 19, 30)).single;
    expect(n.id, 2);
    expect(n.title, 'Morgen bei Kind');
    expect(n.lines, ['Lernkontrolle NaWi · 09:00', 'Elternabend 6 · 19:00']);
    // Schon gemeldet: nichts; ein neuer Termin: vollständige Meldung.
    expect(at(DateTime(2026, 10, 19, 19, 30), sent: n.keys.toSet()), isEmpty);
    expect(
      at(DateTime(2026, 10, 19, 19, 30), sent: {n.keys.first}).single.lines,
      hasLength(2),
    );
  });

  test('Freitagabend nichts für Samstag, Sonntagabend für Montag', () {
    final sat = [_ev('Sportfest', DateTime(2026, 10, 24, 9))];
    expect(at(DateTime(2026, 10, 23, 19, 30), events: sat), isEmpty);
    final mon = [_ev('Sportfest', DateTime(2026, 10, 26, 9))];
    expect(
      at(DateTime(2026, 10, 25, 19, 30), events: mon).single.title,
      'Morgen bei Kind',
    );
  });

  test('große Termine', () {
    WeekItem w(String t, WeekKind k) =>
        WeekItem(day: DateTime(2026), title: t, kind: k);
    expect(isBigEvent(w('Sportfest', WeekKind.event)), isTrue);
    expect(isBigEvent(w('Projektpr. Präsentation', WeekKind.event)), isFalse);
    expect(isBigEvent(w('Kein Essen', WeekKind.meal)), isFalse);
    expect(isBigEvent(w('Herbstferien', WeekKind.free)), isTrue);
  });

  test('Schlüssel begrenzt', () {
    final keys = rememberKeys(
      [for (var i = 0; i < 5; i++) 'k$i'],
      ['k1', 'n'],
      max: 4,
    );
    expect(keys, ['k3', 'k4', 'k1', 'n']);
  });

  test('ohne Kindernamen: Schülerkonto „in der Schule“, Elternkonto '
      '„bei deinem Kind“', () {
    final eve = DateTime(2026, 10, 19, 19, 30);
    expect(at(eve, name: '').single.title, 'Morgen in der Schule');
    expect(
      at(eve, name: '', parent: true).single.title,
      'Morgen bei deinem Kind',
    );
  });
}
