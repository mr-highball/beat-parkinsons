# Copyright (c) 2026 beat-parkinsons contributors. All rights reserved.
param([string]$Compiler = $env:FPC)

$ErrorActionPreference = 'Stop'
if (-not $Compiler) {
  $Compiler = 'fpc'
}
$compilerPath = (Get-Command $Compiler -CommandType Application).Source
$experiment = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$run = Join-Path $experiment 'build/unknown-adjudication'
$inputDir = Join-Path $run 'input'
$outputDir = Join-Path $run 'output'
$bin = Join-Path $run 'bin'
$units = Join-Path $run 'units'
New-Item -ItemType Directory -Force $inputDir, $outputDir, $bin, $units | Out-Null

$inputs = [ordered]@{
  'freeze.tsv' = 'freeze.tsv'
  'freeze.sha256' = 'freeze.sha256'
  'verdicts.tsv' = 'verdicts.tsv'
  'assessments.tsv' = 'followup/assessments.tsv'
  'coverage-by-claim.tsv' = 'followup/context-coverage/coverage-by-claim.tsv'
  'prior-adjudications.tsv' = 'followup/weak-direction-audit-nov15/prior-adjudications.tsv'
}
$fingerprints = @{}
foreach ($entry in $inputs.GetEnumerator()) {
  $livePath = Join-Path $experiment $entry.Value
  $snapshot = Join-Path $inputDir $entry.Key
  Copy-Item -LiteralPath $livePath -Destination $snapshot
  $fingerprints[$entry.Key] = (Get-FileHash -LiteralPath $snapshot).Hash
}
$source = Join-Path $PSScriptRoot 'foodexperiment.unknownadjudication.lpr'
$flags = @('-B', '-Pi386', '-Twin32', '-Sa', '-Cr', '-Co', '-Ci', '-gl', '-O2',
  "-Fu$PSScriptRoot", "-FU$units", "-FE$bin")
& $compilerPath @flags $source | Tee-Object -FilePath (Join-Path $run 'compile.log')
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
& (Join-Path $bin 'foodexperiment.unknownadjudication.exe') $inputDir $outputDir |
  Tee-Object -FilePath (Join-Path $run 'run.log')
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$rows = @("experiment_relative_path`tsha256")
foreach ($entry in $inputs.GetEnumerator()) {
  $livePath = Join-Path $experiment $entry.Value
  $liveHash = (Get-FileHash -LiteralPath $livePath).Hash
  if ($liveHash -ne $fingerprints[$entry.Key]) {
    throw "Input changed during replay: $($entry.Value)"
  }
  $rows += "$($entry.Value)`t$($liveHash.ToLowerInvariant())"
}
$sourceHash = (Get-FileHash -LiteralPath $source).Hash.ToLowerInvariant()
$rows += "tools/foodexperiment.unknownadjudication.lpr`t$sourceHash"
[IO.File]::WriteAllText((Join-Path $run 'input-sha256.tsv'), ($rows -join "`n") + "`n")
