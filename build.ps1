[CmdletBinding()]
param(
    [string]$DotNet = 'dotnet',
    [string]$InnoCompiler = 'C:\Program Files\Inno Setup 7\ISCC.exe',
    [string]$CertificateThumbprint,
    [string]$SignTool = 'signtool.exe',
    [string]$TimestampUrl = 'http://timestamp.digicert.com',
    [switch]$RequireSignature,
    [switch]$SkipRestore
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$publish = Join-Path $root 'artifacts/publish'
$output = Join-Path $root 'artifacts/installer'
if ($RequireSignature -and -not $CertificateThumbprint) { throw 'A code-signing certificate is required for this build.' }
if ($CertificateThumbprint -and $CertificateThumbprint -notmatch '^[A-Fa-f0-9]{40,64}$') { throw 'Invalid certificate thumbprint.' }
if (-not (Test-Path -LiteralPath $InnoCompiler)) { throw 'Install Inno Setup or pass -InnoCompiler.' }
& (Join-Path $root 'tests/Validate.ps1')
& (Join-Path $root 'tests/Test-WindowsPlatform.ps1') -InnoCompiler $InnoCompiler
$restoreArgs = @()
if ($SkipRestore) { $restoreArgs += '--no-restore' }
& $DotNet run --project (Join-Path $root 'tests/GPManager.Tests') -c Release @restoreArgs
if ($LASTEXITCODE -ne 0) { throw 'Automated tests failed.' }
& $DotNet publish (Join-Path $root 'src/GPManager.Desktop') -c Release -r win-x64 --self-contained true '-p:PublishSingleFile=false' '-p:PublishTrimmed=false' -o $publish @restoreArgs
if ($LASTEXITCODE -ne 0) { throw 'Publish failed.' }
& (Join-Path $root 'packaging/Collect-Notices.ps1') -Assets (Join-Path $root 'src/GPManager.Desktop/obj/project.assets.json') -Publish $publish
$innoArgs = @("/DPublishDir=$publish", "/DOutputDir=$output")
if ($CertificateThumbprint) {
    & $SignTool sign /sha1 $CertificateThumbprint /fd SHA256 /tr $TimestampUrl /td SHA256 (Join-Path $publish 'GPUsersManager.exe')
    if ($LASTEXITCODE -ne 0) { throw 'Application signing failed.' }
    $signCommand = '"'+$SignTool+'" sign /sha1 '+$CertificateThumbprint+' /fd SHA256 /tr "'+$TimestampUrl+'" /td SHA256 $f'
    $innoArgs += '/DSignedBuild=1'
    $innoArgs += "/Srelease=$signCommand"
}
& $InnoCompiler @innoArgs (Join-Path $root 'packaging/GPUsersManager.iss')
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
$setup = Join-Path $output 'Setup.exe'
if ($RequireSignature -and (Get-AuthenticodeSignature -LiteralPath $setup).Status -ne 'Valid') { throw 'Installer signature verification failed.' }
Get-FileHash -LiteralPath $setup -Algorithm SHA256
Write-Output "Installer: $setup"
if (-not $CertificateThumbprint) { Write-Warning 'Unsigned build. Obtain and use a code-signing certificate for signed distribution.' }
