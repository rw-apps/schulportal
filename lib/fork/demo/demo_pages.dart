import 'dart:convert';

import 'demo_school.dart';

/// Seiten des Demo-Portals, erzeugt aus demo_school.dart.
///
/// Aufbau wie beim echten Schulportal, soweit die Leser der App ihn
/// brauchen – Belege je Seite am Erzeuger (Parser in liblanis bzw.
/// lib/fork). Grenze: Nur, was die App liest; Layout, Skripte und Menüs des
/// Portals fehlen.
///
/// Zeitbezug: [DemoClock.now] statt fester Daten, damit „heute“, „morgen“ und
/// die laufende Stunde immer passen.
class DemoClock {
  const DemoClock(this.now);
  final DateTime now;

  DateTime get today => DateTime(now.year, now.month, now.day);

  /// Montag der Woche, die die App zeigt: am Wochenende die nächste.
  DateTime get monday {
    final t = today;
    return t.weekday >= DateTime.saturday
        ? _plus(t, 8 - t.weekday)
        : _plus(t, 1 - t.weekday);
  }

  /// Kalendertage statt Duration: Über die Zeitumstellung hinweg ergab
  /// `add(Duration(days: 1))` 23:00 bzw. 01:00 statt Mitternacht, und
  /// Vergleiche wie `d == today` (demo_meals.dart) schlugen fehl (Prüfung
  /// 27.10.26, Woche der Umstellung am 25.10.).
  static DateTime _plus(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  /// Schultag [n] ab heute (0 = heute bzw. nächster Schultag).
  DateTime schoolDay(int n) {
    var d = today;
    while (d.weekday >= DateTime.saturday) {
      d = _plus(d, 1);
    }
    var left = n;
    while (left > 0) {
      d = _plus(d, 1);
      if (d.weekday < DateTime.saturday) left--;
    }
    return d;
  }

  /// Letzter Schultag vor heute, [n] Schultage zurück.
  DateTime pastSchoolDay(int n) {
    var d = today;
    var left = n;
    while (left > 0) {
      d = _plus(d, -1);
      if (d.weekday < DateTime.saturday) left--;
    }
    return d;
  }
}

String _two(int v) => v.toString().padLeft(2, '0');
String dmy(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';
String ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
String _esc(String s) => const HtmlEscape().convert(s);

const _days = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag'];

String _page(String title, String body, {String icon = 'fa-child'}) =>
    '<!DOCTYPE html><html lang="de"><head><title>$title - Schulportal Hessen'
    ' - Pädagogische Organisation</title><meta charset="utf-8"></head><body>'
    '<nav><ul class="nav navbar-nav navbar-right"><li><a href="#">'
    '<i class="fa $icon"></i> Demo</a></li></ul></nav>'
    '<div id="content">$body</div></body></html>';

String _icon(DemoUser u) =>
    u.role == DemoRole.parent ? 'fa-user-circle' : 'fa-child';

// ---- Anmeldung ------------------------------------------------------------

/// benutzerverwaltung.php?a=userData – Kontoart am Symbol, Daten als
/// Tabelle (liblanis LanisSession.parseAccountType/parseUserData).
String userDataPage(DemoUser u) {
  final p = u.pupils.first;
  final rows = <(String, String)>[
    ('Login', u.username),
    if (u.role == DemoRole.student) ...[
      ('Nachname', p.last),
      ('Vorname', p.first),
      ('Klasse', p.className),
    ] else ...[
      ('Nachname', 'Beispiel'),
      ('Vorname', 'Sabine'),
    ],
  ];
  return _page(
    'Benutzerdaten',
    '<div class="row"><div class="col-md-12"><table class="table '
        'table-striped"><tbody>'
        '${rows.map((r) => '<tr><td>${r.$1}:</td><td>${_esc(r.$2)}</td></tr>').join()}'
        '</tbody></table></div></div>',
    icon: _icon(u),
  );
}

/// startseite.php?a=ajax&f=apps – angebotene Module
/// (LanisSession.getFastTravelMenu, forkSupportsApplet).
String appsJson(DemoUser u) {
  Map<String, Object> e(String name, String link) => {
    'Name': name,
    'Farbe': '168647',
    'Logo': 'fa fa-book',
    'Ordner': ['Schule'],
    'link': link,
  };
  return jsonEncode({
    'error': '0',
    'entrys': [
      e('Kalender', 'kalender.php'),
      e('mein Unterricht', 'meinunterricht.php'),
      e('Nachrichten', 'nachrichten.php'),
      e('Stundenplan', 'stundenplan.php'),
      e('Vertretungsplan', 'vertretungsplan.php'),
      // Krankmeldung gibt es nur im Elternkonto (forkAbsenceApplet).
      if (u.role == DemoRole.parent)
        e('Abwesenheitsmeldung', 'abwesenheitsmeldung.php'),
    ],
  });
}

/// abwesenheitsmeldung.php – Formular wie parseAbsenceForm es liest
/// (Aufbau nach dem Export von Schule A, absence_form.dart): Kinder,
/// Art, Von/Bis mit Datepicker-Grenzen, Blöcke, Hinweise.
///
/// Ursache (Demo-Prüfung 27.10.26): Ohne das Modul fehlte „Krank melden“
/// in der Demo ganz, und Heute zeigte nie alle vier Knöpfe. Grenze: Die
/// Prüfung (`check=1`) antwortet immer „zulässig“ ([absenceCheckJson]);
/// Absenden gibt es in der App ohnehin nicht (AbsenceDraft).
String absencePage(DemoUser u, DemoClock c) {
  final from = c.schoolDay(0);
  final last = c.schoolDay(10);
  final pupils = [
    for (final (i, p) in u.pupils.indexed)
      '<button type="button" class="btn pupil-select-btn" '
          'data-pupil-id="${p.id}" data-pupil-name="${p.first} ${p.last}" '
          'data-preselected="${i == 0}">${p.first} ${p.last}</button>',
  ].join();
  const blocks = [
    ('1', '1. Block (08:00 - 09:30)'),
    ('2', '2. Block (09:50 - 11:20)'),
    ('3', '3. Block (11:40 - 13:10)'),
    ('4', '4. Block (14:00 - 15:30)'),
  ];
  String options(String name) =>
      '<select name="$name">${[for (final (v, l) in blocks) '<option value="$v">$l</option>'].join()}</select>';
  return _page(
    'Abwesenheitsmeldung',
    '<div id="content"><div class="alert alert-info"><ul>'
        '<li>Meldungen für den aktuellen Tag sind bis 12:00 Uhr möglich.</li>'
        '<li>Ein Attest geben Sie bitte weiterhin im Sekretariat ab.</li>'
        '</ul></div>'
        '<form id="meldungForm">$pupils'
        '<select name="art"><option value="krank">krank</option>'
        '<option value="verspätet">verspätet</option></select>'
        '<input name="von" value="${dmy(from)}">'
        '<input name="bis" value="${dmy(from)}">'
        '${options('stundenVon')}${options('stundenBis')}'
        '<textarea name="kommentar"></textarea>'
        '<div id="kommentarHinweis">Bitte keine Gesundheitsdaten eingeben.</div>'
        '</form>'
        '<table><tbody id="liste"></tbody></table></div>'
        '<script>\$(".datepickergroupvon").datepicker({startDate: "${dmy(from)}", '
        'endDate: "${dmy(last)}"});'
        '\$(".datepickergroupbis").datepicker({startDate: "${dmy(from)}", '
        'endDate: "${dmy(last)}"});</script>',
    icon: _icon(u),
  );
}

/// Antwort auf die Prüfung einer Meldung (`check=1`, checkAbsence).
const absenceCheckJson = '{"success":true,"errors":[]}';

// ---- Stundenplan ----------------------------------------------------------

String _cell(List<DemoSlot> slots) => slots
    .map(
      (s) =>
          '<div class="stunde" data-mix="demo${s.subject}${s.day}${s.from}" '
          'title="${s.subject} im Raum ${s.room}"><b>${s.subject}</b> '
          '${_esc(s.room)} <br /><small> ${s.teacher} </small></div>',
    )
    .join();

String _table(List<DemoSlot> plan) {
  final b = StringBuffer('<table class="table"><tbody>');
  // Leere erste Zeile: liblanis überspringt sie (parseRoomPlan).
  b.write('<tr><td></td>${'<td>&nbsp;</td>' * 5}</tr>');
  final covered = List.generate(10, (_) => List.filled(5, false));
  for (var h = 1; h <= demoBells.length; h++) {
    final (from, to) = demoBells[h - 1];
    b.write(
      '<tr><td><span class="hidden-xs print-show"><b>$h. Stunde</b><br />'
      '<span class="VonBis"><small>$from - $to</small></span></span></td>',
    );
    for (var d = 0; d < 5; d++) {
      if (covered[h][d]) continue;
      final here = [
        for (final s in plan)
          if (s.day == d && s.from == h) s,
      ];
      if (here.isEmpty) {
        b.write('<td>&nbsp;</td>');
        continue;
      }
      final span = here.first.to - here.first.from + 1;
      for (var i = 1; i < span && h + i < covered.length; i++) {
        covered[h + i][d] = true;
      }
      b.write('<td rowspan="$span">${_cell(here)}</td>');
    }
    b.write('</tr>');
  }
  b.write('</tbody></table>');
  return b.toString();
}

/// stundenplan.php – Gesamtplan der Klasse (#all) und persönlicher Plan
/// (#own), Zeiten in `.VonBis` (TimetableStudentParser.parseDocumentHtml,
/// fork/timetable_fix.dart).
String timetablePage(DemoPupil p, DemoClock c) => _page(
  '${p.className} - Stundenplan',
  '<div id="all"><h2>Gesamtplan der ${p.className}</h2>'
      '<div class="plan" data-date="${ymd(c.monday)}">'
      'Stundenplan gültig ab ${dmy(c.monday)}'
      '<div class="pull-right">Diese Woche ist eine '
      '<span class="badge" id="aktuelleWoche">A</span>-Woche.</div>'
      '${_table(p.plan)}</div></div>'
      '<div id="own"><h2>Persönlicher Stundenplan für ${p.last}, ${p.first} '
      '(${p.className})</h2>${_table(p.ownPlan)}</div>',
);

// ---- Vertretungsplan ------------------------------------------------------

class DemoChange {
  const DemoChange(
    this.slot,
    this.art, {
    this.substitute,
    this.room,
    this.note,
  });
  final DemoSlot slot;
  final String art;
  final String? substitute;
  final String? room;
  final String? note;
}

/// Vertretungen eines Kindes am Schultag [day] (0 = heute): heute eine
/// Vertretung, am nächsten Schultag ein Ausfall zu Beginn und ein
/// Raumwechsel. Ursache: So zeigt die Demo jede Hinweisart der Karte
/// (kid_hints.dart) einmal.
List<DemoChange> demoChanges(DemoPupil p, int day, DemoClock c) {
  final wd = c.schoolDay(day).weekday - 1;
  final lessons = [
    for (final s in p.ownPlan)
      if (s.day == wd) s,
  ]..sort((a, b) => a.from.compareTo(b.from));
  if (lessons.isEmpty) return const [];
  if (day == 0) {
    final s = lessons[lessons.length > 2 ? 2 : lessons.length - 1];
    return [
      DemoChange(
        s,
        'Vertretung',
        substitute: s.teacher == 'SOM' ? 'KRA' : 'SOM',
        note: p == demoJonas ? 'Aufgaben im Buch' : null,
      ),
      // Auch heute ein Ausfall (Demo-Prüfung 27.10.26: bisher nur morgen).
      if (lessons.length > 3) DemoChange(lessons.last, 'Entfall'),
    ];
  }
  if (day == 1) {
    return [
      DemoChange(lessons.first, 'Entfall'),
      if (lessons.length > 2)
        DemoChange(lessons.last, 'Raumänderung', room: 'R020'),
    ];
  }
  return const [];
}

/// vertretungsplan.php – Tage als `data-tag` (getSubstitutionDates), dazu
/// je Tag die Nachrichten der Schule (`.infos`, parseInformationTables).
String substitutionsPage(DemoClock c) {
  final days = [c.schoolDay(0), c.schoolDay(1)];
  final b = StringBuffer();
  for (final d in days) {
    final id = '${_two(d.day)}_${_two(d.month)}_${d.year}';
    b.write(
      '<div class="panel" data-tag="${dmy(d)}" id="tag$id">'
      '<h3>${_days[d.weekday - 1]}, ${dmy(d)}</h3>',
    );
    if (d == days.first) {
      b.write(
        '<table class="infos"><tr class="subheader"><td>Allgemein</td></tr>'
        '<tr><td>Am Freitag ist der Kiosk geschlossen.</td></tr></table>',
      );
    }
    b.write('</div>');
  }
  final edit = c.now.subtract(const Duration(minutes: 20));
  b.write(
    '<p>Letzte Aktualisierung: ${dmy(edit)} um ${_two(edit.hour)}:'
    '${_two(edit.minute)}:00 Uhr</p>',
  );
  return _page('Vertretungsplan', b.toString());
}

/// POST vertretungsplan.php?a=my, tag=dd.MM.yyyy – JSON-Liste
/// (SubstitutionsParser.parseAjaxDayJson).
String substitutionsAjax(List<DemoPupil> pupils, String tag, DemoClock c) {
  final out = <Map<String, Object?>>[];
  for (var day = 0; day < 2; day++) {
    if (dmy(c.schoolDay(day)) != tag) continue;
    for (final p in pupils) {
      for (final x in demoChanges(p, day, c)) {
        final s = x.slot;
        final sub = demoTeachers[x.substitute];
        final t = demoTeachers[s.teacher]!;
        out.add({
          'Tag': tag,
          'Stunde': s.from == s.to ? '${s.from}' : '${s.from} - ${s.to}',
          'Klasse': p.className,
          'Fach': x.art == 'Entfall' ? null : s.subject,
          'Fach_alt': s.subject,
          'Raum': x.room ?? (x.art == 'Entfall' ? null : s.room),
          'Raum_alt': s.room,
          'Lehrer': t.full,
          'Lehrerkuerzel': t.code,
          'Vertreter': sub?.full,
          'Vertreterkuerzel': sub?.code,
          'Art': x.art,
          'Hinweis': x.note,
        });
      }
    }
  }
  return jsonEncode(out);
}

// ---- Kalender -------------------------------------------------------------

/// kalender.php – Kategorien als `categories.push({…})`
/// (CalendarParser.parseCategoriesHtml).
String calendarPage() => _page(
  'Kalender',
  '<script>var categories = [];'
      "categories.push({id: 1, name: 'Termine', color: '#168647'});"
      "categories.push({id: 2, name: 'Prüfungen', color: '#d9534f'});"
      "categories.push({id: 3, name: 'Ferien', color: '#5bc0de'});"
      '</script>',
);

/// POST kalender.php?f=getEvents – JSON-Liste (CalendarEvent.fromLanisJson).
String calendarEvents(List<DemoPupil> pupils, DemoClock c) {
  var id = 100;
  Map<String, Object?> ev(
    String title,
    DateTime start,
    DateTime end, {
    int category = 1,
    bool allDay = false,
    String? place,
    String description = '',
  }) => {
    'Id': '${id++}',
    'title': title,
    'description': description,
    'Anfang': '${ymd(start)} ${_two(start.hour)}:${_two(start.minute)}:00',
    'Ende': '${ymd(end)} ${_two(end.hour)}:${_two(end.minute)}:00',
    'allDay': allDay,
    'category': '$category',
    'Ort': place,
    'Geheim': 'nein',
    'Neu': 'nein',
    'Oeffentlich': 'ja',
    'Privat': 'nein',
  };
  DateTime at(DateTime d, int h, [int m = 0]) =>
      DateTime(d.year, d.month, d.day, h, m);
  final out = <Map<String, Object?>>[
    ev(
      'Elternabend Klasse ${pupils.first.className}',
      at(c.schoolDay(3), 19),
      at(c.schoolDay(3), 21),
      place: 'Raum R112',
    ),
    ev(
      'Wandertag',
      c.schoolDay(6),
      c.schoolDay(6),
      allDay: true,
      description: 'Bitte wetterfeste Kleidung und Verpflegung mitbringen.',
    ),
    ev(
      'Kein Mittagessen in der Mensa',
      c.schoolDay(2),
      c.schoolDay(2),
      allDay: true,
    ),
    ev(
      'Schulkonzert',
      at(c.schoolDay(8), 18),
      at(c.schoolDay(8), 20),
      place: 'Aula',
    ),
    for (final p in pupils)
      ev(
        'Klassenarbeit Mathematik ${p.className}',
        at(c.schoolDay(4), 8),
        at(c.schoolDay(4), 9, 30),
        category: 2,
      ),
    // Auch im Kalender (nicht nur in der Kursmappe): Heute zeigt den
    // Vokabeltest dann sofort als Hinweis, ohne auf den Abgleich der
    // Kursmappen zu warten (Demo-Prüfung 27.10.26).
    for (final p in pupils)
      ev(
        'Englisch ${p.className} Test',
        at(c.schoolDay(1), 9, 50),
        at(c.schoolDay(1), 10, 35),
        category: 2,
      ),
  ];
  final f = c.schoolDay(25);
  out.add(
    ev('Ferien', f, f.add(const Duration(days: 9)), category: 3, allDay: true),
  );
  return jsonEncode(out);
}

// ---- Mein Unterricht ------------------------------------------------------

/// Erfundene Themen und Hausaufgaben je Fach, je Jahrgang verschieden
/// (sonst stünden bei zwei Kindern dieselben Aufgaben doppelt).
const _topics7 = {
  'D': ('Gedichte der Romantik', 'Gedicht S. 34 auswendig lernen'),
  'M': ('Brüche erweitern und kürzen', 'Buch S. 52 Nr. 3–5'),
  'E': ('Unit 2: At the station', 'Workbook p. 18'),
  'F': ('Leçon 3: En ville', 'Vokabeln Leçon 3'),
  'BIO': ('Die Zelle', null),
  'CH': ('Stoffe und ihre Eigenschaften', null),
  'PH': ('Licht und Schatten', 'Arbeitsblatt fertigstellen'),
  'G': ('Das Leben im Mittelalter', null),
  'EK': ('Klimazonen der Erde', null),
  'SP': ('Ballspiele', null),
  'MU': ('Rhythmus und Takt', null),
  'KU': ('Farbenlehre', null),
  'ETH': ('Was ist Freundschaft?', null),
  'REV': ('Die Schöpfungsgeschichte', null),
  'RKA': ('Feste im Kirchenjahr', null),
  'INF': ('Algorithmen im Alltag', null),
};

const _topics5 = {
  'D': ('Märchen erzählen', 'Eigenes Märchen schreiben'),
  'M': ('Große Zahlen runden', 'AH S. 14 Nr. 1–2'),
  'E': ('Unit 1: My school', 'Vokabeln Unit 1 lernen'),
  'BIO': ('Haustiere', null),
  'G': ('Die Steinzeit', null),
  'EK': ('Unser Schulort auf der Karte', null),
  'SP': ('Turnen an Geräten', null),
  'MU': ('Instrumente kennenlernen', null),
  'KU': ('Linien und Muster', 'Mustervorlage mitbringen'),
  'ETH': ('Regeln in der Klasse', null),
  'REV': ('Josef und seine Brüder', null),
};

(String, String?) _topic(DemoPupil p, String subject) =>
    (p.className.startsWith('05') ? _topics5 : _topics7)[subject] ??
    (demoSubjects[subject]!.name, null);

String _courseHref(DemoPupil p, String subject, {bool parent = false}) =>
    'meinunterricht.php?a=sus_view&amp;id=${demoCourseId(p, subject)}'
    '${parent ? '&amp;p=${p.id}' : ''}';

/// Letzter Termin eines Kurses vor heute – über alle Stunden des Fachs
/// in der Woche (bis 9427 nur die erste, dann lag die neueste Mathestunde
/// manchmal eine Woche zurück).
///
/// Physik bewusst älter (mindestens acht Schultage): So zeigt die Demo
/// immer eine Aufgabe mit „war fällig … · erledigt?“, unabhängig vom
/// Wochentag (Demo-Prüfung 27.10.26).
DateTime _lastLesson(DemoPupil p, DemoSlot s, DemoClock c) {
  final days = {
    for (final o in p.ownPlan)
      if (o.subject == s.subject) o.day,
  };
  final start = s.subject == 'PH' ? 8 : 1;
  for (var n = start; n < start + 10; n++) {
    final d = c.pastSchoolDay(n);
    if (days.contains(d.weekday - 1)) return d;
  }
  return c.pastSchoolDay(5);
}

String _tiles(DemoPupil p, {required bool parent}) => p.courses.map((s) {
  final t = demoTeachers[s.teacher]!;
  final name = demoSubjects[s.subject]!.name;
  return '<div class="col-md-4"><div class="thumbnail"><h2>$name</h2>'
      '<div class="btn-group"><button title="${t.full} (${t.code})">'
      '${t.code}</button></div>'
      '<a class="btn btn-primary" href="${_courseHref(p, s.subject, parent: parent)}">'
      'Kursmappe</a></div></div>';
}).join();

String _current(
  DemoPupil p,
  DemoClock c, {
  required bool parent,
}) => p.courses.map((s) {
  final (topic, hw) = _topic(p, s.subject);
  final done = s.subject == 'E';
  return '<tr class="printable" data-entry="${demoCourseId(p, s.subject)}1">'
      '<td><h3><a href="${_courseHref(p, s.subject, parent: parent)}">'
      '${demoSubjects[s.subject]!.name}</a></h3>'
      '<span class="datum">${dmy(_lastLesson(p, s, c))}</span> '
      '<b class="thema">${_esc(topic)}</b>'
      '${hw == null ? '' : '<span class="homework"></span>'
                '<span class="realHomework">${_esc(hw)}</span>'
                '${done ? '' : '<span class="undone"></span>'}'}'
      '</td></tr>';
}).join();

String _attendance(DemoPupil p, {required bool parent}) =>
    '<table><thead><tr><th>Kurs</th><th>Lehrkraft</th><th>anwesend</th>'
    '<th>entschuldigt</th><th>unentschuldigt</th></tr></thead><tbody>'
    '${p.courses.map((s) => '<tr><td><a href="${_courseHref(p, s.subject, parent: parent)}">'
        '${demoSubjects[s.subject]!.name}</a></td><td>${s.teacher}</td>'
        '<td>${s.subject == 'SP' ? 10 : 12}</td>'
        '<td>${s.subject == 'SP' ? 2 : 0}</td><td>0</td></tr>').join()}'
    '</tbody></table>';

