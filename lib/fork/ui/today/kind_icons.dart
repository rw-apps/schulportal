import 'package:flutter/material.dart';

import 'today_model.dart';

/// Symbole je Art eines Hinweises – an einer Stelle, damit „Heute“,
/// Kinderkarte und Demnächst dieselben zeigen.
///
/// Ursache (Wunsch 20.10.26: „für Ausfall ein Icon … und für weitere
/// Hinweise“): Vorher stand vor jeder Zeile ein Farbpunkt; Ausfall,
/// Vertretung und Raumwechsel unterschieden sich nur im Text.
IconData changeIcon(ChangeKind kind) => switch (kind) {
  ChangeKind.cancelled => Icons.event_busy_outlined,
  ChangeKind.substitution => Icons.swap_horiz,
  ChangeKind.roomChange => Icons.meeting_room_outlined,
  ChangeKind.unclear => Icons.help_outline,
};

IconData weekIcon(WeekKind kind) => switch (kind) {
  WeekKind.exam => Icons.edit_note,
  WeekKind.event => Icons.event_outlined,
  WeekKind.deadline => Icons.timer_outlined,
  WeekKind.free => Icons.beach_access_outlined,
  WeekKind.meal => Icons.restaurant_outlined,
};
