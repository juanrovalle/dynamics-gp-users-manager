[CmdletBinding()]
param([Parameter(Mandatory)][string]$InnoCompiler)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
& $InnoCompiler /Q (Join-Path $PSScriptRoot 'WindowsPlatform.Tests.iss')
if($LASTEXITCODE -ne 0) { throw 'Platform test harness compilation failed.' }
$folder=Join-Path $repo 'artifacts/platform-tests'
$log=Join-Path $folder ('test-'+[guid]::NewGuid().ToString('N')+'.log')
$exe=Join-Path $folder 'PlatformTests.exe'
$process=Start-Process -FilePath $exe -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',('/LOG="'+$log+'"')) -WindowStyle Hidden -PassThru
if(-not $process.WaitForExit(45000)) { $process.Kill(); throw 'Platform test harness timed out.' }
if(-not(Test-Path -LiteralPath $log)) { throw 'Platform test log was not created.' }
$content=Get-Content -LiteralPath $log -Raw
if($content -notmatch 'USEROPS_PLATFORM_SELF_TEST_PASS: 24 cases' -or $content -match 'USEROPS_PLATFORM_FAIL') {
    throw "Platform policy tests failed. Inspect $log"
}
# A canceled-setup exit is intentional: the harness must never install anything.
Write-Output 'PASS 24 Windows platform cases (shared installer policy; no installation performed).'
Write-Output "Platform test log: $log"
