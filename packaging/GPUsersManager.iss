#ifndef PublishDir
  #define PublishDir "..\artifacts\publish"
#endif
#ifndef OutputDir
  #define OutputDir "..\artifacts\installer"
#endif
[Setup]
AppId={{8C64DB3C-F159-4FF8-81B0-2393263F5F25}
AppName=GP Users Manager
AppVersion=3.0.1
AppVerName=GP Users Manager 3.0.1
AppPublisher=GP Users Manager
DefaultDirName={autopf}\GP Users Manager
DefaultGroupName=GP Users Manager
UninstallDisplayIcon={app}\GPUsersManager.exe
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
Name: "{group}\GP Users Manager"; Filename: "{app}\GPUsersManager.exe"
Name: "{group}\Installation and testing guide"; Filename: "{app}\docs\installation-and-testing.html"
Name: "{group}\Uninstall GP Users Manager"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\GPUsersManager.exe"; Description: "{cm:LaunchProgram,GP Users Manager}"; Flags: nowait postinstall skipifsilent runasoriginaluser

[Code]
#include "WindowsPlatform.iss"

function InitializeSetup(): Boolean;
var
  MessageText: String;
begin
  Result := GPUMCurrentPlatformSupported();
  if Result then Exit;
  if ActiveLanguage = 'spanish' then
    MessageText := 'GP Users Manager requiere Windows 11 x64 o Windows Server 2016, 2019, 2022 o 2025 x64 con Desktop Experience. La consola no se instala en Server Core ni Nano Server. Utilice otro equipo con interfaz grafica para administrar el motor SQL remoto.'
  else
    MessageText := 'GP Users Manager requires Windows 11 x64 or Windows Server 2016, 2019, 2022 or 2025 x64 with Desktop Experience. The console cannot be installed on Server Core or Nano Server. Use another graphical computer to administer the remote SQL engine.';
  Log(MessageText);
  SuppressibleMsgBox(MessageText, mbCriticalError, MB_OK, IDOK);
end;

function InitializeUninstall(): Boolean;
begin
  if ActiveLanguage = 'spanish' then
    MsgBox('Desinstalar elimina la consola, no las bases de datos ni el job de SQL Server Agent. La automatización seguirá funcionando. Si desea detenerla, cancele y utilice Pausar automatización antes de desinstalar. El perfil local sin contraseña también se conserva.', mbInformation, MB_OK)
  else
    MsgBox('Uninstall removes the console only. SQL databases and the SQL Server Agent job are retained and automation continues. To stop it, cancel and pause automation in the console first. The password-free local connection profile is also retained.', mbInformation, MB_OK);
  Result := True;
end;
