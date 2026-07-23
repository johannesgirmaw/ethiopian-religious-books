// Central config for the landing site. Override download URLs via env at build time.
export const site = {
  /** Canonical product name — Amharic everywhere on the platform. */
  name: 'ፈለገ መጻሕፍት',
  /** Latin transliteration for SEO / schema alternateName only. */
  nameLatin: 'Felege Metsahft',
  tagline: 'Ethiopian Orthodox books, Scripture & study tools',
  description:
    'Read Ethiopian Orthodox Tewahedo books and the Holy Bible with powerful study tools — offline reading, highlights, notes, and reading plans. Available on the web, Android, macOS, Windows and Linux.',
  url: 'https://felegemetsahft.com',
  webApp: 'https://app.felegemetsahft.com',
  // Flutter web uses hash routing → /#/login.
  login: 'https://app.felegemetsahft.com/#/login',
  register: 'https://app.felegemetsahft.com/#/register',
  email: 'yohannesgirmaw23@gmail.com',
};

const dl = (file: string) => `https://felegemetsahft.com/downloads/${file}`;

export type Platform = {
  id: 'android' | 'macos' | 'windows' | 'linux';
  os: string;
  label: string;
  ext: string;
  url: string;
  size?: string;
  note: string;
  install: string[];
  comingSoon?: boolean;
};

export const platforms: Platform[] = [
  {
    id: 'android',
    os: 'Android',
    label: 'Download for Android',
    ext: 'APK',
    url: process.env.NEXT_PUBLIC_ANDROID_URL || dl('felege-metsahft.apk'),
    note: 'Android 8.0 or newer',
    install: [
      'Tap the download button to get the .apk file.',
      'Open the file and, if asked, allow installs from this source.',
      'Tap Install, then open ፈለገ መጻሕፍት.',
    ],
  },
  {
    id: 'macos',
    os: 'macOS',
    label: 'Download for macOS',
    ext: 'DMG',
    url: process.env.NEXT_PUBLIC_MACOS_URL || dl('felege-metsahft-macos.dmg'),
    note: 'macOS 11 Big Sur or newer',
    install: [
      'Open the downloaded .dmg file.',
      'Drag ፈለገ መጻሕፍት into your Applications folder.',
      'First launch: right-click the app → Open to bypass Gatekeeper.',
    ],
  },
  {
    id: 'linux',
    os: 'Linux',
    label: 'Download for Linux',
    ext: 'tar.gz',
    url: process.env.NEXT_PUBLIC_LINUX_URL || dl('felege-metsahft-linux-x64.tar.gz'),
    note: '64-bit · GTK 3 desktop',
    install: [
      'Download and extract: tar -xzf felege-metsahft-linux-x64.tar.gz',
      'Enter the folder: cd FelegeMetsahft',
      'Run it: ./ethiopian_reader',
    ],
  },
  {
    id: 'windows',
    os: 'Windows',
    label: 'Download for Windows',
    ext: 'EXE',
    url: process.env.NEXT_PUBLIC_WINDOWS_URL || dl('felege-metsahft-setup.exe'),
    note: 'Windows 10/11 (64-bit)',
    install: [
      'Download and run felege-metsahft-setup.exe.',
      'If SmartScreen appears, choose More info → Run anyway.',
      'Follow the installer, then launch ፈለገ መጻሕፍት from the Start Menu.',
    ],
  },
];
