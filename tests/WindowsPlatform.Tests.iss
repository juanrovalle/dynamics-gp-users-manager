// No application files, shortcuts, registry values, or uninstaller are installed.
// InitializeSetup always returns False after writing the test result to /LOG.
[Setup]
AppName=GPUM platform policy tests
AppVersion=1.0
DefaultDirName={tmp}\GPUM-platform-tests
CreateAppDir=no
Uninstallable=no
PrivilegesRequired=lowest
ArchitecturesAllowed=x64os
OutputDir=..\artifacts\platform-tests
OutputBaseFilename=PlatformTests
SetupLogging=yes

[Code]
#include "..\packaging\WindowsPlatform.iss"

var
  Passed: Integer;

procedure CheckPlatform(Name: String; Major, Minor, Build, ProductType: Cardinal;
  InstallationType: String; Expected: Boolean);
begin
  if GPUMPlatformSupported(Major, Minor, Build, ProductType, InstallationType) <> Expected then
    RaiseException('GPUM_PLATFORM_FAIL: ' + Name);
  Passed := Passed + 1;
  Log('PASS ' + Name);
end;

function InitializeSetup(): Boolean;
begin
  Passed := 0;
  CheckPlatform('Server 2016 Desktop', 10, 0, 14393, VER_NT_SERVER, 'Server', True);
  CheckPlatform('Server 2019 Desktop', 10, 0, 17763, VER_NT_SERVER, 'Server', True);
  CheckPlatform('Server 2022 Desktop', 10, 0, 20348, VER_NT_SERVER, 'Server', True);
  CheckPlatform('Server 2025 Desktop', 10, 0, 26100, VER_NT_SERVER, 'Server', True);
  CheckPlatform('Server 2016 Core', 10, 0, 14393, VER_NT_SERVER, 'Server Core', False);
  CheckPlatform('Server 2019 Core', 10, 0, 17763, VER_NT_SERVER, 'Server Core', False);
  CheckPlatform('Server 2022 Core', 10, 0, 20348, VER_NT_SERVER, 'Server Core', False);
  CheckPlatform('Server 2025 Core', 10, 0, 26100, VER_NT_SERVER, 'Server Core', False);
  CheckPlatform('Nano Server', 10, 0, 20348, VER_NT_SERVER, 'Nano Server', False);
  CheckPlatform('Missing installation type', 10, 0, 20348, VER_NT_SERVER, '', False);
  CheckPlatform('Unknown product type', 10, 0, 20348, 0, 'Server', False);
  CheckPlatform('Client masquerading as Server', 10, 0, 20348, VER_NT_WORKSTATION, 'Server', False);
  CheckPlatform('Server masquerading as Client', 10, 0, 26100, VER_NT_SERVER, 'Client', False);
  CheckPlatform('Server 2012 R2', 6, 3, 9600, VER_NT_SERVER, 'Server', False);
  CheckPlatform('Server 2012', 6, 2, 9200, VER_NT_SERVER, 'Server', False);
  CheckPlatform('Unlisted server build', 10, 0, 25398, VER_NT_SERVER, 'Server', False);
  CheckPlatform('Future server not implicitly accepted', 10, 0, 30000, VER_NT_SERVER, 'Server', False);
  CheckPlatform('Windows 10 1607', 10, 0, 14393, VER_NT_WORKSTATION, 'Client', False);
  CheckPlatform('Windows 10 22H2', 10, 0, 19045, VER_NT_WORKSTATION, 'Client', False);
  CheckPlatform('Windows 11 boundary', 10, 0, 22000, VER_NT_WORKSTATION, 'Client', True);
  CheckPlatform('Windows 11 current family', 10, 0, 26100, VER_NT_WORKSTATION, 'Client', True);
  CheckPlatform('Desktop domain controller classification', 10, 0, 20348, VER_NT_DOMAIN_CONTROLLER, 'Server', True);
  CheckPlatform('Core domain controller rejected', 10, 0, 20348, VER_NT_DOMAIN_CONTROLLER, 'Server Core', False);
  CheckPlatform('Registry comparison is case insensitive', 10, 0, 20348, VER_NT_SERVER, 'server', True);
  Log(Format('GPUM_PLATFORM_SELF_TEST_PASS: %d cases', [Passed]));
  if GPUMCurrentPlatformSupported() then Log('GPUM_CURRENT_PLATFORM_ALLOWED')
  else Log('GPUM_CURRENT_PLATFORM_REJECTED');
  Result := False;
end;

