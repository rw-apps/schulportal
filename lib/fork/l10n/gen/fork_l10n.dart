import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'fork_l10n_de.dart';
import 'fork_l10n_en.dart';
import 'fork_l10n_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of ForkL10n
/// returned by `ForkL10n.of(context)`.
///
/// Applications need to include `ForkL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/fork_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: ForkL10n.localizationsDelegates,
///   supportedLocales: ForkL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the ForkL10n.supportedLocales
/// property.
abstract class ForkL10n {
  ForkL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static ForkL10n of(BuildContext context) {
    return Localizations.of<ForkL10n>(context, ForkL10n)!;
  }

  static const LocalizationsDelegate<ForkL10n> delegate = _ForkL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @dateLong.
  ///
  /// In de, this message translates to:
  /// **'EEEE, d. MMMM'**
  String get dateLong;

  /// No description provided for @dateShort.
  ///
  /// In de, this message translates to:
  /// **'ccc d.M.'**
  String get dateShort;

  /// No description provided for @greetingMorning.
  ///
  /// In de, this message translates to:
  /// **'Guten Morgen'**
  String get greetingMorning;

  /// No description provided for @greetingDay.
  ///
  /// In de, this message translates to:
  /// **'Guten Tag'**
  String get greetingDay;

  /// No description provided for @greetingEvening.
  ///
  /// In de, this message translates to:
  /// **'Guten Abend'**
  String get greetingEvening;

  /// No description provided for @dayToday.
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get dayToday;

  /// No description provided for @dayTomorrow.
  ///
  /// In de, this message translates to:
  /// **'Morgen'**
  String get dayTomorrow;

  /// No description provided for @demoNote.
  ///
  /// In de, this message translates to:
  /// **'Vorschau mit erfundenen Beispieldaten'**
  String get demoNote;

  /// No description provided for @importantTitle.
  ///
  /// In de, this message translates to:
  /// **'Wichtig heute und morgen'**
  String get importantTitle;

  /// No description provided for @lessonCancelled.
  ///
  /// In de, this message translates to:
  /// **'fällt aus'**
  String get lessonCancelled;

  /// No description provided for @changeRoom.
  ///
  /// In de, this message translates to:
  /// **'Raumwechsel'**
  String get changeRoom;

  /// No description provided for @changeSubstitution.
  ///
  /// In de, this message translates to:
  /// **'Vertretung'**
  String get changeSubstitution;

  /// No description provided for @homeworkCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Hausaufgabe} other{{count} Hausaufgaben}}'**
  String homeworkCount(int count);

  /// No description provided for @unreadCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Nachricht} other{{count} Nachrichten}}'**
  String unreadCount(int count);

  /// No description provided for @orderMeal.
  ///
  /// In de, this message translates to:
  /// **'Essen bestellen'**
  String get orderMeal;

  /// No description provided for @reportSick.
  ///
  /// In de, this message translates to:
  /// **'Krank melden'**
  String get reportSick;

  /// No description provided for @nowRunning.
  ///
  /// In de, this message translates to:
  /// **'Jetzt · {slot} · noch {minutes} Min.'**
  String nowRunning(String slot, int minutes);

  /// No description provided for @nowFirst.
  ///
  /// In de, this message translates to:
  /// **'Erste Stunde · {slot} · um {time}'**
  String nowFirst(String slot, String time);

  /// No description provided for @nowNext.
  ///
  /// In de, this message translates to:
  /// **'Gleich · {slot} · um {time}'**
  String nowNext(String slot, String time);

  /// No description provided for @schoolOverLabel.
  ///
  /// In de, this message translates to:
  /// **'Schulschluss'**
  String get schoolOverLabel;

  /// No description provided for @schoolOverTitle.
  ///
  /// In de, this message translates to:
  /// **'Unterricht vorbei'**
  String get schoolOverTitle;

  /// No description provided for @lastLessonEnded.
  ///
  /// In de, this message translates to:
  /// **'Letzte Stunde endete um {time}'**
  String lastLessonEnded(String time);

  /// No description provided for @noLessons.
  ///
  /// In de, this message translates to:
  /// **'Kein Unterricht'**
  String get noLessons;

  /// No description provided for @barThen.
  ///
  /// In de, this message translates to:
  /// **'Danach {time} {subject}'**
  String barThen(String time, String subject);

