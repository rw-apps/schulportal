// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'fork_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class ForkL10nEn extends ForkL10n {
  ForkL10nEn([String locale = 'en']) : super(locale);

  @override
  String get dateLong => 'EEEE, MMMM d';

  @override
  String get dateShort => 'ccc M/d';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingDay => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get dayToday => 'Today';

  @override
  String get dayTomorrow => 'Tomorrow';

  @override
  String get demoNote => 'Preview with made-up sample data';

  @override
  String get importantTitle => 'Important today and tomorrow';

  @override
  String get lessonCancelled => 'cancelled';

  @override
  String get changeRoom => 'Room change';

  @override
  String get changeSubstitution => 'Substitute';

  @override
  String homeworkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count assignments',
      one: '1 assignment',
    );
    return '$_temp0';
  }

  @override
  String unreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0';
  }

  @override
  String get orderMeal => 'Order lunch';

  @override
  String get reportSick => 'Report sick';

  @override
  String nowRunning(String slot, int minutes) {
    return 'Now · $slot · $minutes min left';
  }

  @override
  String nowFirst(String slot, String time) {
    return 'First lesson · $slot · at $time';
  }

  @override
  String nowNext(String slot, String time) {
    return 'Next · $slot · at $time';
  }

  @override
  String get schoolOverLabel => 'School\'s out';

  @override
  String get schoolOverTitle => 'Lessons are over';

  @override
  String lastLessonEnded(String time) {
    return 'Last lesson ended at $time';
  }

  @override
  String get noLessons => 'No lessons';

  @override
  String barThen(String time, String subject) {
    return 'Then $time $subject';
  }

  @override
  String barUntil(String time) {
    return 'until $time';
  }

  @override
  String pauseUntil(String time) {
    return 'Break until $time';
  }

  @override
  String get lessonRunning => 'now';

  @override
  String get dayCollapse => 'Hide day';

  @override
  String get dayExpand => 'Show whole day';

  @override
  String get upcoming => 'Coming up';

  @override
  String get allEvents => 'All events';

  @override
  String get forEveryone => 'Everyone';

  @override
  String periodsToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lessons today',
      one: '1 lesson today',
    );
    return '$_temp0';
  }

  @override
  String blocksToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocks today',
      one: '1 block today',
    );
    return '$_temp0';
  }

  @override
  String get chooseGroupInPlan => 'Choose the group in the timetable';

  @override
  String teacherAbsent(String name) {
    return '$name is absent';
  }

  @override
  String roomInsteadOf(String room, String old) {
    return '$room instead of $old';
  }

  @override
  String get lessonFallback => 'Lesson';

  @override
  String mealToday(String notes) {
    return 'Today: $notes';
  }

  @override
  String mealTomorrow(String notes) {
    return 'Tomorrow: $notes';
  }

  @override
  String noticeTodayFor(String name) {
    return 'Today for $name';
  }

  @override
  String noticeTomorrowFor(String name) {
    return 'Tomorrow for $name';
  }

  @override
  String get noticeTodaySchool => 'Today at school';

  @override
  String get noticeTomorrowSchool => 'Tomorrow at school';

  @override
  String get noticeTodayChild => 'Today for your child';

  @override
  String get noticeTomorrowChild => 'Tomorrow for your child';

  @override
  String get navToday => 'Today';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navCourses => 'Lessons';

  @override
  String get navMessages => 'Messages';

  @override
  String get navMore => 'More';

  @override
  String get reportSickDetail => 'For now only checked with the portal';

  @override
  String get orderMealSetup => 'Enter the canteen\'s order page once';

  @override
  String get mensaChange => 'Change canteen address';

  @override
  String get learningPlatform => 'Learning platform (Moodle)';

  @override
  String get portalInBrowser => 'Schulportal in the browser';

  @override
  String get settings => 'Settings';

  @override
  String get settingsDetail => 'Account, notifications, appearance, privacy';

  @override
  String get invalidUrl => 'That doesn\'t look like a web address.';

  @override
  String get mensaDialogTitle => 'Canteen order page';

  @override
  String get mensaDialogText =>
      'Address of the page where you order lunch. The app opens it in the browser; you sign in there.';

  @override
  String get mensaDialogHint => 'e.g. order.example.com';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get eventsNone => 'No events in the coming weeks.';

  @override
  String get kindExam => 'Exam';

  @override
  String get kindFree => 'No school';

  @override
  String get kindDeadline => 'Deadline';

  @override
  String get kindMeal => 'Lunch';

  @override
  String get allDay => 'all day';

  @override
  String get noTimetable =>
      'The school doesn\'t offer a timetable for this account.';

  @override
  String get offlineNothingSaved => 'No connection and nothing saved yet.';

  @override
  String get timetableFailed => 'The timetable could not be loaded.';

  @override
  String get retry => 'Try again';

  @override
  String get viewDay => 'Day';

  @override
  String get viewWeek => 'Week';

  @override
  String get viewEvents => 'Events';

  @override
  String get chooseGroupLabel => 'Choose group:';

  @override
  String get noLessonsThisDay => 'No lessons on this day.';

  @override
  String get freePeriod => 'Free period';

  @override
  String subjectGroups(String subject, int count) {
    return '$subject · $count groups';
  }

  @override
  String notChosenYet(String slot) {
    return '$slot · not chosen yet';
  }

  @override
  String get choose => 'Choose';

  @override
  String get cancelledCap => 'Cancelled';

  @override
  String get otherGroup => 'Other group';

  @override
  String get cellChoice => 'Choice';

  @override
  String cellGroups(int count) {
    return '$count groups';
  }

  @override
  String cellSubjects(int count) {
    return '$count subjects';
  }

  @override
  String get cellChoose => 'choose';

  @override
  String groupSheetTitle(String subject) {
    return '$subject – choose group';
  }

  @override
  String get whichSubject => 'Which subject?';

  @override
  String groupSheetSame(String subject, String name) {
    return 'Applies to all of $name\'s $subject lessons. The other groups are hidden.';
  }

  @override
  String groupSheetParallel(String subject, String name) {
    return '$subject run in parallel. Choose what $name has; the others are hidden.';
  }

  @override
  String groupOf(String teacher) {
    return 'Group $teacher';
  }

  @override
  String roomValue(String room) {
    return 'Room $room';
  }

  @override
  String get detectedViaCourse =>
      'Detected from the course in “Mein Unterricht”';

  @override
  String get showAllAgain => 'Show all again';

  @override
  String get nameUnknown => 'Name unknown';

  @override
  String teacherCode(String code) {
    return 'Code $code';
  }

  @override
  String get noTeacherGiven => 'No teacher given.';

  @override
  String get tapToNameTeacher =>
      'Tap to enter a name. It is only saved on this device for this account.';

  @override
  String nameFor(String code) {
    return 'Name for $code';
  }

  @override
  String get teacherNameHint => 'e.g. Ms Smith';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String get logoutQuestion => 'Sign out?';

  @override
  String get logoutText =>
      'The account is removed from this device, including saved group choices and teacher names. To come back, sign in again.';

  @override
  String get logout => 'Sign out';

  @override
  String get subscribeEvents => 'Subscribe to events';

  @override
  String get subscribeFailed => 'The subscription address could not be loaded.';

  @override
  String get subscribeText =>
      'With this address your calendar app (e.g. Google Calendar: “Other calendars” → “From URL”) adds the school events and keeps them up to date.';

  @override
  String get copyAddress => 'Copy address';

  @override
  String get close => 'Close';

  @override
  String get parentAccount => 'Parent account';

  @override
  String get studentAccount => 'Student account';

  @override
  String get teacherAccount => 'Teacher';

  @override
  String get back => 'Back';

  @override
  String get sectionAccount => 'Account';

  @override
  String get userData => 'User data';

  @override
  String get userDataDetail => 'What the portal stores about this account';

  @override
  String get switchAccount => 'Switch or add account';

  @override
  String get logoutDetail => 'Removes the account from this device';

  @override
  String get sectionNotifications => 'Notifications';

  @override
  String get allowNotifications => 'Allow notifications';

  @override
  String get notificationsBlocked =>
      'Your phone is currently blocking them for this app';

  @override
  String get forThisAccount => 'For this account';

  @override
  String get notifySubstitutions => 'Cancellations, substitutions, big events';

  @override
  String get notifySubstitutionsDetail =>
      'Today right away, for tomorrow from 7 pm';

  @override
  String get notifyMessages => 'New messages';

  @override
  String get timeWindow => 'Time window';

  @override
  String get timeWindowDetail => 'Quiet outside these hours';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get likePhone => 'Same as phone';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get fontSize => 'Text size';

  @override
  String get fontNormal => 'Normal';

  @override
  String get fontLarge => 'Large';

  @override
  String get fontXLarge => 'Very large';

  @override
  String get language => 'Language';

  @override
  String get languageNote =>
      'School content such as subjects, events and messages stays as the school writes it.';

  @override
  String get sectionData => 'Data';

  @override
  String get subscribeEventsDetail => 'School events in your own calendar';

  @override
  String get clearCache => 'Clear cache';

  @override
  String get clearCacheDetail => 'Downloaded files from courses and messages';

  @override
  String get sectionAbout => 'About the app';

  @override
  String versionValue(String version) {
    return 'Version $version';
  }

  @override
  String get unofficial => 'unofficial, not from the State of Hesse';

  @override
  String get whatsNew => 'New in this version';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacyDetail =>
      'No server of our own – everything stays on your phone';

  @override
  String get sourceLicense => 'Source code and licence';

  @override
  String sourceLicenseDetail(String upstream) {
    return 'Free software (GPL-3.0), based on $upstream';
  }

  @override
  String get libraries => 'Libraries used';

  @override
  String get sectionDebug => 'Troubleshooting';

  @override
  String get debugToggle => 'For follow-up questions about problems';

  @override
  String get debugExport => 'Debug export';

  @override
  String get debugExportDetail => 'Log to pass on, passwords blacked out';

  @override
  String get userDataNote =>
      'What the Schulportal stores about this account. It can only be changed in the portal itself.';
}