/// meinunterricht.php – Schüler: `#mappen`, `tr.printable`, `#anwesend`
/// (LessonsStudentParser.getHome); Eltern: je Kind `div.pupilbox` mit
/// `h2[data-pupil]` und `#mappen<ID>` … (fork/lessons_parent.dart).
String lessonsPage(DemoUser u, DemoClock c) {
  if (u.role == DemoRole.student) {
    final p = u.pupils.first;
    return _page(
      'mein Unterricht',
      '<div id="aktuell"><table>${_current(p, c, parent: false)}</table></div>'
          '<div id="mappen"><div class="row">${_tiles(p, parent: false)}</div></div>'
          '<div id="anwesend">${_attendance(p, parent: false)}</div>',
    );
  }
  return _page(
    'mein Unterricht',
    u.pupils
        .map(
          (p) =>
              '<div class="pupilbox"><h2 data-pupil="${p.id}">${p.last}, '
              '${p.first}</h2>'
              '<div id="aktuell${p.id}"><table>${_current(p, c, parent: true)}</table></div>'
              '<div id="mappen${p.id}"><div class="row">${_tiles(p, parent: true)}</div></div>'
              '<div id="anwesend${p.id}">${_attendance(p, parent: true)}</div>'
              '</div>',
        )
        .join(),
    icon: _icon(u),
  );
}

