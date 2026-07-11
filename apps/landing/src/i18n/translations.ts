export type Lang = 'en' | 'am';

export type Dict = {
  nav: { features: string; platforms: string; download: string };
  cta: { login: string; getStarted: string; openWebApp: string };
  hero: {
    eyebrow: string;
    titleA: string;
    titleB: string;
    subtitle: string;
    freeLine: string;
    downloadApp: string;
    downloadFor: string; // uses {os}
    chooseAnother: string;
    cards: { bible: string; praise: string; synax: string };
  };
  features: {
    eyebrow: string;
    heading: string;
    sub: string;
    items: { title: string; body: string }[];
  };
  platforms: {
    eyebrow: string;
    heading: string;
    body: string;
    openWebApp: string;
    allDownloads: string;
  };
  ctaSection: { heading: string; body: string; createAccount: string; openWebApp: string };
  footer: { webApp: string; rights: string; builtFor: string };
  download: {
    eyebrow: string;
    title: string; // uses {name}
    sub: string;
    openInstead: string;
    help: string; // uses {email} placeholder handled in component
    comingSoon: string;
    downloadExt: string; // uses {ext}
    freeNote: string;
    yourDevice: string;
  };
  // Per-platform copy (os display names stay untranslated).
  plat: Record<'android' | 'macos' | 'windows' | 'linux', { note: string; install: string[] }>;
  langName: string;
};

