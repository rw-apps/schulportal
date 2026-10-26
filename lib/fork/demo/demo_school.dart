/// Erfundene Schule für den Demo-Modus (demo_portal.dart).
///
/// Ursache (Entscheidung 26.10.26): Neue Nutzer, Lehrkräfte und die
/// Abnahme sollen die App ohne echtes Konto ansehen können. Alle Namen,
/// Klassen, Räume und Kürzel sind frei erfunden (Sicherheitsregel: keine
/// echten Schuldaten im Repo); die Vornamen der Kinder sind dieselben wie in
/// der Vorschau (preview/demo_plan.dart), damit Bilder und Demo
/// zusammenpassen.
///
/// Grenze: Eine Woche, die sich wiederholt; Vertretungen, Termine und
/// Einträge liegen relativ zu „heute“ (DemoPortal.now), damit Heute und die
/// laufende Stunde immer etwas zeigen.
library;

/// Schulnummer der Demo. Ursache: liblanis braucht eine Zahl (Anmeldung
/// `?i=`); 0 vergibt das Portal nicht, eine Verwechslung ist ausgeschlossen.
const demoSchoolId = 0;
const demoSchoolName = 'Demo-Gesamtschule Musterstadt';

class DemoTeacher {
  const DemoTeacher(this.code, this.first, this.last);
  final String code;
  final String first;
  final String last;
  String get full => '$first $last';
}

const demoTeachers = {
  'KLM': DemoTeacher('KLM', 'Petra', 'Klemm'),
  'BEC': DemoTeacher('BEC', 'Maria', 'Becker'),
  'FIS': DemoTeacher('FIS', 'Anna', 'Fischer'),
  'MAY': DemoTeacher('MAY', 'Lukas', 'Mayer'),
  'SOM': DemoTeacher('SOM', 'Tim', 'Sommer'),
  'NEU': DemoTeacher('NEU', 'Jan', 'Neumann'),
  'ORT': DemoTeacher('ORT', 'Eva', 'Ort'),
  'PAU': DemoTeacher('PAU', 'Ole', 'Paulsen'),
  'HAH': DemoTeacher('HAH', 'Ida', 'Hahn'),
  'WEB': DemoTeacher('WEB', 'Nina', 'Weber'),
  'ROT': DemoTeacher('ROT', 'Paul', 'Roth'),
  'VOG': DemoTeacher('VOG', 'Lea', 'Vogel'),
  'KRA': DemoTeacher('KRA', 'Ben', 'Krause'),
};

/// Fach: Kürzel im Plan, Name in „Mein Unterricht“.
class DemoSubject {
  const DemoSubject(this.code, this.name);
  final String code;
  final String name;
}

const demoSubjects = {
  'D': DemoSubject('D', 'Deutsch'),
  'M': DemoSubject('M', 'Mathematik'),
  'E': DemoSubject('E', 'Englisch'),
  'F': DemoSubject('F', 'Französisch'),
  'BIO': DemoSubject('BIO', 'Biologie'),
  'CH': DemoSubject('CH', 'Chemie'),
  'PH': DemoSubject('PH', 'Physik'),
  'G': DemoSubject('G', 'Geschichte'),
  'EK': DemoSubject('EK', 'Erdkunde'),
  'SP': DemoSubject('SP', 'Sport'),
  'MU': DemoSubject('MU', 'Musik'),
  'KU': DemoSubject('KU', 'Kunst'),
  'ETH': DemoSubject('ETH', 'Ethik'),
  'REV': DemoSubject('REV', 'Ev. Religion'),
  'RKA': DemoSubject('RKA', 'Kath. Religion'),
  'INF': DemoSubject('INF', 'Informatik'),
};

/// Eine Stunde im Wochenplan: Fach, Lehrkraft, Raum, Stunden von–bis.
/// Mehrere Einträge mit gleicher Zeit = parallele Kurse (Religion/Ethik).
class DemoSlot {
  const DemoSlot(
    this.day,
    this.from,
    this.to,
    this.subject,
    this.teacher,
    this.room,
  );
  final int day; // 0 = Montag
  final int from;
  final int to;
  final String subject;
  final String teacher;
  final String room;
}

/// Stundenraster (1.–8. Stunde).
const demoBells = [
  ('08:00', '08:45'),
  ('08:45', '09:30'),
  ('09:50', '10:35'),
  ('10:35', '11:20'),
  ('11:40', '12:25'),
  ('12:25', '13:10'),
  ('14:00', '14:45'),
  ('14:45', '15:30'),
];

class DemoPupil {
  const DemoPupil({
    required this.id,
    required this.first,
    required this.last,
    required this.className,
    required this.plan,
    required this.ownGroups,
  });

  /// Interne Nummer wie `p=` im Portal (erfunden).
  final String id;
  final String first;
  final String last;
  final String className;
  final List<DemoSlot> plan;

  /// Gewählte Kurse bei parallelen Gruppen (persönlicher Plan).
  final Set<String> ownGroups;

  /// Kurse dieses Kindes: je Fach einmal, eigene Gruppe statt aller.
  List<DemoSlot> get courses {
    final seen = <String>{};
    return [
      for (final s in plan)
        if (_mine(s) && seen.add(s.subject)) s,
    ];
  }

  bool _mine(DemoSlot s) {
    final parallel = plan.where(
      (o) => o.day == s.day && o.from == s.from && o.subject != s.subject,
    );
    return parallel.isEmpty || ownGroups.contains(s.subject);
  }