/// meinunterricht.php?a=sus_view&id=… – Kursmappe mit Historie, Anwesenheit,
/// Noten und Leistungskontrollen (LessonsStudentParser.getDetailedCourseView).
/// Grenze: `#marks` und `#klausuren` müssen da sein, sonst bricht der Parser
/// ab (Cast `as List`, `children[0]`).
String? coursePage(DemoUser u, String courseId, DemoClock c) {
  for (final p in u.pupils) {
    for (final s in p.courses) {
      if (demoCourseId(p, s.subject) != courseId) continue;
      final t = demoTeachers[s.teacher]!;
      final name = demoSubjects[s.subject]!.name;
      final (topic, hw) = _topic(p, s.subject);
      final last = _lastLesson(p, s, c);
      final hours = s.from == s.to ? '${s.from}.' : '${s.from}. - ${s.to}.';
      String entry(
        int n,
        DateTime d,
        String title,
        String? homework,
        bool done, {
        String presence = 'anwesend',
      }) =>
          '<tr data-entry="$courseId$n"><td>${dmy(d)}\n$hours Stunde</td>'
          '<td><b>${_esc(title)}</b><br /><span class="markup">'
          '<i class="far fa-comment-alt"></i> Wir haben das Thema '
          'gemeinsam erarbeitet.</span>'
          '${homework == null ? '' : '<br /><span class="homework">Hausaufgabe</span>'
                    '<br /><span class="markup">${_esc(homework)}</span>'
                    '${done ? '' : '<span class="done hidden"></span>'}'}'
          '${n == 1 ? _uploadButtons(p, s.subject, c) : ''}'
          '</td><td>$presence</td></tr>';
      final exam = s.subject == 'M'
          ? '<li>${dmy(c.schoolDay(4))} Klassenarbeit, 1. - 2. Std.</li>'
          // Morgen, damit Heute die Arbeit als Hinweis zeigt (examIsHint gilt
          // nur heute und am nächsten Schultag; Demo-Prüfung 27.10.26).
          : s.subject == 'E'
          ? '<li>${dmy(c.schoolDay(1))} Vokabeltest</li>'
          : null;
      final marks = s.subject == 'M' || s.subject == 'D' || s.subject == 'E';
      return _page(
        '$name ${p.className}',
        '<h1><small>Kursmappe</small> $name ${p.className}</h1>'
            '<div class="btn-group"><button class="btn btn-primary '
            'dropdown-toggle btn-md">${t.code}</button><ul><li><a href="#">'
            '${t.full}</a></li></ul></div>'
            '<div id="history"><table><tbody>'
            '${entry(1, last, topic, hw, s.subject == 'E')}'
            '${entry(2, last.subtract(const Duration(days: 7)), 'Wiederholung', null, true, presence: s.subject == 'SP' ? 'entschuldigt' : 'anwesend')}'
            '</tbody></table></div>'
            '<div id="attendanceTable"><table><tbody>'
            '<tr><td>anwesend</td><td>${s.subject == 'SP' ? 10 : 12}</td></tr>'
            '<tr><td>entschuldigt</td><td>${s.subject == 'SP' ? 2 : 0}</td></tr>'
            '</tbody></table></div>'
            '<div id="marks"><table><tbody>'
            '${marks ? '<tr><td>Mündliche Mitarbeit</td><td>${dmy(c.pastSchoolDay(12))}</td><td>2</td></tr>' : ''}'
            '</tbody></table></div>'
            '<div id="klausuren">${exam == null ? '<p>Diese Kursmappe beinhaltet leider noch keine Leistungskontrollen!</p>' : '<div><h3>Kommende Leistungskontrollen</h3><ul>$exam</ul></div>'}</div>',
        icon: _icon(u),
      );
    }
  }
  return null;
}