  /// No description provided for @barUntil.
  ///
  /// In de, this message translates to:
  /// **'bis {time}'**
  String barUntil(String time);

  /// No description provided for @pauseUntil.
  ///
  /// In de, this message translates to:
  /// **'Pause bis {time}'**
  String pauseUntil(String time);

  /// No description provided for @lessonRunning.
  ///
  /// In de, this message translates to:
  /// **'läuft'**
  String get lessonRunning;

  /// No description provided for @dayCollapse.
  ///
  /// In de, this message translates to:
  /// **'Tag zuklappen'**
  String get dayCollapse;

  /// No description provided for @dayExpand.
  ///
  /// In de, this message translates to:
  /// **'Ganzen Tag zeigen'**
  String get dayExpand;

  /// No description provided for @upcoming.
  ///
  /// In de, this message translates to:
  /// **'Demnächst'**
  String get upcoming;

  /// No description provided for @allEvents.
  ///
  /// In de, this message translates to:
  /// **'Alle Termine'**
  String get allEvents;

  /// No description provided for @forEveryone.
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get forEveryone;

  /// No description provided for @periodsToday.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Stunde heute} other{{count} Stunden heute}}'**
  String periodsToday(int count);

  /// No description provided for @blocksToday.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Block heute} other{{count} Blöcke heute}}'**
  String blocksToday(int count);

  /// No description provided for @chooseGroupInPlan.
  ///
  /// In de, this message translates to:
  /// **'Gruppe im Plan wählen'**
  String get chooseGroupInPlan;

  /// No description provided for @teacherAbsent.
  ///
  /// In de, this message translates to:
  /// **'{name} fehlt'**
  String teacherAbsent(String name);

  /// No description provided for @roomInsteadOf.
  ///
  /// In de, this message translates to:
  /// **'{room} statt {old}'**
  String roomInsteadOf(String room, String old);

  /// No description provided for @lessonFallback.
  ///
  /// In de, this message translates to:
  /// **'Unterricht'**
  String get lessonFallback;

  /// No description provided for @mealToday.
  ///
  /// In de, this message translates to:
  /// **'Heute: {notes}'**
  String mealToday(String notes);

  /// No description provided for @mealTomorrow.
  ///
  /// In de, this message translates to:
  /// **'Morgen: {notes}'**
  String mealTomorrow(String notes);

  /// No description provided for @noticeTodayFor.
  ///
  /// In de, this message translates to:
  /// **'Heute bei {name}'**
  String noticeTodayFor(String name);

  /// No description provided for @noticeTomorrowFor.
  ///
  /// In de, this message translates to:
  /// **'Morgen bei {name}'**
  String noticeTomorrowFor(String name);

  /// No description provided for @noticeTodaySchool.
  ///
  /// In de, this message translates to:
  /// **'Heute in der Schule'**
  String get noticeTodaySchool;

  /// No description provided for @noticeTomorrowSchool.
  ///
  /// In de, this message translates to:
  /// **'Morgen in der Schule'**
  String get noticeTomorrowSchool;

  /// No description provided for @noticeTodayChild.
  ///
  /// In de, this message translates to:
  /// **'Heute bei deinem Kind'**
  String get noticeTodayChild;

  /// No description provided for @noticeTomorrowChild.
  ///
  /// In de, this message translates to:
  /// **'Morgen bei deinem Kind'**
  String get noticeTomorrowChild;

  /// No description provided for @navToday.
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get navToday;

  /// No description provided for @navCalendar.
  ///
  /// In de, this message translates to:
  /// **'Kalender'**
  String get navCalendar;

  /// No description provided for @navCourses.
  ///
  /// In de, this message translates to:
  /// **'Unterricht'**
  String get navCourses;

  /// No description provided for @navMessages.
  ///
  /// In de, this message translates to:
  /// **'Nachrichten'**
  String get navMessages;

  /// No description provided for @navMore.
  ///
  /// In de, this message translates to:
  /// **'Mehr'**
  String get navMore;

  /// No description provided for @reportSickDetail.
  ///
  /// In de, this message translates to:
  /// **'Vorerst nur beim Portal prüfen'**
  String get reportSickDetail;

