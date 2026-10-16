import '../plan/plan_model.dart';
import '../today/today_model.dart' show ChangeKind;

/// Beispielwochen für die Vorschau „Plan“. Lehrkräfte (Kürzel und Namen),
/// Räume und Kindernamen erfunden. Zeitraster Schule A (Blöcke) aus dem Export vom 16.10.26, Raster der
/// Schule B geschätzt. Dienstag passt zur Vorschau „Heute“ (10:50).
///
/// Parallelgruppen wie im echten Klassenplan von Schule A: Textil in vier Gruppen
/// (Do und Fr 1. Block); bei Lena Religion/Ethik nebeneinander.
List<KidPlan> demoPlans() => [_lena(), _jonas()];

PlanCell _c(List<PlanLesson> l) => PlanCell(l);
PlanCell get _e => const PlanCell([]);

PlanLesson _l(
  String short,
  String subject,
  String room,
  String teacher, {
  ChangeKind? change,
  String? detail,
}) => PlanLesson(
  short: short,
  subject: subject,
  room: room,
  teacher: teacher,
  change: change,
  changeDetail: detail,
);

KidPlan _lena() {
  final d = _l('D', 'Deutsch', 'R 112', 'KLE');
  final e = _l('E', 'Englisch', 'R 117', 'MAY');
  final m = _l('M', 'Mathematik', 'R 204', 'BEC');
  final bio = _l('Bio', 'Biologie', 'R 310', 'FIS');
  final ch = _l('Ch', 'Chemie', 'R 301', 'ORT');
  final ek = _l('Ek', 'Erdkunde', 'R 021', 'HOL');
  final mu = _l('Mu', 'Musik', 'Musiksaal', 'LEH');
  final ph = _l('Ph', 'Physik', 'R 302', 'NEU');
  final g = _l('G', 'Geschichte', 'R 118', 'PAU');
  final sp = _l('Sp', 'Sport', 'Halle 1', 'WAG');
  final spAus = _l(
    'Sp',
    'Sport',
    'Halle 1',
    'WAG',
    change: ChangeKind.cancelled,
  );
  final dVertr = _l(
    'D',
    'Deutsch',
    'R 112',
    'KLE',
    change: ChangeKind.substitution,
    detail: 'Tim Sommer, R 112',
  );
  final reli = [
    _l('ER', 'Ev. Religion', 'R 205', 'ABE'),
    _l('KR', 'Kath. Religion', 'R 206', 'BRA'),
    _l('Eth', 'Ethik', 'R 207', 'CEL'),
  ];
  return KidPlan(
    firstName: 'Lena',
    colorIndex: 0,
    teacherNames: const {
      'KLE': 'Petra Klemm',
      'MAY': 'Lukas Mayer',
      'BEC': 'Maria Becker',
      'FIS': 'Anna Fischer',
      'ORT': 'Stefan Ort',
      'HOL': 'Julia Holm',
      'LEH': 'Peter Lehmann',
      'NEU': 'Sabine Neumann',
      'PAU': 'Thomas Paulsen',
      'WAG': 'Nina Wagner',
      'ABE': 'Eva Abel',
      'BRA': 'Paul Brandt',
      'CEL': 'Lea Celik',
    },
    slots: const [
      PlanSlot(label: '1.', start: '08:00', end: '08:45'),
      PlanSlot(label: '2.', start: '08:45', end: '09:30'),
      PlanSlot(label: '3.', start: '09:50', end: '10:35'),
      PlanSlot(label: '4.', start: '10:35', end: '11:20'),
      PlanSlot(label: '5.', start: '11:40', end: '12:25'),
      PlanSlot(label: '6.', start: '12:30', end: '13:15'),
      PlanSlot(label: '7.', start: '14:00', end: '14:45'),
      PlanSlot(label: '8.', start: '14:45', end: '15:30'),
    ],
    days: [
      [
        _c([d]),
        _c([d]),
        _c([e]),
        _c([e]),
        _c([ch]),
        _c([ch]),
        _e,
        _e,
      ],
      [
        _c([bio]),
        _c([bio]),
        _c([m]),
        _c([m]),
        _c([dVertr]),
        _c([e]),
        _c([ek]),
        _c([mu]),
      ],
      [
        _c([spAus]),
        _c([spAus]),
        _c([m]),
        _c([m]),
        _c(reli),
        _c(reli),
        _e,
        _e,
      ],
      [
        _c([ph]),
        _c([ph]),
        _c([d]),
        _c([d]),
        _c([m]),
        _c([e]),
        _e,
        _e,
      ],
      [
        _c([g]),
        _c([g]),
        _c([bio]),
        _c([bio]),
        _c([m]),
        _c([sp]),
        _e,
        _e,
      ],
    ],
  );
}

KidPlan _jonas() {
  final nawi = _l('NaWi', 'Naturwissenschaften', 'G205', 'NOR');
  final d = _l('D', 'Deutsch', 'R106', 'DIE');
  final e = _l('E', 'Englisch', 'R106', 'WLF');
  final m = _l('M', 'Mathematik', 'R106', 'MEI');
  final gl = _l('GL', 'Gesellschaftslehre', 'R106', 'KRA');
  final ku = _l('Ku', 'Kunst', 'Atelier', 'KUR');
  final sp = _l('Sp', 'Sport', 'Halle', 'BUC');
  List<PlanLesson> txt({bool raumwechsel = false}) => [
    _l(
      'TXT',
      'Textil',
      raumwechsel ? 'R101' : 'R106',
      'ABE',
      change: raumwechsel ? ChangeKind.roomChange : null,
      detail: raumwechsel ? 'R101 statt R106' : null,
    ),
    _l('TXT', 'Textil', 'G107', 'BRU'),
    _l('TXT', 'Textil', 'G108', 'CEL'),
    _l('TXT', 'Textil', 'G109', 'DOR'),
  ];
  return KidPlan(
    firstName: 'Jonas',
    colorIndex: 1,
    teacherNames: const {
      'NOR': 'Ole Nordmann',
      'DIE': 'Ina Dietz',
      'WLF': 'Jan Wolf',
      'MEI': 'Sven Meier',
      'KRA': 'Lisa Kramer',
      'KUR': 'Tom Kurz',
      'BUC': 'Mia Buch',
      'ABE': 'Eva Abel',
      'BRU': 'Ben Brück',
      'CEL': 'Lea Celik',
      'DOR': 'Rita Dorn',
    },
    slots: const [
      PlanSlot(label: '0. Block', start: '08:00', end: '08:45'),
      PlanSlot(label: '1. Block', start: '09:00', end: '10:15'),
      PlanSlot(label: '2. Block', start: '10:30', end: '11:45'),
      PlanSlot(label: '3. Block', start: '12:30', end: '13:45'),
      PlanSlot(label: '4. Block', start: '14:00', end: '15:15'),
    ],
    days: [
      [
        _e,
        _c([nawi]),
        _c([d]),
        _c([ku]),
        _c([ku]),
      ],
      [
        _e,
        _c([gl]),
        _c([e]),
        _c([m]),
        _e,
      ],
      [
        _e,
        _c([d]),
        _c([sp]),
        _c([m]),
        _e,
      ],
      [
        _e,
        _c(txt(raumwechsel: true)),
        _c([e]),
        _c([nawi]),
        _e,
      ],
      [
        _e,
        _c(txt()),
        _c([e]),
        _c([m]),
        _e,
      ],
    ],
  );
}