// ---- Abgaben ----------------------------------------------------------------

/// Erfundene Abgabe einer Kursstunde (Lena, 7b). Ursache (Wunsch
/// 27.10.26): Die neue Abgabeseite (upload_view.dart) war in der Demo nicht
/// zu sehen – keine Kursmappe hatte eine Abgabe. Je ein Beispiel für die
/// drei Zustände: offen mit einer Datei (G), schon abgegeben (INF), mehrere
/// Dateien beliebig oft mit Hinweis und Dateien der Lerngruppe (KU).
/// Grenze: Hochladen und Löschen sperrt die Demo (blockedInDemo); die
/// Dateien sind ein leeres Demo-PDF ([demoPdf]).
class DemoUpload {
  const DemoUpload({
    required this.subject,
    required this.name,
    required this.startBack,
    required this.dueIn,
    required this.dueTime,
    this.multiple = false,
    this.repeat = false,
    this.visibility = 'Lehrkraft',
    this.types = 'pdf, docx, jpg',
    this.ownFile,
    this.note,
    this.publicFiles = const [],
  });
  final String subject;
  final String name;

  /// Start [startBack] Schultage zurück, 08:00.
  final int startBack;

  /// Frist in [dueIn] Schultagen um [dueTime].
  final int dueIn;
  final String dueTime;
  final bool multiple;
  final bool repeat;
  final String visibility;
  final String types;

