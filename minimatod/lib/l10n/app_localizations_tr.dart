// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Minimatod';

  @override
  String get note => 'Not';

  @override
  String get task => 'Görev';

  @override
  String get notes => 'Notlar';

  @override
  String get tasks => 'Görevler';

  @override
  String get emptyTitle => 'Burada henüz bir şey yok';

  @override
  String get emptySubtitle => 'İlk öğeni eklemek için + simgesine dokun';

  @override
  String get writeNoteHint => 'Bir not yaz…';

  @override
  String get addTaskHint => 'Bir görev ekle…';

  @override
  String get addNote => 'Yeni not';

  @override
  String get addTask => 'Yeni görev';

  @override
  String get add => 'Ekle';

  @override
  String get save => 'Kaydet';

  @override
  String get cancel => 'İptal';

  @override
  String get delete => 'Sil';

  @override
  String get rename => 'Yeniden adlandır';

  @override
  String get moveToTop => 'En üste taşı';

  @override
  String get renameTitle => 'Yeniden adlandır';

  @override
  String get deleteConfirmTitle => 'Bu öğe silinsin mi?';

  @override
  String get deleteConfirmBody => 'İçindeki her şey de silinecek.';

  @override
  String get searchHint => 'Not ve görevlerde ara';

  @override
  String get searchEmpty => 'Sonuç yok';

  @override
  String get home => 'Ana sayfa';

  @override
  String get settings => 'Ayarlar';

  @override
  String get about => 'Hakkında';

  @override
  String get appearance => 'Görünüm';

  @override
  String get theme => 'Tema';

  @override
  String get language => 'Dil';

  @override
  String get themeAuto => 'Otomatik';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeDark => 'Koyu';

  @override
  String get themeDarkBlue => 'Koyu Mavi';

  @override
  String get languageSystem => 'Sistem';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get privacyPolicy => 'Gizlilik Politikası';

  @override
  String get contactSupport => 'Destek ile iletişim';

  @override
  String get website => 'Web sitesi';

  @override
  String get openWebApp => 'Web uygulamasını aç';

  @override
  String versionLabel(String version) {
    return 'Sürüm $version';
  }

  @override
  String couldNotOpen(String url) {
    return 'Açılamadı: $url';
  }

  @override
  String get noteBodyHint => 'Ayrıntı ekle…';

  @override
  String get emptyChildrenHint =>
      'Henüz öğe yok — not için sola kaydır ya da + ile ekle.';

  @override
  String get tabItems => 'Öğeler';

  @override
  String get tabNote => 'Not';

  @override
  String get done => 'Bitti';

  @override
  String get convertToTask => 'Göreve dönüştür';

  @override
  String get convertToNote => 'Nota dönüştür';

  @override
  String get iconLabel => 'Simge';

  @override
  String get colorLabel => 'Renk';

  @override
  String get reminderLabel => 'Hatırlatıcı';

  @override
  String get setReminder => 'Tarih ve saat seç';

  @override
  String get edit => 'Düzenle';

  @override
  String get reminderLaterToday => 'Bugün ilerisi';

  @override
  String get reminderTomorrow => 'Yarın';

  @override
  String get reminderNextWeek => 'Gelecek hafta';

  @override
  String get enableReminders => 'Hatırlatıcılar açılsın mı?';

  @override
  String get enableRemindersBody =>
      'Belirlediğin saatte seni uyarabilmemiz için bildirimlere izin ver. Bunu istediğin zaman ayarlardan değiştirebilirsin.';

  @override
  String get notNow => 'Şimdi değil';

  @override
  String get enable => 'İzin ver';

  @override
  String get remindersBlocked =>
      'Hatırlatıcılar kapalı. Almak için bildirimlere izin ver.';

  @override
  String get howToEnable => 'Nasıl açılır';

  @override
  String get enableInstructionsWeb =>
      'Tarayıcın bu site için bildirimleri engelledi. Adres çubuğunun solundaki sayfa bilgisi simgesine dokun, Bildirimler’i İzin Ver yap ve sayfayı yenile.';

  @override
  String get enableInstructionsNative =>
      'Bildirimler kapalı. Cihaz Ayarları’nı aç, Minimatod’u bul ve Bildirimler’e izin ver.';

  @override
  String get remindersNeedPermission =>
      'Hatırlatıcı henüz çalışmaz. İzin vermek için dokun.';

  @override
  String tasksLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'görev kaldı',
    );
    return '$_temp0';
  }
}
