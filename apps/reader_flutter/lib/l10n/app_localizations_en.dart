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
  String get navBrowse => 'Browse';

  @override
  String get navAccount => 'Profile';

  @override
  String get navProfile => 'Profile';

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
  String get readerPageCurlOn => 'Turn page curl on';

  @override
  String get readerPageCurlOff => 'Turn page curl off';

  @override
  String get readerPageCurlHint =>
      'Drag up-left from the bottom-right corner to curl the page';

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
  String get newBookTooltip => 'New book';

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
}
