[CmdletBinding()]
param([Parameter(Mandatory)][string]$InnoCompiler)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
& $InnoCompiler /Q (Join-Path $PSScriptRoot 'LegacyUpgrade.Tests.iss')
if($LASTEXITCODE -ne 0) { throw 'Legacy upgrade harness compilation failed.' }
$folder=Join-Path $repo 'artifacts/upgrade-tests'
$log=Join-Path $folder ('test-'+[guid]::NewGuid().ToString('N')+'.log')
$exe=Join-Path $folder 'LegacyUpgradeTests.exe'
$process=Start-Process -FilePath $exe -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',('/LOG="'+$log+'"')) -WindowStyle Hidden -PassThru
if(-not $process.WaitForExit(45000)) { $process.Kill(); throw 'Legacy upgrade test harness timed out.' }
if(-not(Test-Path -LiteralPath $log)) { throw 'Legacy upgrade test log was not created.' }
$content=Get-Content -LiteralPath $log -Raw
if($content -notmatch 'USEROPS_UPGRADE_SELF_TEST_PASS: 12 cases' -or $content -match 'USEROPS_UPGRADE_FAIL') {
    throw "Legacy upgrade workflow tests failed. Inspect $log"
}
Write-Output 'PASS 12 legacy upgrade workflow cases (shared installer code; no product installed or removed).'
Write-Output "Legacy upgrade test log: $log"
