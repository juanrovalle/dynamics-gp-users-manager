[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$scripts = Get-ChildItem -LiteralPath $root -Recurse -Filter '*.ps1'
foreach ($script in $scripts) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
}
Write-Output "PASS PowerShell syntax ($($scripts.Count) scripts)"

[xml]$report = Get-Content -LiteralPath (Join-Path $root 'src/Install/reports/GP Manager For SRSS.rdl') -Raw
$ns = [System.Xml.XmlNamespaceManager]::new($report.NameTable)
$ns.AddNamespace('r', $report.DocumentElement.NamespaceURI)
if ($report.SelectNodes('//r:SharedDataSet', $ns).Count -ne 0) { throw 'Report still depends on external datasets.' }
$datasets = $report.SelectNodes('//r:DataSets/r:DataSet', $ns)
if ($datasets.Count -ne 4) { throw 'Expected four report datasets.' }
foreach ($dataset in $datasets) {
    $source = $dataset.SelectSingleNode('r:Query/r:DataSourceName', $ns).InnerText
    if (-not $report.SelectSingleNode("//r:DataSources/r:DataSource[@Name='$source']", $ns)) { throw "Missing source: $source" }
    if (-not $dataset.SelectSingleNode('r:Query/r:CommandText', $ns).InnerText.StartsWith('SELECT ')) { throw 'Missing read-only report query.' }
}
$active = $report.SelectSingleNode('//r:Textbox[@Name="Disponible"]//r:Value', $ns).InnerText
$available = $report.SelectSingleNode('//r:Textbox[@Name="Textbox8"]//r:Value', $ns).InnerText
if ($active -ne '=(Fields!Limite.Value-Fields!Disponible.Value)' -or $available -ne '=Fields!Disponible.Value') {
    throw 'Active/available columns are swapped.'
}
if ($report.OuterXml -match 'reportes\.ntdingredientes\.com|SharedDataSetReference') { throw 'Private report dependencies remain.' }
if ($report.SelectSingleNode('//r:Chart[@Name="DataBar4"]//r:ChartDataLabel/r:Label', $ns).InnerText -match '[\\/]') {
    throw 'Net availability label must not divide by a session count.'
}
Write-Output 'PASS RDL XML, data sources, embedded queries and metric bindings'

$installer = Get-Content -LiteralPath (Join-Path $root 'src/Install/install.sql') -Raw
foreach ($match in [regex]::Matches($installer, '(?m)^:r (.+)\r?$')) {
    $include = Join-Path (Join-Path $root 'src/Install') $match.Groups[1].Value.Trim()
    if (-not (Test-Path -LiteralPath $include -PathType Leaf)) { throw "Missing SQL include: $include" }
}
# Validate input guards without a server or sqlcmd. Each call must fail before connecting.
foreach ($invalidName in @('master', 'tempdb', 'DYNAMICS', 'bad]name', 'name with spaces')) {
    $rejected = $false
    try { & (Join-Path $root 'src/Install/Install.ps1') -Server 'not-used' -ManagerDatabase $invalidName }
    catch {
        if ($_.Exception.Message -notmatch 'separate application database|validation pattern|ValidatePattern|does not match|no coincide|patr.n') {
            throw
        }
        $rejected = $true
    }
    if (-not $rejected) { throw "Unsafe database name accepted: $invalidName" }
}
Write-Output 'PASS include paths and installer database-name guards'
$setup = Get-Content -LiteralPath (Join-Path $root 'packaging/GPUsersManager.iss') -Raw
foreach ($required in @('MinVersion=10.0.14393', 'ArchitecturesAllowed=x64os', '#include "WindowsPlatform.iss"', 'Result := GPUMCurrentPlatformSupported();')) {
    if (-not $setup.Contains($required)) { throw "Installer platform guard missing: $required" }
}
Write-Output 'PASS Windows installer platform guard wiring'
Write-Output 'Static validation passed. SQL execution and SSRS rendering require separate environments.'
