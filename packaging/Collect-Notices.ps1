[CmdletBinding()]
param([Parameter(Mandatory)][string]$Assets,[Parameter(Mandatory)][string]$Publish)
$ErrorActionPreference='Stop'
$data=Get-Content -LiteralPath $Assets -Raw | ConvertFrom-Json
$roots=@($data.packageFolders.PSObject.Properties.Name)
$paths=[System.Collections.Generic.HashSet[string]]::new()
foreach($lib in $data.libraries.PSObject.Properties) {
    if($lib.Value.type -eq 'package') { [void]$paths.Add($lib.Value.path) }
}
foreach($framework in $data.project.frameworks.PSObject.Properties.Value) {
    foreach($dependency in $framework.downloadDependencies) {
        $version=($dependency.version.Trim('[',']').Split(',')[0]).Trim()
        [void]$paths.Add($dependency.name.ToLowerInvariant()+'/'+$version)
    }
}
$destination=Join-Path $Publish 'third-party-notices'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$index=[System.Collections.Generic.List[string]]::new()
$index.Add('Third-party package metadata and license notices for this build.')
$index.Add('Files are copied from the exact resolved NuGet packages. Not all packaged assemblies are loaded during normal operation.')
foreach($relative in $paths) {
    $folder=$null
    foreach($root in $roots) { $candidate=Join-Path $root $relative; if(Test-Path -LiteralPath $candidate) { $folder=$candidate; break } }
    if(-not $folder) { throw "Missing package for license collection: $relative" }
    $target=Join-Path $destination ($relative.Replace('/','_'))
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    $spec=Get-ChildItem -LiteralPath $folder -Filter '*.nuspec' | Select-Object -First 1
    Copy-Item -LiteralPath $spec.FullName -Destination $target
    [xml]$xml=Get-Content -LiteralPath $spec.FullName -Raw
    $license=$xml.package.metadata.license
    if($license.type -eq 'file') {
        $licensePath=Join-Path $folder $license.InnerText
        if(-not(Test-Path -LiteralPath $licensePath)) { throw "License file missing: $relative" }
        Copy-Item -LiteralPath $licensePath -Destination $target
    } elseif($license.InnerText -eq 'MIT') {
        $copyright=[string]$xml.package.metadata.copyright
        if(-not $copyright) { $copyright='Copyright holders: '+[string]$xml.package.metadata.authors }
        $mit=@"
MIT License
$copyright

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
"@
        [System.IO.File]::WriteAllText((Join-Path $target 'MIT.txt'),$mit)
    } else { throw "Review unsupported license expression for $relative before distributing." }
    foreach($notice in (Get-ChildItem -LiteralPath $folder -File | Where-Object { $_.Name -match '^(LICENSE|THIRD.PARTY.NOTICES|NOTICE)(\..*)?$' })) {
        Copy-Item -LiteralPath $notice.FullName -Destination $target -Force
    }
    $index.Add($relative+' — '+$license.InnerText)
}
[System.IO.File]::WriteAllLines((Join-Path $destination 'index.txt'),$index)
Write-Output "Collected notices for $($paths.Count) packages."

