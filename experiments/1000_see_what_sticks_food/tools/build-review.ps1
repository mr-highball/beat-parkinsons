# Copyright (c) 2026 beat-parkinsons contributors. All rights reserved.
[CmdletBinding()]
param([string]$Compiler = $(if ($env:FPC) { $env:FPC } else { 'fpc' }))

$ErrorActionPreference = 'Stop'
$reviewCompiler = (Get-Command $Compiler -CommandType Application).Source
$reviewVersion = (& $reviewCompiler '-iV').Trim()
if ($LASTEXITCODE -ne 0) { throw 'FPC version probe failed.' }
$reviewCpu = (& $reviewCompiler '-iTP').Trim()
if ($LASTEXITCODE -ne 0) { throw 'FPC CPU probe failed.' }
$reviewOs = (& $reviewCompiler '-iTO').Trim()
if ($LASTEXITCODE -ne 0) { throw 'FPC OS probe failed.' }
Write-Output "$reviewCompiler | $reviewVersion | $reviewCpu | $reviewOs"

$reviewExperiment = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$reviewBase = Join-Path $reviewExperiment 'build/food-experiment-review'
$reviewBuild = Join-Path $reviewBase "$reviewCpu-$reviewOs-$reviewVersion"
$reviewUnits = Join-Path $reviewBuild 'units'
$reviewBin = Join-Path $reviewBuild 'bin'
New-Item -ItemType Directory -Force $reviewUnits, $reviewBin | Out-Null

$reviewFlags = @('-B', '-Mdelphi', '-Sa', '-Cr', '-Co', '-Ci', '-gl',
    "-FU$reviewUnits", "-FE$reviewBin")
foreach ($reviewSource in @('foodexperiment.review.lpr', 'foodexperiment.review.tests.lpr')) {
    & $reviewCompiler @reviewFlags (Join-Path $PSScriptRoot $reviewSource)
    if ($LASTEXITCODE -ne 0) { throw "FPC compilation failed for $reviewSource." }
}

$reviewSuffix = if ($reviewOs -match '^win') { '.exe' } else { '' }
$reviewProgram = Join-Path $reviewBin "foodexperiment.review$reviewSuffix"
$reviewTests = Join-Path $reviewBin "foodexperiment.review.tests$reviewSuffix"
& $reviewTests $reviewProgram $reviewBuild
if ($LASTEXITCODE -ne 0) { throw 'Native review fixture failed.' }
