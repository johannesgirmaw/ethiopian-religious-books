; Inno Setup script — packages the Flutter Windows release build into a single
; installer: felege-metsahft-setup.exe (Start Menu + optional desktop shortcut,
; clean uninstall). Compiled by the GitHub Actions Windows job.
;
; Overridable defines (passed via ISCC /D...):
;   MyAppVersion  — e.g. 1.0.0   (from pubspec)
;   SourceDir     — path to build\windows\x64\runner\Release
;   OutputDir     — where to write the setup .exe

#define MyAppName "Ethiopian Reader"
#define MyAppPublisher "Felege Metsahft"
#define MyAppURL "https://felegemetsahft.com"
#define MyAppExeName "ethiopian_reader.exe"

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "installer_out"
#endif

[Setup]
; Stable AppId so upgrades/uninstall track the same product. Do not change.
AppId={{8F3A1C2E-5B4D-4E6F-9A7B-2C1D3E4F5A6B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\Ethiopian Reader
DefaultGroupName=Ethiopian Reader
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir={#OutputDir}
OutputBaseFilename=felege-metsahft-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\Ethiopian Reader"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall Ethiopian Reader"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Ethiopian Reader"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Ethiopian Reader"; Flags: nowait postinstall skipifsilent
