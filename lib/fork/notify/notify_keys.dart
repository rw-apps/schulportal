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