  /// No description provided for @orderMealSetup.
  ///
  /// In de, this message translates to:
  /// **'Bestellseite der Mensa einmal eintragen'**
  String get orderMealSetup;

  /// No description provided for @mensaChange.
  ///
  /// In de, this message translates to:
  /// **'Mensa-Adresse ändern'**
  String get mensaChange;

  /// No description provided for @learningPlatform.
  ///
  /// In de, this message translates to:
  /// **'Lernplattform (Moodle)'**
  String get learningPlatform;

  /// No description provided for @portalInBrowser.
  ///
  /// In de, this message translates to:
  /// **'Schulportal im Browser'**
  String get portalInBrowser;

  /// No description provided for @settings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settings;

  /// No description provided for @settingsDetail.
  ///
  /// In de, this message translates to:
  /// **'Konto, Benachrichtigungen, Darstellung, Datenschutz'**
  String get settingsDetail;

  /// No description provided for @invalidUrl.
  ///
  /// In de, this message translates to:
  /// **'Das sieht nicht nach einer Web-Adresse aus.'**
  String get invalidUrl;

  /// No description provided for @mensaDialogTitle.
  ///
  /// In de, this message translates to:
  /// **'Bestellseite der Mensa'**
  String get mensaDialogTitle;

  /// No description provided for @mensaDialogText.
  ///
  /// In de, this message translates to:
  /// **'Adresse der Seite, auf der ihr das Essen bestellt. Die App öffnet sie im Browser; die Anmeldung bleibt dort.'**
  String get mensaDialogText;

  /// No description provided for @mensaDialogHint.
  ///
  /// In de, this message translates to:
  /// **'z. B. bestellung.example.de'**
  String get mensaDialogHint;

  /// No description provided for @delete.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get save;

  /// No description provided for @eventsNone.
  ///
  /// In de, this message translates to:
  /// **'Keine Termine in den nächsten Wochen.'**
  String get eventsNone;

  /// No description provided for @kindExam.
  ///
  /// In de, this message translates to:
  /// **'Arbeit'**
  String get kindExam;

  /// No description provided for @kindFree.
  ///
  /// In de, this message translates to:
  /// **'Schulfrei'**
  String get kindFree;

  /// No description provided for @kindDeadline.
  ///
  /// In de, this message translates to:
  /// **'Frist'**
  String get kindDeadline;

  /// No description provided for @kindMeal.
  ///
  /// In de, this message translates to:
  /// **'Essen'**
  String get kindMeal;

  /// No description provided for @allDay.
  ///
  /// In de, this message translates to:
  /// **'ganztags'**
  String get allDay;

  /// No description provided for @noTimetable.
  ///
  /// In de, this message translates to:
  /// **'Die Schule bietet für dieses Konto keinen Stundenplan an.'**
  String get noTimetable;

  /// No description provided for @offlineNothingSaved.
  ///
  /// In de, this message translates to:
  /// **'Keine Verbindung und noch nichts gespeichert.'**
  String get offlineNothingSaved;

  /// No description provided for @timetableFailed.
  ///
  /// In de, this message translates to:
  /// **'Der Stundenplan ließ sich nicht laden.'**
  String get timetableFailed;

  /// No description provided for @retry.
  ///
  /// In de, this message translates to:
  /// **'Erneut versuchen'**
  String get retry;

  /// No description provided for @viewDay.
  ///
  /// In de, this message translates to:
  /// **'Tag'**
  String get viewDay;

  /// No description provided for @viewWeek.
  ///
  /// In de, this message translates to:
  /// **'Woche'**
  String get viewWeek;

  /// No description provided for @viewEvents.
  ///
  /// In de, this message translates to:
  /// **'Termine'**
  String get viewEvents;

  /// No description provided for @chooseGroupLabel.
  ///
  /// In de, this message translates to:
  /// **'Gruppe wählen:'**
  String get chooseGroupLabel;

  /// No description provided for @noLessonsThisDay.
  ///
  /// In de, this message translates to:
  /// **'An diesem Tag kein Unterricht.'**
  String get noLessonsThisDay;

  /// No description provided for @freePeriod.
  ///
  /// In de, this message translates to:
  /// **'Freistunde'**
  String get freePeriod;

  /// No description provided for @subjectGroups.
  ///
  /// In de, this message translates to:
  /// **'{subject} · {count} Gruppen'**
  String subjectGroups(String subject, int count);

