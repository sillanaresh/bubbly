#define MyAppName "Bubbly"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "Bubbly"
#define MyAppExeName "Bubbly.Windows.exe"

[Setup]
AppId={{6D3C9386-715F-4B56-8C81-1C0B9B18C617}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\Bubbly
DefaultGroupName=Bubbly
DisableProgramGroupPage=yes
OutputDir=..\..\artifacts\installer
OutputBaseFilename=Bubbly-Windows-v1
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
SetupIconFile=bubbly-app-icon.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "..\..\artifacts\publish\Bubbly.Windows\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Bubbly"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\Bubbly"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Bubbly"; Flags: nowait postinstall skipifsilent
