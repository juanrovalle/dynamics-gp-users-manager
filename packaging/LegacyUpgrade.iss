// Shared workflow. The installer supplies Windows adapters; the test harness supplies mocks.
// Never cache a failed check: PrepareToInstall can be called again after an error or cancellation.
function UserOpsPrepareLegacyUpgrade(): String;
var
  Command: String;
begin
  Result := '';
  if not LegacyIsInstalled() then Exit;
  if LegacySilentMode() then
  begin
    Result := LegacyText('GP Users Manager 3.x is installed. Run this upgrade interactively.',
      'GP Users Manager 3.x está instalado. Ejecuta esta actualización de forma interactiva.');
    Exit;
  end;
  if LegacyConsoleRunning() then
  begin
    Result := LegacyText('Close GP Users Manager 3.x, then retry installation.',
      'Cierra GP Users Manager 3.x y vuelve a intentar la instalación.');
    Exit;
  end;
  if not LegacyUninstaller(Command) then
  begin
    Result := LegacyText('The legacy uninstaller is missing or invalid. Repair the GP Users Manager 3.x installation before upgrading. SQL was not changed.',
      'El desinstalador anterior no existe o no es válido. Repara GP Users Manager 3.x antes de actualizar. SQL no se modificó.');
    Exit;
  end;
  if not ConfirmLegacyReplacement() then
  begin
    Result := LegacyText('Upgrade canceled before removing the legacy console.',
      'Actualización cancelada antes de retirar la consola anterior.');
    Exit;
  end;
  if not RunLegacyUninstaller(Command) then
  begin
    Result := LegacyText('The GP Users Manager 3.x console could not be removed. SQL was not changed. Resolve the uninstall issue and retry.',
      'No se pudo retirar la consola GP Users Manager 3.x. SQL no se modificó. Resuelve el problema del desinstalador y vuelve a intentar.');
    Exit;
  end;
  // A successful process exit is not sufficient evidence that the old product was removed.
  if LegacyIsInstalled() then
    Result := LegacyText('GP Users Manager 3.x is still registered after uninstall. Setup cannot install a second product. Resolve the legacy uninstall issue and retry.',
      'GP Users Manager 3.x sigue registrado después de desinstalar. Setup no instalará un segundo producto. Resuelve la desinstalación anterior y vuelve a intentar.');
end;