  /// Schon abgegebene eigene Datei (gestern, 19:42).
  final String? ownFile;
  final String? note;

  /// (Datei, Person) – erfundene Mitschüler.
  final List<(String, String)> publicFiles;
}

const demoUploads = [
  DemoUpload(
    subject: 'G',
    name: 'Referat Mittelalter',
    startBack: 1,
    dueIn: 3,
    dueTime: '18:00',
  ),
  DemoUpload(
    subject: 'INF',
    name: 'Algorithmus aus dem Alltag',
    startBack: 4,
    dueIn: 2,
    dueTime: '20:00',
    ownFile: 'Algorithmus_Fruehstueck.pdf',
  ),
  DemoUpload(
    subject: 'KU',
    name: 'Fotos Farbkreis',
    startBack: 2,
    dueIn: 6,
    dueTime: '23:59',
    multiple: true,
    repeat: true,
    visibility: 'Lehrkraft und Kursteilnehmer',
    types: 'jpg, png, pdf',
    note: 'Bitte fotografiert euren Farbkreis bei Tageslicht.',
    publicFiles: [
      ('Farbkreis_Tim.pdf', 'Tim K.'),
      ('Farbkreis_Ella.pdf', 'Ella S.'),
    ],
  ),
];

String _uploadId(DemoPupil p, DemoUpload u) => '${demoCourseId(p, u.subject)}9';

