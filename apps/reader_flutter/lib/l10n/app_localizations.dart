import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('am'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Ethiopian Reader'**
  String get appTitle;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Sacred texts, timeless wisdom'**
  String get splashTagline;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get goBack;

  /// No description provided for @generalCategory.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalCategory;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get registrationFailed;

  /// No description provided for @cachedJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get cachedJustNow;

  /// No description provided for @cachedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String cachedMinutesAgo(int count);

  /// No description provided for @cachedHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String cachedHoursAgo(int count);

  /// No description provided for @cachedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String cachedDaysAgo(int count);

  /// No description provided for @catalogSynced.
  ///
  /// In en, this message translates to:
  /// **'Catalog synced {when}'**
  String catalogSynced(String when);

  /// No description provided for @showingLibrarySynced.
  ///
  /// In en, this message translates to:
  /// **'Showing library synced {when}'**
  String showingLibrarySynced(String when);

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get navBrowse;

  /// No description provided for @navAccount.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navAccount;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @drawerHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get drawerHome;

  /// No description provided for @drawerBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse books'**
  String get drawerBrowse;

  /// No description provided for @drawerAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get drawerAccount;

  /// No description provided for @drawerProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get drawerProfile;

  /// No description provided for @drawerSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get drawerSettings;

  /// No description provided for @drawerAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get drawerAbout;

  /// No description provided for @drawerContinueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue reading'**
  String get drawerContinueReading;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsCacheSection.
  ///
  /// In en, this message translates to:
  /// **'Storage & cache'**
  String get settingsCacheSection;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutAppSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'About this app'**
  String get aboutAppSectionTitle;

  /// No description provided for @aboutAppSectionBody.
  ///
  /// In en, this message translates to:
  /// **'Ethiopian Reader helps you browse, read, and study religious texts with offline support and reading progress.'**
  String get aboutAppSectionBody;

  /// No description provided for @aboutVersionSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersionSectionTitle;

  /// No description provided for @aboutVersionValue.
  ///
  /// In en, this message translates to:
  /// **'1.0.0'**
  String get aboutVersionValue;

  /// No description provided for @aboutDevelopersSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Developers'**
  String get aboutDevelopersSectionTitle;

  /// No description provided for @aboutDevelopersBody.
  ///
  /// In en, this message translates to:
  /// **'Ethiopian Religious Books project'**
  String get aboutDevelopersBody;

  /// No description provided for @homeQuickProfile.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get homeQuickProfile;

  /// No description provided for @homeQuickProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Account and sign in'**
  String get homeQuickProfileSubtitle;

  /// No description provided for @homeQuickSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeQuickSettings;

  /// No description provided for @homeQuickSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Language, offline cache, and reminders'**
  String get homeQuickSettingsSubtitle;

  /// No description provided for @actionRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get actionRead;

  /// No description provided for @actionInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get actionInfo;

  /// No description provided for @continueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue reading'**
  String get continueReading;

  /// No description provided for @resumeReading.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeReading;

  /// No description provided for @readNow.
  ///
  /// In en, this message translates to:
  /// **'Read now'**
  String get readNow;

  /// No description provided for @recentlyOpened.
  ///
  /// In en, this message translates to:
  /// **'Recently opened'**
  String get recentlyOpened;

  /// No description provided for @homeQuickBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse all books'**
  String get homeQuickBrowse;

  /// No description provided for @homeQuickBrowseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search and filter the full catalog'**
  String get homeQuickBrowseSubtitle;

  /// No description provided for @homeQuickDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get homeQuickDownloads;

  /// No description provided for @homeQuickDownloadsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Books saved for offline reading'**
  String get homeQuickDownloadsSubtitle;

  /// No description provided for @downloadsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadsPageTitle;

  /// No description provided for @downloadsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing downloaded yet'**
  String get downloadsEmptyTitle;

  /// No description provided for @downloadsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Save books for offline reading from a book\'s detail page or while reading.'**
  String get downloadsEmptyMessage;

  /// No description provided for @downloadsSavedSection.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device'**
  String get downloadsSavedSection;

  /// No description provided for @downloadsActiveSection.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadsActiveSection;

  /// No description provided for @downloadsFailedSection.
  ///
  /// In en, this message translates to:
  /// **'Failed downloads'**
  String get downloadsFailedSection;

  /// No description provided for @downloadsNoSavedYet.
  ///
  /// In en, this message translates to:
  /// **'No books saved offline yet. Open a book and use Save offline.'**
  String get downloadsNoSavedYet;

  /// No description provided for @unableToLoadDownloads.
  ///
  /// In en, this message translates to:
  /// **'Unable to load downloads'**
  String get unableToLoadDownloads;

  /// No description provided for @savedOfflineBadge.
  ///
  /// In en, this message translates to:
  /// **'Available offline'**
  String get savedOfflineBadge;

  /// No description provided for @downloadInProgress.
  ///
  /// In en, this message translates to:
  /// **'Download in progress…'**
  String get downloadInProgress;

  /// No description provided for @downloadFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailedGeneric;

  /// No description provided for @downloadsSyncCache.
  ///
  /// In en, this message translates to:
  /// **'Sync from server'**
  String get downloadsSyncCache;

  /// No description provided for @downloadsClearBookCache.
  ///
  /// In en, this message translates to:
  /// **'Remove offline copy'**
  String get downloadsClearBookCache;

  /// No description provided for @downloadsClearAllCache.
  ///
  /// In en, this message translates to:
  /// **'Clear all offline copies'**
  String get downloadsClearAllCache;

  /// No description provided for @downloadsSyncDone.
  ///
  /// In en, this message translates to:
  /// **'Offline copy updated'**
  String get downloadsSyncDone;

  /// No description provided for @downloadsClearBookTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{title}\"?'**
  String downloadsClearBookTitle(String title);

  /// No description provided for @downloadsClearBookBody.
  ///
  /// In en, this message translates to:
  /// **'This removes saved chapters and pages for this book on this device only.'**
  String get downloadsClearBookBody;

  /// No description provided for @downloadsCacheInvalid.
  ///
  /// In en, this message translates to:
  /// **'No readable content — sync or remove'**
  String get downloadsCacheInvalid;

  /// No description provided for @downloadsNotInCatalogHint.
  ///
  /// In en, this message translates to:
  /// **'This book is not in the public catalog; details are from your offline copy only.'**
  String get downloadsNotInCatalogHint;

  /// No description provided for @homeQuickAccount.
  ///
  /// In en, this message translates to:
  /// **'Account & sync'**
  String get homeQuickAccount;

  /// No description provided for @homeQuickAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Profile, plans, and preferences'**
  String get homeQuickAccountSubtitle;

  /// No description provided for @browseByCategory.
  ///
  /// In en, this message translates to:
  /// **'Browse by category'**
  String get browseByCategory;

  /// No description provided for @booksInCategory.
  ///
  /// In en, this message translates to:
  /// **'{count} books'**
  String booksInCategory(int count);

  /// No description provided for @readFullBook.
  ///
  /// In en, this message translates to:
  /// **'Read full book'**
  String get readFullBook;

  /// No description provided for @headerCategoriesStat.
  ///
  /// In en, this message translates to:
  /// **'{count} categories'**
  String headerCategoriesStat(int count);

  /// No description provided for @headerBooksStat.
  ///
  /// In en, this message translates to:
  /// **'{count} books'**
  String headerBooksStat(int count);

  /// No description provided for @mostReadSection.
  ///
  /// In en, this message translates to:
  /// **'Recently opened'**
  String get mostReadSection;

  /// No description provided for @searchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTooltip;

  /// No description provided for @homeNoBooksTitle.
  ///
  /// In en, this message translates to:
  /// **'No published books yet'**
  String get homeNoBooksTitle;

  /// No description provided for @homeNoBooksMessage.
  ///
  /// In en, this message translates to:
  /// **'New titles will appear here as soon as they are available.'**
  String get homeNoBooksMessage;

  /// No description provided for @openLibrary.
  ///
  /// In en, this message translates to:
  /// **'Open Library'**
  String get openLibrary;

  /// No description provided for @exploreWisdomTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore wisdom and history'**
  String get exploreWisdomTitle;

  /// No description provided for @exploreWisdomBody.
  ///
  /// In en, this message translates to:
  /// **'Browse curated religious texts in a clean editorial layout with fast access to reading.'**
  String get exploreWisdomBody;

  /// No description provided for @searchLibrary.
  ///
  /// In en, this message translates to:
  /// **'Search Library'**
  String get searchLibrary;

  /// No description provided for @browseCollections.
  ///
  /// In en, this message translates to:
  /// **'Browse Collections'**
  String get browseCollections;

  /// No description provided for @featuredBooks.
  ///
  /// In en, this message translates to:
  /// **'Featured Books'**
  String get featuredBooks;

  /// No description provided for @curatedSelections.
  ///
  /// In en, this message translates to:
  /// **'{count} curated selections'**
  String curatedSelections(int count);

  /// No description provided for @librarySections.
  ///
  /// In en, this message translates to:
  /// **'Library Sections'**
  String get librarySections;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @unableToLoadHome.
  ///
  /// In en, this message translates to:
  /// **'Unable to load home'**
  String get unableToLoadHome;

  /// No description provided for @noSummaryYet.
  ///
  /// In en, this message translates to:
  /// **'No summary available yet.'**
  String get noSummaryYet;

  /// No description provided for @readDetails.
  ///
  /// In en, this message translates to:
  /// **'Read details'**
  String get readDetails;

  /// No description provided for @unknownAuthor.
  ///
  /// In en, this message translates to:
  /// **'Unknown author'**
  String get unknownAuthor;

  /// No description provided for @openArticle.
  ///
  /// In en, this message translates to:
  /// **'Open article'**
  String get openArticle;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// No description provided for @filterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filterTooltip;

  /// No description provided for @filterByLanguage.
  ///
  /// In en, this message translates to:
  /// **'Filter by language'**
  String get filterByLanguage;

  /// No description provided for @allLanguages.
  ///
  /// In en, this message translates to:
  /// **'All languages'**
  String get allLanguages;

  /// No description provided for @chapterKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter key'**
  String get chapterKeyLabel;

  /// No description provided for @chapterKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Optional server filter'**
  String get chapterKeyHint;

  /// No description provided for @pageNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Page number'**
  String get pageNumberLabel;

  /// No description provided for @pageNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Optional server filter'**
  String get pageNumberHint;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get applyFilters;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Library is empty'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No published books are available right now.'**
  String get libraryEmptyMessage;

  /// No description provided for @librarySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by title, author, or summary'**
  String get librarySearchHint;

  /// No description provided for @clearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearchTooltip;

  /// No description provided for @booksAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} book(s) available'**
  String booksAvailable(int count);

  /// No description provided for @clearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get clearFilter;

  /// No description provided for @languageChip.
  ///
  /// In en, this message translates to:
  /// **'Language: {lang}'**
  String languageChip(String lang);

  /// No description provided for @chapterChip.
  ///
  /// In en, this message translates to:
  /// **'Chapter: {ch}'**
  String chapterChip(String ch);

  /// No description provided for @pageChip.
  ///
  /// In en, this message translates to:
  /// **'Page: {page}'**
  String pageChip(int page);

  /// No description provided for @noMatchingBooksTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching books'**
  String get noMatchingBooksTitle;

  /// No description provided for @noMatchingBooksMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a different keyword or clear filters.'**
  String get noMatchingBooksMessage;

  /// No description provided for @unableToLoadLibrary.
  ///
  /// In en, this message translates to:
  /// **'Unable to load library'**
  String get unableToLoadLibrary;

  /// No description provided for @revisionLabel.
  ///
  /// In en, this message translates to:
  /// **'Revision {n}'**
  String revisionLabel(int n);

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @readerAccount.
  ///
  /// In en, this message translates to:
  /// **'Reader Account'**
  String get readerAccount;

  /// No description provided for @noEmail.
  ///
  /// In en, this message translates to:
  /// **'No email'**
  String get noEmail;

  /// No description provided for @adminRoleBadge.
  ///
  /// In en, this message translates to:
  /// **'ADMIN'**
  String get adminRoleBadge;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @inProgressDownloads.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get inProgressDownloads;

  /// No description provided for @failedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Failed downloads'**
  String get failedDownloads;

  /// No description provided for @availableBooks.
  ///
  /// In en, this message translates to:
  /// **'Available books'**
  String get availableBooks;

  /// No description provided for @languagesMetric.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languagesMetric;

  /// No description provided for @offlineChapterCache.
  ///
  /// In en, this message translates to:
  /// **'Offline chapter cache'**
  String get offlineChapterCache;

  /// No description provided for @offlineBooksSaved.
  ///
  /// In en, this message translates to:
  /// **'{count} book(s) saved offline'**
  String offlineBooksSaved(int count);

  /// No description provided for @checkingCache.
  ///
  /// In en, this message translates to:
  /// **'Checking cache...'**
  String get checkingCache;

  /// No description provided for @cacheUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Cache unavailable'**
  String get cacheUnavailable;

  /// No description provided for @clearOfflineCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear offline cache?'**
  String get clearOfflineCacheTitle;

  /// No description provided for @clearOfflineCacheBody.
  ///
  /// In en, this message translates to:
  /// **'This removes downloaded chapter/page content from this device.'**
  String get clearOfflineCacheBody;

  /// No description provided for @offlineCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Offline cache cleared'**
  String get offlineCacheCleared;

  /// No description provided for @studyAndReminders.
  ///
  /// In en, this message translates to:
  /// **'Study & reminders'**
  String get studyAndReminders;

  /// No description provided for @dailyReadingReminders.
  ///
  /// In en, this message translates to:
  /// **'Daily reading reminders'**
  String get dailyReadingReminders;

  /// No description provided for @reminderTimeUtc.
  ///
  /// In en, this message translates to:
  /// **'UTC {hh}:{mm}{weekdays}'**
  String reminderTimeUtc(String hh, String mm, String weekdays);

  /// No description provided for @weekdaysOnlySuffix.
  ///
  /// In en, this message translates to:
  /// **' · weekdays only'**
  String get weekdaysOnlySuffix;

  /// No description provided for @reminderUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Reminder settings could not be updated. Please run backend migrations and try again.'**
  String get reminderUpdateFailed;

  /// No description provided for @loadingReminderSettings.
  ///
  /// In en, this message translates to:
  /// **'Loading reminder settings...'**
  String get loadingReminderSettings;

  /// No description provided for @reminderSettingsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Reminder settings unavailable'**
  String get reminderSettingsUnavailable;

  /// No description provided for @dailyReadingPlans.
  ///
  /// In en, this message translates to:
  /// **'Daily reading plans'**
  String get dailyReadingPlans;

  /// No description provided for @noReadingPlansYet.
  ///
  /// In en, this message translates to:
  /// **'No reading plans yet'**
  String get noReadingPlansYet;

  /// No description provided for @readingPlansConfigured.
  ///
  /// In en, this message translates to:
  /// **'{count} plan(s) configured'**
  String readingPlansConfigured(int count);

  /// No description provided for @tapOpenTodaysReading.
  ///
  /// In en, this message translates to:
  /// **' · tap to open today\'s reading'**
  String get tapOpenTodaysReading;

  /// No description provided for @createPlanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create plan'**
  String get createPlanTooltip;

  /// No description provided for @dailyPlanCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Daily plan could not be created. Please run backend migrations and try again.'**
  String get dailyPlanCreateFailed;

  /// No description provided for @accountInfo.
  ///
  /// In en, this message translates to:
  /// **'Account Info'**
  String get accountInfo;

  /// No description provided for @profileAccountDetails.
  ///
  /// In en, this message translates to:
  /// **'Account details'**
  String get profileAccountDetails;

  /// No description provided for @profileUserIdLabel.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get profileUserIdLabel;

  /// No description provided for @profileRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get profileRoleLabel;

  /// No description provided for @profilePreferredLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Preferred language'**
  String get profilePreferredLanguageLabel;

  /// No description provided for @profileSuperuserLabel.
  ///
  /// In en, this message translates to:
  /// **'Administrator access'**
  String get profileSuperuserLabel;

  /// No description provided for @profileValueNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get profileValueNotSet;

  /// No description provided for @profileYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get profileYes;

  /// No description provided for @profileNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get profileNo;

  /// No description provided for @profileOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileOpenSettings;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayNameLabel;

  /// No description provided for @adminPanel.
  ///
  /// In en, this message translates to:
  /// **'Admin panel'**
  String get adminPanel;

  /// No description provided for @adminPanelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage books, visibility, and publishing'**
  String get adminPanelSubtitle;

  /// No description provided for @noProfileCached.
  ///
  /// In en, this message translates to:
  /// **'No profile cached.'**
  String get noProfileCached;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue reading and keep your progress synced.'**
  String get signInSubtitle;

  /// No description provided for @emailFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailFieldLabel;

  /// No description provided for @emailFieldHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get emailFieldHint;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get emailInvalid;

  /// No description provided for @passwordFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordFieldLabel;

  /// No description provided for @passwordMinHelper.
  ///
  /// In en, this message translates to:
  /// **'Minimum 10 characters'**
  String get passwordMinHelper;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get createAccount;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your profile to save progress, bookmarks, and downloads.'**
  String get registerSubtitle;

  /// No description provided for @passwordMinRegisterHelper.
  ///
  /// In en, this message translates to:
  /// **'Use at least 10 characters'**
  String get passwordMinRegisterHelper;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 10 characters'**
  String get passwordTooShort;

  /// No description provided for @displayNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Display name (optional)'**
  String get displayNameOptional;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccount;

  /// No description provided for @languagePreferenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languagePreferenceTitle;

  /// No description provided for @languagePreferenceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose English or Amharic for app menus and buttons.'**
  String get languagePreferenceSubtitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageAmharic.
  ///
  /// In en, this message translates to:
  /// **'አማርኛ (Amharic)'**
  String get languageAmharic;

  /// No description provided for @saveLanguage.
  ///
  /// In en, this message translates to:
  /// **'Save language'**
  String get saveLanguage;

  /// No description provided for @languageSaved.
  ///
  /// In en, this message translates to:
  /// **'Language saved'**
  String get languageSaved;

  /// No description provided for @bookDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Book Details'**
  String get bookDetailsTitle;

  /// No description provided for @preparingDownload.
  ///
  /// In en, this message translates to:
  /// **'Preparing download…'**
  String get preparingDownload;

  /// No description provided for @savedUnderPath.
  ///
  /// In en, this message translates to:
  /// **'Saved under {path}'**
  String savedUnderPath(String path);

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String downloadFailed(String error);

  /// No description provided for @summarySection.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summarySection;

  /// No description provided for @readyToRead.
  ///
  /// In en, this message translates to:
  /// **'Ready to read'**
  String get readyToRead;

  /// No description provided for @downloadState.
  ///
  /// In en, this message translates to:
  /// **'Download: {state}'**
  String downloadState(String state);

  /// No description provided for @startReading.
  ///
  /// In en, this message translates to:
  /// **'Start Reading'**
  String get startReading;

  /// No description provided for @downloadOffline.
  ///
  /// In en, this message translates to:
  /// **'Download for offline reading'**
  String get downloadOffline;

  /// No description provided for @unableToLoadBook.
  ///
  /// In en, this message translates to:
  /// **'Unable to load this book'**
  String get unableToLoadBook;

  /// No description provided for @bookLoadErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The book could not be opened right now. Please try again.'**
  String get bookLoadErrorMessage;

  /// No description provided for @bookNotInCatalogTitle.
  ///
  /// In en, this message translates to:
  /// **'Book not available in reader catalog'**
  String get bookNotInCatalogTitle;

  /// No description provided for @bookNotInCatalogMessage.
  ///
  /// In en, this message translates to:
  /// **'This book is likely unpublished or hidden. Publish it from admin and try again.'**
  String get bookNotInCatalogMessage;

  /// No description provided for @readerTitle.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get readerTitle;

  /// No description provided for @bookmarkSavedAt.
  ///
  /// In en, this message translates to:
  /// **'Saved at {pct}%'**
  String bookmarkSavedAt(int pct);

  /// No description provided for @bookmarkRemoved.
  ///
  /// In en, this message translates to:
  /// **'Bookmark removed'**
  String get bookmarkRemoved;

  /// No description provided for @bookmarkSaved.
  ///
  /// In en, this message translates to:
  /// **'Bookmark saved'**
  String get bookmarkSaved;

  /// No description provided for @noBookmarksYet.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet. Tap bookmark in reader controls.'**
  String get noBookmarksYet;

  /// No description provided for @savedLocation.
  ///
  /// In en, this message translates to:
  /// **'Saved location'**
  String get savedLocation;

  /// No description provided for @removeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeTooltip;

  /// No description provided for @selectChapter.
  ///
  /// In en, this message translates to:
  /// **'Select chapter'**
  String get selectChapter;

  /// No description provided for @selectPage.
  ///
  /// In en, this message translates to:
  /// **'Select page'**
  String get selectPage;

  /// No description provided for @readerPosition.
  ///
  /// In en, this message translates to:
  /// **'Reader position'**
  String get readerPosition;

  /// No description provided for @readingPosition.
  ///
  /// In en, this message translates to:
  /// **'Reading position'**
  String get readingPosition;

  /// No description provided for @pageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} page(s)'**
  String pageCount(int count);

  /// No description provided for @pageNumberTitle.
  ///
  /// In en, this message translates to:
  /// **'Page {n}'**
  String pageNumberTitle(int n);

  /// No description provided for @choosePage.
  ///
  /// In en, this message translates to:
  /// **'Choose page'**
  String get choosePage;

  /// No description provided for @jumpToPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Jump directly to a page'**
  String get jumpToPageSubtitle;

  /// No description provided for @allChapters.
  ///
  /// In en, this message translates to:
  /// **'All chapters'**
  String get allChapters;

  /// No description provided for @searchPagesWholeBook.
  ///
  /// In en, this message translates to:
  /// **'Search pages across the whole book'**
  String get searchPagesWholeBook;

  /// No description provided for @noChapterSelected.
  ///
  /// In en, this message translates to:
  /// **'No chapter selected'**
  String get noChapterSelected;

  /// No description provided for @cloudBookmarkSaved.
  ///
  /// In en, this message translates to:
  /// **'Cloud bookmark saved'**
  String get cloudBookmarkSaved;

  /// No description provided for @quickNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Quick note'**
  String get quickNoteLabel;

  /// No description provided for @quickNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Write your reflection or summary'**
  String get quickNoteHint;

  /// No description provided for @saveNote.
  ///
  /// In en, this message translates to:
  /// **'Save note'**
  String get saveNote;

  /// No description provided for @noteSaved.
  ///
  /// In en, this message translates to:
  /// **'Note saved'**
  String get noteSaved;

  /// No description provided for @highlightSavedOnPage.
  ///
  /// In en, this message translates to:
  /// **'Highlight saved on page {n}'**
  String highlightSavedOnPage(int n);

  /// No description provided for @highlightsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Highlights are currently unavailable'**
  String get highlightsUnavailable;

  /// No description provided for @noHighlightsYet.
  ///
  /// In en, this message translates to:
  /// **'No highlights yet. Tap the highlighter icon to save one.'**
  String get noHighlightsYet;

  /// No description provided for @highlightDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get highlightDefaultTitle;

  /// No description provided for @highlightChapterPage.
  ///
  /// In en, this message translates to:
  /// **'Chapter {ch} · Page {page}'**
  String highlightChapterPage(String ch, String page);

  /// No description provided for @offlineCopyRemoved.
  ///
  /// In en, this message translates to:
  /// **'Offline copy removed'**
  String get offlineCopyRemoved;

  /// No description provided for @savedOfflineReading.
  ///
  /// In en, this message translates to:
  /// **'Saved for offline reading'**
  String get savedOfflineReading;

  /// No description provided for @findInBookLabel.
  ///
  /// In en, this message translates to:
  /// **'Find in book'**
  String get findInBookLabel;

  /// No description provided for @findInBookHint.
  ///
  /// In en, this message translates to:
  /// **'Type a word or phrase'**
  String get findInBookHint;

  /// No description provided for @searchOutsideChapter.
  ///
  /// In en, this message translates to:
  /// **'Search outside the selected chapter'**
  String get searchOutsideChapter;

  /// No description provided for @noMatchesYet.
  ///
  /// In en, this message translates to:
  /// **'No matches yet.'**
  String get noMatchesYet;

  /// No description provided for @matchCount.
  ///
  /// In en, this message translates to:
  /// **'{count} match(es)'**
  String matchCount(int count);

  /// No description provided for @previousMatch.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get previousMatch;

  /// No description provided for @nextMatch.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get nextMatch;

  /// No description provided for @typographyCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get typographyCompact;

  /// No description provided for @typographyComfort.
  ///
  /// In en, this message translates to:
  /// **'Comfort'**
  String get typographyComfort;

  /// No description provided for @typographyLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get typographyLarge;

  /// No description provided for @typographyPresetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Typography presets'**
  String get typographyPresetsTitle;

  /// No description provided for @typographyPresetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the most comfortable reading mode'**
  String get typographyPresetsSubtitle;

  /// No description provided for @typographySizeLine.
  ///
  /// In en, this message translates to:
  /// **'Size {size} • Line {line}'**
  String typographySizeLine(int size, String line);

  /// No description provided for @chaptersHeading.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get chaptersHeading;

  /// No description provided for @noChapterContentYet.
  ///
  /// In en, this message translates to:
  /// **'This book has no chapter/page content yet. Add chapters and pages in Admin, then publish.'**
  String get noChapterContentYet;

  /// No description provided for @chapterChipRaw.
  ///
  /// In en, this message translates to:
  /// **'Chapter: {label}'**
  String chapterChipRaw(String label);

  /// No description provided for @pageChipShort.
  ///
  /// In en, this message translates to:
  /// **'Page: {n}'**
  String pageChipShort(int n);

  /// No description provided for @backToChaptersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back to chapters'**
  String get backToChaptersTooltip;

  /// No description provided for @filterChapterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter chapter'**
  String get filterChapterTooltip;

  /// No description provided for @filterPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter page'**
  String get filterPageTooltip;

  /// No description provided for @removeOfflineCopy.
  ///
  /// In en, this message translates to:
  /// **'Remove offline copy'**
  String get removeOfflineCopy;

  /// No description provided for @saveChaptersOffline.
  ///
  /// In en, this message translates to:
  /// **'Save chapters offline'**
  String get saveChaptersOffline;

  /// No description provided for @backToChapters.
  ///
  /// In en, this message translates to:
  /// **'Back to chapters'**
  String get backToChapters;

  /// No description provided for @noChapterSelectedShort.
  ///
  /// In en, this message translates to:
  /// **'No chapter selected'**
  String get noChapterSelectedShort;

  /// No description provided for @typographyPresetsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Typography presets'**
  String get typographyPresetsTooltip;

  /// No description provided for @saveCloudBookmarkTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save cloud bookmark'**
  String get saveCloudBookmarkTooltip;

  /// No description provided for @addNoteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNoteTooltip;

  /// No description provided for @addHighlightTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add highlight'**
  String get addHighlightTooltip;

  /// No description provided for @highlightsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get highlightsTooltip;

  /// No description provided for @pinControls.
  ///
  /// In en, this message translates to:
  /// **'Pin controls'**
  String get pinControls;

  /// No description provided for @autoHideControls.
  ///
  /// In en, this message translates to:
  /// **'Auto-hide controls'**
  String get autoHideControls;

  /// No description provided for @readerExpandTools.
  ///
  /// In en, this message translates to:
  /// **'Show reading tools'**
  String get readerExpandTools;

  /// No description provided for @readerCollapseTools.
  ///
  /// In en, this message translates to:
  /// **'Hide reading tools'**
  String get readerCollapseTools;

  /// No description provided for @readerPageCurlOn.
  ///
  /// In en, this message translates to:
  /// **'Turn page curl on'**
  String get readerPageCurlOn;

  /// No description provided for @readerPageCurlOff.
  ///
  /// In en, this message translates to:
  /// **'Turn page curl off'**
  String get readerPageCurlOff;

  /// No description provided for @readerPageCurlHint.
  ///
  /// In en, this message translates to:
  /// **'Drag up-left from the bottom-right corner to curl the page'**
  String get readerPageCurlHint;

  /// No description provided for @matchOnPage.
  ///
  /// In en, this message translates to:
  /// **'Match on page {page}: {snippet}'**
  String matchOnPage(int page, String snippet);

  /// No description provided for @readerChapterLabel.
  ///
  /// In en, this message translates to:
  /// **'CHAPTER'**
  String get readerChapterLabel;

  /// No description provided for @readerPageLabel.
  ///
  /// In en, this message translates to:
  /// **'PAGE'**
  String get readerPageLabel;

  /// No description provided for @adminHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminHomeTitle;

  /// No description provided for @publisherTools.
  ///
  /// In en, this message translates to:
  /// **'Publisher tools'**
  String get publisherTools;

  /// No description provided for @publisherToolsBody.
  ///
  /// In en, this message translates to:
  /// **'Manage catalog visibility, book metadata, and publishing. Uploading revision packages still uses presigned URLs from the API (use a desktop workflow or future in-app upload).'**
  String get publisherToolsBody;

  /// No description provided for @adminBooksMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get adminBooksMenuTitle;

  /// No description provided for @adminBooksMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'List, create, edit, publish / unpublish'**
  String get adminBooksMenuSubtitle;

  /// No description provided for @adminBooksListTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage books'**
  String get adminBooksListTitle;

  /// No description provided for @adminBooksCount.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total} books'**
  String adminBooksCount(int shown, int total);

  /// No description provided for @adminEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get adminEditAction;

  /// No description provided for @adminBookActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Book actions'**
  String get adminBookActionsTooltip;

  /// No description provided for @newBookTooltip.
  ///
  /// In en, this message translates to:
  /// **'New book'**
  String get newBookTooltip;

  /// No description provided for @noBooksYetTitle.
  ///
  /// In en, this message translates to:
  /// **'No books yet'**
  String get noBooksYetTitle;

  /// No description provided for @noBooksYetMessage.
  ///
  /// In en, this message translates to:
  /// **'Create your first book to start publishing to readers.'**
  String get noBooksYetMessage;

  /// No description provided for @createFirstBook.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createFirstBook;

  /// No description provided for @searchBooksLabel.
  ///
  /// In en, this message translates to:
  /// **'Search books'**
  String get searchBooksLabel;

  /// No description provided for @searchBooksHint.
  ///
  /// In en, this message translates to:
  /// **'Title, author, language'**
  String get searchBooksHint;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get filterPublished;

  /// No description provided for @filterHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get filterHidden;

  /// No description provided for @sortRecent.
  ///
  /// In en, this message translates to:
  /// **'Sort: recent'**
  String get sortRecent;

  /// No description provided for @sortTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort: title'**
  String get sortTitle;

  /// No description provided for @noBooksMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No books match these filters.'**
  String get noBooksMatchFilters;

  /// No description provided for @unableToLoadBooks.
  ///
  /// In en, this message translates to:
  /// **'Unable to load books'**
  String get unableToLoadBooks;

  /// No description provided for @visibilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Visibility: {vis}'**
  String visibilityLabel(String vis);

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String statusLabel(String status);

  /// No description provided for @publishedStatus.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get publishedStatus;

  /// No description provided for @draftStatus.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draftStatus;

  /// No description provided for @statusChip.
  ///
  /// In en, this message translates to:
  /// **'{status} · {vis}'**
  String statusChip(String status, String vis);

  /// No description provided for @bookNotFound.
  ///
  /// In en, this message translates to:
  /// **'Book not found.'**
  String get bookNotFound;

  /// No description provided for @unpublishFailed.
  ///
  /// In en, this message translates to:
  /// **'Unpublish failed'**
  String get unpublishFailed;

  /// No description provided for @publishLatestDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish latest draft'**
  String get publishLatestDraftTitle;

  /// No description provided for @publishLatestDraftBody.
  ///
  /// In en, this message translates to:
  /// **'This publishes the latest draft revision for this book. If no draft exists, the backend will generate one from current metadata.'**
  String get publishLatestDraftBody;

  /// No description provided for @publish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publish;

  /// No description provided for @publishedRevisionNumber.
  ///
  /// In en, this message translates to:
  /// **'Published revision #{n}'**
  String publishedRevisionNumber(int n);

  /// No description provided for @publishedLatestRevision.
  ///
  /// In en, this message translates to:
  /// **'Published latest revision'**
  String get publishedLatestRevision;

  /// No description provided for @publishFailed.
  ///
  /// In en, this message translates to:
  /// **'Publish failed'**
  String get publishFailed;

  /// No description provided for @bookFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get bookFallbackTitle;

  /// No description provided for @editMetadataTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit metadata'**
  String get editMetadataTooltip;

  /// No description provided for @publishedVisibleBanner.
  ///
  /// In en, this message translates to:
  /// **'Published and visible in reader'**
  String get publishedVisibleBanner;

  /// No description provided for @draftOnlyBanner.
  ///
  /// In en, this message translates to:
  /// **'Draft only - not visible in reader'**
  String get draftOnlyBanner;

  /// No description provided for @visibilityTile.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get visibilityTile;

  /// No description provided for @authorCompilerTile.
  ///
  /// In en, this message translates to:
  /// **'Author / compiler'**
  String get authorCompilerTile;

  /// No description provided for @languageTile.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTile;

  /// No description provided for @draftChaptersPagesTile.
  ///
  /// In en, this message translates to:
  /// **'Draft chapters/pages'**
  String get draftChaptersPagesTile;

  /// No description provided for @noDraftChapters.
  ///
  /// In en, this message translates to:
  /// **'No draft chapters'**
  String get noDraftChapters;

  /// No description provided for @draftChapterPageCounts.
  ///
  /// In en, this message translates to:
  /// **'{chapters} chapter(s), {pages} page(s)'**
  String draftChapterPageCounts(int chapters, int pages);

  /// No description provided for @publishedRevisionTile.
  ///
  /// In en, this message translates to:
  /// **'Published revision'**
  String get publishedRevisionTile;

  /// No description provided for @openInReader.
  ///
  /// In en, this message translates to:
  /// **'Open in reader'**
  String get openInReader;

  /// No description provided for @publishFirstToOpenReader.
  ///
  /// In en, this message translates to:
  /// **'Publish this book first to open it in reader mode.'**
  String get publishFirstToOpenReader;

  /// No description provided for @publishRevision.
  ///
  /// In en, this message translates to:
  /// **'Publish revision'**
  String get publishRevision;

  /// No description provided for @unpublish.
  ///
  /// In en, this message translates to:
  /// **'Unpublish'**
  String get unpublish;

  /// No description provided for @summaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summaryLabel;

  /// No description provided for @createBookFirstValidate.
  ///
  /// In en, this message translates to:
  /// **'Create the book first, then run draft validation.'**
  String get createBookFirstValidate;

  /// No description provided for @draftValidationTitle.
  ///
  /// In en, this message translates to:
  /// **'Draft validation'**
  String get draftValidationTitle;

  /// No description provided for @warningsHeading.
  ///
  /// In en, this message translates to:
  /// **'Warnings:'**
  String get warningsHeading;

  /// No description provided for @discardUnsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get discardUnsavedTitle;

  /// No description provided for @discardUnsavedBody.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved edits. If you leave now, those changes will be lost.'**
  String get discardUnsavedBody;

  /// No description provided for @discardUnsavedBodyEditor.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved updates in this editor. Leave without saving?'**
  String get discardUnsavedBodyEditor;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @chooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get chooseImage;

  /// No description provided for @removeCover.
  ///
  /// In en, this message translates to:
  /// **'Remove cover'**
  String get removeCover;

  /// No description provided for @validateDraft.
  ///
  /// In en, this message translates to:
  /// **'Validate draft'**
  String get validateDraft;

  /// No description provided for @addChapter.
  ///
  /// In en, this message translates to:
  /// **'Add chapter'**
  String get addChapter;

  /// No description provided for @noPagesYet.
  ///
  /// In en, this message translates to:
  /// **'No pages yet'**
  String get noPagesYet;

  /// No description provided for @moveUpTooltip.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUpTooltip;

  /// No description provided for @moveDownTooltip.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDownTooltip;

  /// No description provided for @addPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add page'**
  String get addPageTooltip;

  /// No description provided for @editChapterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit chapter'**
  String get editChapterTooltip;

  /// No description provided for @deleteChapterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete chapter'**
  String get deleteChapterTooltip;

  /// No description provided for @editPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit page'**
  String get editPageTooltip;

  /// No description provided for @deletePageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete page'**
  String get deletePageTooltip;

  /// No description provided for @addChapterTitle.
  ///
  /// In en, this message translates to:
  /// **'Add chapter'**
  String get addChapterTitle;

  /// No description provided for @editChapterTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit chapter'**
  String get editChapterTitle;

  /// No description provided for @chapterKeyHintExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. chapter-1'**
  String get chapterKeyHintExample;

  /// No description provided for @untitledChapter.
  ///
  /// In en, this message translates to:
  /// **'Untitled chapter'**
  String get untitledChapter;

  /// No description provided for @unsupportedEmbeddedContent.
  ///
  /// In en, this message translates to:
  /// **'Unsupported embedded content'**
  String get unsupportedEmbeddedContent;

  /// No description provided for @editPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit page'**
  String get editPageTitle;

  /// No description provided for @tagSlugsHint.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated, e.g. liturgy, bible'**
  String get tagSlugsHint;

  /// No description provided for @visibilityHidden.
  ///
  /// In en, this message translates to:
  /// **'hidden'**
  String get visibilityHidden;

  /// No description provided for @visibilityPublished.
  ///
  /// In en, this message translates to:
  /// **'published'**
  String get visibilityPublished;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @commaSeparated.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated'**
  String get commaSeparated;

  /// No description provided for @chapterTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter title'**
  String get chapterTitleLabel;

  /// No description provided for @chapterKeyFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter key'**
  String get chapterKeyFieldLabel;

  /// No description provided for @eachChapterNeedsKey.
  ///
  /// In en, this message translates to:
  /// **'Each chapter must have a chapter key.'**
  String get eachChapterNeedsKey;

  /// No description provided for @duplicateChapterKey.
  ///
  /// In en, this message translates to:
  /// **'Duplicate chapter key found: {key}'**
  String duplicateChapterKey(String key);

  /// No description provided for @pageNumberMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Page number must be greater than 0 in chapter {title}.'**
  String pageNumberMustBePositive(String title);

  /// No description provided for @duplicatePageNumber.
  ///
  /// In en, this message translates to:
  /// **'Duplicate page number {n} in chapter {title}.'**
  String duplicatePageNumber(int n, String title);

  /// No description provided for @draftValidationNoWarnings.
  ///
  /// In en, this message translates to:
  /// **'No warnings.\n\nChapters: {chapters}\nPages: {pages}\nEmpty pages: {empty}'**
  String draftValidationNoWarnings(int chapters, int pages, int empty);

  /// No description provided for @draftValidationStatsLine.
  ///
  /// In en, this message translates to:
  /// **'Chapters: {chapters} · Pages: {pages} · Empty pages: {empty}'**
  String draftValidationStatsLine(int chapters, int pages, int empty);

  /// No description provided for @validationFailed.
  ///
  /// In en, this message translates to:
  /// **'Validation failed'**
  String get validationFailed;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get saveFailed;

  /// No description provided for @newBookAppBar.
  ///
  /// In en, this message translates to:
  /// **'New book'**
  String get newBookAppBar;

  /// No description provided for @editBookAppBar.
  ///
  /// In en, this message translates to:
  /// **'Edit book'**
  String get editBookAppBar;

  /// No description provided for @metadataSection.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get metadataSection;

  /// No description provided for @titleLabelRequired.
  ///
  /// In en, this message translates to:
  /// **'Title *'**
  String get titleLabelRequired;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get titleRequired;

  /// No description provided for @subtitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get subtitleLabel;

  /// No description provided for @thumbnailCover.
  ///
  /// In en, this message translates to:
  /// **'Thumbnail / cover'**
  String get thumbnailCover;

  /// No description provided for @coverFormatHelp.
  ///
  /// In en, this message translates to:
  /// **'JPEG, PNG, or WebP. Uploads after you save the book.'**
  String get coverFormatHelp;

  /// No description provided for @authorCompilerLabel.
  ///
  /// In en, this message translates to:
  /// **'Author / compiler'**
  String get authorCompilerLabel;

  /// No description provided for @primaryLanguageCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary language code'**
  String get primaryLanguageCodeLabel;

  /// No description provided for @languageCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Language code is required'**
  String get languageCodeRequired;

  /// No description provided for @scriptTagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Script tags'**
  String get scriptTagsLabel;

  /// No description provided for @chaptersPagesSection.
  ///
  /// In en, this message translates to:
  /// **'Chapters & pages'**
  String get chaptersPagesSection;

  /// No description provided for @noChaptersYetHelp.
  ///
  /// In en, this message translates to:
  /// **'No chapters yet. Add chapters and pages for reader navigation.'**
  String get noChaptersYetHelp;

  /// No description provided for @chapterKeyPageCount.
  ///
  /// In en, this message translates to:
  /// **'{key} · {count} page(s)'**
  String chapterKeyPageCount(String key, int count);

  /// No description provided for @pageListTitle.
  ///
  /// In en, this message translates to:
  /// **'p.{n} · {title}'**
  String pageListTitle(int n, String title);

  /// No description provided for @pageTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Page {n}'**
  String pageTitleFallback(int n);

  /// No description provided for @cancelEdit.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelEdit;

  /// No description provided for @tagSlugsCreateOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Tag slugs (create only)'**
  String get tagSlugsCreateOnlyLabel;

  /// No description provided for @catalogVisibilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Catalog visibility'**
  String get catalogVisibilityLabel;

  /// No description provided for @pageNumberFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Page number'**
  String get pageNumberFieldLabel;

  /// No description provided for @pageTitleFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Page title'**
  String get pageTitleFieldLabel;

  /// No description provided for @pageContentHeading.
  ///
  /// In en, this message translates to:
  /// **'Page content'**
  String get pageContentHeading;

  /// No description provided for @pageEditorPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Write this page…'**
  String get pageEditorPlaceholder;

  /// No description provided for @pageEditorFormattingToggle.
  ///
  /// In en, this message translates to:
  /// **'Formatting'**
  String get pageEditorFormattingToggle;

  /// No description provided for @pageEditorFormattingHide.
  ///
  /// In en, this message translates to:
  /// **'Hide tools'**
  String get pageEditorFormattingHide;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['am', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