  /// No description provided for @notChosenYet.
  ///
  /// In de, this message translates to:
  /// **'{slot} · noch nicht gewählt'**
  String notChosenYet(String slot);

  /// No description provided for @choose.
  ///
  /// In de, this message translates to:
  /// **'Wählen'**
  String get choose;

  /// No description provided for @cancelledCap.
  ///
  /// In de, this message translates to:
  /// **'Fällt aus'**
  String get cancelledCap;

  /// No description provided for @otherGroup.
  ///
  /// In de, this message translates to:
  /// **'Andere Gruppe'**
  String get otherGroup;

  /// No description provided for @cellChoice.
  ///
  /// In de, this message translates to:
  /// **'Wahl'**
  String get cellChoice;

  /// No description provided for @cellGroups.
  ///
  /// In de, this message translates to:
  /// **'{count} Gruppen'**
  String cellGroups(int count);

  /// No description provided for @cellSubjects.
  ///
  /// In de, this message translates to:
  /// **'{count} Fächer'**
  String cellSubjects(int count);

  /// No description provided for @cellChoose.
  ///
  /// In de, this message translates to:
  /// **'wählen'**
  String get cellChoose;

  /// No description provided for @groupSheetTitle.
  ///
  /// In de, this message translates to:
  /// **'{subject} – Gruppe wählen'**
  String groupSheetTitle(String subject);

  /// No description provided for @whichSubject.
  ///
  /// In de, this message translates to:
  /// **'Welches Fach?'**
  String get whichSubject;

  /// No description provided for @groupSheetSame.
  ///
  /// In de, this message translates to:
  /// **'Gilt für alle {subject}-Stunden von {name}. Die anderen Gruppen werden ausgeblendet.'**
  String groupSheetSame(String subject, String name);

  /// No description provided for @groupSheetParallel.
  ///
  /// In de, this message translates to:
  /// **'Parallel laufen {subject}. Wähle, was {name} hat; die anderen werden ausgeblendet.'**
  String groupSheetParallel(String subject, String name);

  /// No description provided for @groupOf.
  ///
  /// In de, this message translates to:
  /// **'Gruppe {teacher}'**
  String groupOf(String teacher);

  /// No description provided for @roomValue.
  ///
  /// In de, this message translates to:
  /// **'Raum {room}'**
  String roomValue(String room);

  /// No description provided for @detectedViaCourse.
  ///
  /// In de, this message translates to:
  /// **'Erkannt über den Kurs in „Mein Unterricht“'**
  String get detectedViaCourse;

  /// No description provided for @showAllAgain.
  ///
  /// In de, this message translates to:
  /// **'Wieder alle zeigen'**
  String get showAllAgain;

  /// No description provided for @nameUnknown.
  ///
  /// In de, this message translates to:
  /// **'Name unbekannt'**
  String get nameUnknown;

  /// No description provided for @teacherCode.
  ///
  /// In de, this message translates to:
  /// **'Kürzel {code}'**
  String teacherCode(String code);

  /// No description provided for @noTeacherGiven.
  ///
  /// In de, this message translates to:
  /// **'Keine Lehrkraft angegeben.'**
  String get noTeacherGiven;

  /// No description provided for @tapToNameTeacher.
  ///
  /// In de, this message translates to:
  /// **'Antippen, um einen Namen einzutragen. Er wird nur auf diesem Gerät für dieses Konto gespeichert.'**
  String get tapToNameTeacher;

  /// No description provided for @nameFor.
  ///
  /// In de, this message translates to:
  /// **'Name für {code}'**
  String nameFor(String code);

  /// No description provided for @teacherNameHint.
  ///
  /// In de, this message translates to:
  /// **'z. B. Frau Muster'**
  String get teacherNameHint;

  /// No description provided for @cacheCleared.
  ///
  /// In de, this message translates to:
  /// **'Zwischenspeicher geleert'**
  String get cacheCleared;

  /// No description provided for @logoutQuestion.
  ///
  /// In de, this message translates to:
  /// **'Abmelden?'**
  String get logoutQuestion;

  /// No description provided for @logoutText.
  ///
  /// In de, this message translates to:
  /// **'Das Konto wird von diesem Gerät entfernt, auch gespeicherte Gruppenwahl und Lehrernamen. Zum Wiederkommen meldest du dich neu an.'**
  String get logoutText;

