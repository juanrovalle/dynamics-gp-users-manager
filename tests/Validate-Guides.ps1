[CmdletBinding()]
param(
    [string]$Docs = (Join-Path (Split-Path $PSScriptRoot -Parent) 'docs'),
    [string]$Installer = (Join-Path (Split-Path $PSScriptRoot -Parent) 'packaging/DynamicsGPUserOps.iss')
)
$ErrorActionPreference='Stop'
# Keep these guides offline, cross-linked, and present in every source-built installer.
$requiredGuides = @(
    'index.html',
    'installation-and-testing.en.html',
    'installation-and-testing.es.html',
    'installation-and-testing.html',
    'windows-server.en.html',
    'windows-server.es.html'
)
$Docs = (Resolve-Path -LiteralPath $Docs).Path
foreach ($name in $requiredGuides) {
    if (-not (Test-Path -LiteralPath (Join-Path $Docs $name) -PathType Leaf)) {
        throw "Missing required guide: $name"
    }
}
$all=@{}
foreach($file in Get-ChildItem -LiteralPath $Docs -Filter '*.html') {
    $html=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    if($html -match '<script\b|<iframe\b|<img[^>]+src="https?://|<link[^>]+rel="stylesheet"[^>]+href="https?://') {
        throw "Unexpected online/executable dependency in $($file.Name)"
    }
    $xmlText=[regex]::Replace($html,'<!doctype[^>]*>','',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $xmlText=[regex]::Replace($xmlText,'<(meta|link|br|hr)(\s[^>]*?)?(?<!/)>','<$1$2/>',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    [xml]$doc=$xmlText
    $all[$file.Name]=$doc
    $ids=@($doc.SelectNodes('//*[@id]') | ForEach-Object { $_.GetAttribute('id') })
    if(($ids | Select-Object -Unique).Count -ne $ids.Count) { throw "Duplicate anchors in $($file.Name)" }
    foreach($row in $doc.SelectNodes('//table/tbody/tr')) {
        if($row.SelectNodes('td').Count -lt 2) { throw "Malformed table row in $($file.Name)" }
    }
    foreach($link in $doc.SelectNodes('//a[@href] | //link[@href]')) {
        $href=$link.GetAttribute('href')
        if($href -match '^https://') { continue }
        if($href -match '^[a-zA-Z]+:|^\.\.|^/') { throw "Unexpected link: $href" }
        $parts=$href.Split('#',2)
        $target=if($parts[0]){Join-Path $Docs $parts[0]}else{$file.FullName}
        $target = [System.IO.Path]::GetFullPath($target)
        $docsPrefix = $Docs.TrimEnd([char[]]'\\/') + [System.IO.Path]::DirectorySeparatorChar
        if (-not $target.StartsWith($docsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Link escapes the documentation directory: $href"
        }
        if(-not(Test-Path -LiteralPath $target -PathType Leaf)) { throw "Broken link $href in $($file.Name)" }
        if($parts.Count -eq 2) {
            $targetText=Get-Content -LiteralPath $target -Raw -Encoding UTF8
            if($targetText -notmatch ('id="'+[regex]::Escape($parts[1])+'"')) { throw "Broken anchor $href" }
        }
    }
    foreach($block in $doc.SelectNodes('//pre/code')) {
        $tokens=$null; $errors=$null
        [System.Management.Automation.Language.Parser]::ParseInput($block.InnerText,[ref]$tokens,[ref]$errors) | Out-Null
        if($errors.Count) { throw "PowerShell snippet does not parse in $($file.Name): $errors" }
    }
    Write-Output "PASS HTML structure, local links, offline dependencies and code: $($file.Name)"
}
foreach($topic in @('installation-and-testing','windows-server')) {
    $es=$all["$topic.es.html"]; $en=$all["$topic.en.html"]
    if($es.html.lang -ne 'es' -or $en.html.lang -ne 'en') { throw "Wrong language for $topic" }
    foreach($path in @('//section','//h2','//h3','//table','//table/tbody/tr','//pre/code')) {
        if($es.SelectNodes($path).Count -ne $en.SelectNodes($path).Count) { throw "Translation structure differs for $topic $path" }
    }
    $esIds=@($es.SelectNodes('//*[@id]') | ForEach-Object { $_.id }) -join ','
    $enIds=@($en.SelectNodes('//*[@id]') | ForEach-Object { $_.id }) -join ','
    if($esIds -ne $enIds) { throw "Section parity differs for $topic" }
    if(-not $es.SelectSingleNode("//a[@href='$topic.en.html']") -or -not $en.SelectSingleNode("//a[@href='$topic.es.html']")) {
        throw "Missing reciprocal language links for $topic"
    }
    foreach($technical in @('4.0.0','Desktop Experience','Server Core','PAUSED','SQL Server Agent')) {
        if(-not $es.DocumentElement.InnerText.Contains($technical) -or -not $en.DocumentElement.InnerText.Contains($technical)) { throw "Missing shared technical term $technical in $topic" }
    }
    Write-Output "PASS Spanish/English structural parity: $topic"
}
foreach ($language in @('en', 'es')) {
    $tests=$all["installation-and-testing.$language.html"].SelectNodes("//section[@id='tests']/table/tbody/tr")
    if($tests.Count -ne 17) { throw "Acceptance checklist must retain all 17 tests: $language" }
    for ($i = 0; $i -lt 17; $i++) {
        $label = [string][char](65 + $i) + '.'
        if (-not $tests[$i].SelectSingleNode('td').InnerText.StartsWith($label)) {
            throw "Missing or reordered acceptance test $label in $language"
        }
    }
}
Write-Output 'PASS all 17 acceptance scenarios retained in both languages.'

if (-not $all['installation-and-testing.html'].SelectSingleNode("//a[@href='installation-and-testing.es.html']")) {
    throw 'The legacy installation-guide address must direct users to the Spanish edition.'
}
foreach ($name in $requiredGuides | Where-Object { $_ -match '\.(en|es)\.html$' }) {
    if (-not $all['index.html'].SelectSingleNode("//a[@href='$name']")) {
        throw "Language selector does not link to $name"
    }
}
Write-Output 'PASS legacy Spanish guide redirect and bilingual guide selector'

$setup = Get-Content -LiteralPath $Installer -Raw -Encoding UTF8
if (-not $setup.Contains('Source: "..\docs\*"; DestDir: "{app}\docs";')) {
    throw 'Installer does not package the documentation directory.'
}
$icons = [regex]::Match($setup, '(?ms)^\[Icons\]\s*(.*?)(?=^\[|\z)').Groups[1].Value
foreach ($name in $requiredGuides | Where-Object { $_ -ne 'installation-and-testing.html' }) {
    if (-not $icons.Contains('Filename: "{app}\docs\' + $name + '"')) {
        throw "Installer is missing the guide shortcut: $name"
    }
}
Write-Output 'PASS installer documentation packaging and all five guide shortcuts'