export const dict: Record<Lang, Dict> = {
  en: {
    nav: { features: 'Features', platforms: 'Platforms', download: 'Download' },
    cta: { login: 'Log in', getStarted: 'Get started', openWebApp: 'Open the web app' },
    hero: {
      eyebrow: 'ፈለገ መጻሕፍት · Ethiopian Orthodox Library',
      titleA: 'The sacred books of the Church,',
      titleB: 'beautifully in your pocket',
      subtitle:
        'Read Ethiopian Orthodox Tewahedo books and the Holy Bible with a calm, modern reader — offline access, highlights, notes and daily reading plans. On every device you own.',
      freeLine: 'Free · Web · Android · macOS · Windows · Linux',
      downloadApp: 'Download the app',
      downloadFor: 'Download for {os}',
      chooseAnother: 'or choose another platform →',
      cards: { bible: 'Holy Bible · 81 books', praise: 'Praise of St. Mary', synax: 'Synaxarium · daily' },
    },
    features: {
      eyebrow: 'Why Felege Metsahft',
      heading: 'A reverent reading experience, thoughtfully modern',
      sub: 'Everything you need to read, study and treasure the books of the Church.',
      items: [
        { title: 'Full Orthodox library', body: 'The Holy Bible with all 81 books, plus liturgical and spiritual works — organized by genre and searchable in Amharic and Geʽez.' },
        { title: 'Read offline, anywhere', body: 'Download books for secure offline reading. Your library travels with you — on the bus, in church, or off the grid.' },
        { title: 'Highlights & notes', body: 'Mark meaningful passages, write personal reflections, and revisit them any time across all your devices.' },
        { title: 'Reading plans', body: 'Follow guided daily plans and gentle reminders to keep a steady rhythm of Scripture and study.' },
        { title: 'Fast, tolerant search', body: 'Find verses and passages instantly — even with partial spelling — with full-text search built for Ethiopic script.' },
        { title: 'Synced everywhere', body: 'Your progress, favorites and notes stay in sync between web, phone and desktop through your free account.' },
      ],
    },
    platforms: {
      eyebrow: 'One account, every device',
      heading: 'Available wherever you pray and study',
      body: 'Start on the web in seconds, or install the native app for a faster, offline-first experience. Sign in once and pick up right where you left off.',
      openWebApp: 'Open web app',
      allDownloads: 'All downloads',
    },
    ctaSection: {
      heading: 'Begin your journey through the sacred books today',
      body: 'Create a free account and carry the treasures of the Church wherever you go.',
      createAccount: 'Create free account',
      openWebApp: 'Open web app',
    },
    footer: {
      webApp: 'Web app',
      rights: 'All rights reserved.',
      builtFor: 'Built for the Ethiopian Orthodox Tewahedo community.',
    },
    download: {
      eyebrow: 'Install the app',
      title: 'Get {name} on your device',
      sub: 'Choose your platform below. Prefer not to install? You can use everything right in your browser.',
      openInstead: 'Open the web app instead',
      help: 'Having trouble installing? Email us at',
      comingSoon: 'Coming soon',
      downloadExt: 'Download {ext}',
      freeNote: 'Free forever · No ads · Sync across all your devices',
      yourDevice: 'Your device',
    },
    plat: {
      android: { note: 'Android 8.0 or newer', install: [
        'Tap the download button to get the .apk file.',
        'Open the file and, if asked, allow installs from this source.',
        'Tap Install, then open Felege Metsahft.',
      ] },
      macos: { note: 'macOS 11 Big Sur or newer', install: [
        'Open the downloaded .dmg and drag the app into your Applications folder.',
        'In Applications, right-click the app → Open, then click Open in the dialog (first launch only).',
        'If macOS says the app is “damaged”, open Terminal and run: xattr -dr com.apple.quarantine /Applications/ethiopian_reader.app',
      ] },
      windows: { note: 'Windows 10/11 (64-bit)', install: [
        'Download and run felege-metsahft-setup.exe.',
        'If SmartScreen appears, choose More info → Run anyway.',
        'Follow the installer, then launch Felege Metsahft.',
      ] },
      linux: { note: '64-bit · GTK 3 desktop', install: [
        'Download and extract: tar -xzf felege-metsahft-linux-x64.tar.gz',
        'Enter the folder: cd FelegeMetsahft',
        'Run it: ./ethiopian_reader',
      ] },
    },
    langName: 'English',
  },

  am: {
    nav: { features: 'ባህሪያት', platforms: 'መድረኮች', download: 'አውርድ' },
    cta: { login: 'ግባ', getStarted: 'ጀምር', openWebApp: 'የድር መተግበሪያውን ክፈት' },
    hero: {
      eyebrow: 'ፈለገ መጻሕፍት · የኢትዮጵያ ኦርቶዶክስ ቤተ መጻሕፍት',
      titleA: 'የቤተ ክርስቲያን ቅዱሳት መጻሕፍት፣',
      titleB: 'በእጅዎ ውስጥ በውበት',
      subtitle:
        'የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ መጻሕፍትንና መጽሐፍ ቅዱስን በተረጋጋና ዘመናዊ አንባቢ ያንብቡ — ከበይነመረብ ውጭ ማንበብ፣ ማድመቅ፣ ማስታወሻዎችና ዕለታዊ የንባብ ዕቅዶች። በሁሉም መሣሪያዎችዎ ላይ።',
      freeLine: 'ነጻ · ድር · አንድሮይድ · ማክ · ዊንዶውስ · ሊኑክስ',
      downloadApp: 'መተግበሪያውን አውርድ',
      downloadFor: 'ለ{os} አውርድ',
      chooseAnother: 'ወይም ሌላ መድረክ ይምረጡ →',
      cards: { bible: 'መጽሐፍ ቅዱስ · 81 መጻሕፍት', praise: 'ውዳሴ ማርያም', synax: 'ስንክሳር · ዕለታዊ' },
    },
    features: {
      eyebrow: 'ለምን ፈለገ መጻሕፍት?',
      heading: 'ክብር ያለው የንባብ ተሞክሮ፣ በዘመናዊ መልኩ',
      sub: 'የቤተ ክርስቲያንን መጻሕፍት ለማንበብ፣ ለማጥናትና ለመጠበቅ የሚያስፈልግዎ ሁሉ።',
      items: [
        { title: 'ሙሉ የኦርቶዶክስ ቤተ መጻሕፍት', body: 'መጽሐፍ ቅዱስን ከ81ዱ መጻሕፍት ጋር፣ እንዲሁም የሥርዓተ ቅዳሴና መንፈሳዊ ሥራዎችን — በዘውግ የተደራጀ በአማርኛና በግዕዝ የሚፈለግ።' },
        { title: 'ከበይነመረብ ውጭ ማንበብ', body: 'መጻሕፍትን አውርደው በደኅንነት ከበይነመረብ ውጭ ያንብቡ። ቤተ መጻሕፍትዎ ከእርስዎ ጋር ይጓዛል — በአውቶቡስ፣ በቤተ ክርስቲያን ወይም ያለ ኢንተርኔት።' },
        { title: 'ማድመቅና ማስታወሻዎች', body: 'ትርጉም ያላቸውን ክፍሎች ምልክት ያድርጉ፣ የግል ማስተንተኖችን ይጻፉ፣ በሁሉም መሣሪያዎችዎ ላይ በማንኛውም ጊዜ ይመለሱባቸው።' },
        { title: 'የንባብ ዕቅዶች', body: 'የተመሩ ዕለታዊ ዕቅዶችንና ገር ማስታወሻዎችን በመከተል የቅዱሳት መጻሕፍት ንባብ ቋሚ ምት ይኑርዎ።' },
        { title: 'ፈጣንና ታጋሽ ፍለጋ', body: 'ጥቅሶችንና ክፍሎችን ወዲያውኑ ያግኙ — በከፊል ፊደል እንኳ — ለግዕዝ ፊደል በተዘጋጀ ሙሉ የጽሑፍ ፍለጋ።' },
        { title: 'በሁሉም ቦታ የተመሳሰለ', body: 'እድገትዎ፣ ተወዳጆችዎና ማስታወሻዎችዎ በነጻ መለያዎ አማካኝነት በድር፣ በስልክና በኮምፒውተር መካከል ተመሳስለው ይቆያሉ።' },
      ],
    },
    platforms: {
      eyebrow: 'አንድ መለያ፣ ለሁሉም መሣሪያ',
      heading: 'በሚጸልዩበትና በሚያጠኑበት ሁሉ ይገኛል',
      body: 'በሰከንዶች ውስጥ በድር ይጀምሩ፣ ወይም ለፈጣንና ከበይነመረብ ውጭ ለሚሰራ ተሞክሮ የመጫኛ መተግበሪያውን ይጫኑ። አንድ ጊዜ ይግቡና ካቆሙበት ይቀጥሉ።',
      openWebApp: 'የድር መተግበሪያ ክፈት',
      allDownloads: 'ሁሉም ማውረጃዎች',
    },
    ctaSection: {
      heading: 'ዛሬ በቅዱሳት መጻሕፍት ጉዞዎን ይጀምሩ',
      body: 'ነጻ መለያ ይክፈቱና የቤተ ክርስቲያንን ውድ ሀብቶች በሚሄዱበት ሁሉ ይያዙ።',
      createAccount: 'ነጻ መለያ ይክፈቱ',
      openWebApp: 'የድር መተግበሪያ ክፈት',
    },
    footer: {
      webApp: 'የድር መተግበሪያ',
      rights: 'መብቱ በሕግ የተጠበቀ ነው።',
      builtFor: 'ለኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ማኅበረሰብ የተሰራ።',
    },
    download: {
      eyebrow: 'መተግበሪያውን ይጫኑ',
      title: '{name}ን በመሣሪያዎ ላይ ያግኙ',
      sub: 'ከታች መድረክዎን ይምረጡ። መጫን አይፈልጉም? ሁሉንም ነገር በአሳሽዎ ውስጥ መጠቀም ይችላሉ።',
      openInstead: 'በምትኩ የድር መተግበሪያውን ክፈት',
      help: 'በመጫን ላይ ችግር ገጠመዎት? በኢሜይል ያግኙን፦',
      comingSoon: 'በቅርቡ ይመጣል',
      downloadExt: '{ext} አውርድ',
      freeNote: 'ለዘላለም ነጻ · ማስታወቂያ የለም · በሁሉም መሣሪያዎችዎ ላይ ተመሳስሎ',
      yourDevice: 'የእርስዎ መሣሪያ',
    },
    plat: {
      android: { note: 'አንድሮይድ 8.0 ወይም ከዚያ በላይ', install: [
        'የማውረጃ ቁልፉን ተጭነው የ.apk ፋይሉን ያግኙ።',
        'ፋይሉን ይክፈቱ፣ ከተጠየቁ ከዚህ ምንጭ መጫንን ይፍቀዱ።',
        'ጫን የሚለውን ተጭነው ፈለገ መጻሕፍትን ይክፈቱ።',
      ] },
      macos: { note: 'ማክ 11 Big Sur ወይም ከዚያ በላይ', install: [
        'የወረደውን .dmg ከፍተው መተግበሪያውን ወደ Applications አቃፊ ይጎትቱ።',
        'በApplications ውስጥ መተግበሪያውን በቀኝ ተጭነው → Open፣ ከዚያ በሳጥኑ ላይ Open ይምረጡ (ለመጀመሪያ ጊዜ ብቻ)።',
        'ማክ “damaged” ካለ Terminal ከፍተው ይህን ያስኪዱ፦ xattr -dr com.apple.quarantine /Applications/ethiopian_reader.app',
      ] },
      windows: { note: 'ዊንዶውስ 10/11 (64-ቢት)', install: [
        'felege-metsahft-setup.exe ን አውርደው ያስኪዱ።',
        'SmartScreen ከታየ More info → Run anyway ይምረጡ።',
        'ጫኚውን ተከትለው ፈለገ መጻሕፍትን ይክፈቱ።',
      ] },
      linux: { note: '64-ቢት · GTK 3 ዴስክቶፕ', install: [
        'አውርደው ይክፈቱ፦ tar -xzf felege-metsahft-linux-x64.tar.gz',
        'ወደ አቃፊው ይግቡ፦ cd FelegeMetsahft',
        'ያስኪዱት፦ ./ethiopian_reader',
      ] },
    },
    langName: 'አማርኛ',
  },
};
