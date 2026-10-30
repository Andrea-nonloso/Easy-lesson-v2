; Installer Windows di Easy Lesson (Inno Setup 6).
; Si compila da build_windows.ps1 dopo "flutter build windows --release".

#define MyAppName "Easy Lesson"
#define MyAppVersion "2.0.0"
#define MyAppExe "easy_lesson.exe"

[Setup]
AppId={{8E3B6C2A-5F1D-4C7B-9A2E-EA51E550A002}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=Easy Lesson
DefaultDirName={autopf}\Easy Lesson
DefaultGroupName=Easy Lesson
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=EasyLesson-Setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExe}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExe}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
