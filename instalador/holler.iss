; Instalador do HOLLER (Inno Setup 6). Montado automaticamente pelo GitHub Actions.
; Instala so para o usuario atual: nao pede senha de administrador.
#ifndef Versao
  #define Versao "0.0.0"
#endif

[Setup]
AppId={{7B0C2D0E-6E6A-4B57-9C0D-60919871024A}
AppName=HOLLER
AppVersion={#Versao}
AppVerName=HOLLER {#Versao}
AppPublisher=HOLLER
DefaultDirName={autopf}\HOLLER
DisableProgramGroupPage=yes
DisableDirPage=auto
DisableReadyPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\build
OutputBaseFilename=HOLLER-Instalador
SetupIconFile=holler.ico
UninstallDisplayIcon={app}\HOLLER.exe
UninstallDisplayName=HOLLER
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
CloseApplications=yes

[Languages]
Name: "ptbr"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Files]
Source: "..\build\HOLLER.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "LEIAME.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autodesktop}\HOLLER"; Filename: "{app}\HOLLER.exe"; WorkingDir: "{app}"; Comment: "Jogar HOLLER"
Name: "{autoprograms}\HOLLER"; Filename: "{app}\HOLLER.exe"; WorkingDir: "{app}"; Comment: "Jogar HOLLER"

[Run]
Filename: "{app}\HOLLER.exe"; Description: "Jogar HOLLER agora"; Flags: nowait postinstall skipifsilent
