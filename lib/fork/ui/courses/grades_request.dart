import 'package:flutter/foundation.dart';

/// Auftrag an „Unterricht“, beim nächsten Aufbau „Arbeiten & Noten“ zu
/// zeigen (CoursesPage). Ursache (Rückmeldung 30.10.26): Ein Arbeits-
/// Hinweis auf Heute führte in den Kalender; gefragt sind dort aber die
/// anstehenden Arbeiten und Noten des Kindes. Gesetzt von preview_shell.dart
/// (_openExams), verbraucht von der ersten CoursesPage, die ihn sieht.
/// Grenze: Die Ansicht „Alle“ hat keinen Umschalter; das Kind wählt die
/// Heute-Seite vorher aus (live_today_page.dart, select).
final gradesRequest = ValueNotifier<bool>(false);
