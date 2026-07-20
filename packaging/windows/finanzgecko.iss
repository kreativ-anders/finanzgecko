; Inno-Setup-Skript für FinanzGecko (Windows).
;
; Erzeugt aus dem Flutter-Windows-Bundle (Executable + data/ + DLLs) einen
; einzigen Installer `FinanzGecko-<Version>-Setup.exe`, statt Testnutzern den
; rohen Bundle-Ordner zuzumuten: der Installer legt alles nach Program Files,
; setzt Start-Menü- (und optional Desktop-)Verknüpfungen und einen sauberen
; Uninstaller an. Das löst die Verwirrung, dass ein lose entpacktes Bundle wie
; ein Haufen loser Dateien aussieht und beim Löschen einzelner Dateien
; (DLLs / data/) nicht mehr startet. Der Dateiname trägt MyAppVersion (aus
; pubspec.yaml, via /DMyAppVersion), damit mehrere heruntergeladene Releases
; nebeneinander unterscheidbar bleiben.
;
; Aufruf (siehe .github/workflows/release.yml, Job "windows"):
;   iscc /DMyAppVersion=<X.Y.Z> /DBuildDir=<Pfad zu ...\Release> finanzgecko.iss
; Beide /D-Defines sind Pflicht; ohne sie bricht der Compiler unten ab.

#ifndef MyAppVersion
  #error "MyAppVersion nicht gesetzt — mit /DMyAppVersion=X.Y.Z aufrufen"
#endif
#ifndef BuildDir
  #error "BuildDir nicht gesetzt — mit /DBuildDir=<...\Release> aufrufen"
#endif

#define MyAppName "FinanzGecko"
#define MyAppExeName "finanzgecko.exe"
#define MyAppPublisher "Manuel Steinberg"

[Setup]
; Stabile AppId — NICHT ändern, sonst erkennt Windows Updates nicht als
; dieselbe Anwendung (Nebeneinander-Installation statt In-Place-Update).
AppId={{7C1E9A42-3B6D-4F58-9E2A-8D5C41B0F7A3}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\FinanzGecko
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputBaseFilename=FinanzGecko-{#MyAppVersion}-Setup
OutputDir=.
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
SetupIconFile=..\..\windows\runner\resources\app_icon.ico

; Nur Deutsch — die App ist durchgängig deutsch. Mit einer einzigen Sprache
; zeigt Inno Setup keinen Sprachauswahl-Dialog beim Start des Installers.
[Languages]
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\FinanzGecko"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\FinanzGecko"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,FinanzGecko}"; Flags: nowait postinstall skipifsilent
