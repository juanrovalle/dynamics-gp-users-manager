// No files, registry entries, shortcuts, or uninstallers are installed or removed.
[Setup]
AppName=Dynamics GP UserOps legacy upgrade tests
AppVersion=1.0
DefaultDirName={tmp}\DynamicsGPUserOps-upgrade-tests
CreateAppDir=no
Uninstallable=no
PrivilegesRequired=lowest
ArchitecturesAllowed=x64os
OutputDir=..\artifacts\upgrade-tests
OutputBaseFilename=LegacyUpgradeTests
SetupLogging=yes

[Code]
var
  Installed, SilentMode, Running, ValidUninstaller, Confirmed, LaunchSucceeds,
    RemoveRegistration, Spanish: Boolean;
  UninstallExitCode, Executions, Confirmations, Passed: Integer;

function LegacyIsInstalled(): Boolean;
begin Result := Installed; end;
function LegacySilentMode(): Boolean;
begin Result := SilentMode; end;
function LegacyConsoleRunning(): Boolean;
begin Result := Running; end;
function LegacyText(EnglishText, SpanishText: String): String;
begin
  if Spanish then Result := SpanishText else Result := EnglishText;
end;
function LegacyUninstaller(var Command: String): Boolean;
begin
  Command := 'mock-uninstaller.exe';
  Result := ValidUninstaller;
end;
function ConfirmLegacyReplacement(): Boolean;
begin
  Confirmations := Confirmations + 1;
  Result := Confirmed;
end;
function RunLegacyUninstaller(Command: String): Boolean;
begin
  Executions := Executions + 1;
  Result := LaunchSucceeds and (UninstallExitCode = 0);
  if Result and RemoveRegistration then Installed := False;
end;

#include "..\packaging\LegacyUpgrade.iss"

procedure ResetFixture();
begin
  Installed := True; SilentMode := False; Running := False;
  ValidUninstaller := True; Confirmed := True; LaunchSucceeds := True;
  RemoveRegistration := True; Spanish := False;
  UninstallExitCode := 0; Executions := 0; Confirmations := 0;
end;

procedure Check(Name: String; Condition: Boolean);
begin
  if not Condition then RaiseException('USEROPS_UPGRADE_FAIL: ' + Name);
  Passed := Passed + 1;
  Log('PASS ' + Name);
end;

function InitializeSetup(): Boolean;
var
  First, Second: String;
begin
  Passed := 0;
  ResetFixture(); Installed := False;
  Check('Clean install does not run legacy actions', (UserOpsPrepareLegacyUpgrade() = '') and (Executions = 0) and (Confirmations = 0));

  ResetFixture(); SilentMode := True;
  Check('Silent legacy upgrade is blocked', (UserOpsPrepareLegacyUpgrade() <> '') and (Executions = 0));

  ResetFixture(); Running := True;
  Check('Running legacy console is blocked', (UserOpsPrepareLegacyUpgrade() <> '') and (Executions = 0));

  ResetFixture(); ValidUninstaller := False;
  Check('Missing uninstaller is blocked', (UserOpsPrepareLegacyUpgrade() <> '') and (Executions = 0) and (Confirmations = 0));

  ResetFixture(); Confirmed := False;
  First := UserOpsPrepareLegacyUpgrade(); Second := UserOpsPrepareLegacyUpgrade();
  Check('Canceled retry cannot bypass check', (First <> '') and (Second <> '') and Installed and (Executions = 0) and (Confirmations = 2));

  ResetFixture(); LaunchSucceeds := False;
  First := UserOpsPrepareLegacyUpgrade(); Second := UserOpsPrepareLegacyUpgrade();
  Check('Launch failure remains blocked on retry', (First <> '') and (Second <> '') and Installed and (Executions = 2));

  ResetFixture(); UninstallExitCode := 1;
  First := UserOpsPrepareLegacyUpgrade(); Second := UserOpsPrepareLegacyUpgrade();
  Check('Nonzero exit remains blocked on retry', (First <> '') and (Second <> '') and Installed and (Executions = 2));

  ResetFixture(); RemoveRegistration := False;
  First := UserOpsPrepareLegacyUpgrade(); Second := UserOpsPrepareLegacyUpgrade();
  Check('Residual product registration is blocked', (First <> '') and (Second <> '') and Installed and (Executions = 2));

  ResetFixture();
  First := UserOpsPrepareLegacyUpgrade(); Second := UserOpsPrepareLegacyUpgrade();
  Check('Successful removal is not repeated', (First = '') and (Second = '') and not Installed and (Executions = 1));

  ResetFixture(); Running := True; First := UserOpsPrepareLegacyUpgrade();
  Running := False; Second := UserOpsPrepareLegacyUpgrade();
  Check('Retry succeeds after closing console', (First <> '') and (Second = '') and not Installed and (Executions = 1));

  ResetFixture(); Confirmed := False; First := UserOpsPrepareLegacyUpgrade();
  Confirmed := True; Second := UserOpsPrepareLegacyUpgrade();
  Check('Retry succeeds after explicit confirmation', (First <> '') and (Second = '') and not Installed and (Confirmations = 2) and (Executions = 1));

  ResetFixture(); Spanish := True; SilentMode := True;
  Check('Spanish upgrade error is localized', Pos('Ejecuta', UserOpsPrepareLegacyUpgrade()) > 0);

  Log(Format('USEROPS_UPGRADE_SELF_TEST_PASS: %d cases', [Passed]));
  Result := False;
end;
