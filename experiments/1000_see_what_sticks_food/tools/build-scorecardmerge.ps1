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
$repo = (Resolve-Path -LiteralPath (Join-Path $experiment '../..')).Path
$oracleDir = Join-Path $repo 'experiments/tools/parkinsons-oracle'
$run = Join-Path $experiment "build/scorecardmerge-$version-$cpu-$os"
$units = Join-Path $run 'units'
$bin = Join-Path $run 'bin'
$fixture = Join-Path $run 'fixture'
New-Item -ItemType Directory -Force $units, $bin | Out-Null
if (Test-Path -LiteralPath $fixture) {
  Remove-Item -LiteralPath $fixture -Recurse -Force
}

$flags = @('-B', '-Sa', '-Cr', '-Co', '-Ci', '-gl',
  "-Fu$PSScriptRoot", "-Fu$oracleDir", "-FU$units", "-FE$bin")
& $compilerPath @flags (Join-Path $PSScriptRoot 'foodexperiment.scorecardmerge.lpr')
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
& $compilerPath @flags (Join-Path $PSScriptRoot 'foodexperiment.scorecardmerge.tests.lpr')
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$merger = Join-Path $bin 'foodexperiment.scorecardmerge.exe'
$tests = Join-Path $bin 'foodexperiment.scorecardmerge.tests.exe'
& $tests $merger $fixture
exit $LASTEXITCODE
