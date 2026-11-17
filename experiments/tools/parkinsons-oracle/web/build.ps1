# Copyright (c) 2026 beat-parkinsons contributors. All rights reserved.
[CmdletBinding()]
param(
    [string] $Compiler = $env:PAS2JS,
    [string] $Runtime = $env:PAS2JS_RTL,
    [string] $UnitRoot = $env:PAS2JS_UNITS,
    [string] $OutputDirectory
)

$ErrorActionPreference = 'Stop'
$Repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../../..')).Path
if (!$Compiler) {
    $Compiler = (Get-Command pas2js -ErrorAction Stop).Source
}
if (!$Runtime) {
    $Candidate = Join-Path (Split-Path -Parent (Get-Command $Compiler).Source) 'rtl.js'
    if (!(Test-Path -LiteralPath $Candidate -PathType Leaf)) {
        throw 'Pass -Runtime with the rtl.js distributed with this pas2js compiler.'
    }
    $Runtime = $Candidate
}
$Vendor = Join-Path $Repo 'experiments/tools/vendor/nyx/src'
$SharedUnits = Split-Path -Parent $PSScriptRoot
$Output = $OutputDirectory
if (!$Output) {
    $Output = Join-Path $Repo 'build/parkinsons-oracle/web'
}
New-Item -ItemType Directory -Path $Output -Force | Out-Null
$CompilerArgs = @(
    '-Mdelphi', '-Tbrowser', '-Jc',
    "-Fu$Vendor", "-Fi$Vendor", "-Fu$SharedUnits", "-FE$Output"
)
if ($UnitRoot) {
    $Packages = (Resolve-Path -LiteralPath $UnitRoot).Path
    $CompilerArgs += "-Fu$Packages/*/src"
}
$CompilerArgs += (Join-Path $PSScriptRoot 'oracleweb.lpr')
& $Compiler @CompilerArgs
if ($LASTEXITCODE) {
    exit $LASTEXITCODE
}
Move-Item -LiteralPath (Join-Path $Output 'oracleweb.js') -Destination (Join-Path $Output 'app.js') -Force
Copy-Item -LiteralPath $Runtime -Destination (Join-Path $Output 'rtl.js') -Force
foreach ($Name in @('index.html', 'oracle.css')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $Name) -Destination $Output -Force
}