  List<DemoSlot> get ownPlan => [
    for (final s in plan)
      if (_mine(s)) s,
  ];
}

/// Lena, 7b – im Schüler-Demo das eigene Konto, im Eltern-Demo das
/// zweite Konto der Familie (wie bei einem älteren Kind mit eigenem
/// Zugang).
const demoLena = DemoPupil(
  id: '41007',
  first: 'Lena',
  last: 'Beispiel',
  className: '07B',
  ownGroups: {'REV'},
  plan: [
    DemoSlot(0, 1, 2, 'D', 'KLM', 'R112'),
    DemoSlot(0, 3, 4, 'M', 'BEC', 'R204'),
    DemoSlot(0, 5, 5, 'E', 'MAY', 'R117'),
    DemoSlot(0, 6, 6, 'BIO', 'FIS', 'R310'),
    DemoSlot(1, 1, 2, 'SP', 'PAU', 'Halle 1'),
    DemoSlot(1, 3, 4, 'E', 'MAY', 'R117'),
    DemoSlot(1, 5, 6, 'ETH', 'ROT', 'R101'),
    DemoSlot(1, 5, 6, 'REV', 'VOG', 'R102'),
    DemoSlot(1, 5, 6, 'RKA', 'KRA', 'R103'),
    DemoSlot(2, 1, 2, 'M', 'BEC', 'R204'),
    DemoSlot(2, 3, 3, 'G', 'SOM', 'R118'),
    DemoSlot(2, 4, 4, 'EK', 'PAU', 'R021'),
    DemoSlot(2, 5, 6, 'KU', 'WEB', 'Kunstraum'),
    DemoSlot(3, 1, 2, 'F', 'HAH', 'R115'),
    DemoSlot(3, 3, 4, 'D', 'KLM', 'R112'),
    DemoSlot(3, 5, 5, 'PH', 'NEU', 'R302'),
    DemoSlot(3, 6, 6, 'MU', 'HAH', 'Musiksaal'),
    DemoSlot(3, 7, 8, 'INF', 'NEU', 'R305'),
    DemoSlot(4, 1, 1, 'CH', 'ORT', 'R301'),
    DemoSlot(4, 2, 2, 'BIO', 'FIS', 'R310'),
    DemoSlot(4, 3, 4, 'M', 'BEC', 'R204'),
    DemoSlot(4, 5, 6, 'D', 'KLM', 'R112'),
  ],
);

/// Jonas, 5a – das Kind im Elternkonto.
const demoJonas = DemoPupil(
  id: '41005',
  first: 'Jonas',
  last: 'Beispiel',
  className: '05A',
  ownGroups: {'ETH'},
  plan: [
    DemoSlot(0, 1, 2, 'M', 'BEC', 'R201'),
    DemoSlot(0, 3, 4, 'D', 'SOM', 'R105'),
    DemoSlot(0, 5, 6, 'SP', 'PAU', 'Halle 2'),
    DemoSlot(1, 1, 2, 'E', 'MAY', 'R106'),
    DemoSlot(1, 3, 3, 'BIO', 'FIS', 'R310'),
    DemoSlot(1, 4, 4, 'MU', 'HAH', 'Musiksaal'),
    DemoSlot(1, 5, 6, 'KU', 'WEB', 'Kunstraum'),
    DemoSlot(2, 1, 2, 'D', 'SOM', 'R105'),
    DemoSlot(2, 3, 4, 'M', 'BEC', 'R201'),
    DemoSlot(2, 5, 5, 'EK', 'PAU', 'R021'),
    DemoSlot(2, 6, 6, 'ETH', 'ROT', 'R101'),
    DemoSlot(2, 6, 6, 'REV', 'VOG', 'R102'),
    DemoSlot(3, 1, 2, 'E', 'MAY', 'R106'),
    DemoSlot(3, 3, 3, 'G', 'SOM', 'R105'),
    DemoSlot(3, 4, 4, 'BIO', 'FIS', 'R310'),
    DemoSlot(3, 5, 6, 'SP', 'PAU', 'Halle 2'),
    DemoSlot(4, 1, 2, 'M', 'BEC', 'R201'),
    DemoSlot(4, 3, 4, 'D', 'SOM', 'R105'),
    DemoSlot(4, 5, 5, 'E', 'MAY', 'R106'),
  ],
);

/// Wer sich in der Demo anmeldet (Benutzername → Rolle).
enum DemoRole { parent, student }

class DemoUser {
  const DemoUser(this.username, this.role, this.pupils);
  final String username;
  final DemoRole role;

  /// Schüler: das Kind selbst; Eltern: die Kinder im Konto.
  final List<DemoPupil> pupils;
}

const demoParent = DemoUser('demo.eltern', DemoRole.parent, [demoJonas]);
const demoStudent = DemoUser('demo.lena', DemoRole.student, [demoLena]);

DemoUser? demoUserNamed(String username) => switch (username) {
  'demo.eltern' => demoParent,
  'demo.lena' => demoStudent,
  _ => null,
};

/// Kurs-ID wie im Portal (`meinunterricht.php?a=sus_view&id=…`).
String demoCourseId(DemoPupil p, String subject) =>
    '${p.id.substring(3)}${demoSubjects.keys.toList().indexOf(subject) + 10}';
