#ifndef PublishDir
  #define PublishDir "..\artifacts\publish"
#endif
#ifndef OutputDir
  #define OutputDir "..\artifacts\installer"
#endif
[Setup]
AppId={{0270D2AE-EEAD-4D3E-9933-930B6AEBE13C}
AppName=Dynamics GP UserOps
AppVersion=4.0.0
AppVerName=Dynamics GP UserOps 4.0.0
AppPublisher=Dynamics GP UserOps
AppPublisherURL=https://github.com/juanrovalle/dynamics-gp-users-manager
DefaultDirName={autopf}\Dynamics GP UserOps
DefaultGroupName=Dynamics GP UserOps
UninstallDisplayIcon={app}\DynamicsGPUserOps.exe
SetupIconFile=..\assets\DynamicsGPUserOps.ico
VersionInfoVersion=4.0.0.0
VersionInfoCompany=Dynamics GP UserOps
VersionInfoDescription=Dynamics GP UserOps Setup
VersionInfoProductName=Dynamics GP UserOps
VersionInfoProductVersion=4.0.0
OutputDir={#OutputDir}
OutputBaseFilename=Setup
LicenseFile=..\LICENSE
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
; Lower common minimum; InitializeSetup separately checks workstation/server types.
MinVersion=10.0.14393
CloseApplications=yes
RestartApplications=no
SetupLogging=yes
#ifdef SignedBuild
SignTool=release
SignedUninstaller=yes
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Dynamics GP UserOps"; Filename: "{app}\DynamicsGPUserOps.exe"
Name: "{group}\Installation and testing guide"; Filename: "{app}\docs\installation-and-testing.en.html"
Name: "{group}\Guía de instalación y pruebas"; Filename: "{app}\docs\installation-and-testing.es.html"
Name: "{group}\Windows Server guide (English)"; Filename: "{app}\docs\windows-server.en.html"
Name: "{group}\Guía Windows Server (Español)"; Filename: "{app}\docs\windows-server.es.html"
Name: "{group}\Guías - Guides"; Filename: "{app}\docs\index.html"
Name: "{group}\Uninstall Dynamics GP UserOps"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\DynamicsGPUserOps.exe"; Description: "{cm:LaunchProgram,Dynamics GP UserOps}"; Flags: nowait postinstall skipifsilent runasoriginaluser

[Code]
#include "WindowsPlatform.iss"

const
  LegacyUninstallKey = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8C64DB3C-F159-4FF8-81B0-2393263F5F25}_is1';

function LegacyIsInstalled(): Boolean;
begin
  Result := RegKeyExists(HKLM64, LegacyUninstallKey);
end;

function LegacyText(EnglishText, SpanishText: String): String;
begin
  if ActiveLanguage = 'spanish' then Result := SpanishText
  else Result := EnglishText;
end;

function LegacySilentMode(): Boolean;
begin
  Result := WizardSilent;
end;

function LegacyConsoleRunning(): Boolean;
begin
  Result := FindWindowByWindowName('GP Users Manager') <> 0;
end;

function LegacyUninstaller(var Command: String): Boolean;
begin
  Result := RegQueryStringValue(HKLM64, LegacyUninstallKey, 'UninstallString', Command);
  if Result then Result := (Trim(Command) <> '') and FileExists(RemoveQuotes(Command));
end;

function ConfirmLegacyReplacement(): Boolean;
var
  MessageText: String;
begin
  MessageText := LegacyText(
    'GP Users Manager 3.x was detected. Setup will remove only the previous Windows console and then install Dynamics GP UserOps. SQL databases, data, and SQL Server Agent jobs will continue running. The password-free profile will be imported on first launch.',
    'Se detectó GP Users Manager 3.x. Setup retirará únicamente la consola anterior y luego instalará Dynamics GP UserOps. Las bases, datos y jobs de SQL Server Agent continuarán funcionando. El perfil sin contraseña se importará en el primer inicio.');
  Result := SuppressibleMsgBox(MessageText, mbConfirmation, MB_OKCANCEL, IDOK) = IDOK;
end;

function RunLegacyUninstaller(Command: String): Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec(RemoveQuotes(Command), '/SILENT /NORESTART', '', SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode);
  if Result then Result := ResultCode = 0;
end;

#include "LegacyUpgrade.iss"

function InitializeSetup(): Boolean;
var
  MessageText: String;
begin
  Result := UserOpsCurrentPlatformSupported();
  if Result then Exit;
  if ActiveLanguage = 'spanish' then
    MessageText := 'Dynamics GP UserOps requiere Windows 11 x64 o Windows Server 2016, 2019, 2022 o 2025 x64 con Desktop Experience. La consola no se instala en Server Core ni Nano Server. Utilice otro equipo con interfaz grafica para administrar el motor SQL remoto.'
  else
    MessageText := 'Dynamics GP UserOps requires Windows 11 x64 or Windows Server 2016, 2019, 2022 or 2025 x64 with Desktop Experience. The console cannot be installed on Server Core or Nano Server. Use another graphical computer to administer the remote SQL engine.';
  Log(MessageText);
  SuppressibleMsgBox(MessageText, mbCriticalError, MB_OK, IDOK);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := UserOpsPrepareLegacyUpgrade();
end;

function InitializeUninstall(): Boolean;
begin
  if ActiveLanguage = 'spanish' then
    MsgBox('Desinstalar elimina la consola, no las bases de datos ni el job de SQL Server Agent. La automatización seguirá funcionando. Si desea detenerla, cancele y utilice Pause automation antes de desinstalar. El perfil local sin contraseña también se conserva.', mbInformation, MB_OK)
  else
    MsgBox('Uninstall removes the console only. SQL databases and the SQL Server Agent job are retained and automation continues. To stop it, cancel and pause automation in the console first. The password-free local connection profile is also retained.', mbInformation, MB_OK);
  Result := True;
end;
