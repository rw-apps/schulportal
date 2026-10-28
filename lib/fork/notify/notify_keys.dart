import 'package:liblanis/liblanis.dart' show TypedSettings;

/// Schalter der Benachrichtigungen, gemeinsam für „Was und wann“
/// (notify_settings_page.dart) und den Hintergrund (background_service.dart,
/// notify_task.dart).

/// Je Konto: große Termine am Vorabend (notices.dart, isBigEvent).
///
/// Ursache (Abnahme 27.10.26): Bisher hingen sie am Schalter für den
/// Vertretungsplan („Ausfall, Vertretung, große Termine“) – kurzfristig
/// Dringendes und Planbares ließen sich nicht getrennt abschalten. Ohne
/// eigenen Eintrag gilt der bisherige Schalter weiter, damit nach dem Update
/// nichts von selbst an- oder ausgeht.
const notifyEventsKey = 'notification-events';

bool notifyEventsOn(TypedSettings account) =>
    account.getBool(notifyEventsKey) ??
    (account.getBool('notification-vertretungsplan.php') ?? true);

/// Für alle Konten: neue Nachrichten auch außerhalb des Zeitfensters,
/// dann ohne Ton (Abnahme 27.10.26, „Nachrichten auch nachts“). Standard
/// aus: Das Zeitfenster schützt die Nachtruhe.
const notifyNightMessagesKey = 'fork-notify/night-messages';

bool notifyNightMessages(TypedSettings shared) =>
    shared.getBool(notifyNightMessagesKey) ?? false;

/// Für alle Konten: Ende des letzten vollständigen Hintergrundlaufs im
/// Zeitfenster (ISO-8601), geschrieben von callbackDispatcher
/// (background_service.dart).
const notifyLastFullRunKey = 'fork-notify/last-full-run';

DateTime? lastFullRun(TypedSettings shared) =>
    DateTime.tryParse(shared.getString(notifyLastFullRunKey) ?? '');

void noteFullRun(TypedSettings shared, DateTime at) =>
    shared.setString(notifyLastFullRunKey, at.toIso8601String());

/// Braucht es den Einmal-Lauf kurz nach dem Start (setupBackgroundService)?
///
/// Ursache (Prüfung 27.10.26, Befund 9): Er wurde bei JEDEM App-Start
/// geplant und meldete 10 s später jedes Konto noch einmal an – zusätzlich
/// zur Anmeldung der App selbst (AuthController, FamilyScope). Gedacht ist
/// er für die erste Meldung bald nach dem Einrichten. Jetzt nur, wenn noch
/// nie ein vollständiger Lauf war oder der letzte mindestens einen Abstand
/// [interval] (der regelmäßigen Abfrage) zurückliegt.
///
/// Grenze: Liegt [lastRun] in der Zukunft (Uhr zurückgestellt), gilt der
/// Lauf als fällig – sonst bliebe er womöglich tagelang aus. Abgebrochene
/// Läufe (außerhalb der Uhrzeiten, nur nachts die Nachrichten, kein Netz)
/// zählen nicht als vollständig.
bool startRunDue(DateTime? lastRun, DateTime now, Duration interval) {
  if (lastRun == null || lastRun.isAfter(now)) return true;
  return now.difference(lastRun) >= interval;
}
