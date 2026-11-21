# Copyright (c) 2026 beat-parkinsons contributors. All rights reserved.
param(
  [string]$Compiler = $env:FPC
)

$ErrorActionPreference = 'Stop'
if (-not $Compiler) {
  $Compiler = 'fpc'
}
$compilerPath = (Get-Command $Compiler -CommandType Application).Source
$version = (& $compilerPath -iV).Trim()
$cpu = (& $compilerPath -iTP).Trim()
$os = (& $compilerPath -iTO).Trim()
Write-Host "FPC: $compilerPath ($version, $cpu-$os)"

$experiment = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$run = Join-Path $experiment "build/homographscreen-$version-$cpu-$os"
$units = Join-Path $run 'units'
$bin = Join-Path $run 'bin'
New-Item -ItemType Directory -Force $units, $bin | Out-Null

$flags = @('-B', '-Sa', '-Cr', '-Co', '-Ci', '-gl', '-O2',
  "-Fu$PSScriptRoot", "-FU$units", "-FE$bin")
& $compilerPath @flags (Join-Path $PSScriptRoot 'foodexperiment.homograph.tests.lpr')
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
& $compilerPath @flags (Join-Path $PSScriptRoot 'foodexperiment.homographscreen.lpr')
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

& (Join-Path $bin 'foodexperiment.homograph.tests.exe')
exit $LASTEXITCODE
