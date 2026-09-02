[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Server,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9_]{0,127}$')][string]$ManagerDatabase = 'DEVELOPMENT',
    [ValidatePattern('^[A-Za-z][A-Za-z0-9_]{0,127}$')][string]$GPDatabase = 'DYNAMICS',
    [ValidatePattern('^[A-Za-z][A-Za-z0-9_]{0,127}$')][string]$DexDatabase = 'tempdb',
    [switch]$InstallAgentJob
)
$ErrorActionPreference = 'Stop'
if ($ManagerDatabase -in @('master', 'model', 'msdb', 'tempdb', $GPDatabase, $DexDatabase)) {
    throw 'ManagerDatabase must be a separate application database.'
}
if ($GPDatabase -eq $DexDatabase) { throw 'GPDatabase and DexDatabase must differ.' }
if ($InstallAgentJob -and $ManagerDatabase.Length -gt 96) { throw 'Agent job installation requires a manager database name of 96 characters or fewer.' }
Get-Command sqlcmd -ErrorAction Stop | Out-Null
Push-Location $PSScriptRoot
try {
    & sqlcmd -S $Server -E -b -r 1 -i install.sql -v "ManagerDatabase=$ManagerDatabase" "GPDatabase=$GPDatabase" "DexDatabase=$DexDatabase"
    if ($LASTEXITCODE -ne 0) { throw "Installation failed (sqlcmd exit $LASTEXITCODE)." }
    if ($InstallAgentJob) {
        & sqlcmd -S $Server -E -b -r 1 -i install-agent-job.sql -v "ManagerDatabase=$ManagerDatabase"
        if ($LASTEXITCODE -ne 0) { throw 'Core installed, but SQL Agent job installation failed.' }
    }
} finally { Pop-Location }