Iterable<DemoUpload> _uploadsOf(DemoPupil p, String subject) =>
    p.className.startsWith('07')
    ? demoUploads.where((u) => u.subject == subject)
    : const [];

const _weekdays = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

/// Wie das Portal: „Freitag, den 30.10.26 18:00 Uhr“ (UploadDates.tryParse,
/// Muster „EEEE d.M.yy H:mm“ nach Entfernen von „,“, „ den“, „ Uhr“).
String _portalDateTime(DateTime d, String time) =>
    '${_weekdays[d.weekday - 1]}, den ${_two(d.day)}.${_two(d.month)}.'
    '${_two(d.year % 100)} $time Uhr';

/// Abgabe-Knöpfe in der Kursmappe (liblanis StudentParser
/// .getDetailedCourseView: `div.btn-group` mit `.btn-warning`, Name als
/// drittes Kind, `span.badge` = abgegeben, `small` = Frist, Adresse aus
/// `ul.dropdown-menu li a`).
String _uploadButtons(DemoPupil p, String subject, DemoClock c) =>
    _uploadsOf(p, subject).map((u) {
      final due = c.schoolDay(u.dueIn);
      final badge = u.ownFile == null
          ? ''
          : '<span class="badge">1 Datei</span> ';
      return '<div class="btn-group"><button type="button" '
          'class="btn btn-warning btn-xs dropdown-toggle"> '
          '<i class="fa fa-upload"></i> ${_esc(u.name)} $badge'
          '<small>bis ${dmy(due)} ${u.dueTime}</small></button>'
          '<ul class="dropdown-menu"><li><a href="meinunterricht.php?'
          'a=sus_abgabe&amp;id=${_uploadId(p, u)}">Abgabe öffnen</a></li>'
          '</ul></div>';
    }).join();

