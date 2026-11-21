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
$buildRoot = Join-Path $experiment "build/roundtransfer-$version-$cpu-$os"
$binDir = Join-Path $buildRoot 'bin'
$unitDir = Join-Path $buildRoot 'units'
$testTemp = Join-Path $buildRoot 'test-run'
New-Item -ItemType Directory -Force -Path $binDir, $unitDir, $testTemp | Out-Null

$flags = @('-B', '-Sa', '-Cr', '-Co', '-Ci', '-gl', '-O2',
  "-Fu$PSScriptRoot", "-FU$unitDir", "-FE$binDir")

& $compilerPath @flags (Join-Path $PSScriptRoot 'foodexperiment.roundtransfer.lpr')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $compilerPath @flags (Join-Path $PSScriptRoot 'foodexperiment.roundtransfer.tests.lpr')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$exe = Join-Path $binDir 'foodexperiment.roundtransfer.exe'
$testExe = Join-Path $binDir 'foodexperiment.roundtransfer.tests.exe'
& $testExe $exe $testTemp
exit $LASTEXITCODE
