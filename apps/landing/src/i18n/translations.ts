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
    scroll: string;
  };
  reader: { today: string; lead: string; verse: string; tail: string; progress: string };
  experience: {
    eyebrow: string;
    heading: string;
    body: string;
    stats: { value: string; label: string }[];
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
  footer: { webApp: string; rights: string; builtFor: string; toTop: string };
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
  langAria: string;
  menuAria: string;
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
      scroll: 'Scroll',
    },
    reader: {
      today: 'Today’s reading',
      lead: 'Open the books of the Church in a calm, focused reader — Geʽez and Amharic, verse by verse.',
      verse: 'My soul magnifies the Lord, and my spirit rejoices in God my Saviour.',
      tail: 'Highlight a line, leave a note, and pick up the same page on every device you own.',
      progress: 'Reading progress',
    },
    experience: {
      eyebrow: 'The library, in numbers',
      heading: 'A reverent reading experience',
      body: 'Felege Metsahft brings Scripture, liturgy and study into a calm modern reader — so the treasures of the Church stay with you, online and off, on every device you pray with.',
      stats: [
        { value: '81+', label: 'Canonical books' },
        { value: '6', label: 'Ways to read' },
        { value: '2', label: 'Sacred scripts' },
      ],
    },
    features: {
      eyebrow: 'Why ፈለገ መጻሕፍት',
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
      toTop: 'Back to top',
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
        'Tap Install, then open ፈለገ መጻሕፍት.',
      ] },
      macos: { note: 'macOS 11 Big Sur or newer', install: [
        'Open the downloaded .dmg and drag the app into your Applications folder.',
        'In Applications, right-click the app → Open, then click Open in the dialog (first launch only).',
        'If macOS says the app is “damaged”, open Terminal and run: xattr -dr com.apple.quarantine /Applications/ethiopian_reader.app',
      ] },
      windows: { note: 'Windows 10/11 (64-bit)', install: [
        'Download and run felege-metsahft-setup.exe.',
        'If SmartScreen appears, choose More info → Run anyway.',
        'Follow the installer, then launch ፈለገ መጻሕፍት.',
      ] },
      linux: { note: '64-bit · GTK 3 desktop', install: [
        'Download and extract: tar -xzf felege-metsahft-linux-x64.tar.gz',
        'Enter the folder: cd FelegeMetsahft',
        'Run it: ./ethiopian_reader',
      ] },
    },
    langName: 'English',
    langAria: 'Language',
    menuAria: 'Menu',
  },

  am: {
    nav: { features: 'ይዘቱ', platforms: 'መሣሪያዎች', download: 'ያውርዱ' },
    cta: { login: 'ይግቡ', getStarted: 'ይመዝገቡ', openWebApp: 'በድረ ገጽ ይክፈቱ' },
    hero: {
      eyebrow: 'ፈለገ መጻሕፍት · የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ቤተ መጻሕፍት',
      titleA: 'የቤተ ክርስቲያን ቅዱሳት መጻሕፍት',
      titleB: 'አሁን በእጅዎ ይገኛሉ',
      subtitle:
        'መጽሐፍ ቅዱስን፣ ውዳሴ ማርያምን፣ ስንክሳርንና የቤተ ክርስቲያንን ሌሎች መጻሕፍት በግዕዝና በአማርኛ ያንብቡ። በቤትም፣ በጉዞም፣ ኢንተርኔት ቢኖርም ባይኖርም ንባብዎ አይቋረጥም።',
      freeLine: 'ነጻ · ድረ ገጽ · አንድሮይድ · ማክ · ዊንዶውስ · ሊኑክስ',
      downloadApp: 'ወደ መሣሪያዎ ያውርዱ',
      downloadFor: 'ለ{os} ያውርዱ',
      chooseAnother: 'ሌላ መሣሪያ ይምረጡ →',
      cards: { bible: 'መጽሐፍ ቅዱስ · 81 ቅዱሳት መጻሕፍት', praise: 'ውዳሴ ማርያም', synax: 'ስንክሳር · የዕለቱ' },
      scroll: 'ወደ ታች',
    },
    reader: {
      today: 'የዛሬው ንባብ',
      lead: 'የቤተ ክርስቲያንን መጻሕፍት በትኩረት ያንብቡ — በግዕዝም በአማርኛም፣ ጥቅስ በጥቅስ።',
      verse: 'ነፍሴ ጌታን ታከብራለች፥ መንፈሴም በአምላኬ በመድኃኒቴ ሐሤት ታደርጋለች።',
      tail: 'የወደዱትን ጥቅስ ያድምቁ፣ ማስታወሻ ይጻፉ፤ ንባብዎ በሁሉም መሣሪያዎ ላይ ከቆመበት ይቀጥላል።',
      progress: 'የደረሱበት',
    },
    experience: {
      eyebrow: 'ቤተ መጻሕፍቱ በቁጥር',
      heading: 'ንባብ በአክብሮትና በትኩረት',
      body: 'ፈለገ መጻሕፍት መጽሐፍ ቅዱስን፣ ሥርዓተ ቅዳሴንና የትምህርተ ሃይማኖት መጻሕፍትን ወደ አንድ ቦታ ያመጣል። በሚጸልዩበትና በሚያጠኑበት ሁሉ — ኢንተርኔት ቢኖርም ባይኖርም — የቤተ ክርስቲያን ሀብት ከእርስዎ ጋር ነው።',
      stats: [
        { value: '81+', label: 'ቅዱሳት መጻሕፍት' },
        { value: '6', label: 'የንባብ መንገድ' },
        { value: '2', label: 'ግዕዝና አማርኛ' },
      ],
    },
    features: {
      eyebrow: 'ለምን ፈለገ መጻሕፍት?',
      heading: 'በቤተ ክርስቲያን ልማድ፣ በዘመኑ መገልገያ',
      sub: 'ለንባብ፣ ለትምህርት፣ ለጸሎት የሚያስፈልግዎ በአንድ ቦታ።',
      items: [
        { title: 'ሙሉ የቤተ ክርስቲያን ቤተ መጻሕፍት', body: 'መጽሐፍ ቅዱስ በ81ዱ መጻሕፍቱ፣ እንዲሁም ቅዳሴ፣ ውዳሴ፣ ስንክሳርና ገድላት — በአማርኛና በግዕዝ ይፈልጉ።' },
        { title: 'ያለ ኢንተርኔትም ያንብቡ', body: 'መጽሐፉን አንዴ ካወረዱ በኋላ በአውቶቡስም፣ በቤተ ክርስቲያንም፣ ኢንተርኔት በሌለበትም ያንብቡ።' },
        { title: 'ማድመቂያና ማስታወሻ', body: 'የወደዱትን ጥቅስ ያድምቁ፣ የልብዎን ቃል ይጻፉ፤ በሁሉም መሣሪያዎ ላይ ይመለሱበታል።' },
        { title: 'የዕለት ንባብ', body: 'እንደ ቤተ ክርስቲያን ልማድ ዕለታዊ ንባብ ይከተሉ፤ ማስታወሻ ይደርስዎታል።' },
        { title: 'በግዕዝ ፊደል የሚሠራ ፍለጋ', body: 'ጥቅሱን ወዲያውኑ ያግኙ — ፊደል ቢስትም እንኳ።' },
        { title: 'በሁሉም መሣሪያ አንድ ንባብ', body: 'የደረሱበት፣ ያደመቁትና የጻፉት በነጻ መለያዎ በስልክ፣ በኮምፒውተርና በድረ ገጽ አንድ ይሆናል።' },
      ],
    },
    platforms: {
      eyebrow: 'አንድ መለያ፣ በሚሄዱበት ሁሉ',
      heading: 'በሚጸልዩበትና በሚያጠኑበት ሁሉ',
      body: 'በድረ ገጽ ወዲያውኑ ይጀምሩ፤ ወይም መጽሐፉን ወደ መሣሪያዎ ያውርዱ። አንድ ጊዜ ከገቡ በኋላ ካቆሙበት ይቀጥላሉ።',
      openWebApp: 'በድረ ገጽ ይክፈቱ',
      allDownloads: 'ሁሉንም ያውርዱ',
    },
    ctaSection: {
      heading: 'ዛሬ ንባብዎን ይጀምሩ',
      body: 'ነጻ መለያ ይክፈቱ፤ የቤተ ክርስቲያን ውድ መጻሕፍት በሚሄዱበት ሁሉ ከእርስዎ ጋር ይሁኑ።',
      createAccount: 'ነጻ ይመዝገቡ',
      openWebApp: 'በድረ ገጽ ይክፈቱ',
    },
    footer: {
      webApp: 'ድረ ገጽ',
      rights: 'መብቱ በሕግ የተጠበቀ ነው።',
      builtFor: 'ለኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ሕዝብ የተሠራ።',
      toTop: 'ወደ ላይ',
    },
    download: {
      eyebrow: 'ወደ መሣሪያዎ ያውርዱ',
      title: '{name}ን ወደ መሣሪያዎ ያምጡ',
      sub: 'ከታች መሣሪያዎን ይምረጡ። መጫን ካልፈለጉ በድረ ገጽ ሁሉንም መጠቀም ይችላሉ።',
      openInstead: 'በድረ ገጽ ይክፈቱ',
      help: 'በመጫን ላይ ችግር ገጠመዎት? በኢሜይል ያግኙን፦',
      comingSoon: 'በቅርቡ ይመጣል',
      downloadExt: '{ext} ያውርዱ',
      freeNote: 'ሁልጊዜ ነጻ · ማስታወቂያ የለም · በሁሉም መሣሪያዎ ላይ አንድ ንባብ',
      yourDevice: 'የእርስዎ መሣሪያ',
    },
    plat: {
      android: { note: 'አንድሮይድ 8.0 ወይም ከዚያ በላይ', install: [
        'ያውርዱ የሚለውን ይንኩና የ.apk ፋይሉን ይቀበሉ።',
        'ፋይሉን ይክፈቱ፤ ከተጠየቁ ከዚህ ምንጭ መጫንን ይፍቀዱ።',
        'ጫን ብለው ፈለገ መጻሕፍትን ይክፈቱ።',
      ] },
      macos: { note: 'ማክ 11 Big Sur ወይም ከዚያ በላይ', install: [
        'የወረደውን .dmg ከፍተው መተግበሪያውን ወደ Applications አቃፊ ይጎትቱ።',
        'በApplications ውስጥ በቀኝ ይንኩና Open ይበሉ፤ በሳጥኑም Open ይምረጡ (ለመጀመሪያ ጊዜ ብቻ)።',
        'ማክ “damaged” ካለ Terminal ከፍተው ይህን ያስኪዱ፦ xattr -dr com.apple.quarantine /Applications/ethiopian_reader.app',
      ] },
      windows: { note: 'ዊንዶውስ 10/11 (64-ቢት)', install: [
        'felege-metsahft-setup.exe ን አውርደው ይክፈቱ።',
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
    langAria: 'ቋንቋ',
    menuAria: 'ዝርዝር',
  },
};