  /// No description provided for @logout.
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get logout;

  /// No description provided for @subscribeEvents.
  ///
  /// In de, this message translates to:
  /// **'Termine abonnieren'**
  String get subscribeEvents;

  /// No description provided for @subscribeFailed.
  ///
  /// In de, this message translates to:
  /// **'Die Abo-Adresse ließ sich nicht laden.'**
  String get subscribeFailed;

  /// No description provided for @subscribeText.
  ///
  /// In de, this message translates to:
  /// **'Mit dieser Adresse übernimmt dein Kalender (z. B. Google Kalender: „Weitere Kalender“ → „Per URL“) die Schultermine und hält sie aktuell.'**
  String get subscribeText;

  /// No description provided for @copyAddress.
  ///
  /// In de, this message translates to:
  /// **'Adresse kopieren'**
  String get copyAddress;

  /// No description provided for @close.
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get close;

  /// No description provided for @parentAccount.
  ///
  /// In de, this message translates to:
  /// **'Elternkonto'**
  String get parentAccount;

  /// No description provided for @studentAccount.
  ///
  /// In de, this message translates to:
  /// **'Schülerkonto'**
  String get studentAccount;

  /// No description provided for @teacherAccount.
  ///
  /// In de, this message translates to:
  /// **'Lehrkraft'**
  String get teacherAccount;

  /// No description provided for @back.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get back;

  /// No description provided for @sectionAccount.
  ///
  /// In de, this message translates to:
  /// **'Konto'**
  String get sectionAccount;

  /// No description provided for @userData.
  ///
  /// In de, this message translates to:
  /// **'Benutzerdaten'**
  String get userData;

  /// No description provided for @userDataDetail.
  ///
  /// In de, this message translates to:
  /// **'Was das Portal über dieses Konto führt'**
  String get userDataDetail;

  /// No description provided for @switchAccount.
  ///
  /// In de, this message translates to:
  /// **'Konto wechseln oder hinzufügen'**
  String get switchAccount;

  /// No description provided for @logoutDetail.
  ///
  /// In de, this message translates to:
  /// **'Entfernt das Konto von diesem Gerät'**
  String get logoutDetail;

  /// No description provided for @sectionNotifications.
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigungen'**
  String get sectionNotifications;

  /// No description provided for @allowNotifications.
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigungen erlauben'**
  String get allowNotifications;

  /// No description provided for @notificationsBlocked.
  ///
  /// In de, this message translates to:
  /// **'Das Handy blockiert sie gerade für diese App'**
  String get notificationsBlocked;

  /// No description provided for @forThisAccount.
  ///
  /// In de, this message translates to:
  /// **'Für dieses Konto'**
  String get forThisAccount;

  /// No description provided for @notifySubstitutions.
  ///
  /// In de, this message translates to:
  /// **'Ausfall, Vertretung, große Termine'**
  String get notifySubstitutions;

  /// No description provided for @notifySubstitutionsDetail.
  ///
  /// In de, this message translates to:
  /// **'Heute sofort, für morgen ab 19 Uhr'**
  String get notifySubstitutionsDetail;

  /// No description provided for @notifyMessages.
  ///
  /// In de, this message translates to:
  /// **'Neue Nachrichten'**
  String get notifyMessages;

  /// No description provided for @timeWindow.
  ///
  /// In de, this message translates to:
  /// **'Zeitfenster'**
  String get timeWindow;

  /// No description provided for @timeWindowDetail.
  ///
  /// In de, this message translates to:
  /// **'Außerhalb ist Ruhe'**
  String get timeWindowDetail;

  /// No description provided for @sectionAppearance.
  ///
  /// In de, this message translates to:
  /// **'Darstellung'**
  String get sectionAppearance;

  /// No description provided for @likePhone.
  ///
  /// In de, this message translates to:
  /// **'Wie das Handy'**
  String get likePhone;

  /// No description provided for @themeLight.
  ///
  /// In de, this message translates to:
  /// **'Hell'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In de, this message translates to:
  /// **'Dunkel'**
  String get themeDark;

  /// No description provided for @fontSize.
  ///
  /// In de, this message translates to:
  /// **'Schriftgröße'**
  String get fontSize;

