# Copyright (c) 2026 beat-parkinsons contributors. All rights reserved.
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('reserve', 'generate', 'verify')]
    [string]$Action,
    [string]$Compiler = $env:FPC
)

$ErrorActionPreference = 'Stop'
if (-not $Compiler) {
    $Compiler = 'fpc'
}
$compilerPath = (Get-Command $Compiler -CommandType Application).Source
$experimentRoot = Split-Path -Parent $PSScriptRoot
$roundTwo = Join-Path $experimentRoot '1000_see_what_sticks_food_round_2'
$originalTools = Join-Path $experimentRoot '1000_see_what_sticks_food/tools'
$build = Join-Path $roundTwo 'build/series'
$bin = Join-Path $build 'bin'
$units = Join-Path $build 'units'
New-Item -ItemType Directory -Force $bin, $units | Out-Null
$flags = @('-B', '-Pi386', '-Twin32', '-Sa', '-Cr', '-Co', '-Ci', '-gl', '-O2',
    "-Fu$originalTools", "-FU$units", "-FE$bin")
& $compilerPath @flags (Join-Path $PSScriptRoot 'foodexperiment.series.lpr')
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
& (Join-Path $bin 'foodexperiment.series.exe') $Action $experimentRoot
exit $LASTEXITCODE

