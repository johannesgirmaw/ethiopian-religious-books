// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Ethiopian Reader';

  @override
  String get splashTagline => 'Sacred texts, timeless wisdom';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get clear => 'Clear';

  @override
  String get search => 'Search';

  @override
  String get goBack => 'Go back';

  @override
  String get generalCategory => 'General';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get registrationFailed => 'Registration failed';

  @override
  String get cachedJustNow => 'just now';

  @override
  String cachedMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String cachedHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String cachedDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String catalogSynced(String when) {
    return 'Catalog synced $when';
  }

  @override
  String showingLibrarySynced(String when) {
    return 'Showing library synced $when';
  }

  @override
  String get navHome => 'Home';

  @override
  String get navLibrary => 'Library';

  @override
  String get navSettings => 'Settings';

  @override
  String get navBrowse => 'Browse';

  @override
  String get navAccount => 'Profile';

  @override
  String get navProfile => 'Profile';

  @override
  String get navPurchases => 'Purchases';

  @override
  String get drawerHome => 'Home';

  @override
  String get drawerBrowse => 'Browse books';

  @override
  String get drawerAccount => 'Account';

  @override
  String get drawerProfile => 'Profile';

  @override
  String get drawerSettings => 'Settings';

  @override
  String get drawerAbout => 'About';

  @override
  String get drawerContinueReading => 'Continue reading';

  @override
  String get profileTitle => 'Profile';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsCacheSection => 'Storage & cache';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutAppSectionTitle => 'About this app';

  @override
  String get aboutAppSectionBody =>
      'Ethiopian Reader helps you browse, read, and study religious texts with offline support and reading progress.';

  @override
  String get aboutVersionSectionTitle => 'Version';

  @override
  String get aboutVersionValue => '1.0.0';

  @override
  String get aboutDevelopersSectionTitle => 'Developers';

  @override
  String get aboutDevelopersBody => 'Ethiopian Religious Books project';

  @override
  String get homeQuickProfile => 'Your profile';

  @override
  String get homeQuickProfileSubtitle => 'Account and sign in';

  @override
  String get homeQuickSettings => 'Settings';

  @override
  String get homeQuickSettingsSubtitle =>
      'Language, offline cache, and reminders';

  @override
  String get actionRead => 'Read';

  @override
  String get actionInfo => 'Info';

  @override
  String get continueReading => 'Continue reading';

  @override
  String get resumeReading => 'Resume';

  @override
  String get readNow => 'Read now';

  @override
  String get recentlyOpened => 'Recently opened';

  @override
  String get homeQuickBrowse => 'Browse all books';

  @override
  String get homeQuickBrowseSubtitle => 'Search and filter the full catalog';

  @override
  String get homeQuickDownloads => 'Downloads';

  @override
  String get homeQuickDownloadsSubtitle => 'Books saved for offline reading';

  @override
  String get downloadsPageTitle => 'Downloads';

  @override
  String get downloadsEmptyTitle => 'Nothing downloaded yet';

  @override
  String get downloadsEmptyMessage =>
      'Save books for offline reading from a book\'s detail page or while reading.';

  @override
  String get downloadsSavedSection => 'Saved on this device';

  @override
  String get downloadsActiveSection => 'Downloading';

  @override
  String get downloadsFailedSection => 'Failed downloads';

  @override
  String get downloadsNoSavedYet =>
      'No books saved offline yet. Open a book and use Save offline.';

  @override
  String get unableToLoadDownloads => 'Unable to load downloads';

  @override
  String get savedOfflineBadge => 'Available offline';

  @override
  String get downloadInProgress => 'Download in progress…';

  @override
  String get downloadFailedGeneric => 'Download failed';

  @override
  String get downloadErrorStorageUnreachable =>
      'Could not reach the file server. Make sure Docker is running (MinIO on port 19000) and this device can reach your development machine on the same network.';

  @override
  String get downloadErrorConnection =>
      'Could not connect to download the book. Check your connection and try again.';

  @override
  String get downloadErrorTimeout =>
      'Download timed out. Try again when you have a stable connection.';

  @override
  String get downloadErrorGeneric => 'Download failed. Please try again.';

  @override
  String get downloadsSyncCache => 'Sync from server';

  @override
  String get downloadsClearBookCache => 'Remove offline copy';

  @override
  String get downloadsClearAllCache => 'Clear all offline copies';

  @override
  String get downloadsSyncDone => 'Offline copy updated';

  @override
  String downloadsClearBookTitle(String title) {
    return 'Remove \"$title\"?';
  }

  @override
  String get downloadsClearBookBody =>
      'This removes saved chapters and pages for this book on this device only.';

  @override
  String get downloadsCacheInvalid => 'No readable content — sync or remove';

  @override
  String get downloadsNotInCatalogHint =>
      'This book is not in the public catalog; details are from your offline copy only.';

  @override
  String get homeQuickAccount => 'Account & sync';

  @override
  String get homeQuickAccountSubtitle => 'Profile, plans, and preferences';

  @override
  String get browseByCategory => 'Browse by category';

  @override
  String booksInCategory(int count) {
    return '$count books';
  }

  @override
  String get readFullBook => 'Read full book';

  @override
  String headerCategoriesStat(int count) {
    return '$count categories';
  }

  @override
  String headerBooksStat(int count) {
    return '$count books';
  }

  @override
  String get mostReadSection => 'Recently opened';

  @override
  String get searchTooltip => 'Search';

  @override
  String get homeNoBooksTitle => 'No published books yet';

  @override
  String get homeNoBooksMessage =>
      'New titles will appear here as soon as they are available.';

  @override
  String get openLibrary => 'Open Library';

  @override
  String get exploreWisdomTitle => 'Explore wisdom and history';

  @override
  String get exploreWisdomBody =>
      'Browse curated religious texts in a clean editorial layout with fast access to reading.';

  @override
  String get searchLibrary => 'Search Library';

  @override
  String get browseCollections => 'Browse Collections';

  @override
  String get featuredBooks => 'Featured Books';

  @override
  String curatedSelections(int count) {
    return '$count curated selections';
  }

  @override
  String get librarySections => 'Library Sections';

  @override
  String get viewAll => 'View all';

  @override
  String get unableToLoadHome => 'Unable to load home';

  @override
  String get noSummaryYet => 'No summary available yet.';

  @override
  String get readDetails => 'Read details';

  @override
  String get unknownAuthor => 'Unknown author';

  @override
  String get openArticle => 'Open article';

  @override
  String get libraryTitle => 'Library';

  @override
  String get filterTooltip => 'Filter';

  @override
  String get filterByLanguage => 'Filter by language';

  @override
  String get allLanguages => 'All languages';

  @override
  String get chapterKeyLabel => 'Chapter key';

  @override
  String get chapterKeyHint => 'Optional server filter';

  @override
  String get pageNumberLabel => 'Page number';

  @override
  String get pageNumberHint => 'Optional server filter';

  @override
  String get applyFilters => 'Apply filters';

  @override
  String get libraryEmptyTitle => 'Library is empty';

  @override
  String get libraryEmptyMessage =>
      'No published books are available right now.';

  @override
  String get librarySearchHint => 'Search by title, author, or summary';

  @override
  String get clearSearchTooltip => 'Clear search';

  @override
  String booksAvailable(int count) {
    return '$count book(s) available';
  }

  @override
  String catalogChapterCount(int count) {
    return '$count chapters';
  }

  @override
  String readingProgressPercent(int percent) {
    return '$percent%';
  }

  @override
  String get catalogLanguageAmharic => 'Amharic';

  @override
  String get catalogLanguageGeez => 'Geez';

  @override
  String get catalogLanguageEnglish => 'English';

  @override
  String get clearFilter => 'Clear filter';

  @override
  String languageChip(String lang) {
    return 'Language: $lang';
  }

  @override
  String chapterChip(String ch) {
    return 'Chapter: $ch';
  }

  @override
  String pageChip(int page) {
    return 'Page: $page';
  }

  @override
  String get noMatchingBooksTitle => 'No matching books';

  @override
  String get noMatchingBooksMessage =>
      'Try a different keyword or clear filters.';

  @override
  String get unableToLoadLibrary => 'Unable to load library';

  @override
  String revisionLabel(int n) {
    return 'Revision $n';
  }

  @override
  String get open => 'Open';

  @override
  String get accountTitle => 'Account';

  @override
  String get readerAccount => 'Reader Account';

  @override
  String get noEmail => 'No email';

  @override
  String get adminRoleBadge => 'ADMIN';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get inProgressDownloads => 'In progress';

  @override
  String get failedDownloads => 'Failed downloads';

  @override
  String get availableBooks => 'Available books';

  @override
  String get languagesMetric => 'Languages';

  @override
  String get offlineChapterCache => 'Offline chapter cache';

  @override
  String offlineBooksSaved(int count) {
    return '$count book(s) saved offline';
  }

  @override
  String get checkingCache => 'Checking cache...';

  @override
  String get cacheUnavailable => 'Cache unavailable';

  @override
  String get clearOfflineCacheTitle => 'Clear offline cache?';

  @override
  String get clearOfflineCacheBody =>
      'This removes downloaded chapter/page content from this device.';

  @override
  String get offlineCacheCleared => 'Offline cache cleared';

  @override
  String get studyAndReminders => 'Study & reminders';

  @override
  String get dailyReadingReminders => 'Daily reading reminders';

  @override
  String reminderTimeUtc(String hh, String mm, String weekdays) {
    return 'UTC $hh:$mm$weekdays';
  }

  @override
  String get weekdaysOnlySuffix => ' · weekdays only';

  @override
  String get reminderUpdateFailed =>
      'Reminder settings could not be updated. Please run backend migrations and try again.';

  @override
  String get loadingReminderSettings => 'Loading reminder settings...';

  @override
  String get reminderSettingsUnavailable => 'Reminder settings unavailable';

  @override
  String get dailyReadingPlans => 'Daily reading plans';

  @override
  String get noReadingPlansYet => 'No reading plans yet';

  @override
  String readingPlansConfigured(int count) {
    return '$count plan(s) configured';
  }

  @override
  String get tapOpenTodaysReading => ' · tap to open today\'s reading';

  @override
  String get createPlanTooltip => 'Create plan';

  @override
  String get dailyPlanCreateFailed =>
      'Daily plan could not be created. Please run backend migrations and try again.';

  @override
  String get accountInfo => 'Account Info';

  @override
  String get profileAccountDetails => 'Account details';

  @override
  String get profileUserIdLabel => 'User ID';

  @override
  String get profileUserIdCopied => 'User ID copied';

  @override
  String get profileRoleLabel => 'Role';

  @override
  String get profilePreferredLanguageLabel => 'Preferred language';

  @override
  String get profileSuperuserLabel => 'Administrator access';

  @override
  String get profileValueNotSet => 'Not set';

  @override
  String get profileYes => 'Yes';

  @override
  String get profileNo => 'No';

  @override
  String get profileOpenSettings => 'Settings';

  @override
  String get emailLabel => 'Email';

  @override
  String get displayNameLabel => 'Display name';

  @override
  String get adminPanel => 'Admin panel';

  @override
  String get adminPanelSubtitle => 'Manage books, visibility, and publishing';

  @override
  String get adminManageBooksSubtitle =>
      'Create, import, and publish your books';

  @override
  String get noProfileCached => 'No profile cached.';

  @override
  String get signOut => 'Sign out';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get signInSubtitle =>
      'Sign in to continue reading and keep your progress synced.';

  @override
  String get emailFieldLabel => 'Email';

  @override
  String get emailFieldHint => 'you@example.com';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get emailInvalid => 'Enter a valid email';

  @override
  String get passwordFieldLabel => 'Password';

  @override
  String get passwordMinHelper => 'Minimum 10 characters';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get signIn => 'Sign in';

  @override
  String get createAccount => 'Create an account';

  @override
  String get createAccountTitle => 'Create account';

  @override
  String get registerSubtitle =>
      'Create your profile to save progress, bookmarks, and downloads.';

  @override
  String get passwordMinRegisterHelper => 'Use at least 10 characters';

  @override
  String get passwordTooShort => 'Password must be at least 10 characters';

  @override
  String get displayNameOptional => 'Display name (optional)';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get forgotPasswordTitle => 'Reset password';

  @override
  String get forgotPasswordSubtitle =>
      'Enter your email and we\'ll send you a 6-digit code to reset your password.';

  @override
  String get sendResetCode => 'Send reset code';

  @override
  String get resetPasswordTitle => 'Set a new password';

  @override
  String resetPasswordSubtitle(String email) {
    return 'Enter the code we sent to $email and choose a new password.';
  }

  @override
  String get resetCodeFieldLabel => '6-digit code';

  @override
  String get resetCodeRequired => 'Enter the 6-digit code';

  @override
  String get resetCodeInvalid => 'The code must be 6 digits';

  @override
  String get newPasswordFieldLabel => 'New password';

  @override
  String get confirmPasswordFieldLabel => 'Confirm new password';

  @override
  String get confirmPasswordRequired => 'Confirm your new password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get resetPasswordCta => 'Reset password';

  @override
  String get passwordResetSuccess =>
      'Your password has been reset. Please sign in.';

  @override
  String get resetPasswordFailed =>
      'Could not reset your password. Check the code and try again.';

  @override
  String get resendCode => 'Resend code';

  @override
  String resendCodeIn(int seconds) {
    return 'Resend code in ${seconds}s';
  }

  @override
  String get resetCodeResent => 'A new code is on its way.';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get changePasswordSubtitle =>
      'Choose a new password for your account.';

  @override
  String get currentPasswordFieldLabel => 'Current password';

  @override
  String get currentPasswordRequired => 'Enter your current password';

  @override
  String get changePasswordCta => 'Update password';

  @override
  String get passwordChangedSuccess => 'Your password has been updated.';

  @override
  String get changePasswordFailed => 'Could not update your password.';

  @override
  String get profileSecuritySection => 'Security';

  @override
  String get changePasswordLinkSubtitle => 'Update your account password';

  @override
  String get languagePreferenceTitle => 'Language';

  @override
  String get languagePreferenceSubtitle =>
      'Choose English or Amharic for app menus and buttons.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageAmharic => 'አማርኛ (Amharic)';

  @override
  String get saveLanguage => 'Save language';

  @override
  String get languageSaved => 'Language saved';

  @override
  String get bookDetailsTitle => 'Book Details';

  @override
  String get bookStatChapters => 'Chapters';

  @override
  String get bookStatPages => 'Pages';

  @override
  String get bookStatReaders => 'Readers';

  @override
  String get shareBookTooltip => 'Share book';

  @override
  String get bookSharedToClipboard => 'Book link copied';

  @override
  String get preparingDownload => 'Preparing download…';

  @override
  String savedUnderPath(String path) {
    return 'Saved under $path';
  }

  @override
  String downloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get summarySection => 'Summary';

  @override
  String get readyToRead => 'Ready to read';

  @override
  String downloadState(String state) {
    return 'Download: $state';
  }

  @override
  String get startReading => 'Start Reading';

  @override
  String get downloadOffline => 'Download for offline reading';

  @override
  String get unableToLoadBook => 'Unable to load this book';

  @override
  String get bookLoadErrorMessage =>
      'The book could not be opened right now. Please try again.';

  @override
  String get bookNotInCatalogTitle => 'Book not available in reader catalog';

  @override
  String get bookNotInCatalogMessage =>
      'This book is likely unpublished or hidden. Publish it from admin and try again.';

  @override
  String get readerTitle => 'Reader';

  @override
  String bookmarkSavedAt(int pct) {
    return 'Saved at $pct%';
  }

  @override
  String get bookmarkRemoved => 'Bookmark removed';

  @override
  String get bookmarkSaved => 'Bookmark saved';

  @override
  String get noBookmarksYet =>
      'No bookmarks yet. Tap bookmark in reader controls.';

  @override
  String get savedLocation => 'Saved location';

  @override
  String get removeTooltip => 'Remove';

  @override
  String get selectChapter => 'Select chapter';

  @override
  String get selectPage => 'Select page';

  @override
  String get readerPosition => 'Reader position';

  @override
  String get readingPosition => 'Reading position';

  @override
  String pageCount(int count) {
    return '$count page(s)';
  }

  @override
  String pageNumberTitle(int n) {
    return 'Page $n';
  }

  @override
  String get choosePage => 'Choose page';

  @override
  String get jumpToPageSubtitle => 'Jump directly to a page';

  @override
  String get allChapters => 'All chapters';

  @override
  String get searchPagesWholeBook => 'Search pages across the whole book';

  @override
  String get noChapterSelected => 'No chapter selected';

  @override
  String get cloudBookmarkSaved => 'Cloud bookmark saved';

  @override
  String get quickNoteLabel => 'Quick note';

  @override
  String get quickNoteHint => 'Write your reflection or summary';

  @override
  String get saveNote => 'Save note';

  @override
  String get noteSaved => 'Note saved';

  @override
  String highlightSavedOnPage(int n) {
    return 'Highlight saved on page $n';
  }

  @override
  String get highlightsUnavailable => 'Highlights are currently unavailable';

  @override
  String get noHighlightsYet =>
      'No highlights yet. Tap the highlighter icon to save one.';

  @override
  String get highlightDefaultTitle => 'Highlight';

  @override
  String highlightChapterPage(String ch, String page) {
    return 'Chapter $ch · Page $page';
  }

  @override
  String get offlineCopyRemoved => 'Offline copy removed';

  @override
  String get savedOfflineReading => 'Saved for offline reading';

  @override
  String get findInBookLabel => 'Find in book';

  @override
  String get findInBookHint => 'Type a word or phrase';

  @override
  String get searchOutsideChapter => 'Search outside the selected chapter';

  @override
  String get noMatchesYet => 'No matches yet.';

  @override
  String matchCount(int count) {
    return '$count match(es)';
  }

  @override
  String get previousMatch => 'Previous match';

  @override
  String get nextMatch => 'Next match';

  @override
  String get typographyCompact => 'Compact';

  @override
  String get typographyComfort => 'Comfort';

  @override
  String get typographyLarge => 'Large';

  @override
  String get typographyPresetsTitle => 'Typography presets';

  @override
  String get typographyPresetsSubtitle =>
      'Choose the most comfortable reading mode';

  @override
  String typographySizeLine(int size, String line) {
    return 'Size $size • Line $line';
  }

  @override
  String get chaptersHeading => 'Chapters';

  @override
  String get noChapterContentYet =>
      'This book has no chapter/page content yet. Add chapters and pages in Admin, then publish.';

  @override
  String chapterChipRaw(String label) {
    return 'Chapter: $label';
  }

  @override
  String pageChipShort(int n) {
    return 'Page: $n';
  }

  @override
  String get backToChaptersTooltip => 'Back to chapters';

  @override
  String get filterChapterTooltip => 'Filter chapter';

  @override
  String get filterPageTooltip => 'Filter page';

  @override
  String get removeOfflineCopy => 'Remove offline copy';

  @override
  String get saveChaptersOffline => 'Save chapters offline';

  @override
  String get backToChapters => 'Back to chapters';

  @override
  String get noChapterSelectedShort => 'No chapter selected';

  @override
  String get typographyPresetsTooltip => 'Typography presets';

  @override
  String get saveCloudBookmarkTooltip => 'Save cloud bookmark';

  @override
  String get addNoteTooltip => 'Add note';

  @override
  String get addHighlightTooltip => 'Add highlight';

  @override
  String get highlightsTooltip => 'Highlights';

  @override
  String get pinControls => 'Pin controls';

  @override
  String get autoHideControls => 'Auto-hide controls';

  @override
  String get readerExpandTools => 'Show reading tools';

  @override
  String get readerCollapseTools => 'Hide reading tools';

  @override
  String get readerPageCurlOn => 'Switch to page view';

  @override
  String get readerPageCurlOff => 'Switch to scroll view';

  @override
  String get readerPageCurlHint =>
      'Use the arrows on the sides to change pages.';

  @override
  String matchOnPage(int page, String snippet) {
    return 'Match on page $page: $snippet';
  }

  @override
  String get readerChapterLabel => 'CHAPTER';

  @override
  String get readerPageLabel => 'PAGE';

  @override
  String get adminHomeTitle => 'Admin';

  @override
  String get publisherTools => 'Publisher tools';

  @override
  String get publisherToolsBody =>
      'Manage catalog visibility, book metadata, and publishing. Uploading revision packages still uses presigned URLs from the API (use a desktop workflow or future in-app upload).';

  @override
  String get adminBooksMenuTitle => 'Books';

  @override
  String get adminBooksMenuSubtitle =>
      'List, create, edit, publish / unpublish';

  @override
  String get adminBooksListTitle => 'Manage books';

  @override
  String adminBooksCount(int shown, int total) {
    return '$shown of $total books';
  }

  @override
  String get adminEditAction => 'Edit';

  @override
  String get adminBookActionsTooltip => 'Book actions';

  @override
  String get adminPublishedBookLockedTitle => 'Published book';

  @override
  String get adminPublishedBookLockedMessage =>
      'Unpublish this book before editing its metadata or draft content.';

  @override
  String get adminNotBookCreatorTitle => 'Editing restricted';

  @override
  String get adminNotBookCreatorMessage =>
      'Only the user who created this book can edit it.';

  @override
  String get newBookTooltip => 'New book';

  @override
  String get importFromWord => 'Import Word (.docx)';

  @override
  String get importDocxInProgress => 'Importing document…';

  @override
  String get importDocxSuccess =>
      'Imported. Review the chapters, then publish.';

  @override
  String get importDocxFailed => 'Could not import the document.';

  @override
  String get importScanning => 'Scanning document…';

  @override
  String get importLegacyDocTitle => 'Save as .docx';

  @override
  String get importLegacyDocMessage =>
      'This is an older .doc file. Open it in Word and use Save As → Word Document (.docx), then try again.';

  @override
  String get importChooseStructure => 'How should chapters be detected?';

  @override
  String get importModeAuto => 'Automatic';

  @override
  String get importModeHeading => 'Heading styles';

  @override
  String get importModePatterns => 'Chapter text (e.g. ምዕራፍ 1)';

  @override
  String get importModeFormat => 'Bold / centered titles';

  @override
  String get importModePagebreak => 'Page breaks';

  @override
  String get importModeMarker => 'Marker lines (### / <<<CHAPTER>>>)';

  @override
  String get importModeSize => 'Single chapter (by size)';

  @override
  String importDetectedCounts(int chapters, int pages) {
    return '$chapters chapters · $pages pages';
  }

  @override
  String get importRecommendedBadge => 'Recommended';

  @override
  String get importCustomPatternLabel => 'Custom pattern (regex)';

  @override
  String get importCustomMarkerLabel => 'Custom marker';

  @override
  String get importRescan => 'Re-scan';

  @override
  String get importDetectedChaptersTitle => 'Detected chapters';

  @override
  String get importNoChapters => 'No chapters detected for this option.';

  @override
  String importMoreTitles(int count) {
    return '+$count more';
  }

  @override
  String get importAction => 'Import';

  @override
  String get ok => 'OK';

  @override
  String get noBooksYetTitle => 'No books yet';

  @override
  String get noBooksYetMessage =>
      'Create your first book to start publishing to readers.';

  @override
  String get createFirstBook => 'Create';

  @override
  String get searchBooksLabel => 'Search books';

  @override
  String get searchBooksHint => 'Title, author, language';

  @override
  String get filterAll => 'All';

  @override
  String get filterPublished => 'Published';

  @override
  String get filterHidden => 'Hidden';

  @override
  String get sortRecent => 'Sort: recent';

  @override
  String get sortTitle => 'Sort: title';

  @override
  String get noBooksMatchFilters => 'No books match these filters.';

  @override
  String get unableToLoadBooks => 'Unable to load books';

  @override
  String visibilityLabel(String vis) {
    return 'Visibility: $vis';
  }

  @override
  String statusLabel(String status) {
    return 'Status: $status';
  }

  @override
  String get publishedStatus => 'Published';

  @override
  String get draftStatus => 'Draft';

  @override
  String statusChip(String status, String vis) {
    return '$status · $vis';
  }

  @override
  String get bookNotFound => 'Book not found.';

  @override
  String get unpublishFailed => 'Unpublish failed';

  @override
  String get publishLatestDraftTitle => 'Publish latest draft';

  @override
  String get publishLatestDraftBody =>
      'This publishes the latest draft revision for this book. If no draft exists, the backend will generate one from current metadata.';

  @override
  String get publish => 'Publish';

  @override
  String publishedRevisionNumber(int n) {
    return 'Published revision #$n';
  }

  @override
  String get publishedLatestRevision => 'Published latest revision';

  @override
  String get publishFailed => 'Publish failed';

  @override
  String get bookFallbackTitle => 'Book';

  @override
  String get editMetadataTooltip => 'Edit metadata';

  @override
  String get publishedVisibleBanner => 'Published and visible in reader';

  @override
  String get draftOnlyBanner => 'Draft only - not visible in reader';

  @override
  String get visibilityTile => 'Visibility';

  @override
  String get authorCompilerTile => 'Author / compiler';

  @override
  String get languageTile => 'Language';

  @override
  String get draftChaptersPagesTile => 'Draft chapters/pages';

  @override
  String get noDraftChapters => 'No draft chapters';

  @override
  String draftChapterPageCounts(int chapters, int pages) {
    return '$chapters chapter(s), $pages page(s)';
  }

  @override
  String get publishedRevisionTile => 'Published revision';

  @override
  String get openInReader => 'Open in reader';

  @override
  String get publishFirstToOpenReader =>
      'Publish this book first to open it in reader mode.';

  @override
  String get publishRevision => 'Publish revision';

  @override
  String get unpublish => 'Unpublish';

  @override
  String get summaryLabel => 'Summary';

  @override
  String get createBookFirstValidate =>
      'Create the book first, then run draft validation.';

  @override
  String get draftValidationTitle => 'Draft validation';

  @override
  String get warningsHeading => 'Warnings:';

  @override
  String get discardUnsavedTitle => 'Discard unsaved changes?';

  @override
  String get discardUnsavedBody =>
      'You have unsaved edits. If you leave now, those changes will be lost.';

  @override
  String get discardUnsavedBodyEditor =>
      'You have unsaved updates in this editor. Leave without saving?';

  @override
  String get formDraftRestored =>
      'Draft restored — continue where you left off.';

  @override
  String get formDraftSaved => 'Draft saved. You can continue later.';

  @override
  String get formDraftDiscardTitle => 'Discard saved draft?';

  @override
  String get formDraftDiscardBody =>
      'This permanently deletes your locally saved draft for this form.';

  @override
  String get formDraftDiscardAction => 'Discard draft';

  @override
  String get formDraftLeaveAndSave => 'Save draft & leave';

  @override
  String get stay => 'Stay';

  @override
  String get discard => 'Discard';

  @override
  String get chooseImage => 'Choose image';

  @override
  String get removeCover => 'Remove cover';

  @override
  String get validateDraft => 'Validate draft';

  @override
  String get addChapter => 'Add chapter';

  @override
  String get noPagesYet => 'No pages yet';

  @override
  String get moveUpTooltip => 'Move up';

  @override
  String get moveDownTooltip => 'Move down';

  @override
  String get addPageTooltip => 'Add page';

  @override
  String get editChapterTooltip => 'Edit chapter';

  @override
  String get deleteChapterTooltip => 'Delete chapter';

  @override
  String get editPageTooltip => 'Edit page';

  @override
  String get deletePageTooltip => 'Delete page';

  @override
  String get addChapterTitle => 'Add chapter';

  @override
  String get editChapterTitle => 'Edit chapter';

  @override
  String get chapterKeyHintExample => 'e.g. chapter-1';

  @override
  String get untitledChapter => 'Untitled chapter';

  @override
  String get unsupportedEmbeddedContent => 'Unsupported embedded content';

  @override
  String get editPageTitle => 'Edit page';

  @override
  String get tagSlugsHint => 'Comma-separated, e.g. liturgy, bible';

  @override
  String get visibilityHidden => 'hidden';

  @override
  String get visibilityPublished => 'published';

  @override
  String get create => 'Create';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get commaSeparated => 'Comma-separated';

  @override
  String get chapterTitleLabel => 'Chapter title';

  @override
  String get chapterKeyFieldLabel => 'Chapter key';

  @override
  String get eachChapterNeedsKey => 'Each chapter must have a chapter key.';

  @override
  String duplicateChapterKey(String key) {
    return 'Duplicate chapter key found: $key';
  }

  @override
  String pageNumberMustBePositive(String title) {
    return 'Page number must be greater than 0 in chapter $title.';
  }

  @override
  String duplicatePageNumber(int n, String title) {
    return 'Duplicate page number $n in chapter $title.';
  }

  @override
  String draftValidationNoWarnings(int chapters, int pages, int empty) {
    return 'No warnings.\n\nChapters: $chapters\nPages: $pages\nEmpty pages: $empty';
  }

  @override
  String draftValidationStatsLine(int chapters, int pages, int empty) {
    return 'Chapters: $chapters · Pages: $pages · Empty pages: $empty';
  }

  @override
  String get validationFailed => 'Validation failed';

  @override
  String get saveFailed => 'Save failed';

  @override
  String get newBookAppBar => 'New book';

  @override
  String get editBookAppBar => 'Edit book';

  @override
  String get metadataSection => 'Metadata';

  @override
  String get titleLabelRequired => 'Title *';

  @override
  String get titleRequired => 'Title is required';

  @override
  String get subtitleLabel => 'Subtitle';

  @override
  String get thumbnailCover => 'Thumbnail / cover';

  @override
  String get coverFormatHelp =>
      'JPEG, PNG, or WebP. Uploads after you save the book.';

  @override
  String get authorCompilerLabel => 'Author / compiler';

  @override
  String get primaryLanguageCodeLabel => 'Primary language code';

  @override
  String get languageCodeRequired => 'Language code is required';

  @override
  String get scriptTagsLabel => 'Script tags';

  @override
  String get chaptersPagesSection => 'Chapters & pages';

  @override
  String get noChaptersYetHelp =>
      'No chapters yet. Add chapters and pages for reader navigation.';

  @override
  String chapterKeyPageCount(String key, int count) {
    return '$key · $count page(s)';
  }

  @override
  String pageListTitle(int n, String title) {
    return 'p.$n · $title';
  }

  @override
  String pageTitleFallback(int n) {
    return 'Page $n';
  }

  @override
  String get cancelEdit => 'Cancel';

  @override
  String get tagSlugsCreateOnlyLabel => 'Tag slugs (create only)';

  @override
  String get catalogVisibilityLabel => 'Catalog visibility';

  @override
  String get pageNumberFieldLabel => 'Page number';

  @override
  String get pageTitleFieldLabel => 'Page title';

  @override
  String get pageContentHeading => 'Page content';

  @override
  String get pageEditorPlaceholder => 'Write this page…';

  @override
  String get pageEditorFormattingToggle => 'Formatting';

  @override
  String get pageEditorFormattingHide => 'Hide tools';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get libraryViewList => 'List';

  @override
  String get libraryViewGrid => 'Grid';

  @override
  String get homePopularBadge => 'Popular';

  @override
  String get homeReadMore => 'Read more';

  @override
  String get homeAllGenre => 'All Genre';

  @override
  String get homeSectionExplore => 'Explore books';

  @override
  String get homeSearchHint => 'Search books…';

  @override
  String get catalogAllResults => 'All Results';

  @override
  String get bookCategoryPsalms => 'Psalms & Mezmur';

  @override
  String get bookCategoryMarian => 'Marian';

  @override
  String get bookCategoryLiturgy => 'Liturgy';

  @override
  String get bookCategorySynaxarium => 'Synaxarium';

  @override
  String get bookCategorySaints => 'Saints & Gedl';

  @override
  String get bookCategoryOther => 'General';

  @override
  String get favouritesTitle => 'Favourites';

  @override
  String get favouritesEmptyTitle => 'No favourites yet';

  @override
  String get favouritesEmptyMessage =>
      'Tap the heart on any book to save it here.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmptyTitle => 'You\'re all caught up';

  @override
  String get notificationsEmptyMessage =>
      'Notifications about new books and reminders show up here.';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get reviewsSection => 'Reviews';

  @override
  String get reviewsEmpty =>
      'No reviews yet — be the first to review this book.';

  @override
  String get writeReviewTitle => 'Write a review';

  @override
  String get yourRatingLabel => 'Your rating';

  @override
  String get reviewBodyHint => 'Share your thoughts (optional)';

  @override
  String get submitReviewAction => 'Submit review';

  @override
  String ratingsCountLabel(int count) {
    return '$count ratings';
  }

  @override
  String get homeRecommended => 'Recommended';

  @override
  String get sortLabel => 'Sort';

  @override
  String get sortNewest => 'Newest';

  @override
  String get sortOldest => 'Oldest';

  @override
  String get sortPopular => 'Popular';

  @override
  String get sortTopRated => 'Top rated';

  @override
  String get sortTitleAz => 'Title (A–Z)';

  @override
  String get premiumLockedTitle => 'Premium book';

  @override
  String get premiumLockedMessage =>
      'This title is part of premium. Premium access isn\'t available yet — check back soon.';

  @override
  String get premiumGotIt => 'Got it';

  @override
  String get adminSummaryLabel => 'Summary';

  @override
  String get adminGenreLabel => 'Genre / category';

  @override
  String get adminGenreNone => 'None';

  @override
  String get adminPublishedYearLabel => 'Publication year';

  @override
  String get adminIsPremiumLabel => 'Premium book';

  @override
  String get adminIsPremiumSubtitle => 'Requires premium access to read';

  @override
  String get tagsLabel => 'Tags';

  @override
  String get adminChipAddHint => 'Add and press Enter';

  @override
  String get adminIsFeaturedLabel => 'Featured (Popular)';

  @override
  String get adminIsFeaturedSubtitle =>
      'Show in the Popular banner on the home screen';

  @override
  String get readerDisplayTitle => 'Display';

  @override
  String get readerThemeLabel => 'Theme';

  @override
  String get readerThemeLight => 'Light';

  @override
  String get readerThemeSepia => 'Sepia';

  @override
  String get readerThemeDark => 'Dark';

  @override
  String get readerTextSizeLabel => 'Text size';

  @override
  String get readerSpacingLabel => 'Line spacing';

  @override
  String get readerModeLabel => 'Reading mode';

  @override
  String get readerModeScroll => 'Scroll';

  @override
  String get readerModePage => 'Pages';

  @override
  String get readerToolsTitle => 'Reading tools';

  @override
  String get readerMoreTooltip => 'Reading tools';

  @override
  String get paymentTitle => 'Payment';

  @override
  String get paymentChooseMethod => 'Choose a payment method';

  @override
  String get paymentMethodStripe => 'Credit / debit card';

  @override
  String get paymentMethodPaypal => 'PayPal';

  @override
  String get paymentMethodTelebirr => 'Telebirr';

  @override
  String get paymentMethodBank => 'Bank transfer';

  @override
  String get paymentOrderSummary => 'Order summary';

  @override
  String get paymentPrice => 'Price';

  @override
  String get paymentSalePrice => 'Sale price';

  @override
  String get paymentTotal => 'Total';

  @override
  String get paymentContinue => 'Continue';

  @override
  String get paymentSelectBank => 'Select bank';

  @override
  String get paymentBankDetails => 'Bank details';

  @override
  String get paymentAccountName => 'Account name';

  @override
  String get paymentAccountNumber => 'Account number';

  @override
  String get paymentUploadReceipt => 'Upload receipt';

  @override
  String get paymentReceiptHint =>
      'Drag & drop or tap to upload — JPG, PNG or PDF (max 10MB)';

  @override
  String paymentReceiptSelected(String name) {
    return 'Selected: $name';
  }

  @override
  String get paymentChangeFile => 'Change file';

  @override
  String get paymentTransactionReference => 'Transaction reference';

  @override
  String get paymentTransactionReferenceHint =>
      'Enter the bank transaction reference';

  @override
  String get paymentSubmit => 'Submit payment';

  @override
  String get paymentSubmitting => 'Submitting…';

  @override
  String paymentPayNow(String amount) {
    return 'Pay $amount';
  }

  @override
  String get paymentSuccessTitle => 'Payment submitted';

  @override
  String get paymentSuccessMessage =>
      'Your payment is pending verification. We\'ll notify you once it\'s approved.';

  @override
  String paymentSuccessReference(String reference) {
    return 'Reference: $reference';
  }

  @override
  String get paymentDone => 'Done';

  @override
  String get paymentCopy => 'Copy';

  @override
  String get paymentCopied => 'Copied to clipboard';

  @override
  String get paymentErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get paymentGatewayUnavailable =>
      'This payment method isn\'t available right now.';

  @override
  String get paymentReceiptRequired => 'Please upload a receipt.';

  @override
  String get paymentReferenceRequired =>
      'Please enter the transaction reference.';

  @override
  String get paymentBankRequired => 'Please select a bank.';

  @override
  String get paymentNoMethods => 'No payment methods are available right now.';

  @override
  String get paymentNoBanks =>
      'No banks are available for bank transfer right now.';

  @override
  String get paymentBuyToRead => 'Buy to read';

  @override
  String get purchaseBook => 'Purchase book';

  @override
  String get paymentMyPurchases => 'Purchases';

  @override
  String get paymentStatusPending => 'Pending';

  @override
  String get paymentStatusOnReview => 'On review';

  @override
  String get paymentStatusApproved => 'Approved';

  @override
  String get paymentStatusCompleted => 'Completed';

  @override
  String get paymentStatusCancelled => 'Cancelled';

  @override
  String get paymentStatusRejected => 'Rejected';

  @override
  String get paymentStepMethod => 'Method';

  @override
  String get paymentStepDetails => 'Details';

  @override
  String get paymentStepDone => 'Done';

  @override
  String get paymentTransferInstruction =>
      'Transfer the total to the account below, then upload your receipt and reference.';

  @override
  String get paymentNoPurchases => 'You haven\'t made any purchases yet.';

  @override
  String get paymentPurchasesSubtitle => 'Track your orders and payment status';

  @override
  String get profileSettingsSubtitle => 'Reading, language and app preferences';

  @override
  String get adminPricingSection => 'Pricing & commission';

  @override
  String get adminCurrencyLabel => 'Currency';

  @override
  String get adminPriceLabel => 'Price';

  @override
  String get adminSalePriceLabel => 'Sale price (optional)';

  @override
  String get adminCommissionPercentLabel => 'Commission %';

  @override
  String get adminCommissionHelp =>
      'Leave blank to use the author or platform default';

  @override
  String get adminPaymentsTitle => 'Orders & payments';

  @override
  String get adminManageOrders => 'Manage orders';

  @override
  String get adminOrdersSubtitle => 'Review, approve and complete payments';

  @override
  String get adminPendingReviews => 'Pending reviews';

  @override
  String get adminCompleted => 'Completed';

  @override
  String get adminGrossRevenue => 'Gross revenue';

  @override
  String get adminPlatformRevenue => 'Platform revenue';

  @override
  String get adminAuthorRevenue => 'Author revenue';

  @override
  String get adminNoOrders => 'No orders to show.';

  @override
  String get adminNoMatchingOrders => 'No orders match your search.';

  @override
  String get adminSearchOrdersHint => 'Search customer, book or reference';

  @override
  String get adminShowingResultsFor => 'Showing results for:';

  @override
  String get adminClearFilters => 'Clear all';

  @override
  String get adminRowsPerPage => 'Rows per page';

  @override
  String get adminActionsTooltip => 'Actions';

  @override
  String get adminCopyReference => 'Copy reference';

  @override
  String get adminApproveConfirm => 'Approve this payment?';

  @override
  String get bibleTitle => 'Bible';

  @override
  String get bibleOldTestament => 'Old Testament';

  @override
  String get bibleNewTestament => 'New Testament';

  @override
  String get bibleChapter => 'Chapter';

  @override
  String get bibleChapters => 'Chapters';

  @override
  String get bibleSearchHint => 'Search verses or a reference (e.g. ማቴ 3:16)';

  @override
  String get bibleNoResults => 'No verses found.';

  @override
  String get bibleReferenceNotFound => 'Couldn\'t resolve that reference.';

  @override
  String get bibleSearchScopeAll => 'All';

  @override
  String get bibleSearch => 'Search the Bible';

  @override
  String get numberSystemTitle => 'Ge\'ez numerals';

  @override
  String get numberSystemSubtitle =>
      'Show chapter and verse numbers in Ge\'ez (፩ ፪ ፫)';

  @override
  String get geezConvertTooltip => 'Convert selected numbers to Ge\'ez (1 → ፩)';

  @override
  String get adminIsBibleLabel => 'Bible book';

  @override
  String get adminIsBibleSubtitle =>
      'Manage chapters, sections and verses instead of pages';

  @override
  String get adminTestamentLabel => 'Testament';

  @override
  String get adminBibleSaveFirst =>
      'Save the book first, then manage its Bible content.';

  @override
  String get adminManageBibleContent => 'Manage Bible content';

  @override
  String get adminBibleContentTitle => 'Bible content';

  @override
  String get adminAddChapter => 'Add chapter';

  @override
  String get adminAddSection => 'Add section';

  @override
  String get adminAddVerse => 'Add verse';

  @override
  String get adminSectionTitle => 'Section title';

  @override
  String get adminVerseNumberLabel => 'No.';

  @override
  String get adminVerseTextLabel => 'Verse text';

  @override
  String adminChapterLabel(int number) {
    return 'Chapter $number';
  }

  @override
  String get adminChapterSaved => 'Chapter saved';

  @override
  String get adminDeleteChapterConfirm => 'Delete this chapter\'s content?';

  @override
  String get adminNoChaptersYet => 'No chapters yet. Add one to begin.';

  @override
  String adminVersesCount(int count) {
    return '$count verses';
  }

  @override
  String get adminSelectChapter =>
      'Select a chapter to edit, or add a new one.';

  @override
  String get adminUnsavedChanges => 'Unsaved changes';

  @override
  String get adminDiscardChangesConfirm => 'Discard unsaved changes?';

  @override
  String get adminDiscard => 'Discard';

  @override
  String get adminDeleteChapter => 'Delete chapter';

  @override
  String adminSectionLabel(int number) {
    return 'Section $number';
  }

  @override
  String bibleResultsCount(int count) {
    return '$count verses';
  }

  @override
  String adminOrdersRange(int start, int end, int total) {
    return '$start–$end of $total';
  }

  @override
  String get adminReview => 'Review';

  @override
  String get adminOrderDetail => 'Order details';

  @override
  String get adminCustomer => 'Customer';

  @override
  String get adminBook => 'Book';

  @override
  String get adminBank => 'Bank';

  @override
  String get adminReceipt => 'Receipt';

  @override
  String get adminNoReceipt => 'No receipt uploaded';

  @override
  String get adminViewReceipt => 'View receipt';

  @override
  String get adminRejectReason => 'Reason (optional)';

  @override
  String get adminApprove => 'Approve & complete';

  @override
  String get adminReject => 'Reject';

  @override
  String get adminApproved => 'Order approved and completed';

  @override
  String get adminRejected => 'Order rejected';

  @override
  String get authorMyBooks => 'My books';

  @override
  String get paymentDate => 'Date';

  @override
  String get paymentMethod => 'Method';

  @override
  String get paymentCommission => 'Platform commission';

  @override
  String get paymentOrderId => 'Order ID';

  @override
  String get adminOrdersAllStatuses => 'All';

  @override
  String get paymentStatusColumn => 'Status';
}
