# Copyright (c) 2026 beat-parkinsons contributors. All rights reserved.
param(
  [string]$Compiler = $env:FPC,
  [string]$Overlay = 'build/claim-search-complete-date-overlay/ingredient_results.tsv'
)

$ErrorActionPreference = 'Stop'
if (-not $Compiler) {
  $Compiler = 'fpc'
}
$compilerPath = (Get-Command $Compiler -CommandType Application).Source
$experiment = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$run = Join-Path $experiment 'build/context-coverage'
$bin = Join-Path $run 'bin'
$units = Join-Path $run 'units'
$output = Join-Path $run 'output'
$reviewPaths = Join-Path $experiment 'followup/context-coverage/extra-review-paths.tsv'
$source = Join-Path $PSScriptRoot 'foodexperiment.contextqueue.lpr'
New-Item -ItemType Directory -Force $bin, $units, $output | Out-Null
$flags = @('-B', '-Pi386', '-Twin32', '-Sa', '-Cr', '-Co', '-Ci', '-gl', '-O2',
  "-Fu$PSScriptRoot", "-FU$units", "-FE$bin")
& $compilerPath @flags $source | Tee-Object -FilePath (Join-Path $run 'compile.log')
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
$program = Join-Path $bin 'foodexperiment.contextqueue.exe'
& $program $experiment $Overlay $output $reviewPaths |
  Tee-Object -FilePath (Join-Path $run 'run.log')
exit $LASTEXITCODE