/// meinunterricht.php?a=sus_abgabe&id=… – Abgabeseite (liblanis
/// StudentParser.getUploadInfo): `#content .row .col-md-12` [1] Vorgaben,
/// [2] eigene Dateien; `.col-md-7 form` mit b/e/id (fehlt nach der
/// einzigen Abgabe); `.col-md-5` Dateien der Lerngruppe. Grenze: Die beiden
/// Haken stehen immer als `label-success` da – der Parser liest sie per
/// Index, ein anderes Label würde die Seite brechen.
String? uploadPage(DemoUser user, String id, DemoClock c) {
  for (final p in user.pupils) {
    for (final u in demoUploads) {
      if (_uploadId(p, u) != id || _uploadsOf(p, u.subject).isEmpty) continue;
      final course = demoCourseId(p, u.subject);
      final start = c.pastSchoolDay(u.startBack);
      final due = c.schoolDay(u.dueIn);
      final deletion = DateTime(due.year, due.month + 3, due.day);
      String flag(bool on) =>
          '<i class="fa fa-check-square-o fa-fw"></i>'
          '<span class="label label-success">${on ? 'erlaubt' : 'nicht erlaubt'}</span>';
      final eye = u.visibility == 'Lehrkraft' ? 'fa-eye-slash' : 'fa-eye';
      final own = u.ownFile == null
          ? ''
          : '<li><a href="meinunterricht.php?a=download&amp;f=1">'
                '${_esc(u.ownFile!)}</a> <small>(hochgeladen am '
                '${dmy(c.pastSchoolDay(1))} um 19:42 Uhr)</small></li>';
      final closed = u.ownFile != null && !u.repeat;
      final form = closed
          ? ''
          : '<form><input name="b" value="$course" />'
                '<input name="e" value="${course}1" />'
                '<input name="id" value="$id" /></form>';
      final public = u.publicFiles.isEmpty
          ? ''
          : '<div class="col-md-5"><h3>Dateien der Lerngruppe</h3><ul>'
                '${[for (final (i, (f, who)) in u.publicFiles.indexed) '<li><a href="meinunterricht.php?a=download&amp;f=${i + 2}">${_esc(f)}</a> <span class="label label-info">${_esc(who)}</span></li>'].join()}'
                '</ul></div>';
      return _page(
        u.name,
        '<div id="content">'
        '<div class="row"><div class="col-md-12"><h1>${_esc(u.name)}</h1>'
        '</div></div>'
        '<div class="row"><div class="col-md-12">'
        '<p>Abgabe ab <span class="editable">${_portalDateTime(start, '08:00')} ab</span></p>'
        '<p>Abgabe bis <b><span class="editable">${_portalDateTime(due, u.dueTime)}  spätestens</span></b></p>'
        '<p>Mehrere Dateien ${flag(u.multiple)}</p>'
        '<p>Beliebig oft abgeben ${flag(u.repeat)}</p>'
        '<p>Sichtbar für <i class="fa $eye fa-fw"></i><span class="label">${u.visibility}</span></p>'
        '<p>Löschung <i class="fa fa-trash-o fa-fw"></i><span class="label label-info">${dmy(deletion)}</span></p>'
        '<p>Dateitypen <i class="fa fa-file fa-fw"></i><span class="label label-warning">${u.types}</span></p>'
        '<p>Größe <i class="fa fa-file fa-fw"></i><span class="label label-warning">10 MB</span></p>'
        '${u.note == null ? '' : '<div class="alert alert-info"><b>Hinweis:</b>\n${_esc(u.note!)}\n</div>'}'
        '</div></div>'
        '<div class="row"><div class="col-md-12"><h3>Eigene Dateien</h3>'
        '<ul>$own</ul></div></div>'
        '<div class="row"><div class="col-md-7">$form</div>$public</div>'
        '</div>',
      );
    }
  }
  return null;
}