  /// No description provided for @fontNormal.
  ///
  /// In de, this message translates to:
  /// **'Normal'**
  String get fontNormal;

  /// No description provided for @fontLarge.
  ///
  /// In de, this message translates to:
  /// **'Groß'**
  String get fontLarge;

  /// No description provided for @fontXLarge.
  ///
  /// In de, this message translates to:
  /// **'Sehr groß'**
  String get fontXLarge;

  /// No description provided for @language.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get language;

  /// No description provided for @languageNote.
  ///
  /// In de, this message translates to:
  /// **'Inhalte der Schule wie Fächer, Termine und Nachrichten bleiben so, wie die Schule sie schreibt.'**
  String get languageNote;

  /// No description provided for @sectionData.
  ///
  /// In de, this message translates to:
  /// **'Daten'**
  String get sectionData;

  /// No description provided for @subscribeEventsDetail.
  ///
  /// In de, this message translates to:
  /// **'Schultermine im eigenen Kalender'**
  String get subscribeEventsDetail;

  /// No description provided for @clearCache.
  ///
  /// In de, this message translates to:
  /// **'Zwischenspeicher leeren'**
  String get clearCache;

  /// No description provided for @clearCacheDetail.
  ///
  /// In de, this message translates to:
  /// **'Geladene Dateien aus Kursen und Nachrichten'**
  String get clearCacheDetail;

  /// No description provided for @sectionAbout.
  ///
  /// In de, this message translates to:
  /// **'Über die App'**
  String get sectionAbout;

  /// No description provided for @versionValue.
  ///
  /// In de, this message translates to:
  /// **'Version {version}'**
  String versionValue(String version);

  /// No description provided for @unofficial.
  ///
  /// In de, this message translates to:
  /// **'inoffiziell, nicht vom Land Hessen'**
  String get unofficial;

  /// No description provided for @whatsNew.
  ///
  /// In de, this message translates to:
  /// **'Neu in dieser Version'**
  String get whatsNew;

  /// No description provided for @privacy.
  ///
  /// In de, this message translates to:
  /// **'Datenschutz'**
  String get privacy;

  /// No description provided for @privacyDetail.
  ///
  /// In de, this message translates to:
  /// **'Kein eigener Server – alles bleibt auf dem Handy'**
  String get privacyDetail;

  /// No description provided for @sourceLicense.
  ///
  /// In de, this message translates to:
  /// **'Quellcode und Lizenz'**
  String get sourceLicense;

  /// No description provided for @sourceLicenseDetail.
  ///
  /// In de, this message translates to:
  /// **'Freie Software (GPL-3.0), Grundlage {upstream}'**
  String sourceLicenseDetail(String upstream);

  /// No description provided for @libraries.
  ///
  /// In de, this message translates to:
  /// **'Verwendete Bibliotheken'**
  String get libraries;

  /// No description provided for @sectionDebug.
  ///
  /// In de, this message translates to:
  /// **'Fehlersuche'**
  String get sectionDebug;

  /// No description provided for @debugToggle.
  ///
  /// In de, this message translates to:
  /// **'Für Rückfragen bei Problemen'**
  String get debugToggle;

  /// No description provided for @debugExport.
  ///
  /// In de, this message translates to:
  /// **'Debug-Export'**
  String get debugExport;

  /// No description provided for @debugExportDetail.
  ///
  /// In de, this message translates to:
  /// **'Protokoll zum Weitergeben, Passwörter geschwärzt'**
  String get debugExportDetail;

  /// No description provided for @userDataNote.
  ///
  /// In de, this message translates to:
  /// **'Was das Schulportal über dieses Konto führt. Ändern lässt es sich nur im Portal selbst.'**
  String get userDataNote;
}

class _ForkL10nDelegate extends LocalizationsDelegate<ForkL10n> {
  const _ForkL10nDelegate();

  @override
  Future<ForkL10n> load(Locale locale) {
    return SynchronousFuture<ForkL10n>(lookupForkL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_ForkL10nDelegate old) => false;
}

ForkL10n lookupForkL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return ForkL10nDe();
    case 'en':
      return ForkL10nEn();
    case 'tr':
      return ForkL10nTr();
  }

  throw FlutterError(
    'ForkL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
