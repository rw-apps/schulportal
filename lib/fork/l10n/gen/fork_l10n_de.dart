// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'fork_l10n.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class ForkL10nDe extends ForkL10n {
  ForkL10nDe([String locale = 'de']) : super(locale);

  @override
  String get dateLong => 'EEEE, d. MMMM';

  @override
  String get dateShort => 'ccc d.M.';

  @override
  String get greetingMorning => 'Guten Morgen';

  @override
  String get greetingDay => 'Guten Tag';

  @override
  String get greetingEvening => 'Guten Abend';

  @override
  String get dayToday => 'Heute';

  @override
  String get dayTomorrow => 'Morgen';

  @override
  String get demoNote => 'Vorschau mit erfundenen Beispieldaten';

  @override
  String get importantTitle => 'Wichtig heute und morgen';

  @override
  String get lessonCancelled => 'fällt aus';

  @override
  String get changeRoom => 'Raumwechsel';

  @override
  String get changeSubstitution => 'Vertretung';

  @override
  String homeworkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Hausaufgaben',
      one: '1 Hausaufgabe',
    );
    return '$_temp0';
  }

  @override
  String unreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachrichten',
      one: '1 Nachricht',
    );
    return '$_temp0';
  }

  @override
  String get orderMeal => 'Essen bestellen';

  @override
  String get reportSick => 'Krank melden';

  @override
  String nowRunning(String slot, int minutes) {
    return 'Jetzt · $slot · noch $minutes Min.';
  }

  @override
  String nowFirst(String slot, String time) {
    return 'Erste Stunde · $slot · um $time';
  }

  @override
  String nowNext(String slot, String time) {
    return 'Gleich · $slot · um $time';
  }

  @override
  String get schoolOverLabel => 'Schulschluss';

  @override
  String get schoolOverTitle => 'Unterricht vorbei';

  @override
  String lastLessonEnded(String time) {
    return 'Letzte Stunde endete um $time';
  }

  @override
  String get noLessons => 'Kein Unterricht';

  @override
  String barThen(String time, String subject) {
    return 'Danach $time $subject';
  }

  @override
  String barUntil(String time) {
    return 'bis $time';
  }

  @override
  String pauseUntil(String time) {
    return 'Pause bis $time';
  }

  @override
  String get lessonRunning => 'läuft';

  @override
  String get dayCollapse => 'Tag zuklappen';

  @override
  String get dayExpand => 'Ganzen Tag zeigen';

  @override
  String get upcoming => 'Demnächst';

  @override
  String get allEvents => 'Alle Termine';

  @override
  String get forEveryone => 'Alle';

  @override
  String periodsToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden heute',
      one: '1 Stunde heute',
    );
    return '$_temp0';
  }

  @override
  String blocksToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Blöcke heute',
      one: '1 Block heute',
    );
    return '$_temp0';
  }

  @override
  String get chooseGroupInPlan => 'Gruppe im Plan wählen';

  @override
  String teacherAbsent(String name) {
    return '$name fehlt';
  }

  @override
  String roomInsteadOf(String room, String old) {
    return '$room statt $old';
  }

  @override
  String get lessonFallback => 'Unterricht';

  @override
  String mealToday(String notes) {
    return 'Heute: $notes';
  }

  @override
  String mealTomorrow(String notes) {
    return 'Morgen: $notes';
  }

  @override
  String noticeTodayFor(String name) {
    return 'Heute bei $name';
  }

  @override
  String noticeTomorrowFor(String name) {
    return 'Morgen bei $name';
  }

  @override
  String get noticeTodaySchool => 'Heute in der Schule';

  @override
  String get noticeTomorrowSchool => 'Morgen in der Schule';

  @override
  String get noticeTodayChild => 'Heute bei deinem Kind';

  @override
  String get noticeTomorrowChild => 'Morgen bei deinem Kind';

  @override
  String get navToday => 'Heute';

  @override
  String get navCalendar => 'Kalender';

  @override
  String get navCourses => 'Unterricht';

  @override
  String get navMessages => 'Nachrichten';

  @override
  String get navMore => 'Mehr';

  @override
  String get reportSickDetail => 'Vorerst nur beim Portal prüfen';

  @override
  String get orderMealSetup => 'Bestellseite der Mensa einmal eintragen';

  @override
  String get mensaChange => 'Mensa-Adresse ändern';

  @override
  String get learningPlatform => 'Lernplattform (Moodle)';

  @override
  String get portalInBrowser => 'Schulportal im Browser';

  @override
  String get settings => 'Einstellungen';

  @override
  String get settingsDetail =>
      'Konto, Benachrichtigungen, Darstellung, Datenschutz';

  @override
  String get invalidUrl => 'Das sieht nicht nach einer Web-Adresse aus.';

  @override
  String get mensaDialogTitle => 'Bestellseite der Mensa';

  @override
  String get mensaDialogText =>
      'Adresse der Seite, auf der ihr das Essen bestellt. Die App öffnet sie im Browser; die Anmeldung bleibt dort.';

  @override
  String get mensaDialogHint => 'z. B. bestellung.example.de';

  @override
  String get delete => 'Löschen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get eventsNone => 'Keine Termine in den nächsten Wochen.';

  @override
  String get kindExam => 'Arbeit';

  @override
  String get kindFree => 'Schulfrei';

  @override
  String get kindDeadline => 'Frist';

  @override
  String get kindMeal => 'Essen';

  @override
  String get allDay => 'ganztags';

  @override
  String get noTimetable =>
      'Die Schule bietet für dieses Konto keinen Stundenplan an.';

  @override
  String get offlineNothingSaved =>
      'Keine Verbindung und noch nichts gespeichert.';

  @override
  String get timetableFailed => 'Der Stundenplan ließ sich nicht laden.';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get viewDay => 'Tag';

  @override
  String get viewWeek => 'Woche';

  @override
  String get viewEvents => 'Termine';

  @override
  String get chooseGroupLabel => 'Gruppe wählen:';

  @override
  String get noLessonsThisDay => 'An diesem Tag kein Unterricht.';

  @override
  String get freePeriod => 'Freistunde';

  @override
  String subjectGroups(String subject, int count) {
    return '$subject · $count Gruppen';
  }

  @override
  String notChosenYet(String slot) {
    return '$slot · noch nicht gewählt';
  }

  @override
  String get choose => 'Wählen';

  @override
  String get cancelledCap => 'Fällt aus';

  @override
  String get otherGroup => 'Andere Gruppe';

  @override
  String get cellChoice => 'Wahl';

  @override
  String cellGroups(int count) {
    return '$count Gruppen';
  }

  @override
  String cellSubjects(int count) {
    return '$count Fächer';
  }

  @override
  String get cellChoose => 'wählen';

  @override
  String groupSheetTitle(String subject) {
    return '$subject – Gruppe wählen';
  }

  @override
  String get whichSubject => 'Welches Fach?';

  @override
  String groupSheetSame(String subject, String name) {
    return 'Gilt für alle $subject-Stunden von $name. Die anderen Gruppen werden ausgeblendet.';
  }

  @override
  String groupSheetParallel(String subject, String name) {
    return 'Parallel laufen $subject. Wähle, was $name hat; die anderen werden ausgeblendet.';
  }

  @override
  String groupOf(String teacher) {
    return 'Gruppe $teacher';
  }

  @override
  String roomValue(String room) {
    return 'Raum $room';
  }

  @override
  String get detectedViaCourse => 'Erkannt über den Kurs in „Mein Unterricht“';

  @override
  String get showAllAgain => 'Wieder alle zeigen';

  @override
  String get nameUnknown => 'Name unbekannt';

  @override
  String teacherCode(String code) {
    return 'Kürzel $code';
  }

  @override
  String get noTeacherGiven => 'Keine Lehrkraft angegeben.';

  @override
  String get tapToNameTeacher =>
      'Antippen, um einen Namen einzutragen. Er wird nur auf diesem Gerät für dieses Konto gespeichert.';

  @override
  String nameFor(String code) {
    return 'Name für $code';
  }

  @override
  String get teacherNameHint => 'z. B. Frau Muster';

  @override
  String get cacheCleared => 'Zwischenspeicher geleert';

  @override
  String get logoutQuestion => 'Abmelden?';

  @override
  String get logoutText =>
      'Das Konto wird von diesem Gerät entfernt, auch gespeicherte Gruppenwahl und Lehrernamen. Zum Wiederkommen meldest du dich neu an.';

  @override
  String get logout => 'Abmelden';

  @override
  String get subscribeEvents => 'Termine abonnieren';

  @override
  String get subscribeFailed => 'Die Abo-Adresse ließ sich nicht laden.';

  @override
  String get subscribeText =>
      'Mit dieser Adresse übernimmt dein Kalender (z. B. Google Kalender: „Weitere Kalender“ → „Per URL“) die Schultermine und hält sie aktuell.';

  @override
  String get copyAddress => 'Adresse kopieren';

  @override
  String get close => 'Schließen';

  @override
  String get parentAccount => 'Elternkonto';

  @override
  String get studentAccount => 'Schülerkonto';

  @override
  String get teacherAccount => 'Lehrkraft';

  @override
  String get back => 'Zurück';

  @override
  String get sectionAccount => 'Konto';

  @override
  String get userData => 'Benutzerdaten';

  @override
  String get userDataDetail => 'Was das Portal über dieses Konto führt';

  @override
  String get switchAccount => 'Konto wechseln oder hinzufügen';

  @override
  String get logoutDetail => 'Entfernt das Konto von diesem Gerät';

  @override
  String get sectionNotifications => 'Benachrichtigungen';

  @override
  String get allowNotifications => 'Benachrichtigungen erlauben';

  @override
  String get notificationsBlocked =>
      'Das Handy blockiert sie gerade für diese App';

  @override
  String get forThisAccount => 'Für dieses Konto';

  @override
  String get notifySubstitutions => 'Ausfall, Vertretung, große Termine';

  @override
  String get notifySubstitutionsDetail => 'Heute sofort, für morgen ab 19 Uhr';

  @override
  String get notifyMessages => 'Neue Nachrichten';

  @override
  String get timeWindow => 'Zeitfenster';

  @override
  String get timeWindowDetail => 'Außerhalb ist Ruhe';

  @override
  String get sectionAppearance => 'Darstellung';

  @override
  String get likePhone => 'Wie das Handy';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get fontSize => 'Schriftgröße';

  @override
  String get fontNormal => 'Normal';

  @override
  String get fontLarge => 'Groß';

  @override
  String get fontXLarge => 'Sehr groß';

  @override
  String get language => 'Sprache';

  @override
  String get languageNote =>
      'Inhalte der Schule wie Fächer, Termine und Nachrichten bleiben so, wie die Schule sie schreibt.';

  @override
  String get sectionData => 'Daten';

  @override
  String get subscribeEventsDetail => 'Schultermine im eigenen Kalender';

  @override
  String get clearCache => 'Zwischenspeicher leeren';

  @override
  String get clearCacheDetail => 'Geladene Dateien aus Kursen und Nachrichten';

  @override
  String get sectionAbout => 'Über die App';

  @override
  String versionValue(String version) {
    return 'Version $version';
  }

  @override
  String get unofficial => 'inoffiziell, nicht vom Land Hessen';

  @override
  String get whatsNew => 'Neu in dieser Version';

  @override
  String get privacy => 'Datenschutz';

  @override
  String get privacyDetail =>
      'Kein eigener Server – alles bleibt auf dem Handy';

  @override
  String get sourceLicense => 'Quellcode und Lizenz';

  @override
  String sourceLicenseDetail(String upstream) {
    return 'Freie Software (GPL-3.0), Grundlage $upstream';
  }

  @override
  String get libraries => 'Verwendete Bibliotheken';

  @override
  String get sectionDebug => 'Fehlersuche';

  @override
  String get debugToggle => 'Für Rückfragen bei Problemen';

  @override
  String get debugExport => 'Debug-Export';

  @override
  String get debugExportDetail =>
      'Protokoll zum Weitergeben, Passwörter geschwärzt';

  @override
  String get userDataNote =>
      'Was das Schulportal über dieses Konto führt. Ändern lässt es sich nur im Portal selbst.';
}
