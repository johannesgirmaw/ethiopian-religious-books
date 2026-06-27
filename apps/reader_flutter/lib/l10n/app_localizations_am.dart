// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get appTitle => 'የኢትዮጵያ አንባቢ';

  @override
  String get splashTagline => 'ቅዱስ መጻሕፍት፣ የማይጠፉ ጥበብ';

  @override
  String get cancel => 'ሰርዝ';

  @override
  String get save => 'አስቀምጥ';

  @override
  String get close => 'ዝጋ';

  @override
  String get retry => 'እንደገና ሞክር';

  @override
  String get clear => 'አጽዳ';

  @override
  String get search => 'ፈልግ';

  @override
  String get goBack => 'ተመለስ';

  @override
  String get generalCategory => 'አጠቃላይ';

  @override
  String get loginFailed => 'መግባት አልተሳካም';

  @override
  String get registrationFailed => 'መመዝገብ አልተሳካም';

  @override
  String get cachedJustNow => 'አሁን';

  @override
  String cachedMinutesAgo(int count) {
    return 'ከ$count ደቂቃ በፊት';
  }

  @override
  String cachedHoursAgo(int count) {
    return 'ከ$count ሰዓት በፊት';
  }

  @override
  String cachedDaysAgo(int count) {
    return 'ከ$count ቀን በፊት';
  }

  @override
  String catalogSynced(String when) {
    return 'የመጽሐፍ ዝርዝር ከ$when ጋር ተመሳሰለ';
  }

  @override
  String showingLibrarySynced(String when) {
    return 'ቤተ-መጽሐፍት ከ$when ጋር ተመሳሰለ';
  }

  @override
  String get navHome => 'መነሻ';

  @override
  String get navLibrary => 'ቤተ-መጽሐፍት';

  @override
  String get navSettings => 'ቅንብሮች';

  @override
  String get navBrowse => 'መጽሐፍት';

  @override
  String get navAccount => 'መገለጫ';

  @override
  String get navProfile => 'መገለጫ';

  @override
  String get navPurchases => 'ግዢዎች';

  @override
  String get drawerHome => 'መነሻ';

  @override
  String get drawerBrowse => 'መጽሐፍት ያስሱ';

  @override
  String get drawerAccount => 'መለያ';

  @override
  String get drawerProfile => 'መገለጫ';

  @override
  String get drawerSettings => 'ቅንብሮች';

  @override
  String get drawerAbout => 'ስለ መተግበሪያው';

  @override
  String get drawerContinueReading => 'ንባብ ይቀጥሉ';

  @override
  String get profileTitle => 'መገለጫ';

  @override
  String get settingsTitle => 'ቅንብሮች';

  @override
  String get settingsCacheSection => 'ማከማቻ እና ቤተ-መጻሕፍት';

  @override
  String get aboutTitle => 'ስለ መተግበሪያው';

  @override
  String get aboutAppSectionTitle => 'ስለ መተግበሪያው';

  @override
  String get aboutAppSectionBody =>
      'የኢትዮጵያ አንባቢ ሃይማኖታዊ መጽሐፍትን ለማሰስ፣ ለንባብ እና ለመማር ከኦፍላይን ድጋፍ ጋር ያግዛል።';

  @override
  String get aboutVersionSectionTitle => 'ስሪት';

  @override
  String get aboutVersionValue => '1.0.0';

  @override
  String get aboutDevelopersSectionTitle => 'አበልጻጊዎች';

  @override
  String get aboutDevelopersBody => 'የኢትዮጵያ ሃይማኖታዊ መጽሐፍት ፕሮጀክት';

  @override
  String get homeQuickProfile => 'መገለጫዎ';

  @override
  String get homeQuickProfileSubtitle => 'መለያ እና መግባት';

  @override
  String get homeQuickSettings => 'ቅንብሮች';

  @override
  String get homeQuickSettingsSubtitle => 'ቋንቋ፣ ኦፍላይን መደበር እና ማስታወሻ';

  @override
  String get actionRead => 'አንብብ';

  @override
  String get actionInfo => 'መረጃ';

  @override
  String get continueReading => 'ንባብ ይቀጥሉ';

  @override
  String get resumeReading => 'ቀጥል';

  @override
  String get readNow => 'አሁን አንብብ';

  @override
  String get recentlyOpened => 'በቅርብ የተከፈቱ';

  @override
  String get homeQuickBrowse => 'ሁሉንም መጽሐፍት';

  @override
  String get homeQuickBrowseSubtitle => 'የሙሉ ዝርዝር ፍለጋ እና ማጣሪያ';

  @override
  String get homeQuickDownloads => 'የወረዱ';

  @override
  String get homeQuickDownloadsSubtitle => 'ለኦፍላይን የተቀመጡ መጽሐፍት';

  @override
  String get downloadsPageTitle => 'የወረዱ';

  @override
  String get downloadsEmptyTitle => 'እስካሁን ምንም አልወረደም';

  @override
  String get downloadsEmptyMessage => 'ከመጽሐፍ ዝርዝር ወይንም በማንበብ ወቅት ለኦፍላይን ያስቀምጡ።';

  @override
  String get downloadsSavedSection => 'በዚህ መሳሪያ ላይ የተቀመጡ';

  @override
  String get downloadsActiveSection => 'በመውረድ ላይ';

  @override
  String get downloadsFailedSection => 'የተሳሳቱ ማውረዶች';

  @override
  String get downloadsNoSavedYet =>
      'እስካሁን ምንም ከመስመር ውጭ አልተቀመጠም። መጽሐፍ ክፈትና ከመስመር ውጭ አስቀምጥ ተጠቀም።';

  @override
  String get unableToLoadDownloads => 'የወረዱን ማስገባት አልተቻለም';

  @override
  String get savedOfflineBadge => 'ከመስመር ውጭ ይገኛል';

  @override
  String get downloadInProgress => 'በመውረድ ላይ…';

  @override
  String get downloadFailedGeneric => 'ማውረድ አልተሳካም';

  @override
  String get downloadErrorStorageUnreachable =>
      'የፋይል ሰርቨሩን ማግኘት አልተቻለም። Docker (MinIO በፖርት 19000) እየሰራ መሆኑንና ይህ መሳሪያ የልማት ኮምፒዩተርዎን በተመሳሳይ አውታረ መረብ ማግኘት እንደሚችል ያረጋግጡ።';

  @override
  String get downloadErrorConnection =>
      'መጽሐፉን ለማውረድ መገናኘት አልተቻለም። ግንኙነትዎን ይፈትሹና እንደገና ይሞክሩ።';

  @override
  String get downloadErrorTimeout =>
      'ማውረድ ጊዜው አልፏል። ቋሚ ግንኙነት ሲኖርዎት እንደገና ይሞክሩ።';

  @override
  String get downloadErrorGeneric => 'ማውረድ አልተሳካም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get downloadsSyncCache => 'ከሰርቨር አመሳስል';

  @override
  String get downloadsClearBookCache => 'ከመስመር ውጭ ቅጂ አስወግድ';

  @override
  String get downloadsClearAllCache => 'ሁሉንም ከመስመር ውጭ ቅጂዎች አጽዳ';

  @override
  String get downloadsSyncDone => 'ከመስመር ውጭ ቅጂ ታድሷል';

  @override
  String downloadsClearBookTitle(String title) {
    return '\"$title\" ይወገድ?';
  }

  @override
  String get downloadsClearBookBody =>
      'በዚህ መሳሪያ ላይ ለዚህ መጽሐፍ የተቀመጡ ምዕራፎችንና ገጾችን ብቻ ያስወግዳል።';

  @override
  String get downloadsCacheInvalid => 'ሊነበብ የሚችል ይዘት የለም — አመሳስል ወይም አስወግድ';

  @override
  String get downloadsNotInCatalogHint =>
      'ይህ መጽሐፍ በህዝብ ካታሎጉ ላይ አይደለም፤ ዝርዝሩ ከኦፍላይን ቅጂዎ ይታያል።';

  @override
  String get homeQuickAccount => 'መለያ እና ማመሳሰል';

  @override
  String get homeQuickAccountSubtitle => 'መገለጫ፣ ዕቅዶች እና ምርጫዎች';

  @override
  String get browseByCategory => 'በምድብ ያስሱ';

  @override
  String booksInCategory(int count) {
    return '$count መጽሐፍት';
  }

  @override
  String get readFullBook => 'ሙሉ መጽሐፍ አንብብ';

  @override
  String headerCategoriesStat(int count) {
    return '$count ምድቦች';
  }

  @override
  String headerBooksStat(int count) {
    return '$count መጽሐፍት';
  }

  @override
  String get mostReadSection => 'በቅርብ የተከፈቱ';

  @override
  String get searchTooltip => 'ፈልግ';

  @override
  String get homeNoBooksTitle => 'እስካሁን የታተሙ መጽሐፍት የሉም';

  @override
  String get homeNoBooksMessage => 'አዲስ መጽሐፍት ሲገኙ እዚህ ይታያሉ።';

  @override
  String get openLibrary => 'ቤተ-መጽሐፍት ክፈት';

  @override
  String get exploreWisdomTitle => 'ጥበብን እና ታሪክን ያስሱ';

  @override
  String get exploreWisdomBody => 'የሃይማኖት መጽሐፍትን በንጹህ አቀራረብ ያንብቡ።';

  @override
  String get searchLibrary => 'ቤተ-መጽሐፍት ፈልግ';

  @override
  String get browseCollections => 'ስብስቦችን ያስሱ';

  @override
  String get featuredBooks => 'የተመረጡ መጽሐፍት';

  @override
  String curatedSelections(int count) {
    return '$count የተመረጡ';
  }

  @override
  String get librarySections => 'የቤተ-መጽሐፍት ክፍሎች';

  @override
  String get viewAll => 'ሁሉንም አሳይ';

  @override
  String get unableToLoadHome => 'መነሻ ገጽ መጫን አልተሳካም';

  @override
  String get noSummaryYet => 'እስካሁን ማጠቃለያ የለም።';

  @override
  String get readDetails => 'ዝርዝሮችን አንብብ';

  @override
  String get unknownAuthor => 'ያልታወቀ ደራሲ';

  @override
  String get openArticle => 'ጽሑፍ ክፈት';

  @override
  String get libraryTitle => 'ቤተ-መጽሐፍት';

  @override
  String get filterTooltip => 'አጣራ';

  @override
  String get filterByLanguage => 'በቋንቋ አጣራ';

  @override
  String get allLanguages => 'ሁሉም ቋንቋዎች';

  @override
  String get chapterKeyLabel => 'የምዕራፍ ቁልፍ';

  @override
  String get chapterKeyHint => 'አማራጭ የሰርቨር ማጣሪያ';

  @override
  String get pageNumberLabel => 'የገጽ ቁጥር';

  @override
  String get pageNumberHint => 'አማራጭ የሰርቨር ማጣሪያ';

  @override
  String get applyFilters => 'ማጣሪያዎችን ተግብር';

  @override
  String get libraryEmptyTitle => 'ቤተ-መጽሐፍት ባዶ ነው';

  @override
  String get libraryEmptyMessage => 'አሁን የታተሙ መጽሐፍት የሉም።';

  @override
  String get librarySearchHint => 'በርዕስ፣ ደራሲ ወይም ማጠቃለያ ፈልግ';

  @override
  String get clearSearchTooltip => 'ፍለጋ አጽዳ';

  @override
  String booksAvailable(int count) {
    return '$count መጽሐፍ(ቶች) ይገኛሉ';
  }

  @override
  String catalogChapterCount(int count) {
    return '$count ምዕራፎች';
  }

  @override
  String readingProgressPercent(int percent) {
    return '$percent%';
  }

  @override
  String get catalogLanguageAmharic => 'አማርኛ';

  @override
  String get catalogLanguageGeez => 'ግዕዝ';

  @override
  String get catalogLanguageEnglish => 'English';

  @override
  String get clearFilter => 'ማጣሪያ አጽዳ';

  @override
  String languageChip(String lang) {
    return 'ቋንቋ፦ $lang';
  }

  @override
  String chapterChip(String ch) {
    return 'ምዕራፍ፦ $ch';
  }

  @override
  String pageChip(int page) {
    return 'ገጽ፦ $page';
  }

  @override
  String get noMatchingBooksTitle => 'የሚዛመዱ መጽሐፍት የሉም';

  @override
  String get noMatchingBooksMessage => 'ሌላ ቁልፍ ቃል ይሞክሩ ወይም ማጣሪያዎችን ያጽዱ።';

  @override
  String get unableToLoadLibrary => 'ቤተ-መጽሐፍት መጫን አልተሳካም';

  @override
  String revisionLabel(int n) {
    return 'ማሻሻያ $n';
  }

  @override
  String get open => 'ክፈት';

  @override
  String get accountTitle => 'መለያ';

  @override
  String get readerAccount => 'የአንባቢ መለያ';

  @override
  String get noEmail => 'ኢሜይል የለም';

  @override
  String get adminRoleBadge => 'አስተዳዳሪ';

  @override
  String get dashboard => 'ዳሽቦርድ';

  @override
  String get inProgressDownloads => 'በሂደት ላይ';

  @override
  String get failedDownloads => 'የተሳሳቱ ማውረዶች';

  @override
  String get availableBooks => 'የሚገኙ መጽሐፍት';

  @override
  String get languagesMetric => 'ቋንቋዎች';

  @override
  String get offlineChapterCache => 'ከመስመር ውጭ የምዕራፍ ማከማቻ';

  @override
  String offlineBooksSaved(int count) {
    return '$count መጽሐፍ(ቶች) ከመስመር ውጭ ተቀምጠዋል';
  }

  @override
  String get checkingCache => 'ማከማቻ በመፈተሽ ላይ...';

  @override
  String get cacheUnavailable => 'ማከማቻ አይገኝም';

  @override
  String get clearOfflineCacheTitle => 'ከመስመር ውጭ ማከማቻ ይጸዳ?';

  @override
  String get clearOfflineCacheBody => 'የወረዱ የምዕራፍ/ገጽ ይዘቶች ከመሣሪያው ይወገዳሉ።';

  @override
  String get offlineCacheCleared => 'ከመስመር ውጭ ማከማቻ ተጸድቋል';

  @override
  String get studyAndReminders => 'ጥናት እና ማስታወሻዎች';

  @override
  String get dailyReadingReminders => 'ዕለታዊ የንባብ ማስታወሻዎች';

  @override
  String reminderTimeUtc(String hh, String mm, String weekdays) {
    return 'UTC $hh:$mm$weekdays';
  }

  @override
  String get weekdaysOnlySuffix => ' · በስራ ቀናት ብቻ';

  @override
  String get reminderUpdateFailed => 'የማስታወሻ ቅንብሮች አልተሻሻሉም።';

  @override
  String get loadingReminderSettings => 'የማስታወሻ ቅንብሮች በመጫን ላይ...';

  @override
  String get reminderSettingsUnavailable => 'የማስታወሻ ቅንብሮች አይገኙም';

  @override
  String get dailyReadingPlans => 'ዕለታዊ የንባብ እቅዶች';

  @override
  String get noReadingPlansYet => 'እስካሁን እቅዶች የሉም';

  @override
  String readingPlansConfigured(int count) {
    return '$count እቅድ(ዎች) ተዋቅረዋል';
  }

  @override
  String get tapOpenTodaysReading => ' · የዛሬውን ንባብ ለመክፈት ይንኩ';

  @override
  String get createPlanTooltip => 'እቅድ ፍጠር';

  @override
  String get dailyPlanCreateFailed => 'ዕለታዊ እቅድ መፍጠር አልተሳካም።';

  @override
  String get accountInfo => 'የመለያ መረጃ';

  @override
  String get profileAccountDetails => 'የመለያ ዝርዝሮች';

  @override
  String get profileUserIdLabel => 'የተጠቃሚ መለያ';

  @override
  String get profileUserIdCopied => 'የተጠቃሚ መለያ ተቀድቷል';

  @override
  String get profileRoleLabel => 'ሚና';

  @override
  String get profilePreferredLanguageLabel => 'የተመረጠ ቋንቋ';

  @override
  String get profileSuperuserLabel => 'የአስተዳዳሪ መዳረሻ';

  @override
  String get profileValueNotSet => 'አልተመረጠም';

  @override
  String get profileYes => 'አዎ';

  @override
  String get profileNo => 'አይ';

  @override
  String get profileOpenSettings => 'ቅንብሮች';

  @override
  String get emailLabel => 'ኢሜይል';

  @override
  String get displayNameLabel => 'የማሳያ ስም';

  @override
  String get adminPanel => 'የአስተዳዳሪ ፓነል';

  @override
  String get adminPanelSubtitle => 'መጽሐፍት፣ ታይነት እና ህትመት ያቀናብሩ';

  @override
  String get noProfileCached => 'መገለጫ አልተቀመጠም።';

  @override
  String get signOut => 'ውጣ';

  @override
  String get welcomeBack => 'እንኳን በደህና መጡ';

  @override
  String get signInSubtitle => 'ለመቀጠል ይግቡ እና እድገትዎን ያመሳስሉ።';

  @override
  String get emailFieldLabel => 'ኢሜይል';

  @override
  String get emailFieldHint => 'you@example.com';

  @override
  String get emailRequired => 'ኢሜይል ያስፈልጋል';

  @override
  String get emailInvalid => 'ትክክለኛ ኢሜይል ያስገቡ';

  @override
  String get passwordFieldLabel => 'የይለፍ ቃል';

  @override
  String get passwordMinHelper => 'ቢያንስ 10 ቁምፊዎች';

  @override
  String get passwordRequired => 'የይለፍ ቃል ያስፈልጋል';

  @override
  String get signIn => 'ግባ';

  @override
  String get createAccount => 'መለያ ፍጠር';

  @override
  String get createAccountTitle => 'መለያ ፍጠር';

  @override
  String get registerSubtitle => 'እድገት፣ ምልክቶች እና ማውረዶችን ለማስቀመጥ መገለጫ ይፍጠሩ።';

  @override
  String get passwordMinRegisterHelper => 'ቢያንስ 10 ቁምፊዎች ይጠቀሙ';

  @override
  String get passwordTooShort => 'የይለፍ ቃል ቢያንስ 10 ቁምፊዎች መሆን አለበት';

  @override
  String get displayNameOptional => 'የማሳያ ስም (አማራጭ)';

  @override
  String get alreadyHaveAccount => 'መለያ አለዎት? ይግቡ';

  @override
  String get languagePreferenceTitle => 'ቋንቋ';

  @override
  String get languagePreferenceSubtitle =>
      'ለመተግበሪያው ምናሌዎች እና ቁልፎች እንግሊዝኛ ወይም አማርኛ ይምረጡ።';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageAmharic => 'አማርኛ';

  @override
  String get saveLanguage => 'ቋንቋ አስቀምጥ';

  @override
  String get languageSaved => 'ቋንቋ ተቀምጧል';

  @override
  String get bookDetailsTitle => 'የመጽሐፍ ዝርዝሮች';

  @override
  String get bookStatChapters => 'ምዕራፎች';

  @override
  String get bookStatPages => 'ገጾች';

  @override
  String get bookStatReaders => 'አንባቦች';

  @override
  String get shareBookTooltip => 'መጽሐፍን አጋራ';

  @override
  String get bookSharedToClipboard => 'የመጽሐፍ ርዕስ ተቀድቷል';

  @override
  String get preparingDownload => 'ማውረድ በመዘጋጀት ላይ…';

  @override
  String savedUnderPath(String path) {
    return 'በ$path ተቀምጧል';
  }

  @override
  String downloadFailed(String error) {
    return 'ማውረድ አልተሳካም፦ $error';
  }

  @override
  String get summarySection => 'ማጠቃለያ';

  @override
  String get readyToRead => 'ለንባብ ዝግጁ';

  @override
  String downloadState(String state) {
    return 'ማውረድ፦ $state';
  }

  @override
  String get startReading => 'ንባብ ጀምር';

  @override
  String get downloadOffline => 'ለከመስመር ውጭ ንባብ አውርድ';

  @override
  String get unableToLoadBook => 'ይህን መጽሐፍ መጫን አልተሳካም';

  @override
  String get bookLoadErrorMessage => 'መጽሐፉ አሁን መክፈት አልተቻለም። እንደገና ይሞክሩ።';

  @override
  String get bookNotInCatalogTitle => 'መጽሐፉ በአንባቢ ዝርዝር ውስጥ የለም';

  @override
  String get bookNotInCatalogMessage =>
      'ያልታተመ ወይም የተደበቀ ሊሆን ይችላል። ከአስተዳዳሪ ይፍቱ።';

  @override
  String get readerTitle => 'አንባቢ';

  @override
  String bookmarkSavedAt(int pct) {
    return 'በ$pct% ተቀምጧል';
  }

  @override
  String get bookmarkRemoved => 'ምልክት ተወግዷል';

  @override
  String get bookmarkSaved => 'ምልክት ተቀምጧል';

  @override
  String get noBookmarksYet => 'እስካሁን ምልክቶች የሉም።';

  @override
  String get savedLocation => 'የተቀመጠ ቦታ';

  @override
  String get removeTooltip => 'አስወግድ';

  @override
  String get selectChapter => 'ምዕራፍ ይምረጡ';

  @override
  String get selectPage => 'ገጽ ይምረጡ';

  @override
  String get readerPosition => 'የአንባቢ ቦታ';

  @override
  String get readingPosition => 'የንባብ ቦታ';

  @override
  String pageCount(int count) {
    return '$count ገጽ(ዎች)';
  }

  @override
  String pageNumberTitle(int n) {
    return 'ገጽ $n';
  }

  @override
  String get choosePage => 'ገጽ ይምረጡ';

  @override
  String get jumpToPageSubtitle => 'በቀጥታ ወደ ገጽ ይዝፉ';

  @override
  String get allChapters => 'ሁሉም ምዕራፎች';

  @override
  String get searchPagesWholeBook => 'በመላው መጽሐፍ ገጾችን ፈልግ';

  @override
  String get noChapterSelected => 'ምዕራፍ አልተመረጠም';

  @override
  String get cloudBookmarkSaved => 'የደመና ምልክት ተቀምጧል';

  @override
  String get quickNoteLabel => 'ፈጣን ማስታወሻ';

  @override
  String get quickNoteHint => 'አስተያየትዎን ይጻፉ';

  @override
  String get saveNote => 'ማስታወሻ አስቀምጥ';

  @override
  String get noteSaved => 'ማስታወሻ ተቀምጧል';

  @override
  String highlightSavedOnPage(int n) {
    return 'በገጽ $n ማድመቅ ተቀምጧል';
  }

  @override
  String get highlightsUnavailable => 'ማድመቆች አሁን አይገኙም';

  @override
  String get noHighlightsYet => 'እስካሁን ማድመቆች የሉም።';

  @override
  String get highlightDefaultTitle => 'ማድመቅ';

  @override
  String highlightChapterPage(String ch, String page) {
    return 'ምዕራፍ $ch · ገጽ $page';
  }

  @override
  String get offlineCopyRemoved => 'ከመስመር ውጭ ቅጂ ተወግዷል';

  @override
  String get savedOfflineReading => 'ለከመስመር ውጭ ንባብ ተቀምጧል';

  @override
  String get findInBookLabel => 'በመጽሐፍ ውስጥ ፈልግ';

  @override
  String get findInBookHint => 'ቃል ወይም ሐረግ ይጻፉ';

  @override
  String get searchOutsideChapter => 'ከተመረጠው ምዕራፍ ውጭ ፈልግ';

  @override
  String get noMatchesYet => 'እስካሁን ተዛመድ የለም።';

  @override
  String matchCount(int count) {
    return '$count ተዛመድ(ዎች)';
  }

  @override
  String get previousMatch => 'ቀዳሚ ተዛመድ';

  @override
  String get nextMatch => 'ቀጣይ ተዛመድ';

  @override
  String get typographyCompact => 'ጠቅላላ';

  @override
  String get typographyComfort => 'መጣጣም';

  @override
  String get typographyLarge => 'ትልቅ';

  @override
  String get typographyPresetsTitle => 'የፊደል ቅንብሮች';

  @override
  String get typographyPresetsSubtitle => 'ለእርስዎ የሚስማማውን ይምረጡ';

  @override
  String typographySizeLine(int size, String line) {
    return 'መጠን $size · መስመር $line';
  }

  @override
  String get chaptersHeading => 'ምዕራፎች';

  @override
  String get noChapterContentYet => 'ይህ መጽሐፍ እስካሁን ምዕራፍ/ገጽ የለውም። በአስተዳዳሪ ይጨምሩ።';

  @override
  String chapterChipRaw(String label) {
    return 'ምዕራፍ፦ $label';
  }

  @override
  String pageChipShort(int n) {
    return 'ገጽ፦ $n';
  }

  @override
  String get backToChaptersTooltip => 'ወደ ምዕራፎች ተመለስ';

  @override
  String get filterChapterTooltip => 'ምዕራፍ አጣራ';

  @override
  String get filterPageTooltip => 'ገጽ አጣራ';

  @override
  String get removeOfflineCopy => 'ከመስመር ውጭ ቅጂ አስወግድ';

  @override
  String get saveChaptersOffline => 'ምዕራፎች ከመስመር ውጭ አስቀምጥ';

  @override
  String get backToChapters => 'ወደ ምዕራፎች ተመለስ';

  @override
  String get noChapterSelectedShort => 'ምዕራፍ አልተመረጠም';

  @override
  String get typographyPresetsTooltip => 'የፊደል ቅንብሮች';

  @override
  String get saveCloudBookmarkTooltip => 'የደመና ምልክት አስቀምጥ';

  @override
  String get addNoteTooltip => 'ማስታወሻ ጨምር';

  @override
  String get addHighlightTooltip => 'ማድመቅ ጨምር';

  @override
  String get highlightsTooltip => 'ማድመቆች';

  @override
  String get pinControls => 'መቆጣጠሪያዎችን አስይዝ';

  @override
  String get autoHideControls => 'መቆጣጠሪያዎችን በራስ-ደብቅ';

  @override
  String get readerExpandTools => 'የንባብ መሳሪያዎችን አሳይ';

  @override
  String get readerCollapseTools => 'የንባብ መሳሪያዎችን ደብቅ';

  @override
  String get readerPageCurlOn => 'ወደ ገጽ እይታ ቀይር';

  @override
  String get readerPageCurlOff => 'ወደ ሸብልል እይታ ቀይር';

  @override
  String get readerPageCurlHint => 'ገጾችን ለመቀየር በጎን የሚገኙትን ቀስት ይጠቀሙ።';

  @override
  String matchOnPage(int page, String snippet) {
    return 'በገጽ $page ተዛመድ፦ $snippet';
  }

  @override
  String get readerChapterLabel => 'ምዕራፍ';

  @override
  String get readerPageLabel => 'ገጽ';

  @override
  String get adminHomeTitle => 'አስተዳዳሪ';

  @override
  String get publisherTools => 'የማተሚያ መሣሪያዎች';

  @override
  String get publisherToolsBody => 'የመጽሐፍ ዝርዝር፣ መረጃ እና ህትመት ያቀናብሩ።';

  @override
  String get adminBooksMenuTitle => 'መጽሐፍት';

  @override
  String get adminBooksMenuSubtitle => 'ዝርዝር፣ ፍጠር፣ አርትዖት፣ ህትመት';

  @override
  String get adminBooksListTitle => 'መጽሐፍት ያቀናብሩ';

  @override
  String adminBooksCount(int shown, int total) {
    return '$shown ከ $total መጽሐፍት';
  }

  @override
  String get adminEditAction => 'አርትዕ';

  @override
  String get adminBookActionsTooltip => 'የመጽሐፍ ተግባራት';

  @override
  String get adminPublishedBookLockedTitle => 'የታተመ መጽሐፍ';

  @override
  String get adminPublishedBookLockedMessage =>
      'መረጃውን ወይም ረቂቁን ከማስተካከልዎ በፊት ይህን መጽሐፍ ህትመት አስቆም።';

  @override
  String get adminNotBookCreatorTitle => 'ማስተካከል የተገደበ';

  @override
  String get adminNotBookCreatorMessage =>
      'ይህን መጽሐፍ የፈጠረው ተጠቃሚ ብቻ ማስተካከል ይችላል።';

  @override
  String get newBookTooltip => 'አዲስ መጽሐፍ';

  @override
  String get noBooksYetTitle => 'እስካሁን መጽሐፍት የሉም';

  @override
  String get noBooksYetMessage => 'ወደ አንባቢዎች ለማተም የመጀመሪያ መጽሐፍዎን ይፍጠሩ።';

  @override
  String get createFirstBook => 'መጽሐፍ ፍጠር';

  @override
  String get searchBooksLabel => 'መጽሐፍት ፈልግ';

  @override
  String get searchBooksHint => 'ርዕስ፣ ደራሲ፣ ቋንቋ';

  @override
  String get filterAll => 'ሁሉም';

  @override
  String get filterPublished => 'የታተመ';

  @override
  String get filterHidden => 'የተደበቀ';

  @override
  String get sortRecent => 'ደርድር፦ ቅርብ';

  @override
  String get sortTitle => 'ደርድር፦ ርዕስ';

  @override
  String get noBooksMatchFilters => 'ከማጣሪያዎች ጋር የሚዛመድ መጽሐፍ የለም።';

  @override
  String get unableToLoadBooks => 'መጽሐፍት መጫን አልተሳካም';

  @override
  String visibilityLabel(String vis) {
    return 'ታይነት፦ $vis';
  }

  @override
  String statusLabel(String status) {
    return 'ሁኔታ፦ $status';
  }

  @override
  String get publishedStatus => 'የታተመ';

  @override
  String get draftStatus => 'ረቂቅ';

  @override
  String statusChip(String status, String vis) {
    return '$status · $vis';
  }

  @override
  String get bookNotFound => 'መጽሐፍ አልተገኘም።';

  @override
  String get unpublishFailed => 'ህትመት ማስቆም አልተሳካም';

  @override
  String get publishLatestDraftTitle => 'የኋለኛውን ረቂቅ አትም';

  @override
  String get publishLatestDraftBody => 'ለዚህ መጽሐፍ የኋለኛውን ረቂቅ ማሻሻያ ያትማል።';

  @override
  String get publish => 'አትም';

  @override
  String publishedRevisionNumber(int n) {
    return 'የታተመ ማሻሻያ #$n';
  }

  @override
  String get publishedLatestRevision => 'የኋለኛው ማሻሻያ ተታትሟል';

  @override
  String get publishFailed => 'ህትመት አልተሳካም';

  @override
  String get bookFallbackTitle => 'መጽሐፍ';

  @override
  String get editMetadataTooltip => 'መረጃ አርትዖት';

  @override
  String get publishedVisibleBanner => 'ተታትሞ በአንባቢ ይታያል';

  @override
  String get draftOnlyBanner => 'ረቂቅ ብቻ - በአንባቢ አይታይም';

  @override
  String get visibilityTile => 'ታይነት';

  @override
  String get authorCompilerTile => 'ደራሲ / አዋቂ';

  @override
  String get languageTile => 'ቋንቋ';

  @override
  String get draftChaptersPagesTile => 'ረቂቅ ምዕራፎች/ገጾች';

  @override
  String get noDraftChapters => 'ረቂቅ ምዕራፎች የሉም';

  @override
  String draftChapterPageCounts(int chapters, int pages) {
    return '$chapters ምዕራፍ(ዎች)፣ $pages ገጽ(ዎች)';
  }

  @override
  String get publishedRevisionTile => 'የታተመ ማሻሻያ';

  @override
  String get openInReader => 'በአንባቢ ውስጥ ክፈት';

  @override
  String get publishFirstToOpenReader => 'በአንባቢ ለመክፈት መጀመሪያ ያትሙ።';

  @override
  String get publishRevision => 'ማሻሻያ አትም';

  @override
  String get unpublish => 'ህትመት አስቆም';

  @override
  String get summaryLabel => 'ማጠቃለያ';

  @override
  String get createBookFirstValidate => 'መጀመሪያ መጽሐፉን ይፍጠሩ፣ ከዚያ ረቂቅ ያረጋግጡ።';

  @override
  String get draftValidationTitle => 'የረቂቅ ማረጋገጫ';

  @override
  String get warningsHeading => 'ማስጠንቀቂያዎች፦';

  @override
  String get discardUnsavedTitle => 'ያልተቀመጡ ለውጦች ይወገዱ?';

  @override
  String get discardUnsavedBody => 'ያልተቀመጡ ለውጦች አሉ። ከዚህ ከወጡ ይጠፋሉ።';

  @override
  String get discardUnsavedBodyEditor =>
      'በአርትዖቱ ውስጥ ያልተቀመጡ ለውጦች አሉ። ያለማስቀመጥ ይወጣሉ?';

  @override
  String get formDraftRestored => 'ረቂቅ ተመልሷል — ከቆሙበት ይቀጥሉ።';

  @override
  String get formDraftSaved => 'ረቂቅ ተቀምጧል። በኋላ መቀጠል ይችላሉ።';

  @override
  String get formDraftDiscardTitle => 'የተቀመጠ ረቂቅ ይወገድ?';

  @override
  String get formDraftDiscardBody => 'ለዚህ ቅጽ በአካባቢው የተቀመጠው ረቂቅ ለዘለዓለም ይሰረዛል።';

  @override
  String get formDraftDiscardAction => 'ረቂቅ ይድረስ';

  @override
  String get formDraftLeaveAndSave => 'ረቂቅ አስቀምጥ እና ውጣ';

  @override
  String get stay => 'Stay';

  @override
  String get discard => 'Discard';

  @override
  String get chooseImage => 'ምስል ይምረጡ';

  @override
  String get removeCover => 'ሽፋን አስወግድ';

  @override
  String get validateDraft => 'ረቂቅ አረጋግጥ';

  @override
  String get addChapter => 'ምዕራፍ ጨምር';

  @override
  String get noPagesYet => 'እስካሁን ገጾች የሉም';

  @override
  String get moveUpTooltip => 'ወደ ላይ አንቀሳቅስ';

  @override
  String get moveDownTooltip => 'ወደ ታች አንቀሳቅስ';

  @override
  String get addPageTooltip => 'ገጽ ጨምር';

  @override
  String get editChapterTooltip => 'ምዕራፍ አርትዖት';

  @override
  String get deleteChapterTooltip => 'ምዕራፍ ሰርዝ';

  @override
  String get editPageTooltip => 'ገጽ አርትዖት';

  @override
  String get deletePageTooltip => 'ገጽ ሰርዝ';

  @override
  String get addChapterTitle => 'ምዕራፍ ጨምር';

  @override
  String get editChapterTitle => 'ምዕራፍ አርትዖት';

  @override
  String get chapterKeyHintExample => 'ለምሳሌ chapter-1';

  @override
  String get untitledChapter => 'ርዕስ የሌለው ምዕራፍ';

  @override
  String get unsupportedEmbeddedContent => 'ያልተደገፈ የተሰካ ይዘት';

  @override
  String get editPageTitle => 'ገጽ አርትዖት';

  @override
  String get tagSlugsHint => 'በነጠላ ሰረዝ የተከፈለ፣ ለምሳሌ liturgy, bible';

  @override
  String get visibilityHidden => 'የተደበቀ';

  @override
  String get visibilityPublished => 'የታተመ';

  @override
  String get create => 'Create';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get commaSeparated => 'በነጠላ ሰረዝ የተከፈለ';

  @override
  String get chapterTitleLabel => 'የምዕራፍ ርዕስ';

  @override
  String get chapterKeyFieldLabel => 'የምዕራፍ ቁልፍ';

  @override
  String get eachChapterNeedsKey => 'እያንዳንዱ ምዕራፍ ቁልፍ ሊኖረው ይገባል።';

  @override
  String duplicateChapterKey(String key) {
    return 'የተደጋገመ የምዕራፍ ቁልፍ ተገኝቷል፦ $key';
  }

  @override
  String pageNumberMustBePositive(String title) {
    return 'በ$title ምዕራፍ ውስጥ የገጽ ቁጥር ከዜሮ ላይ ትልቅ መሆን አለበት።';
  }

  @override
  String duplicatePageNumber(int n, String title) {
    return 'በ$title ምዕራፍ ውስጥ የተደጋገመ የገጽ ቁጥር $n';
  }

  @override
  String draftValidationNoWarnings(int chapters, int pages, int empty) {
    return 'ማስጠንቀቂያ የለም።\n\nምዕራፎች፦ $chapters\nገጾች፦ $pages\nባዶ ገጾች፦ $empty';
  }

  @override
  String draftValidationStatsLine(int chapters, int pages, int empty) {
    return 'ምዕራፎች፦ $chapters · ገጾች፦ $pages · ባዶ ገጾች፦ $empty';
  }

  @override
  String get validationFailed => 'ማረጋገጫ አልተሳካም';

  @override
  String get saveFailed => 'ማስቀመጥ አልተሳካም';

  @override
  String get newBookAppBar => 'አዲስ መጽሐፍ';

  @override
  String get editBookAppBar => 'መጽሐፍ አርትዖት';

  @override
  String get metadataSection => 'መረጃ';

  @override
  String get titleLabelRequired => 'ርዕስ *';

  @override
  String get titleRequired => 'ርዕስ ያስፈልጋል';

  @override
  String get subtitleLabel => 'ንዑስ ርዕስ';

  @override
  String get thumbnailCover => 'አነስተኛ ምስል / ሽፋን';

  @override
  String get coverFormatHelp => 'JPEG፣ PNG ወይም WebP። ከመጽሐፉን ካስቀመጡ በኋላ ይሰቀላል።';

  @override
  String get authorCompilerLabel => 'ደራሲ / አዋቂ';

  @override
  String get primaryLanguageCodeLabel => 'ዋና የቋንቋ ኮድ';

  @override
  String get languageCodeRequired => 'የቋንቋ ኮድ ያስፈልጋል';

  @override
  String get scriptTagsLabel => 'የፊደል መለያዎች';

  @override
  String get chaptersPagesSection => 'ምዕራፎች እና ገጾች';

  @override
  String get noChaptersYetHelp =>
      'እስካሁን ምዕራፎች የሉም። ለአንባቢ አሰሳ ምዕራፎችን እና ገጾችን ይጨምሩ።';

  @override
  String chapterKeyPageCount(String key, int count) {
    return '$key · $count ገጽ(ዎች)';
  }

  @override
  String pageListTitle(int n, String title) {
    return 'p.$n · $title';
  }

  @override
  String pageTitleFallback(int n) {
    return 'ገጽ $n';
  }

  @override
  String get cancelEdit => 'ሰርዝ';

  @override
  String get tagSlugsCreateOnlyLabel => 'የመለያ slug (መፍጠር ብቻ)';

  @override
  String get catalogVisibilityLabel => 'የካታሎግ ታይነት';

  @override
  String get pageNumberFieldLabel => 'የገጽ ቁጥር';

  @override
  String get pageTitleFieldLabel => 'የገጽ ርዕስ';

  @override
  String get pageContentHeading => 'የገጽ ይዘት';

  @override
  String get pageEditorPlaceholder => 'ይህን ገጽ ይጻፉ…';

  @override
  String get pageEditorFormattingToggle => 'ቅርጸት';

  @override
  String get pageEditorFormattingHide => 'መሳሪያ ደብቅ';

  @override
  String get goodMorning => 'እንደምን አደሩ';

  @override
  String get goodAfternoon => 'እንደምን ዋሉ';

  @override
  String get goodEvening => 'እንደምን አመሹ';

  @override
  String get libraryViewList => 'ዝርዝር';

  @override
  String get libraryViewGrid => 'ፍርግርግ';

  @override
  String get homePopularBadge => 'ተወዳጅ';

  @override
  String get homeReadMore => 'ተጨማሪ አንብብ';

  @override
  String get homeAllGenre => 'ሁሉም ዘርፍ';

  @override
  String get homeSectionExplore => 'መጻሕፍትን ያስሱ';

  @override
  String get homeSearchHint => 'መጻሕፍት ይፈልጉ…';

  @override
  String get catalogAllResults => 'ሁሉም ውጤቶች';

  @override
  String get bookCategoryPsalms => 'መዝሙር እና ዳዊት';

  @override
  String get bookCategoryMarian => 'ማርያማዊ';

  @override
  String get bookCategoryLiturgy => 'ቅዳሴ';

  @override
  String get bookCategorySynaxarium => 'ስንክሳር';

  @override
  String get bookCategorySaints => 'ገድላት';

  @override
  String get bookCategoryOther => 'አጠቃላይ';

  @override
  String get favouritesTitle => 'ተወዳጆች';

  @override
  String get favouritesEmptyTitle => 'እስካሁን ተወዳጆች የሉም';

  @override
  String get favouritesEmptyMessage => 'መጽሐፍን ለማስቀመጥ የልብ ምልክቱን ይንኩ።';

  @override
  String get notificationsTitle => 'ማሳወቂያዎች';

  @override
  String get notificationsEmptyTitle => 'ሁሉንም አይተዋል';

  @override
  String get notificationsEmptyMessage =>
      'ስለ አዲስ መጻሕፍትና አስታዋሾች ማሳወቂያዎች እዚህ ይታያሉ።';

  @override
  String get notificationsMarkAllRead => 'ሁሉንም እንዳነበበ ምልክት አድርግ';

  @override
  String get reviewsSection => 'ግምገማዎች';

  @override
  String get reviewsEmpty => 'እስካሁን ግምገማ የለም — የመጀመሪያው ይሁኑ።';

  @override
  String get writeReviewTitle => 'ግምገማ ይጻፉ';

  @override
  String get yourRatingLabel => 'የእርስዎ ደረጃ';

  @override
  String get reviewBodyHint => 'ሐሳብዎን ያካፍሉ (አማራጭ)';

  @override
  String get submitReviewAction => 'ግምገማ አስገባ';

  @override
  String ratingsCountLabel(int count) {
    return '$count ደረጃዎች';
  }

  @override
  String get homeRecommended => 'የሚመከሩ';

  @override
  String get sortLabel => 'ደርድር';

  @override
  String get sortNewest => 'አዲስ';

  @override
  String get sortOldest => 'የቆየ';

  @override
  String get sortPopular => 'ተወዳጅ';

  @override
  String get sortTopRated => 'ከፍተኛ ደረጃ';

  @override
  String get sortTitleAz => 'ርዕስ (ሀ–ፐ)';

  @override
  String get premiumLockedTitle => 'ፕሪሚየም መጽሐፍ';

  @override
  String get premiumLockedMessage =>
      'ይህ መጽሐፍ የፕሪሚየም አካል ነው። የፕሪሚየም መዳረሻ ገና አልተዘጋጀም — በቅርቡ ይመለሱ።';

  @override
  String get premiumGotIt => 'ገባኝ';

  @override
  String get adminSummaryLabel => 'ማጠቃለያ';

  @override
  String get adminGenreLabel => 'ዘርፍ / ምድብ';

  @override
  String get adminGenreNone => 'የለም';

  @override
  String get adminPublishedYearLabel => 'የታተመበት ዓመት';

  @override
  String get adminIsPremiumLabel => 'ፕሪሚየም መጽሐፍ';

  @override
  String get adminIsPremiumSubtitle => 'ለማንበብ የፕሪሚየም መዳረሻ ይፈልጋል';

  @override
  String get tagsLabel => 'መለያዎች';

  @override
  String get adminChipAddHint => 'ጨምረው Enter ይጫኑ';

  @override
  String get adminIsFeaturedLabel => 'ተለይቶ የቀረበ (ተወዳጅ)';

  @override
  String get adminIsFeaturedSubtitle => 'በመነሻ ገጹ የተወዳጆች ባነር ላይ አሳይ';

  @override
  String get readerDisplayTitle => 'ማሳያ';

  @override
  String get readerThemeLabel => 'ገጽታ';

  @override
  String get readerThemeLight => 'ብርሃን';

  @override
  String get readerThemeSepia => 'ሴፒያ';

  @override
  String get readerThemeDark => 'ጨለማ';

  @override
  String get readerTextSizeLabel => 'የጽሑፍ መጠን';

  @override
  String get readerSpacingLabel => 'የመስመር ክፍተት';

  @override
  String get readerModeLabel => 'የንባብ ዘዴ';

  @override
  String get readerModeScroll => 'ሸብለላ';

  @override
  String get readerModePage => 'ገጾች';

  @override
  String get readerToolsTitle => 'የንባብ መሣሪያዎች';

  @override
  String get readerMoreTooltip => 'የንባብ መሣሪያዎች';

  @override
  String get paymentTitle => 'ክፍያ';

  @override
  String get paymentChooseMethod => 'የክፍያ ዘዴ ይምረጡ';

  @override
  String get paymentMethodStripe => 'የክሬዲት / ዴቢት ካርድ';

  @override
  String get paymentMethodPaypal => 'PayPal';

  @override
  String get paymentMethodTelebirr => 'ቴሌብር';

  @override
  String get paymentMethodBank => 'የባንክ ዝውውር';

  @override
  String get paymentOrderSummary => 'የትዕዛዝ ማጠቃለያ';

  @override
  String get paymentPrice => 'ዋጋ';

  @override
  String get paymentSalePrice => 'የቅናሽ ዋጋ';

  @override
  String get paymentTotal => 'ጠቅላላ';

  @override
  String get paymentContinue => 'ቀጥል';

  @override
  String get paymentSelectBank => 'ባንክ ይምረጡ';

  @override
  String get paymentBankDetails => 'የባንክ ዝርዝሮች';

  @override
  String get paymentAccountName => 'የሒሳብ ስም';

  @override
  String get paymentAccountNumber => 'የሒሳብ ቁጥር';

  @override
  String get paymentUploadReceipt => 'ደረሰኝ ይስቀሉ';

  @override
  String get paymentReceiptHint =>
      'ይጎትቱ ወይም ለመስቀል ይንኩ — JPG፣ PNG ወይም PDF (ቢበዛ 10MB)';

  @override
  String paymentReceiptSelected(String name) {
    return 'ተመርጧል፦ $name';
  }

  @override
  String get paymentChangeFile => 'ፋይል ይቀይሩ';

  @override
  String get paymentTransactionReference => 'የግብይት ማመሳከሪያ';

  @override
  String get paymentTransactionReferenceHint => 'የባንክ ግብይት ማመሳከሪያ ያስገቡ';

  @override
  String get paymentSubmit => 'ክፍያ ያስገቡ';

  @override
  String get paymentSubmitting => 'በማስገባት ላይ…';

  @override
  String paymentPayNow(String amount) {
    return '$amount ይክፈሉ';
  }

  @override
  String get paymentSuccessTitle => 'ክፍያ ገብቷል';

  @override
  String get paymentSuccessMessage =>
      'ክፍያዎ ማረጋገጫ በመጠባበቅ ላይ ነው። ሲጸድቅ እናሳውቅዎታለን።';

  @override
  String paymentSuccessReference(String reference) {
    return 'ማመሳከሪያ፦ $reference';
  }

  @override
  String get paymentDone => 'ተጠናቋል';

  @override
  String get paymentCopy => 'ቅዳ';

  @override
  String get paymentCopied => 'ተቀድቷል';

  @override
  String get paymentErrorGeneric => 'የሆነ ስህተት ተፈጥሯል። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get paymentGatewayUnavailable => 'ይህ የክፍያ ዘዴ አሁን አይገኝም።';

  @override
  String get paymentReceiptRequired => 'እባክዎ ደረሰኝ ይስቀሉ።';

  @override
  String get paymentReferenceRequired => 'እባክዎ የግብይት ማመሳከሪያ ያስገቡ።';

  @override
  String get paymentBankRequired => 'እባክዎ ባንክ ይምረጡ።';

  @override
  String get paymentNoMethods => 'አሁን ምንም የክፍያ ዘዴ የለም።';

  @override
  String get paymentNoBanks => 'አሁን ለባንክ ማስተላለፍ ምንም ባንክ የለም።';

  @override
  String get paymentBuyToRead => 'ለማንበብ ይግዙ';

  @override
  String get purchaseBook => 'መጽሐፍ ይግዙ';

  @override
  String get paymentMyPurchases => 'ግዢዎች';

  @override
  String get paymentStatusPending => 'በመጠባበቅ ላይ';

  @override
  String get paymentStatusOnReview => 'በግምገማ ላይ';

  @override
  String get paymentStatusApproved => 'ጸድቋል';

  @override
  String get paymentStatusCompleted => 'ተጠናቋል';

  @override
  String get paymentStatusCancelled => 'ተሰርዟል';

  @override
  String get paymentStatusRejected => 'ተቀባይነት አላገኘም';

  @override
  String get paymentStepMethod => 'ዘዴ';

  @override
  String get paymentStepDetails => 'ዝርዝሮች';

  @override
  String get paymentStepDone => 'ተጠናቋል';

  @override
  String get paymentTransferInstruction =>
      'ጠቅላላውን ወደ ከታች ወዳለው ሒሳብ ያስተላልፉ፣ ከዚያ ደረሰኝዎንና ማመሳከሪያዎን ይስቀሉ።';

  @override
  String get paymentNoPurchases => 'እስካሁን ምንም ግዢ አላደረጉም።';

  @override
  String get paymentPurchasesSubtitle => 'ትዕዛዞችዎንና የክፍያ ሁኔታ ይከታተሉ';

  @override
  String get profileSettingsSubtitle => 'ንባብ፣ ቋንቋ እና የመተግበሪያ ምርጫዎች';

  @override
  String get adminPricingSection => 'ዋጋና ኮሚሽን';

  @override
  String get adminCurrencyLabel => 'ምንዛሬ';

  @override
  String get adminPriceLabel => 'ዋጋ';

  @override
  String get adminSalePriceLabel => 'የቅናሽ ዋጋ (አማራጭ)';

  @override
  String get adminCommissionPercentLabel => 'ኮሚሽን %';

  @override
  String get adminCommissionHelp => 'ባዶ ከተተወ የደራሲውን ወይም የመድረኩን ነባሪ ይጠቀማል';

  @override
  String get adminPaymentsTitle => 'ትዕዛዞችና ክፍያዎች';

  @override
  String get adminManageOrders => 'ትዕዛዞችን ያስተዳድሩ';

  @override
  String get adminOrdersSubtitle => 'ክፍያዎችን ይገምግሙ፣ ያጽድቁ እና ያጠናቅቁ';

  @override
  String get adminPendingReviews => 'በመጠባበቅ ላይ ያሉ ግምገማዎች';

  @override
  String get adminCompleted => 'የተጠናቀቁ';

  @override
  String get adminGrossRevenue => 'ጠቅላላ ገቢ';

  @override
  String get adminPlatformRevenue => 'የመድረክ ገቢ';

  @override
  String get adminAuthorRevenue => 'የደራሲ ገቢ';

  @override
  String get adminNoOrders => 'የሚታይ ትዕዛዝ የለም።';

  @override
  String get adminReview => 'ግምገማ';

  @override
  String get adminOrderDetail => 'የትዕዛዝ ዝርዝሮች';

  @override
  String get adminCustomer => 'ደንበኛ';

  @override
  String get adminBook => 'መጽሐፍ';

  @override
  String get adminBank => 'ባንክ';

  @override
  String get adminReceipt => 'ደረሰኝ';

  @override
  String get adminNoReceipt => 'ደረሰኝ አልተሰቀለም';

  @override
  String get adminViewReceipt => 'ደረሰኝ ይመልከቱ';

  @override
  String get adminRejectReason => 'ምክንያት (አማራጭ)';

  @override
  String get adminApprove => 'አጽድቅና አጠናቅቅ';

  @override
  String get adminReject => 'ውድቅ አድርግ';

  @override
  String get adminApproved => 'ትዕዛዙ ጸድቆ ተጠናቋል';

  @override
  String get adminRejected => 'ትዕዛዙ ውድቅ ተደርጓል';

  @override
  String get authorMyBooks => 'የእኔ መጻሕፍት';

  @override
  String get paymentDate => 'ቀን';

  @override
  String get paymentMethod => 'ዘዴ';

  @override
  String get paymentCommission => 'የመድረክ ኮሚሽን';

  @override
  String get paymentOrderId => 'የትዕዛዝ መለያ';

  @override
  String get adminOrdersAllStatuses => 'ሁሉም';

  @override
  String get paymentStatusColumn => 'ሁኔታ';
}