/// Kleines gültiges PDF mit einer Zeile Text, für jede Datei einer
/// Demo-Abgabe (meinunterricht.php?a=download). Versätze der xref-Tabelle
/// werden mitgerechnet, damit Betrachter es ohne Reparatur öffnen.
String demoPdf() {
  const text = 'Beispieldatei der Demo';
  final stream = 'BT /F1 18 Tf 72 720 Td ($text) Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
    '<< /Length ${stream.length} >>\nstream\n$stream\nendstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  final b = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (final (i, o) in objects.indexed) {
    offsets.add(b.length);
    b.write('${i + 1} 0 obj\n$o\nendobj\n');
  }
  final xref = b.length;
  b.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    b.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  b.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  return b.toString();
}

// ---- Nachrichten ----------------------------------------------------------

class DemoMessage {
  const DemoMessage(
    this.id,
    this.subject,
    this.from,
    this.daysAgo,
    this.text, {
    this.unread = false,
  });
  final String id;
  final String subject;
  final String from;
  final int daysAgo;
  final String text;
  final bool unread;
}

/// Nachrichten je Konto – Eltern bekommen andere als das Kind selbst.
List<DemoMessage> demoMessagesFor(DemoUser u) => u.role == DemoRole.parent
    ? const [
        DemoMessage(
          'demo-msg-e1',
          'Einladung zum Elternabend',
          'SOM',
          0,
          'Liebe Eltern der 5a, herzliche Einladung zum Elternabend. Wir '
              'sprechen über die Klassenfahrt und den Wandertag.',
          unread: true,
        ),
        DemoMessage(
          'demo-msg-e2',
          'Wandertag: Treffpunkt',
          'SOM',
          2,
          'Wir treffen uns um 8:00 Uhr am Haupteingang. Bitte an '
              'wetterfeste Kleidung denken.',
        ),
        DemoMessage(
          'demo-msg-e3',
          'Fotos vom Sportfest',
          'PAU',
          6,
          'Die Fotos liegen ab sofort im Sekretariat zur Ansicht aus.',
        ),
      ]
    : const [
        DemoMessage(
          'demo-msg-s1',
          'Workbook mitbringen',
          'MAY',
          0,
          'Bitte bringt am Donnerstag euer Workbook mit.',
          unread: true,
        ),
        DemoMessage(
          'demo-msg-s2',
          'Informatik-AG',
          'NEU',
          3,
          'Die Anmeldung zur Informatik-AG ist bis Freitag im Raum R305 '
              'möglich.',
        ),
      ];

/// POST nachrichten.php a=headers – Liste als JSON, im Portal verschlüsselt
/// (`rows`, ConversationsParser.getHome). Hier im Klartext; das
/// Verschlüsseln macht DemoPortal mit dem Sitzungsschlüssel.
String messageRows(DemoUser u, DemoClock c) => jsonEncode([
  for (final m in demoMessagesFor(u))
    {
      'Uniquid': m.id,
      'Betreff': m.subject,
      'kuerzel': m.from,
      'SenderName':
          '<i class="fa fa-user"></i> ${demoTeachers[m.from]!.full} (${m.from})',
      'Datum': '${dmy(c.today.subtract(Duration(days: m.daysAgo)))} 07:45',
      'unread': m.unread ? 1 : 0,
      'Papierkorb': 'nein',
    },
]);

/// POST nachrichten.php a=read – eine Unterhaltung (getSingleConversation).
String? messageRead(DemoUser u, String id, DemoClock c) {
  for (final m in demoMessagesFor(u)) {
    if (m.id != id) continue;
    final t = demoTeachers[m.from]!;
    return jsonEncode({
      'Uniquid': m.id,
      'Datum': '${dmy(c.today.subtract(Duration(days: m.daysAgo)))} 07:45',
      'username': '${t.full} (${t.code})',
      'own': false,
      'Inhalt': m.text,
      'Betreff': m.subject,
      'reply': <Object>[],
      'statistik': {'teilnehmer': 24, 'betreuer': 1, 'eltern': 24},
      'SenderArt': 'Betreuer',
      'empf': <Object>[],
      'WeitereEmpfaenger': '',
      'groupOnly': 'nein',
      'privateAnswerOnly': 'ja',
      'noAnswerAllowed': 'ja',
    });
  }
  return null;
}
