// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get appTitle => 'ፈለገ መጻሕፍት';

  @override
  String get brandName => 'ፈለገ መጻሕፍት';

  @override
  String get splashTagline => 'ቅዱሳት መጻሕፍት፣ የማይጠፋ ጥበብ';

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
  String get pdfReaderTitle => 'የPDF አንባቢ';

  @override
  String get pdfLoadingLabel => 'PDF እየተከፈተ ነው…';

  @override
  String get pdfOpenFailed => 'PDF መክፈት አልተቻለም';

  @override
  String get pdfNotAPdfBook => 'ይህ መጽሐፍ PDF አይደለም።';

  @override
  String get pdfDocumentSection => 'የPDF መጽሐፍ';

  @override
  String get pdfPickFile => 'PDF ምረጥ';

  @override
  String get pdfReplaceFile => 'PDF ቀይር';

  @override
  String get pdfUploadHint =>
      'PDF ያያይዙ (ከ100 ሜባ አይብለጥ)። መጀመሪያ መጽሐፉን አስቀምጡ፣ ከዚያ ፋይሉን ያያይዙ።';

  @override
  String pdfReadyLabel(String filename, String size) {
    return 'PDF ዝግጁ ነው፦ $filename ($size)';
  }

  @override
  String get pdfPendingUpload => 'PDF ተመርጧል — ሲያስቀምጡ ይጫናል።';

  @override
  String get pdfUploadFailed => 'PDF መጫን አልተቻለም።';

  @override
  String get pdfUploadSuccess => 'PDF ተጭኗል።';

  @override
  String get pdfBookTypeLabel => 'የPDF መጽሐፍ';

  @override
  String get pdfBookTypeHelp => 'አንባቢው ይህን መጽሐፍ በPDF ይከፍታል እንጂ በምዕራፍ አይደለም።';

  @override
  String get openPdfBook => 'PDF ክፈት';

  @override
  String get pdfNoChaptersHint => 'ይህ መጽሐፍ PDF ነው። ለማንበብ ይክፈቱት።';

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
    return 'የመጻሕፍት ዝርዝር በ$when ተመሳሰለ';
  }

  @override
  String showingLibrarySynced(String when) {
    return 'ቤተ መጻሕፍት በ$when ተመሳሰለ';
  }

  @override
  String get navHome => 'መነሻ';

  @override
  String get navLibrary => 'ቤተ መጻሕፍት';

  @override
  String get navSettings => 'ቅንብሮች';

  @override
  String get navBrowse => 'መጻሕፍት';

  @override
  String get navAccount => 'መገለጫ';

  @override
  String get navProfile => 'መገለጫ';

  @override
  String get navPurchases => 'ግዢዎች';

  @override
  String get navOrders => 'ትዕዛዞች';

  @override
  String get drawerHome => 'መነሻ';

  @override
  String get drawerBrowse => 'መጻሕፍትን ይመልከቱ';

  @override
  String get drawerAccount => 'መለያ';

  @override
  String get drawerProfile => 'መገለጫ';

  @override
  String get drawerSettings => 'ቅንብሮች';

  @override
  String get drawerAbout => 'ስለ ፈለገ መጻሕፍት';

  @override
  String get drawerContinueReading => 'ንባብ ይቀጥሉ';

  @override
  String get profileTitle => 'መገለጫ';

  @override
  String get settingsTitle => 'ቅንብሮች';

  @override
  String get settingsCacheSection => 'የተቀመጡ መጻሕፍት';

  @override
  String get aboutTitle => 'ስለ ፈለገ መጻሕፍት';

  @override
  String get aboutAppSectionTitle => 'ስለ ፈለገ መጻሕፍት';

  @override
  String get aboutAppSectionBody =>
      'ፈለገ መጻሕፍት የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ቅዱሳት መጻሕፍትን ለማንበብ፣ ለማጥናትና በጸሎት ለመከተል የተዘጋጀ ቤተ መጻሕፍት ነው። ኢንተርኔት ቢኖርም ባይኖርም ንባብዎ አይቋረጥም።';

  @override
  String get aboutVersionSectionTitle => 'ስሪት';

  @override
  String get aboutVersionValue => '1.0.0';

  @override
  String get aboutDevelopersSectionTitle => 'ያዘጋጁት';

  @override
  String get aboutDevelopersBody => 'የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ቤተ መጻሕፍት ሥራ';

  @override
  String get homeQuickProfile => 'መገለጫዎ';

  @override
  String get homeQuickProfileSubtitle => 'መለያዎንና መግባትዎን ያስተዳድሩ';

  @override
  String get homeQuickSettings => 'ቅንብሮች';

  @override
  String get homeQuickSettingsSubtitle => 'ቋንቋ፣ የተቀመጡ መጻሕፍትና ማስታወሻ';

  @override
  String get actionRead => 'አንብብ';

  @override
  String get actionInfo => 'ስለ መጽሐፉ';

  @override
  String get continueReading => 'ንባብ ይቀጥሉ';

  @override
  String get resumeReading => 'ከቆሙበት ይቀጥሉ';

  @override
  String get readNow => 'አሁን ያንብቡ';

  @override
  String authoredBy(String name) {
    return 'ያዘጋጁት $name';
  }

  @override
  String get downloadOfflineShort => 'ያለ ኢንተርኔት አስቀምጥ';

  @override
  String get recentlyOpened => 'በቅርብ የከፈቷቸው';

  @override
  String get homeQuickBrowse => 'ሁሉንም መጻሕፍት';

  @override
  String get homeQuickBrowseSubtitle => 'በርዕስ ወይም በምድብ ይፈልጉ';

  @override
  String get homeQuickDownloads => 'የተቀመጡ';

  @override
  String get homeQuickDownloadsSubtitle => 'ያለ ኢንተርኔት የሚነበቡ መጻሕፍት';

  @override
  String get downloadsPageTitle => 'የተቀመጡ መጻሕፍት';

  @override
  String get downloadsEmptyTitle => 'እስካሁን ምንም አልተቀመጠም';

  @override
  String get downloadsEmptyMessage =>
      'መጽሐፍ ሲከፍቱ «ያለ ኢንተርኔት አስቀምጥ» ብለው በጉዞም ያንብቡ።';

  @override
  String get downloadsSavedSection => 'በዚህ መሣሪያ ላይ የተቀመጡ';

  @override
  String get downloadsActiveSection => 'እየወረዱ ያሉ';

  @override
  String get downloadsFailedSection => 'ያልተሳኩ ማውረዶች';

  @override
  String get downloadsNoSavedYet =>
      'እስካሁን ያለ ኢንተርኔት የተቀመጠ መጽሐፍ የለም። መጽሐፍ ይክፈቱና ያስቀምጡ።';

  @override
  String get unableToLoadDownloads => 'የተቀመጡትን ማምጣት አልተቻለም';

  @override
  String get savedOfflineBadge => 'ያለ ኢንተርኔት ይገኛል';

  @override
  String get downloadInProgress => 'እየወረደ ነው…';

  @override
  String get downloadFailedGeneric => 'ማውረድ አልተሳካም';

  @override
  String get downloadErrorStorageUnreachable =>
      'የፋይል ማከማቻው አልተገኘም። Docker (MinIO በፖርት 19000) እየሠራ መሆኑንና ይህ መሣሪያ የልማት ኮምፒውተርዎን ማግኘት እንደሚችል ያረጋግጡ።';

  @override
  String get downloadErrorConnection =>
      'መጽሐፉን ለማውረድ መገናኘት አልተቻለም። ኢንተርኔትዎን ይፈትሹና እንደገና ይሞክሩ።';

  @override
  String get downloadErrorTimeout => 'ማውረዱ ጊዜው አልፏል። ኢንተርኔት ሲረጋጋ እንደገና ይሞክሩ።';

  @override
  String get downloadErrorGeneric => 'ማውረድ አልተሳካም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get downloadsSyncCache => 'አዲሱን አምጣ';

  @override
  String get downloadsClearBookCache => 'ያለ ኢንተርኔት ቅጂ አንሳ';

  @override
  String get downloadsClearAllCache => 'ሁሉንም ያለ ኢንተርኔት ቅጂዎች አጽዳ';

  @override
  String get downloadsSyncDone => 'ያለ ኢንተርኔት ቅጂ ታድሷል';

  @override
  String downloadsClearBookTitle(String title) {
    return '«$title» ይነሳ?';
  }

  @override
  String get downloadsClearBookBody =>
      'በዚህ መሣሪያ ላይ ለዚህ መጽሐፍ የተቀመጡ ምዕራፎችንና ገጾችን ብቻ ያነሳል።';

  @override
  String get downloadsCacheInvalid => 'ሊነበብ የሚችል ይዘት የለም — ያድሱ ወይም ያንሱ';

  @override
  String get downloadsNotInCatalogHint =>
      'ይህ መጽሐፍ በሕዝብ ዝርዝር ላይ አይደለም፤ ዝርዝሩ ያለ ኢንተርኔት ከተቀመጠው ቅጂዎ ይመጣል።';

  @override
  String get homeQuickAccount => 'መለያና አንድ ንባብ';

  @override
  String get homeQuickAccountSubtitle => 'መገለጫ፣ የዕለት ንባብና ምርጫዎች';

  @override
  String get browseByCategory => 'በምድብ ይመልከቱ';

  @override
  String booksInCategory(int count) {
    return '$count መጻሕፍት';
  }

  @override
  String get readFullBook => 'ሙሉ መጽሐፉን ያንብቡ';

  @override
  String headerCategoriesStat(int count) {
    return '$count ምድቦች';
  }

  @override
  String headerBooksStat(int count) {
    return '$count መጻሕፍት';
  }

  @override
  String get mostReadSection => 'በቅርብ የከፈቷቸው';

  @override
  String get searchTooltip => 'ፈልግ';

  @override
  String get homeNoBooksTitle => 'እስካሁን የወጡ መጻሕፍት የሉም';

  @override
  String get homeNoBooksMessage => 'አዲስ መጻሕፍት ሲወጡ እዚህ ይታያሉ።';

  @override
  String get openLibrary => 'ቤተ መጻሕፍት ክፈት';

  @override
  String get exploreWisdomTitle => 'ጥበብና ትውፊት';

  @override
  String get exploreWisdomBody =>
      'የቤተ ክርስቲያንን መጻሕፍት በግልጽ አቀራረብ ያንብቡ፤ ወደ ንባብ በቀላሉ ይግቡ።';

  @override
  String get searchLibrary => 'ቤተ መጻሕፍት ፈልግ';

  @override
  String get browseCollections => 'ምድቦችን ይመልከቱ';

  @override
  String get featuredBooks => 'የተመረጡ መጻሕፍት';

  @override
  String curatedSelections(int count) {
    return '$count የተመረጡ';
  }

  @override
  String get librarySections => 'የቤተ መጻሕፍት ክፍሎች';

  @override
  String get viewAll => 'ሁሉንም አሳይ';

  @override
  String get unableToLoadHome => 'መነሻውን መክፈት አልተቻለም';

  @override
  String get noSummaryYet => 'እስካሁን መግለጫ የለም።';

  @override
  String get readDetails => 'ስለ መጽሐፉ';

  @override
  String get unknownAuthor => 'አዘጋጁ አልተገለጸም';

  @override
  String get openArticle => 'መጽሐፉን ክፈት';

  @override
  String get libraryTitle => 'ቤተ መጻሕፍት';

  @override
  String get filterTooltip => 'አጣራ';

  @override
  String get filterByLanguage => 'በቋንቋ አጣራ';

  @override
  String get allLanguages => 'ሁሉም ቋንቋዎች';

  @override
  String get chapterKeyLabel => 'የምዕራፍ መለያ';

  @override
  String get chapterKeyHint => 'አማራጭ ማጣሪያ';

  @override
  String get pageNumberLabel => 'የገጽ ቁጥር';

  @override
  String get pageNumberHint => 'አማራጭ ማጣሪያ';

  @override
  String get applyFilters => 'አጣራ';

  @override
  String get libraryEmptyTitle => 'ቤተ መጻሕፍት ባዶ ነው';

  @override
  String get libraryEmptyMessage => 'አሁን የወጡ መጻሕፍት የሉም።';

  @override
  String get librarySearchHint => 'በርዕስ፣ በአዘጋጅ ወይም በመግለጫ ፈልግ';

  @override
  String get clearSearchTooltip => 'ፍለጋ አጽዳ';

  @override
  String booksAvailable(int count) {
    return '$count መጻሕፍት ይገኛሉ';
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
  String get catalogLanguageEnglish => 'እንግሊዝኛ';

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
  String get noMatchingBooksTitle => 'የሚመጥን መጽሐፍ አልተገኘም';

  @override
  String get noMatchingBooksMessage => 'ሌላ ቃል ይሞክሩ ወይም ማጣሪያውን ያጽዱ።';

  @override
  String get unableToLoadLibrary => 'ቤተ መጻሕፍትን መክፈት አልተቻለም';

  @override
  String revisionLabel(int n) {
    return 'እትም $n';
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
  String get dashboard => 'አስተዳደር';

  @override
  String get inProgressDownloads => 'እየወረዱ ያሉ';

  @override
  String get failedDownloads => 'ያልተሳኩ ማውረዶች';

  @override
  String get availableBooks => 'የሚገኙ መጻሕፍት';

  @override
  String get languagesMetric => 'ቋንቋዎች';

  @override
  String get offlineChapterCache => 'ያለ ኢንተርኔት የተቀመጡ ምዕራፎች';

  @override
  String offlineBooksSaved(int count) {
    return '$count መጻሕፍት ያለ ኢንተርኔት ተቀምጠዋል';
  }

  @override
  String get checkingCache => 'የተቀመጡትን እየፈተሸ ነው…';

  @override
  String get cacheUnavailable => 'የተቀመጡት አይገኙም';

  @override
  String get clearOfflineCacheTitle => 'ያለ ኢንተርኔት የተቀመጡት ይጸዱ?';

  @override
  String get clearOfflineCacheBody => 'ከዚህ መሣሪያ የወረዱ ምዕራፎችና ገጾች ይነሳሉ።';

  @override
  String get offlineCacheCleared => 'ያለ ኢንተርኔት የተቀመጡት ተጸድተዋል';

  @override
  String get studyAndReminders => 'ትምህርትና ማስታወሻ';

  @override
  String get dailyReadingReminders => 'የዕለት ንባብ ማስታወሻ';

  @override
  String reminderTimeUtc(String hh, String mm, String weekdays) {
    return 'UTC $hh:$mm$weekdays';
  }

  @override
  String get weekdaysOnlySuffix => ' · ከሰኞ እስከ ዓርብ';

  @override
  String get reminderUpdateFailed => 'የማስታወሻ ቅንብሮች አልተሻሻሉም።';

  @override
  String get loadingReminderSettings => 'የማስታወሻ ቅንብሮች እየተከፈቱ ነው…';

  @override
  String get reminderSettingsUnavailable => 'የማስታወሻ ቅንብሮች አይገኙም';

  @override
  String get dailyReadingPlans => 'የዕለት ንባብ';

  @override
  String get noReadingPlansYet => 'እስካሁን የዕለት ንባብ አልተዘጋጀም';

  @override
  String readingPlansConfigured(int count) {
    return '$count የዕለት ንባብ ተዘጋጅተዋል';
  }

  @override
  String get tapOpenTodaysReading => ' · የዛሬውን ንባብ ለመክፈት ይንኩ';

  @override
  String get createPlanTooltip => 'የዕለት ንባብ ጨምር';

  @override
  String get dailyPlanCreateFailed => 'የዕለት ንባብ መፍጠር አልተሳካም።';

  @override
  String get accountInfo => 'የመለያ መረጃ';

  @override
  String get profileAccountDetails => 'የመለያ ዝርዝሮች';

  @override
  String get profileUserIdLabel => 'የተጠቃሚ መለያ';

  @override
  String get profileUserIdCopied => 'የተጠቃሚ መለያ ተቀድቷል';

  @override
  String get profileRoleLabel => 'ኃላፊነት';

  @override
  String get profilePreferredLanguageLabel => 'የመረጡት ቋንቋ';

  @override
  String get profileSuperuserLabel => 'የአስተዳዳሪ ሥልጣን';

  @override
  String get profileValueNotSet => 'አልተመረጠም';

  @override
  String get profileYes => 'አዎ';

  @override
  String get profileNo => 'አይደለም';

  @override
  String get profileOpenSettings => 'ቅንብሮች';

  @override
  String get emailLabel => 'ኢሜይል';

  @override
  String get displayNameLabel => 'ስም';

  @override
  String get adminPanel => 'የአስተዳደር ገጽ';

  @override
  String get adminPanelSubtitle => 'መጻሕፍትን፣ ታይነትንና ህትመትን ያቀናብሩ';

  @override
  String get adminManageBooksSubtitle => 'መጻሕፍትዎን ይፍጠሩ፣ ያስገቡ እና ያውጡ';

  @override
  String get noProfileCached => 'መገለጫ አልተቀመጠም።';

  @override
  String get signOut => 'ይውጡ';

  @override
  String headerGreeting(String name) {
    return 'ሰላም፣ $name';
  }

  @override
  String get welcomeBack => 'እንኳን በደህና መጡ';

  @override
  String get signInSubtitle => 'ንባብዎን ለመቀጠልና የደረሱበት እንዳይጠፋ ይግቡ።';

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
  String get passwordFieldHint => 'የይለፍ ቃልዎን ያስገቡ';

  @override
  String get showPassword => 'የይለፍ ቃል አሳይ';

  @override
  String get hidePassword => 'የይለፍ ቃል ደብቅ';

  @override
  String get passwordMinHelper => 'ቢያንስ 10 ፊደላት';

  @override
  String get passwordRequired => 'የይለፍ ቃል ያስፈልጋል';

  @override
  String get signIn => 'ይግቡ';

  @override
  String get createAccount => 'መለያ ይክፈቱ';

  @override
  String get createAccountTitle => 'መለያ ይክፈቱ';

  @override
  String get registerSubtitle => 'የደረሱበት፣ ምልክቶችዎና የተቀመጡ መጻሕፍት እንዲቆዩ መገለጫ ይክፈቱ።';

  @override
  String get passwordMinRegisterHelper => 'ቢያንስ 10 ፊደላት ይጠቀሙ';

  @override
  String get passwordTooShort => 'የይለፍ ቃል ቢያንስ 10 ፊደላት መሆን አለበት';

  @override
  String get displayNameOptional => 'ስም (አማራጭ)';

  @override
  String get alreadyHaveAccount => 'መለያ አለዎት? ይግቡ';

  @override
  String get forgotPassword => 'የይለፍ ቃልዎን ረሱ?';

  @override
  String get forgotPasswordTitle => 'የይለፍ ቃል ይቀይሩ';

  @override
  String get forgotPasswordSubtitle =>
      'ኢሜይልዎን ያስገቡ፤ የይለፍ ቃልዎን ለመቀየር ባለ 6 አሃዝ ቁጥር እንልክልዎታለን።';

  @override
  String get sendResetCode => 'ቁጥሩን ላክ';

  @override
  String get resetPasswordTitle => 'አዲስ የይለፍ ቃል ያስቀምጡ';

  @override
  String resetPasswordSubtitle(String email) {
    return 'ወደ $email የላክነውን ቁጥር ያስገቡና አዲስ የይለፍ ቃል ይምረጡ።';
  }

  @override
  String get resetCodeFieldLabel => 'ባለ 6 አሃዝ ቁጥር';

  @override
  String get resetCodeRequired => 'ባለ 6 አሃዝ ቁጥሩን ያስገቡ';

  @override
  String get resetCodeInvalid => 'ቁጥሩ 6 አሃዝ መሆን አለበት';

  @override
  String get newPasswordFieldLabel => 'አዲስ የይለፍ ቃል';

  @override
  String get confirmPasswordFieldLabel => 'አዲሱን የይለፍ ቃል ያረጋግጡ';

  @override
  String get confirmPasswordRequired => 'አዲሱን የይለፍ ቃል ያረጋግጡ';

  @override
  String get passwordsDoNotMatch => 'የይለፍ ቃላቶቹ አይመሳሰሉም';

  @override
  String get resetPasswordCta => 'የይለፍ ቃል ቀይር';

  @override
  String get passwordResetSuccess => 'የይለፍ ቃልዎ ተቀይሯል። እባክዎ ይግቡ።';

  @override
  String get resetPasswordFailed =>
      'የይለፍ ቃል መቀየር አልተቻለም። ቁጥሩን ይመልከቱና እንደገና ይሞክሩ።';

  @override
  String get resendCode => 'ቁጥሩን እንደገና ላክ';

  @override
  String resendCodeIn(int seconds) {
    return 'ቁጥሩን እንደገና በ$seconds ሰከንድ';
  }

  @override
  String get resetCodeResent => 'አዲስ ቁጥር ተልኮልዎታል።';

  @override
  String get backToSignIn => 'ወደ መግቢያ ተመለስ';

  @override
  String get changePasswordTitle => 'የይለፍ ቃል ቀይር';

  @override
  String get changePasswordSubtitle => 'ለመለያዎ አዲስ የይለፍ ቃል ይምረጡ።';

  @override
  String get currentPasswordFieldLabel => 'ያሁኑ የይለፍ ቃል';

  @override
  String get currentPasswordRequired => 'ያሁኑን የይለፍ ቃል ያስገቡ';

  @override
  String get changePasswordCta => 'የይለፍ ቃል አድስ';

  @override
  String get passwordChangedSuccess => 'የይለፍ ቃልዎ ታድሷል።';

  @override
  String get changePasswordFailed => 'የይለፍ ቃል ማደስ አልተቻለም።';

  @override
  String get profileSecuritySection => 'ደኅንነት';

  @override
  String get changePasswordLinkSubtitle => 'የመለያዎን የይለፍ ቃል ያድሱ';

  @override
  String get languagePreferenceTitle => 'ቋንቋ';

  @override
  String get languagePreferenceSubtitle =>
      'የመተግበሪያው ጽሑፍና ቁልፎች በእንግሊዝኛ ወይም በአማርኛ ይታዩ።';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageAmharic => 'አማርኛ';

  @override
  String get languageEnglishShort => 'EN';

  @override
  String get languageAmharicShort => 'አማ';

  @override
  String get saveLanguage => 'ቋንቋ አስቀምጥ';

  @override
  String get languageSaved => 'ቋንቋ ተቀምጧል';

  @override
  String get bookDetailsTitle => 'ስለ መጽሐፉ';

  @override
  String get bookStatChapters => 'ምዕራፎች';

  @override
  String get bookStatPages => 'ገጾች';

  @override
  String get bookStatReaders => 'አንባቢዎች';

  @override
  String get shareBookTooltip => 'አገናኝ ቅዳ';

  @override
  String get bookSharedToClipboard => 'የመጽሐፉ አገናኝ ተቀድቷል';

  @override
  String get preparingDownload => 'ማውረድ እየተዘጋጀ ነው…';

  @override
  String savedUnderPath(String path) {
    return 'በ$path ተቀምጧል';
  }

  @override
  String downloadFailed(String error) {
    return 'ማውረድ አልተሳካም፦ $error';
  }

  @override
  String get summarySection => 'መግለጫ';

  @override
  String get readyToRead => 'ለንባብ ዝግጁ ነው';

  @override
  String downloadState(String state) {
    return 'ማውረድ፦ $state';
  }

  @override
  String get startReading => 'ንባብ ይጀምሩ';

  @override
  String get downloadOffline => 'ያለ ኢንተርኔት ለማንበብ አውርድ';

  @override
  String get unableToLoadBook => 'ይህን መጽሐፍ መክፈት አልተቻለም';

  @override
  String get bookLoadErrorMessage => 'መጽሐፉ አሁን ሊከፈት አልቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get bookNotInCatalogTitle => 'መጽሐፉ በቤተ መጻሕፍት አይገኝም';

  @override
  String get bookNotInCatalogMessage =>
      'መጽሐፉ ላልወጣ ወይም ለተደበቀ ይመስላል። ከአስተዳደር አውጥተው እንደገና ይሞክሩ።';

  @override
  String get readerTitle => 'አንባቢ';

  @override
  String bookmarkSavedAt(int pct) {
    return 'በ$pct% ተቀምጧል';
  }

  @override
  String get bookmarkRemoved => 'ምልክቱ ተነስቷል';

  @override
  String get bookmarkSaved => 'ምልክት ተቀምጧል';

  @override
  String get noBookmarksYet => 'እስካሁን ምልክት የለም። በአንባቢው ላይ ምልክት ይንኩ።';

  @override
  String get savedLocation => 'የተቀመጠበት ቦታ';

  @override
  String get removeTooltip => 'አንሳ';

  @override
  String get selectChapter => 'ምዕራፍ ምረጥ';

  @override
  String get selectPage => 'ገጽ ምረጥ';

  @override
  String get readerPosition => 'የደረሱበት';

  @override
  String get readingPosition => 'የደረሱበት';

  @override
  String pageCount(int count) {
    return '$count ገጾች';
  }

  @override
  String pageNumberTitle(int n) {
    return 'ገጽ $n';
  }

  @override
  String get choosePage => 'ገጽ ምረጥ';

  @override
  String get jumpToPageSubtitle => 'ወደ ገጽ በቀጥታ ይሂዱ';

  @override
  String get allChapters => 'ሁሉም ምዕራፎች';

  @override
  String get searchPagesWholeBook => 'በሙሉ መጽሐፉ ውስጥ ፈልግ';

  @override
  String get noChapterSelected => 'ምዕራፍ አልተመረጠም';

  @override
  String get cloudBookmarkSaved => 'ምልክቱ በመለያዎ ተቀምጧል';

  @override
  String get quickNoteLabel => 'አጭር ማስታወሻ';

  @override
  String get quickNoteHint => 'ያሰቡትን ወይም ያጠቃለሉትን ይጻፉ';

  @override
  String get saveNote => 'ማስታወሻ አስቀምጥ';

  @override
  String get noteSaved => 'ማስታወሻ ተቀምጧል';

  @override
  String highlightSavedOnPage(int n) {
    return 'ማድመቂያ በገጽ $n ተቀምጧል';
  }

  @override
  String get highlightsUnavailable => 'ማድመቂያዎች አሁን አይገኙም';

  @override
  String get noHighlightsYet => 'እስካሁን ማድመቂያ የለም። የማድመቂያ ምልክቱን ይንኩ።';

  @override
  String get highlightDefaultTitle => 'ማድመቂያ';

  @override
  String highlightChapterPage(String ch, String page) {
    return 'ምዕራፍ $ch · ገጽ $page';
  }

  @override
  String get offlineCopyRemoved => 'ያለ ኢንተርኔት ቅጂ ተነስቷል';

  @override
  String get savedOfflineReading => 'ያለ ኢንተርኔት ለማንበብ ተቀምጧል';

  @override
  String get findInBookLabel => 'በመጽሐፉ ውስጥ ፈልግ';

  @override
  String get findInBookHint => 'ቃል ወይም ሐረግ ይጻፉ';

  @override
  String get searchOutsideChapter => 'ከተመረጠው ምዕራፍ ውጭም ፈልግ';

  @override
  String get noMatchesYet => 'እስካሁን የሚመጥን አልተገኘም።';

  @override
  String matchCount(int count) {
    return '$count ተገኝተዋል';
  }

  @override
  String get previousMatch => 'ያለፈው';

  @override
  String get nextMatch => 'የሚቀጥለው';

  @override
  String matchPosition(int current, int total) {
    return '$current ከ$total';
  }

  @override
  String get pdfSearching => 'እየፈለገ ነው…';

  @override
  String get typographyCompact => 'ጠባብ';

  @override
  String get typographyComfort => 'ምቹ';

  @override
  String get typographyLarge => 'ትልቅ';

  @override
  String get typographyPresetsTitle => 'የፊደል መጠን';

  @override
  String get typographyPresetsSubtitle => 'ለዓይንዎ የሚመች ንባብ ይምረጡ';

  @override
  String typographySizeLine(int size, String line) {
    return 'መጠን $size • ክፍተት $line';
  }

  @override
  String get chaptersHeading => 'ምዕራፎች';

  @override
  String get noChapterContentYet =>
      'ይህ መጽሐፍ እስካሁን ምዕራፍ/ገጽ የለውም። በአስተዳደር ምዕራፍ ጨምረው ያውጡ።';

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
  String get removeOfflineCopy => 'ያለ ኢንተርኔት ቅጂ አንሳ';

  @override
  String get saveChaptersOffline => 'ምዕራፎችን ያለ ኢንተርኔት አስቀምጥ';

  @override
  String get backToChapters => 'ወደ ምዕራፎች ተመለስ';

  @override
  String get noChapterSelectedShort => 'ምዕራፍ አልተመረጠም';

  @override
  String get typographyPresetsTooltip => 'የፊደል መጠን';

  @override
  String get saveCloudBookmarkTooltip => 'ምልክት በመለያዎ አስቀምጥ';

  @override
  String get addNoteTooltip => 'ማስታወሻ ጨምር';

  @override
  String get addHighlightTooltip => 'ማድመቂያ ጨምር';

  @override
  String get highlightsTooltip => 'ማድመቂያዎች';

  @override
  String get pinControls => 'ሁልጊዜ አሳይ';

  @override
  String get autoHideControls => 'በራሱ ይደበቅ';

  @override
  String get readerExpandTools => 'የንባብ መሣሪያዎችን አሳይ';

  @override
  String get readerCollapseTools => 'የንባብ መሣሪያዎችን ደብቅ';

  @override
  String get readerPageCurlOn => 'ገጽ በገጽ አሳይ';

  @override
  String get readerPageCurlOff => 'ተከታታይ አሳይ';

  @override
  String get readerPageCurlHint => 'ገጽ ለመቀየር የጎን ቀስቶቹን ይጠቀሙ።';

  @override
  String matchOnPage(int page, String snippet) {
    return 'በገጽ $page፦ $snippet';
  }

  @override
  String get readerChapterLabel => 'ምዕራፍ';

  @override
  String get readerPageLabel => 'ገጽ';

  @override
  String get adminHomeTitle => 'አስተዳደር';

  @override
  String get publisherTools => 'የአዘጋጅ መሣሪያዎች';

  @override
  String get publisherToolsBody =>
      'የመጻሕፍት ዝርዝር ታይነት፣ መግለጫና ህትመት ያቀናብሩ። የእትም ጥቅሎች ማስገባት አሁንም ከኤፒአይ የተፈረሙ አድራሻዎችን ይጠቀማል።';

  @override
  String get adminBooksMenuTitle => 'መጻሕፍት';

  @override
  String get adminBooksMenuSubtitle => 'ዝርዝር፣ መፍጠር፣ ማረም፣ ማውጣት / መደበቅ';

  @override
  String get adminBooksListTitle => 'መጻሕፍትን ያቀናብሩ';

  @override
  String adminBooksCount(int shown, int total) {
    return '$shown ከ$total መጻሕፍት';
  }

  @override
  String get adminEditAction => 'አርም';

  @override
  String get adminBookActionsTooltip => 'የመጽሐፍ ተግባራት';

  @override
  String get adminPublishedBookLockedTitle => 'የወጣ መጽሐፍ';

  @override
  String get adminPublishedBookLockedMessage =>
      'መግለጫውን ወይም ረቂቁን ከማረምዎ በፊት መጽሐፉን ይደብቁ።';

  @override
  String get adminNotBookCreatorTitle => 'ማረም የተገደበ ነው';

  @override
  String get adminNotBookCreatorMessage => 'መጽሐፉን የፈጠረው ብቻ ማረም ይችላል።';

  @override
  String get newBookTooltip => 'አዲስ መጽሐፍ';

  @override
  String get importFromWord => 'ከWord ያስገቡ (.docx)';

  @override
  String get importFromPdf => 'ከPDF ያስገቡ (.pdf)';

  @override
  String get importDocxInProgress => 'ሰነዱ እየገባ ነው…';

  @override
  String get importDocxSuccess => 'ገብቷል። ምዕራፎቹን ይመልከቱ፣ ከዚያ ያውጡ።';

  @override
  String get importDocxFailed => 'ሰነዱን ማስገባት አልተቻለም።';

  @override
  String get importPdfInProgress => 'PDF እየገባ ነው…';

  @override
  String get importPdfSuccess => 'ገብቷል። የመጽሐፉን መግለጫ ይመልከቱ፣ ከዚያ ያውጡ።';

  @override
  String get importPdfFailed => 'PDF ማስገባት አልተቻለም።';

  @override
  String get importPdfTooLarge => 'PDF ከ100 ሜባ በላይ ነው።';

  @override
  String get importPdfInvalid => 'የተመረጠው ፋይል ትክክለኛ PDF አይደለም።';

  @override
  String get importScanning => 'ሰነዱ እየተፈተሸ ነው…';

  @override
  String get importLegacyDocTitle => 'እንደ .docx ያስቀምጡ';

  @override
  String get importLegacyDocMessage =>
      'ይህ የቆየ .doc ፋይል ነው። በWord ከፍተው Save As → Word Document (.docx) በማለት እንደገና ይሞክሩ።';

  @override
  String get importChooseStructure => 'ምዕራፎች እንዴት ይለዩ?';

  @override
  String get importModeAuto => 'በራሱ';

  @override
  String get importModeHeading => 'የርዕስ ቅርጾች';

  @override
  String get importModePatterns => 'የምዕራፍ ጽሑፍ (ለምሳሌ ምዕራፍ 1)';

  @override
  String get importModeFormat => 'ደማቅ / መሃል ርዕሶች';

  @override
  String get importModePagebreak => 'የገጽ ስብራት';

  @override
  String get importModeMarker => 'ምልክት መስመሮች (### / <<<CHAPTER>>>)';

  @override
  String get importModeSize => 'አንድ ምዕራፍ (በመጠን)';

  @override
  String importDetectedCounts(int chapters, int pages) {
    return '$chapters ምዕራፎች · $pages ገጾች';
  }

  @override
  String get importRecommendedBadge => 'የሚመከር';

  @override
  String get importCustomPatternLabel => 'የራስዎ ሥርዓት (regex)';

  @override
  String get importCustomMarkerLabel => 'የራስዎ ምልክት';

  @override
  String get importRescan => 'እንደገና ፈትሽ';

  @override
  String get importDetectedChaptersTitle => 'የተገኙ ምዕራፎች';

  @override
  String get importNoChapters => 'ለዚህ ምርጫ ምዕራፍ አልተገኘም።';

  @override
  String importMoreTitles(int count) {
    return '+$count ተጨማሪ';
  }

  @override
  String get importAction => 'አስገባ';

  @override
  String get ok => 'እሺ';

  @override
  String get noBooksYetTitle => 'እስካሁን መጽሐፍ የለም';

  @override
  String get noBooksYetMessage => 'ለአንባቢዎች ለማውጣት የመጀመሪያ መጽሐፍዎን ይፍጠሩ።';

  @override
  String get createFirstBook => 'ፍጠር';

  @override
  String get searchBooksLabel => 'መጻሕፍት ፈልግ';

  @override
  String get searchBooksHint => 'ርዕስ፣ አዘጋጅ፣ ቋንቋ';

  @override
  String get filterAll => 'ሁሉም';

  @override
  String get filterPublished => 'የወጡ';

  @override
  String get filterHidden => 'የተደበቁ';

  @override
  String get sortRecent => 'ደርድር፦ በቅርብ';

  @override
  String get sortTitle => 'ደርድር፦ ርዕስ';

  @override
  String get noBooksMatchFilters => 'ከማጣሪያው ጋር የሚመጥን መጽሐፍ የለም።';

  @override
  String get unableToLoadBooks => 'መጻሕፍትን መክፈት አልተቻለም';

  @override
  String visibilityLabel(String vis) {
    return 'ታይነት፦ $vis';
  }

  @override
  String statusLabel(String status) {
    return 'ሁኔታ፦ $status';
  }

  @override
  String get publishedStatus => 'ወጥቷል';

  @override
  String get draftStatus => 'ረቂቅ';

  @override
  String get inReviewStatus => 'በምርመራ ላይ';

  @override
  String get reviewedStatus => 'ታይቷል';

  @override
  String get sendForReview => 'ለምርመራ ላክ';

  @override
  String get sendForReviewBody => 'ይህን መጽሐፍ ለመርማሪ ይላኩ? በምርመራ ላይ እያለ ማረም አይችሉም።';

  @override
  String get submitReviewSuccess => 'ለምርመራ ተልኳል።';

  @override
  String get withdrawFromReview => 'መልስ';

  @override
  String get withdrawReviewSuccess => 'ከምርመራ ተመልሷል።';

  @override
  String get approveReview => 'አጽድቅ';

  @override
  String get approveReviewBody => 'ይህን መጽሐፍ ያጸድቃሉ? ከዚያ አዘጋጁ ማውጣት ይችላል።';

  @override
  String get approveReviewSuccess => 'መጽሐፉ ጸድቋል።';

  @override
  String get requestChanges => 'ማስተካከያ ጠይቅ';

  @override
  String get requestChangesSuccess => 'ማስተካከያ ተጠይቋል።';

  @override
  String get reviewCommentLabel => 'የሚያስፈልገውን ማስተካከያ ይግለጹ';

  @override
  String get reviewActionFailed => 'የምርመራውን ተግባር ማጠናቀቅ አልተቻለም።';

  @override
  String get viewReviewFeedback => 'አስተያየት ተመልከት';

  @override
  String get reviewFeedbackTitle => 'የመርማሪ አስተያየት';

  @override
  String get changesRequestedBannerTitle => 'ማስተካከያ ተጠይቋል';

  @override
  String get reviewHistoryTitle => 'የምርመራ ታሪክ';

  @override
  String get reviewHistoryEmpty => 'እስካሁን የምርመራ እንቅስቃሴ የለም።';

  @override
  String get reviewNoComment => 'አስተያየት የለም።';

  @override
  String get adminBookInReviewLockedTitle => 'በምርመራ ላይ';

  @override
  String get adminBookInReviewLockedMessage =>
      'ይህ መጽሐፍ በምርመራ ላይ ነው። ለማረም ከምርመራ ይመልሱ።';

  @override
  String get reviewDecisionSubmitted => 'ለምርመራ ተልኳል';

  @override
  String get reviewDecisionApproved => 'ጸድቋል';

  @override
  String get reviewDecisionChangesRequested => 'ማስተካከያ ተጠይቋል';

  @override
  String get reviewDecisionWithdrawn => 'ተመልሷል';

  @override
  String statusChip(String status, String vis) {
    return '$status · $vis';
  }

  @override
  String get bookNotFound => 'መጽሐፉ አልተገኘም።';

  @override
  String get unpublishFailed => 'መደበቅ አልተሳካም';

  @override
  String get publishLatestDraftTitle => 'የቅርብ ረቂቁን አውጣ';

  @override
  String get publishLatestDraftBody =>
      'የቅርብ ረቂቅ እትሙን ያወጣል። ረቂቅ ከሌለ ስርዓቱ ከአሁኑ መግለጫ አንድ ይፈጥራል።';

  @override
  String get publish => 'አውጣ';

  @override
  String publishedRevisionNumber(int n) {
    return 'የወጣ እትም #$n';
  }

  @override
  String get publishedLatestRevision => 'የቅርብ እትሙ ወጥቷል';

  @override
  String get publishFailed => 'ማውጣት አልተሳካም';

  @override
  String get deleteBook => 'መጽሐፍ ሰርዝ';

  @override
  String get deleteBookTitle => 'ይህ ረቂቅ ይሰረዝ?';

  @override
  String deleteBookBody(String title) {
    return '«$title» እና ሁሉም ረቂቅ ምዕራፎቹ ይሰረዛሉ። መልሶ ማምጣት አይቻልም።';
  }

  @override
  String get deleteBookConfirm => 'ሰርዝ';

  @override
  String get deleteBookSuccess => 'ረቂቅ መጽሐፍ ተሰርዟል';

  @override
  String get deleteBookFailed => 'መሰረዝ አልተሳካም';

  @override
  String get bookFallbackTitle => 'መጽሐፍ';

  @override
  String get editMetadataTooltip => 'መግለጫ አርም';

  @override
  String get publishedVisibleBanner => 'ወጥቷል፤ ለአንባቢ ይታያል';

  @override
  String get draftOnlyBanner => 'ረቂቅ ብቻ — ለአንባቢ አይታይም';

  @override
  String get visibilityTile => 'ታይነት';

  @override
  String get authorCompilerTile => 'ደራሲ / አዘጋጅ';

  @override
  String get languageTile => 'ቋንቋ';

  @override
  String get draftChaptersPagesTile => 'የረቂቅ ምዕራፎች/ገጾች';

  @override
  String get noDraftChapters => 'የረቂቅ ምዕራፍ የለም';

  @override
  String draftChapterPageCounts(int chapters, int pages) {
    return '$chapters ምዕራፎች፣ $pages ገጾች';
  }

  @override
  String get publishedRevisionTile => 'የወጣ እትም';

  @override
  String get openInReader => 'በአንባቢ ክፈት';

  @override
  String get publishFirstToOpenReader => 'በአንባቢ ለመክፈት መጀመሪያ መጽሐፉን ያውጡ።';

  @override
  String get publishRevision => 'እትም አውጣ';

  @override
  String get unpublish => 'ደብቅ';

  @override
  String get summaryLabel => 'መግለጫ';

  @override
  String get createBookFirstValidate => 'መጀመሪያ መጽሐፉን ይፍጠሩ፣ ከዚያ ረቂቁን ይፈትሹ።';

  @override
  String get draftValidationTitle => 'የረቂቅ ፍተሻ';

  @override
  String get warningsHeading => 'ማስጠንቀቂያዎች፦';

  @override
  String get discardUnsavedTitle => 'ያልተቀመጡ ለውጦች ይጣሉ?';

  @override
  String get discardUnsavedBody => 'ያልተቀመጡ ማረሚያዎች አሉዎት። አሁን ከሄዱ ይጠፋሉ።';

  @override
  String get discardUnsavedBodyEditor => 'በዚህ አርታኢ ያልተቀመጡ ለውጦች አሉ። ሳያስቀምጡ ይወጡ?';

  @override
  String get formDraftRestored => 'ረቂቅ ተመልሷል — ከቆሙበት ይቀጥሉ።';

  @override
  String get formDraftSaved => 'ረቂቅ ተቀምጧል። በኋላ መቀጠል ይችላሉ።';

  @override
  String get formDraftDiscardTitle => 'የተቀመጠ ረቂቅ ይጣል?';

  @override
  String get formDraftDiscardBody => 'ለዚህ ቅጽ በመሣሪያዎ ላይ የተቀመጠው ረቂቅ ይሰረዛል።';

  @override
  String get formDraftDiscardAction => 'ረቂቅ ጣል';

  @override
  String get formDraftLeaveAndSave => 'ረቂቅ አስቀምጠው ይውጡ';

  @override
  String get stay => 'ቆይ';

  @override
  String get discard => 'ጣል';

  @override
  String get chooseImage => 'ምስል ምረጥ';

  @override
  String get removeCover => 'ሽፋን አንሳ';

  @override
  String get validateDraft => 'ረቂቅ ፈትሽ';

  @override
  String get addChapter => 'ምዕራፍ ጨምር';

  @override
  String get noPagesYet => 'እስካሁን ገጽ የለም';

  @override
  String get moveUpTooltip => 'ወደ ላይ ውሰድ';

  @override
  String get moveDownTooltip => 'ወደ ታች ውሰድ';

  @override
  String get addPageTooltip => 'ገጽ ጨምር';

  @override
  String get editChapterTooltip => 'ምዕራፍ አርም';

  @override
  String get deleteChapterTooltip => 'ምዕራፍ ሰርዝ';

  @override
  String get editPageTooltip => 'ገጽ አርም';

  @override
  String get deletePageTooltip => 'ገጽ ሰርዝ';

  @override
  String get addChapterTitle => 'ምዕራፍ ጨምር';

  @override
  String get editChapterTitle => 'ምዕራፍ አርም';

  @override
  String get chapterKeyHintExample => 'ለምሳሌ chapter-1';

  @override
  String get untitledChapter => 'ርዕስ የሌለው ምዕራፍ';

  @override
  String get unsupportedEmbeddedContent => 'የማይደገፍ የተቀናጀ ይዘት';

  @override
  String get editPageTitle => 'ገጽ አርም';

  @override
  String get tagSlugsHint => 'በነጠላ ሰረዝ፣ ለምሳሌ qidase, metshafe-qidus';

  @override
  String get visibilityHidden => 'የተደበቀ';

  @override
  String get visibilityPublished => 'የወጣ';

  @override
  String get create => 'ፍጠር';

  @override
  String get saveChanges => 'ለውጦችን አስቀምጥ';

  @override
  String get commaSeparated => 'በነጠላ ሰረዝ';

  @override
  String get chapterTitleLabel => 'የምዕራፍ ርዕስ';

  @override
  String get chapterKeyFieldLabel => 'የምዕራፍ መለያ';

  @override
  String get eachChapterNeedsKey => 'እያንዳንዱ ምዕራፍ መለያ ሊኖረው ይገባል።';

  @override
  String duplicateChapterKey(String key) {
    return 'የተደገመ የምዕራፍ መለያ፦ $key';
  }

  @override
  String pageNumberMustBePositive(String title) {
    return 'በምዕራፍ $title የገጽ ቁጥር ከ0 በላይ መሆን አለበት።';
  }

  @override
  String duplicatePageNumber(int n, String title) {
    return 'በምዕራፍ $title የተደገመ የገጽ ቁጥር $n።';
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
  String get validationFailed => 'ፍተሻ አልተሳካም';

  @override
  String get saveFailed => 'ማስቀመጥ አልተሳካም';

  @override
  String get newBookAppBar => 'አዲስ መጽሐፍ';

  @override
  String get editBookAppBar => 'መጽሐፍ አርም';

  @override
  String get metadataSection => 'መግለጫ';

  @override
  String get titleLabelRequired => 'ርዕስ *';

  @override
  String get titleRequired => 'ርዕስ ያስፈልጋል';

  @override
  String get subtitleLabel => 'ንዑስ ርዕስ';

  @override
  String get thumbnailCover => 'ምስል / ሽፋን';

  @override
  String get coverFormatHelp => 'JPEG፣ PNG ወይም WebP። መጽሐፉን ካስቀመጡ በኋላ ይጫናል።';

  @override
  String get authorCompilerLabel => 'ደራሲ / አዘጋጅ';

  @override
  String get primaryLanguageCodeLabel => 'ዋና ቋንቋ';

  @override
  String get languageCodeRequired => 'የቋንቋ ኮድ ያስፈልጋል';

  @override
  String get scriptTagsLabel => 'የፊደል ምልክቶች';

  @override
  String get chaptersPagesSection => 'ምዕራፎችና ገጾች';

  @override
  String get noChaptersYetHelp => 'እስካሁን ምዕራፍ የለም። ለአንባቢ እንዲዞር ምዕራፍና ገጽ ይጨምሩ።';

  @override
  String chapterKeyPageCount(String key, int count) {
    return '$key · $count ገጾች';
  }

  @override
  String pageListTitle(int n, String title) {
    return 'ገ. $n · $title';
  }

  @override
  String pageTitleFallback(int n) {
    return 'ገጽ $n';
  }

  @override
  String get cancelEdit => 'ሰርዝ';

  @override
  String get tagSlugsCreateOnlyLabel => 'የመለያ ስሞች (በመፍጠር ጊዜ ብቻ)';

  @override
  String get catalogVisibilityLabel => 'በዝርዝር መታየት';

  @override
  String get pageNumberFieldLabel => 'የገጽ ቁጥር';

  @override
  String get pageTitleFieldLabel => 'የገጽ ርዕስ';

  @override
  String get pageContentHeading => 'የገጽ ጽሑፍ';

  @override
  String get pageEditorPlaceholder => 'ይህን ገጽ ይጻፉ…';

  @override
  String get pageEditorFormattingToggle => 'ቅርጸት';

  @override
  String get pageEditorFormattingHide => 'መሣሪያዎችን ደብቅ';

  @override
  String get goodMorning => 'እንደምን አደሩ';

  @override
  String get goodAfternoon => 'እንደምን ዋሉ';

  @override
  String get goodEvening => 'እንደምን አመሹ';

  @override
  String get libraryViewList => 'ዝርዝር';

  @override
  String get libraryViewGrid => 'በሽፋን';

  @override
  String get homePopularBadge => 'ተወዳጅ';

  @override
  String get homeReadMore => 'ተጨማሪ ያንብቡ';

  @override
  String get homeAllGenre => 'ሁሉም ምድቦች';

  @override
  String get homeSectionExplore => 'መጻሕፍትን ይመልከቱ';

  @override
  String get homeSearchHint => 'መጻሕፍት ፈልግ…';

  @override
  String get catalogAllResults => 'ሁሉም ውጤቶች';

  @override
  String get bookCategoryPsalms => 'መዝሙረ ዳዊት';

  @override
  String get bookCategoryMarian => 'ውዳሴ ማርያም';

  @override
  String get bookCategoryLiturgy => 'ሥርዓተ ቅዳሴ';

  @override
  String get bookCategorySynaxarium => 'ስንክሳር';

  @override
  String get bookCategorySaints => 'ገድላት';

  @override
  String get bookCategoryOther => 'አጠቃላይ';

  @override
  String get favouritesTitle => 'የወደዷቸው';

  @override
  String get favouritesEmptyTitle => 'እስካሁን የወደዱት የለም';

  @override
  String get favouritesEmptyMessage => 'በማንኛውም መጽሐፍ ላይ ልብን በመንካት እዚህ ያስቀምጡ።';

  @override
  String get notificationsTitle => 'ማሳወቂያዎች';

  @override
  String get notificationsEmptyTitle => 'አዲስ ማሳወቂያ የለም';

  @override
  String get notificationsEmptyMessage =>
      'ስለ አዲስ መጻሕፍትና የዕለት ንባብ ማስታወሻዎች እዚህ ይታያሉ።';

  @override
  String get notificationsMarkAllRead => 'ሁሉንም እንደተነበበ ምልክት አድርግ';

  @override
  String get reviewsSection => 'አስተያየቶች';

  @override
  String get reviewsEmpty => 'እስካሁን አስተያየት የለም — የመጀመሪያው ይሁኑ።';

  @override
  String get writeReviewTitle => 'አስተያየት ይጻፉ';

  @override
  String get yourRatingLabel => 'የእርስዎ ደረጃ';

  @override
  String get reviewBodyHint => 'ያሰቡትን ይጻፉ (አማራጭ)';

  @override
  String get submitReviewAction => 'አስተያየት ላክ';

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
  String get sortOldest => 'ቀድሞ የወጡ';

  @override
  String get sortPopular => 'ተወዳጅ';

  @override
  String get sortTopRated => 'ከፍተኛ ደረጃ';

  @override
  String get sortTitleAz => 'ርዕስ (ሀ–ፐ)';

  @override
  String get premiumLockedTitle => 'በክፍያ የሚነበብ መጽሐፍ';

  @override
  String get premiumLockedMessage =>
      'ይህ መጽሐፍ በክፍያ ነው። ክፍያው ገና አልተከፈተም — በቅርቡ ይመለሱ።';

  @override
  String get premiumGotIt => 'ተረድቻለሁ';

  @override
  String get adminSummaryLabel => 'መግለጫ';

  @override
  String get adminGenreLabel => 'ምድብ';

  @override
  String get adminGenreNone => 'የለም';

  @override
  String get adminPublishedYearLabel => 'የወጣበት ዓመት';

  @override
  String get adminIsPremiumLabel => 'በክፍያ የሚነበብ';

  @override
  String get adminIsPremiumSubtitle => 'ለማንበብ ክፍያ ያስፈልጋል';

  @override
  String get tagsLabel => 'መለያዎች';

  @override
  String get adminChipAddHint => 'ጨምረው Enter ይጫኑ';

  @override
  String get adminIsFeaturedLabel => 'የተመረጠ';

  @override
  String get adminIsFeaturedSubtitle => 'በመነሻው ከላይ ይታይ';

  @override
  String get readerDisplayTitle => 'መልክ';

  @override
  String get readerThemeLabel => 'የገጽ ቀለም';

  @override
  String get readerThemeLight => 'ብሩህ';

  @override
  String get readerThemeSepia => 'የብራና ቀለም';

  @override
  String get readerThemeDark => 'ጨለማ';

  @override
  String get readerTextSizeLabel => 'የፊደል መጠን';

  @override
  String get readerSpacingLabel => 'የመስመር ክፍተት';

  @override
  String get readerModeLabel => 'የንባብ መንገድ';

  @override
  String get readerModeScroll => 'ተከታታይ';

  @override
  String get readerModePage => 'ገጾች';

  @override
  String get readerToolsTitle => 'የንባብ መሣሪያዎች';

  @override
  String get readerMoreTooltip => 'የንባብ መሣሪያዎች';

  @override
  String get paymentTitle => 'ክፍያ';

  @override
  String get paymentChooseMethod => 'የክፍያ መንገድ ይምረጡ';

  @override
  String get paymentMethodStripe => 'የባንክ ካርድ';

  @override
  String get paymentMethodPaypal => 'PayPal';

  @override
  String get paymentMethodTelebirr => 'ቴሌብር';

  @override
  String get paymentMethodBank => 'በባንክ ማስተላለፍ';

  @override
  String get paymentOrderSummary => 'የትዕዛዝ ማጠቃለያ';

  @override
  String get paymentPrice => 'ዋጋ';

  @override
  String get paymentSalePrice => 'የቅናሽ ዋጋ';

  @override
  String get paymentTotal => 'ድምር';

  @override
  String get paymentContinue => 'ቀጥል';

  @override
  String get paymentSelectBank => 'ባንክ ምረጥ';

  @override
  String get paymentBankDetails => 'የባንክ መረጃ';

  @override
  String get paymentAccountName => 'የሂሳብ ስም';

  @override
  String get paymentAccountNumber => 'የሂሳብ ቁጥር';

  @override
  String get paymentUploadReceipt => 'ደረሰኝ ጫን';

  @override
  String get paymentReceiptHint =>
      'ጎትተው ይጣሉ ወይም ይንኩ — JPG፣ PNG ወይም PDF (ከ10ሜባ አይብለጥ)';

  @override
  String paymentReceiptSelected(String name) {
    return 'ተመርጧል፦ $name';
  }

  @override
  String get paymentChangeFile => 'ፋይል ቀይር';

  @override
  String get paymentTransactionReference => 'የክፍያ ቁጥር';

  @override
  String get paymentTransactionReferenceHint => 'የባንኩን የክፍያ ቁጥር ያስገቡ';

  @override
  String get paymentSubmit => 'ክፍያ ላክ';

  @override
  String get paymentSubmitting => 'እየተላከ ነው…';

  @override
  String paymentPayNow(String amount) {
    return '$amount ክፈል';
  }

  @override
  String get paymentSuccessTitle => 'ክፍያ ተልኳል';

  @override
  String get paymentSuccessMessage =>
      'ክፍያዎ ለማረጋገጥ በመጠባበቅ ላይ ነው። ከጸደቀ እናሳውቅዎታለን።';

  @override
  String paymentSuccessReference(String reference) {
    return 'ቁጥር፦ $reference';
  }

  @override
  String get paymentDone => 'ተጠናቋል';

  @override
  String get paymentCopy => 'ቅዳ';

  @override
  String get paymentCopied => 'ተቀድቷል';

  @override
  String get paymentErrorGeneric => 'ችግር ተፈጥሯል። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get paymentGatewayUnavailable => 'ይህ የክፍያ መንገድ አሁን አይገኝም።';

  @override
  String get paymentReceiptRequired => 'እባክዎ ደረሰኝ ይጫኑ።';

  @override
  String get paymentReferenceRequired => 'እባክዎ የክፍያ ቁጥር ያስገቡ።';

  @override
  String get paymentBankRequired => 'እባክዎ ባንክ ይምረጡ።';

  @override
  String get paymentNoMethods => 'አሁን የክፍያ መንገድ የለም።';

  @override
  String get paymentNoBanks => 'አሁን ለባንክ ማስተላለፍ ባንክ የለም።';

  @override
  String get paymentBuyToRead => 'ገዝተው ያንብቡ';

  @override
  String get purchaseBook => 'መጽሐፉን ግዛ';

  @override
  String get paymentMyPurchases => 'ግዢዎች';

  @override
  String get paymentStatusPending => 'በመጠባበቅ';

  @override
  String get paymentStatusOnReview => 'በምርመራ ላይ';

  @override
  String get paymentStatusApproved => 'ጸድቋል';

  @override
  String get paymentStatusCompleted => 'ተጠናቋል';

  @override
  String get paymentStatusCancelled => 'ተሰርዟል';

  @override
  String get paymentStatusRejected => 'ውድቅ ሆኗል';

  @override
  String get paymentStepMethod => 'መንገድ';

  @override
  String get paymentStepDetails => 'ዝርዝር';

  @override
  String get paymentStepDone => 'ተጠናቋል';

  @override
  String get paymentTransferInstruction =>
      'ድምሩን ወደ ከታች ያለው ሂሳብ ያስተላልፉ፣ ከዚያ ደረሰኝና የክፍያ ቁጥር ያስገቡ።';

  @override
  String get paymentNoPurchases => 'እስካሁን ግዢ አላደረጉም።';

  @override
  String get paymentPurchasesSubtitle => 'ትዕዛዞችዎንና የክፍያ ሁኔታን ይከታተሉ';

  @override
  String get profileSettingsSubtitle => 'ንባብ፣ ቋንቋና የመተግበሪያ ምርጫዎች';

  @override
  String get adminPricingSection => 'ዋጋና ድርሻ';

  @override
  String get adminCurrencyLabel => 'ምንዛሬ';

  @override
  String get adminPriceLabel => 'ዋጋ';

  @override
  String get adminSalePriceLabel => 'የቅናሽ ዋጋ (አማራጭ)';

  @override
  String get adminCommissionPercentLabel => 'ድርሻ %';

  @override
  String get adminCommissionHelp => 'ባዶ ቢተዉ የደራሲው ወይም የመድረኩ መደበኛ ይሠራል';

  @override
  String get adminPaymentsTitle => 'ትዕዛዞችና ክፍያዎች';

  @override
  String get adminManageOrders => 'ትዕዛዞችን ያቀናብሩ';

  @override
  String get adminOrdersSubtitle => 'ክፍያዎችን ይመልከቱ፣ ያጸድቁና ያጠናቅቁ';

  @override
  String get adminPendingReviews => 'በመጠባበቅ ያሉ ምርመራዎች';

  @override
  String get adminCompleted => 'ተጠናቀዋል';

  @override
  String get adminGrossRevenue => 'ጠቅላላ ገቢ';

  @override
  String get adminPlatformRevenue => 'የመድረኩ ገቢ';

  @override
  String get adminAuthorRevenue => 'የደራሲው ገቢ';

  @override
  String get adminNoOrders => 'የሚታይ ትዕዛዝ የለም።';

  @override
  String get adminNoMatchingOrders => 'ከፍለጋዎ ጋር የሚመጥን ትዕዛዝ የለም።';

  @override
  String get adminSearchOrdersHint => 'ደንበኛ፣ መጽሐፍ ወይም የክፍያ ቁጥር ፈልግ';

  @override
  String get adminShowingResultsFor => 'የሚታዩ ውጤቶች ለ፦';

  @override
  String get adminClearFilters => 'ሁሉንም አጽዳ';

  @override
  String get adminRowsPerPage => 'በገጽ የሚታዩ ረድፎች';

  @override
  String get adminActionsTooltip => 'ተግባራት';

  @override
  String get adminCopyReference => 'የክፍያ ቁጥር ቅዳ';

  @override
  String get adminApproveConfirm => 'ይህን ክፍያ ያጸድቃሉ?';

  @override
  String get bibleTitle => 'መጽሐፍ ቅዱስ';

  @override
  String get bibleOldTestament => 'ብሉይ ኪዳን';

  @override
  String get bibleNewTestament => 'ሐዲስ ኪዳን';

  @override
  String get bibleChapter => 'ምዕራፍ';

  @override
  String get bibleChapters => 'ምዕራፎች';

  @override
  String get biblePrevious => 'ያለፈው';

  @override
  String get bibleNext => 'ቀጣዩ';

  @override
  String get bibleSearchHint => 'ጥቅስ ወይም ምዕራፍ ፈልግ (ለምሳሌ ማቴ 3፥16)';

  @override
  String get bibleNoResults => 'ጥቅስ አልተገኘም።';

  @override
  String get bibleReferenceNotFound => 'ያ ጥቅስ አልተገኘም።';

  @override
  String get bibleSearchScopeAll => 'ሁሉም';

  @override
  String get bibleSearch => 'መጽሐፍ ቅዱስ ፈልግ';

  @override
  String get numberSystemTitle => 'የግዕዝ ቁጥሮች';

  @override
  String get numberSystemSubtitle => 'የምዕራፍና የጥቅስ ቁጥሮች በግዕዝ ይታዩ (፩ ፪ ፫)';

  @override
  String get geezConvertTooltip => 'የተመረጡ ቁጥሮችን ወደ ግዕዝ ቀይር (1 → ፩)';

  @override
  String get adminIsBibleLabel => 'የመጽሐፍ ቅዱስ';

  @override
  String get adminIsBibleSubtitle => 'ገጾች ሳይሆን ምዕራፍ፣ ክፍልና ጥቅስ ያቀናብሩ';

  @override
  String get adminTestamentLabel => 'ኪዳን';

  @override
  String get adminBibleSaveFirst =>
      'መጀመሪያ መጽሐፉን አስቀምጡ፣ ከዚያ የመጽሐፍ ቅዱስ ጽሑፉን ያቀናብሩ።';

  @override
  String get adminManageBibleContent => 'የመጽሐፍ ቅዱስ ጽሑፍ ያቀናብሩ';

  @override
  String get adminBibleContentTitle => 'የመጽሐፍ ቅዱስ ጽሑፍ';

  @override
  String get adminAddChapter => 'ምዕራፍ ጨምር';

  @override
  String get adminAddSection => 'ክፍል ጨምር';

  @override
  String get adminAddVerse => 'ጥቅስ ጨምር';

  @override
  String get adminSectionTitle => 'የክፍል ርዕስ';

  @override
  String get adminVerseNumberLabel => 'ቁ.';

  @override
  String get adminVerseTextLabel => 'የጥቅስ ጽሑፍ';

  @override
  String adminChapterLabel(int number) {
    return 'ምዕራፍ $number';
  }

  @override
  String get adminChapterSaved => 'ምዕራፍ ተቀምጧል';

  @override
  String get adminDeleteChapterConfirm => 'የዚህ ምዕራፍ ጽሑፍ ይሰረዝ?';

  @override
  String get adminNoChaptersYet => 'እስካሁን ምዕራፍ የለም። ለመጀመር አንዱን ይጨምሩ።';

  @override
  String adminVersesCount(int count) {
    return '$count ጥቅሶች';
  }

  @override
  String get adminSelectChapter => 'ለማረም ምዕራፍ ይምረጡ፣ ወይም አዲስ ይጨምሩ።';

  @override
  String get adminUnsavedChanges => 'ያልተቀመጡ ለውጦች';

  @override
  String get adminDiscardChangesConfirm => 'ያልተቀመጡ ለውጦች ይጣሉ?';

  @override
  String get adminDiscard => 'ጣል';

  @override
  String get adminDeleteChapter => 'ምዕራፍ ሰርዝ';

  @override
  String adminSectionLabel(int number) {
    return 'ክፍል $number';
  }

  @override
  String bibleResultsCount(int count) {
    return '$count ጥቅሶች';
  }

  @override
  String adminOrdersRange(int start, int end, int total) {
    return '$start–$end ከ$total';
  }

  @override
  String get adminReview => 'መርምር';

  @override
  String get adminOrderDetail => 'የትዕዛዝ ዝርዝር';

  @override
  String get adminCustomer => 'ደንበኛ';

  @override
  String get adminBook => 'መጽሐፍ';

  @override
  String get adminBank => 'ባንክ';

  @override
  String get adminReceipt => 'ደረሰኝ';

  @override
  String get adminNoReceipt => 'ደረሰኝ አልተጫነም';

  @override
  String get adminViewReceipt => 'ደረሰኝ ተመልከት';

  @override
  String get adminRejectReason => 'ምክንያት (አማራጭ)';

  @override
  String get adminApprove => 'አጽድቅና አጠናቅቅ';

  @override
  String get adminReject => 'ውድቅ አድርግ';

  @override
  String get adminApproved => 'ትዕዛዙ ጸድቆ ተጠናቋል';

  @override
  String get adminRejected => 'ትዕዛዙ ውድቅ ሆኗል';

  @override
  String get authorMyBooks => 'መጻሕፍቴ';

  @override
  String get paymentDate => 'ቀን';

  @override
  String get paymentMethod => 'መንገድ';

  @override
  String get paymentCommission => 'የመድረኩ ድርሻ';

  @override
  String get paymentOrderId => 'የትዕዛዝ ቁጥር';

  @override
  String get paymentPurchaseDetail => 'የግዢ ዝርዝር';

  @override
  String get adminOrdersAllStatuses => 'ሁሉም';

  @override
  String get paymentStatusColumn => 'ሁኔታ';

  @override
  String get authorApplyEntryTitle => 'ደራሲ ይሁኑ';

  @override
  String get authorApplyEntrySubtitle => 'የራስዎን መጻሕፍት ለማውጣት ይጠይቁ';

  @override
  String get authorApplyTitle => 'የደራሲ ጥያቄ';

  @override
  String get authorApplyIntro =>
      'ስለ ራስዎ ይንገሩን። ቡድናችን እያንዳንዱን ጥያቄ ከመቀበሉ በፊት ይመረምራል።';

  @override
  String get authorApplyStatusPending => 'ጥያቄዎ በምርመራ ላይ ነው።';

  @override
  String get authorApplyStatusApproved => 'እንደ ደራሲ ተቀብለዋል!';

  @override
  String get authorApplyStatusRejected => 'ጥያቄዎ አልተቀበለም። አድሰው እንደገና መላክ ይችላሉ።';

  @override
  String get authorApplyReviewNoteLabel => 'የመርማሪ ማስታወሻ';

  @override
  String get authorApplyAlreadyAuthor => 'አስቀድመው ደራሲ ነዎት።';

  @override
  String get authorApplyManageBooks => 'መጻሕፍትዎን ያቀናብሩ';

  @override
  String get authorApplySubmit => 'ጥያቄ ላክ';

  @override
  String get authorApplyResubmit => 'አድሰው እንደገና ላክ';

  @override
  String get authorApplySubmitted => 'ጥያቄ ተልኳል';

  @override
  String get authorApplyFailed => 'ጥያቄዎን መላክ አልተቻለም።';

  @override
  String get authorApplySectionIdentity => 'ስለ እርስዎ';

  @override
  String get authorApplySectionEvidence => 'የሚደግፍ መረጃ';

  @override
  String get authorApplySectionPayout => 'የክፍያ መረጃ (አማራጭ)';

  @override
  String get authorFieldFullName => 'ሙሉ ስም';

  @override
  String get authorFieldFullNameHint => 'በሕግ የሚታወቀው ስምዎ';

  @override
  String get authorFieldPenName => 'የጽሑፍ ስም';

  @override
  String get authorFieldPenNameHint => 'በመጻሕፍትዎ ላይ የሚታየው ስም';

  @override
  String get authorFieldTitle => 'ማዕረግ';

  @override
  String get authorFieldTitleHint => 'ለምሳሌ ቀሲስ፣ ዲያቆን፣ ዶክተር';

  @override
  String get authorFieldBio => 'አጭር ታሪክ';

  @override
  String get authorFieldBioHint => 'አጭር መግቢያ';

  @override
  String get authorFieldPhone => 'ስልክ';

  @override
  String get authorFieldCountry => 'ሀገር';

  @override
  String get authorFieldCredentials => 'ትምህርትና ማስረጃ';

  @override
  String get authorFieldCredentialsHint => 'ትምህርት፣ ክህነት፣ ምስክር ወረቀቶች';

  @override
  String get authorFieldSampleLinks => 'የጽሑፍ ናሙና / አድራሻ';

  @override
  String get authorFieldSampleLinksHint => 'ቀድሞ የሠሩት ሥራ አድራሻ (አንድ በአንድ መስመር)';

  @override
  String get authorFieldPaymentEmail => 'የክፍያ ኢሜይል';

  @override
  String get authorFieldTelebirr => 'የቴሌብር ቁጥር';

  @override
  String get authorFieldPhoto => 'የግል ፎቶ';

  @override
  String get authorPhotoPick => 'ፎቶ ምረጥ';

  @override
  String get authorPhotoChange => 'ፎቶ ቀይር';

  @override
  String get authorPhotoUploading => 'ፎቶ እየተጫነ ነው…';

  @override
  String get authorFullNameRequired => 'እባክዎ ሙሉ ስምዎን ያስገቡ';

  @override
  String get adminAuthorAppsTitle => 'የደራሲ ጥያቄዎች';

  @override
  String get adminAuthorAppsSubtitle => 'ደራሲ ለመሆን የቀረቡ ጥያቄዎችን ይመልከቱ';

  @override
  String get adminAuthorAppsEmpty => 'እስካሁን የደራሲ ጥያቄ የለም';

  @override
  String get adminAuthorAppsNoMatch => 'ከማጣሪያው ጋር የሚመጥን ጥያቄ የለም';

  @override
  String get adminAuthorAppStatusPending => 'በመጠባበቅ';

  @override
  String get adminAuthorAppStatusApproved => 'ጸድቋል';

  @override
  String get adminAuthorAppStatusRejected => 'ውድቅ ሆኗል';

  @override
  String get adminAuthorAppReviewTitle => 'ጥያቄ';

  @override
  String get adminAuthorAppApproveConfirm => 'ይህን ደራሲ ያጸድቃሉ?';

  @override
  String get adminAuthorAppApproveConfirmBody =>
      'የደራሲ ኃላፊነት ይሰጣልና የደራሲ መገለጫ ይፈጥራል።';

  @override
  String get adminAuthorAppApplicant => 'ጠያቂ';

  @override
  String get adminAuthorAppPendingReviews => 'በመጠባበቅ ያሉ ጥያቄዎች';

  @override
  String get adminAuthorAppUnnamed => 'ስም ያልተሰጠ ጠያቂ';
}
