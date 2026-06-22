// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Minimatod';

  @override
  String get note => 'Note';

  @override
  String get task => 'Task';

  @override
  String get notes => 'Notes';

  @override
  String get tasks => 'Tasks';

  @override
  String get emptyTitle => 'Nothing here yet';

  @override
  String get emptySubtitle => 'Tap + to add your first item';

  @override
  String get writeNoteHint => 'Write a note…';

  @override
  String get addTaskHint => 'Add a task…';

  @override
  String get addNote => 'New note';

  @override
  String get addTask => 'New task';

  @override
  String get add => 'Add';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get moveToTop => 'Move to top';

  @override
  String get renameTitle => 'Rename';

  @override
  String get deleteConfirmTitle => 'Delete this item?';

  @override
  String get deleteConfirmBody => 'This will also delete everything inside it.';

  @override
  String get searchHint => 'Search notes & tasks';

  @override
  String get searchEmpty => 'No matches';

  @override
  String get home => 'Home';

  @override
  String get settings => 'Settings';

  @override
  String get about => 'About';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get language => 'Language';

  @override
  String get themeAuto => 'Auto';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeDarkBlue => 'Dark Blue';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get contactSupport => 'Contact support';

  @override
  String get website => 'Website';

  @override
  String get openWebApp => 'Open web app';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String couldNotOpen(String url) {
    return 'Could not open $url';
  }

  @override
  String get noteBodyHint => 'Add details…';

  @override
  String get emptyChildrenHint =>
      'No items yet — swipe left for the note, or tap + to add one.';

  @override
  String get tabItems => 'Items';

  @override
  String get tabNote => 'Note';

  @override
  String get done => 'Done';

  @override
  String get convertToTask => 'Convert to task';

  @override
  String get convertToNote => 'Convert to note';

  @override
  String get iconLabel => 'Icon';

  @override
  String get colorLabel => 'Color';

  @override
  String get reminderLabel => 'Reminder';

  @override
  String get setReminder => 'Set date & time';

  @override
  String get edit => 'Edit';

  @override
  String get reminderLaterToday => 'Later today';

  @override
  String get reminderTomorrow => 'Tomorrow';

  @override
  String get reminderNextWeek => 'Next week';

  @override
  String get enableReminders => 'Enable reminders?';

  @override
  String get enableRemindersBody =>
      'Allow notifications so Minimatod can alert you at the time you set. You can change this anytime in settings.';

  @override
  String get notNow => 'Not now';

  @override
  String get enable => 'Enable';

  @override
  String get remindersBlocked =>
      'Reminders are off. Allow notifications to receive them.';

  @override
  String get howToEnable => 'How to enable';

  @override
  String get enableInstructionsWeb =>
      'Your browser has blocked notifications for this site. Click the page-info icon (to the left of the address bar), set Notifications to Allow, then reload the page.';

  @override
  String get enableInstructionsNative =>
      'Notifications are turned off. Open your device Settings, find Minimatod, and allow Notifications.';

  @override
  String get remindersNeedPermission =>
      'Reminder won\'t fire yet. Tap to allow notifications.';

  @override
  String tasksLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tasks left',
      one: 'task left',
    );
    return '$_temp0';
  }
}
