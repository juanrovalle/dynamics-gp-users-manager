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
& (Join-Path $root 'packaging/Generate-Icon.ps1')
& (Join-Path $root 'tests/Validate.ps1')
& (Join-Path $root 'tests/Test-WindowsPlatform.ps1') -InnoCompiler $InnoCompiler
& (Join-Path $root 'tests/Test-LegacyUpgrade.ps1') -InnoCompiler $InnoCompiler
$restoreArgs = @()
if ($SkipRestore) { $restoreArgs += '--no-restore' }
& $DotNet run --project (Join-Path $root 'tests/DynamicsGP.UserOps.Tests') -c Release @restoreArgs
if ($LASTEXITCODE -ne 0) { throw 'Automated tests failed.' }
$artifactsRoot = [System.IO.Path]::GetFullPath((Join-Path $root 'artifacts'))
$publishFull = [System.IO.Path]::GetFullPath($publish)
$artifactsPrefix = $artifactsRoot.TrimEnd([char[]]'\/') + [System.IO.Path]::DirectorySeparatorChar
if (-not $publishFull.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe publish path.' }
if (Test-Path -LiteralPath $publishFull) { Remove-Item -LiteralPath $publishFull -Recurse -Force }
New-Item -ItemType Directory -Path $publishFull -Force | Out-Null
& $DotNet publish (Join-Path $root 'src/DynamicsGP.UserOps.Desktop') -c Release -r win-x64 --self-contained true '-p:PublishSingleFile=false' '-p:PublishTrimmed=false' -o $publish @restoreArgs
if ($LASTEXITCODE -ne 0) { throw 'Publish failed.' }
$application = Join-Path $publish 'DynamicsGPUserOps.exe'
if (-not (Test-Path -LiteralPath $application -PathType Leaf)) { throw 'DynamicsGPUserOps.exe was not published.' }
if (Get-ChildItem -LiteralPath $publish -File | Where-Object Name -Match '^(GPUsersManager|GPManager\.)') { throw 'Legacy Windows binaries remain in the clean publish directory.' }
$publishedVersion = (Get-Item -LiteralPath $application).VersionInfo
if ($publishedVersion.ProductName -ne 'Dynamics GP UserOps' -or $publishedVersion.ProductVersion -ne '4.0.0' -or $publishedVersion.FileVersion -ne '4.0.0.0') { throw 'Published Windows metadata is incorrect.' }
& (Join-Path $root 'packaging/Collect-Notices.ps1') -Assets (Join-Path $root 'src/DynamicsGP.UserOps.Desktop/obj/project.assets.json') -Publish $publish
$innoArgs = @("/DPublishDir=$publish", "/DOutputDir=$output")
if ($CertificateThumbprint) {
    & $SignTool sign /sha1 $CertificateThumbprint /fd SHA256 /tr $TimestampUrl /td SHA256 $application
    if ($LASTEXITCODE -ne 0) { throw 'Application signing failed.' }
    $signCommand = '"'+$SignTool+'" sign /sha1 '+$CertificateThumbprint+' /fd SHA256 /tr "'+$TimestampUrl+'" /td SHA256 $f'
    $innoArgs += '/DSignedBuild=1'
    $innoArgs += "/Srelease=$signCommand"
}
& $InnoCompiler @innoArgs (Join-Path $root 'packaging/DynamicsGPUserOps.iss')
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
$setup = Join-Path $output 'Setup.exe'
if ($RequireSignature -and (Get-AuthenticodeSignature -LiteralPath $setup).Status -ne 'Valid') { throw 'Installer signature verification failed.' }
$setupHash = Get-FileHash -LiteralPath $setup -Algorithm SHA256
$checksum = Join-Path $output 'Setup.exe.sha256'
Set-Content -LiteralPath $checksum -Value ($setupHash.Hash.ToLowerInvariant()+' *Setup.exe') -Encoding ascii -NoNewline
$setupHash
Write-Output "Installer: $setup"
Write-Output "Checksum: $checksum"
if (-not $CertificateThumbprint) { Write-Warning 'Unsigned build. Obtain and use a code-signing certificate for signed distribution.' }
