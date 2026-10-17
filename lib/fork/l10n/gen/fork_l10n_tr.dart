// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'fork_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class ForkL10nTr extends ForkL10n {
  ForkL10nTr([String locale = 'tr']) : super(locale);

  @override
  String get dateLong => 'd MMMM EEEE';

  @override
  String get dateShort => 'd MMM ccc';

  @override
  String get greetingMorning => 'Günaydın';

  @override
  String get greetingDay => 'İyi günler';

  @override
  String get greetingEvening => 'İyi akşamlar';

  @override
  String get dayToday => 'Bugün';

  @override
  String get dayTomorrow => 'Yarın';

  @override
  String get demoNote => 'Uydurma örnek verilerle önizleme';

  @override
  String get importantTitle => 'Bugün ve yarın önemli';

  @override
  String get lessonCancelled => 'iptal';

  @override
  String get changeRoom => 'Derslik değişikliği';

  @override
  String get changeSubstitution => 'Vekil öğretmen';

  @override
  String homeworkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ödev',
    );
    return '$_temp0';
  }

  @override
  String unreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesaj',
    );
    return '$_temp0';
  }

  @override
  String get orderMeal => 'Yemek sipariş et';

  @override
  String get reportSick => 'Hastalık bildir';

  @override
  String nowRunning(String slot, int minutes) {
    return 'Şimdi · $slot · $minutes dk kaldı';
  }

  @override
  String nowFirst(String slot, String time) {
    return 'İlk ders · $slot · saat $time';
  }

  @override
  String nowNext(String slot, String time) {
    return 'Sıradaki · $slot · saat $time';
  }

  @override
  String get schoolOverLabel => 'Okul bitti';

  @override
  String get schoolOverTitle => 'Dersler bitti';

  @override
  String lastLessonEnded(String time) {
    return 'Son ders bitişi: $time';
  }

  @override
  String get noLessons => 'Ders yok';

  @override
  String barThen(String time, String subject) {
    return 'Sonra $time $subject';
  }

  @override
  String barUntil(String time) {
    return 'bitiş $time';
  }

  @override
  String pauseUntil(String time) {
    return 'Teneffüs · bitiş $time';
  }

  @override
  String get lessonRunning => 'şu an';

  @override
  String get dayCollapse => 'Günü gizle';

  @override
  String get dayExpand => 'Tüm günü göster';

  @override
  String get upcoming => 'Yaklaşanlar';

  @override
  String get allEvents => 'Tüm etkinlikler';

  @override
  String get forEveryone => 'Herkes';

  @override
  String periodsToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bugün $count ders',
    );
    return '$_temp0';
  }

  @override
  String blocksToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bugün $count blok',
    );
    return '$_temp0';
  }

  @override
  String get chooseGroupInPlan => 'Grubu ders programında seçin';

  @override
  String teacherAbsent(String name) {
    return '$name yok';
  }

  @override
  String roomInsteadOf(String room, String old) {
    return '$old yerine $room';
  }

  @override
  String get lessonFallback => 'Ders';

  @override
  String mealToday(String notes) {
    return 'Bugün: $notes';
  }

  @override
  String mealTomorrow(String notes) {
    return 'Yarın: $notes';
  }

  @override
  String noticeTodayFor(String name) {
    return 'Bugün · $name';
  }

  @override
  String noticeTomorrowFor(String name) {
    return 'Yarın · $name';
  }

  @override
  String get noticeTodaySchool => 'Bugün okulda';

  @override
  String get noticeTomorrowSchool => 'Yarın okulda';

  @override
  String get noticeTodayChild => 'Bugün · çocuğunuz';

  @override
  String get noticeTomorrowChild => 'Yarın · çocuğunuz';

  @override
  String get navToday => 'Bugün';

  @override
  String get navCalendar => 'Takvim';

  @override
  String get navCourses => 'Dersler';

  @override
  String get navMessages => 'Mesajlar';

  @override
  String get navMore => 'Diğer';

  @override
  String get reportSickDetail => 'Şimdilik yalnızca portalda kontrol edilir';

  @override
  String get orderMealSetup => 'Yemekhane sipariş sayfasını bir kez girin';

  @override
  String get mensaChange => 'Yemekhane adresini değiştir';

  @override
  String get learningPlatform => 'Öğrenme platformu (Moodle)';

  @override
  String get portalInBrowser => 'Tarayıcıda Schulportal';

  @override
  String get settings => 'Ayarlar';

  @override
  String get settingsDetail => 'Hesap, bildirimler, görünüm, gizlilik';

  @override
  String get invalidUrl => 'Bu bir web adresine benzemiyor.';

  @override
  String get mensaDialogTitle => 'Yemekhane sipariş sayfası';

  @override
  String get mensaDialogText =>
      'Yemeği sipariş ettiğiniz sayfanın adresi. Uygulama sayfayı tarayıcıda açar; giriş orada yapılır.';

  @override
  String get mensaDialogHint => 'ör. siparis.example.com';

  @override
  String get delete => 'Sil';

  @override
  String get cancel => 'İptal';

  @override
  String get save => 'Kaydet';

  @override
  String get eventsNone => 'Önümüzdeki haftalarda etkinlik yok.';

  @override
  String get kindExam => 'Sınav';

  @override
  String get kindFree => 'Okul tatil';

  @override
  String get kindDeadline => 'Son tarih';

  @override
  String get kindMeal => 'Yemek';

  @override
  String get allDay => 'tüm gün';

  @override
  String get noTimetable => 'Okul bu hesap için ders programı sunmuyor.';

  @override
  String get offlineNothingSaved => 'Bağlantı yok ve henüz kayıtlı veri yok.';

  @override
  String get timetableFailed => 'Ders programı yüklenemedi.';

  @override
  String get retry => 'Tekrar deneyin';

  @override
  String get viewDay => 'Gün';

  @override
  String get viewWeek => 'Hafta';

  @override
  String get viewEvents => 'Etkinlikler';

  @override
  String get chooseGroupLabel => 'Grup seçin:';

  @override
  String get noLessonsThisDay => 'Bu gün ders yok.';

  @override
  String get freePeriod => 'Boş ders';

  @override
  String subjectGroups(String subject, int count) {
    return '$subject · $count grup';
  }

  @override
  String notChosenYet(String slot) {
    return '$slot · henüz seçilmedi';
  }

  @override
  String get choose => 'Seç';

  @override
  String get cancelledCap => 'İptal';

  @override
  String get otherGroup => 'Diğer grup';

  @override
  String get cellChoice => 'Seçim';

  @override
  String cellGroups(int count) {
    return '$count grup';
  }

  @override
  String cellSubjects(int count) {
    return '$count ders';
  }

  @override
  String get cellChoose => 'seç';

  @override
  String groupSheetTitle(String subject) {
    return '$subject – grup seçin';
  }

  @override
  String get whichSubject => 'Hangi ders?';

  @override
  String groupSheetSame(String subject, String name) {
    return '$name için tüm $subject derslerinde geçerlidir. Diğer gruplar gizlenir.';
  }

  @override
  String groupSheetParallel(String subject, String name) {
    return 'Aynı saatte $subject var. $name hangisini alıyorsa onu seçin; diğerleri gizlenir.';
  }

  @override
  String groupOf(String teacher) {
    return 'Grup $teacher';
  }

  @override
  String roomValue(String room) {
    return 'Derslik $room';
  }

  @override
  String get detectedViaCourse => '“Mein Unterricht”teki kurstan tanındı';

  @override
  String get showAllAgain => 'Hepsini yeniden göster';

  @override
  String get nameUnknown => 'Ad bilinmiyor';

  @override
  String teacherCode(String code) {
    return 'Kısaltma $code';
  }

  @override
  String get noTeacherGiven => 'Öğretmen belirtilmemiş.';

  @override
  String get tapToNameTeacher =>
      'Ad girmek için dokunun. Ad yalnızca bu cihazda bu hesap için kaydedilir.';

  @override
  String nameFor(String code) {
    return '$code için ad';
  }

  @override
  String get teacherNameHint => 'ör. Ayşe Hanım';

  @override
  String get cacheCleared => 'Önbellek temizlendi';

  @override
  String get logoutQuestion => 'Çıkış yapılsın mı?';

  @override
  String get logoutText =>
      'Hesap, kayıtlı grup seçimleri ve öğretmen adlarıyla birlikte bu cihazdan kaldırılır. Geri dönmek için yeniden giriş yapın.';

  @override
  String get logout => 'Çıkış yap';

  @override
  String get subscribeEvents => 'Etkinliklere abone ol';

  @override
  String get subscribeFailed => 'Abonelik adresi yüklenemedi.';

  @override
  String get subscribeText =>
      'Bu adresle takvim uygulamanız (ör. Google Takvim: “Diğer takvimler” → “URL ile”) okul etkinliklerini ekler ve güncel tutar.';

  @override
  String get copyAddress => 'Adresi kopyala';

  @override
  String get close => 'Kapat';

  @override
  String get parentAccount => 'Veli hesabı';

  @override
  String get studentAccount => 'Öğrenci hesabı';

  @override
  String get teacherAccount => 'Öğretmen';

  @override
  String get back => 'Geri';

  @override
  String get sectionAccount => 'Hesap';

  @override
  String get userData => 'Kullanıcı bilgileri';

  @override
  String get userDataDetail => 'Portalın bu hesap hakkında tuttuğu bilgiler';

  @override
  String get switchAccount => 'Hesap değiştir veya ekle';

  @override
  String get logoutDetail => 'Hesabı bu cihazdan kaldırır';

  @override
  String get sectionNotifications => 'Bildirimler';

  @override
  String get allowNotifications => 'Bildirimlere izin ver';

  @override
  String get notificationsBlocked =>
      'Telefonunuz şu anda bu uygulama için bildirimleri engelliyor';

  @override
  String get forThisAccount => 'Bu hesap için';

  @override
  String get notifySubstitutions =>
      'İptaller, ders değişiklikleri, önemli etkinlikler';

  @override
  String get notifySubstitutionsDetail =>
      'Bugün için hemen, yarın için saat 19\'dan itibaren';

  @override
  String get notifyMessages => 'Yeni mesajlar';

  @override
  String get timeWindow => 'Zaman aralığı';

  @override
  String get timeWindowDetail => 'Bu saatler dışında sessiz';

  @override
  String get sectionAppearance => 'Görünüm';

  @override
  String get likePhone => 'Telefondaki gibi';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeDark => 'Koyu';

  @override
  String get fontSize => 'Yazı boyutu';

  @override
  String get fontNormal => 'Normal';

  @override
  String get fontLarge => 'Büyük';

  @override
  String get fontXLarge => 'Çok büyük';

  @override
  String get language => 'Dil';

  @override
  String get languageNote =>
      'Dersler, etkinlikler ve mesajlar gibi okul içerikleri okulun yazdığı gibi kalır.';

  @override
  String get sectionData => 'Veriler';

  @override
  String get subscribeEventsDetail => 'Okul etkinlikleri kendi takviminizde';

  @override
  String get clearCache => 'Önbelleği temizle';

  @override
  String get clearCacheDetail => 'Derslerden ve mesajlardan indirilen dosyalar';

  @override
  String get sectionAbout => 'Uygulama hakkında';

  @override
  String versionValue(String version) {
    return 'Sürüm $version';
  }

  @override
  String get unofficial => 'resmî değildir, Hessen eyaletine ait değildir';

  @override
  String get whatsNew => 'Bu sürümdeki yenilikler';

  @override
  String get privacy => 'Gizlilik';

  @override
  String get privacyDetail =>
      'Kendi sunucumuz yok – her şey telefonunuzda kalır';

  @override
  String get sourceLicense => 'Kaynak kodu ve lisans';

  @override
  String sourceLicenseDetail(String upstream) {
    return 'Özgür yazılım (GPL-3.0), temeli $upstream';
  }

  @override
  String get libraries => 'Kullanılan kütüphaneler';

  @override
  String get sectionDebug => 'Sorun giderme';

  @override
  String get debugToggle => 'Sorunlarla ilgili sorular için';

  @override
  String get debugExport => 'Hata ayıklama dışa aktarımı';

  @override
  String get debugExportDetail => 'Paylaşmak için kayıt, parolalar gizlenmiş';

  @override
  String get userDataNote =>
      'Schulportal\'ın bu hesap hakkında tuttuğu bilgiler. Yalnızca portalın kendisinde değiştirilebilir.';
}
