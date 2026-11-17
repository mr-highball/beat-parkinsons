# Copyright (c) 2026 beat-parkinsons contributors. All rights reserved.
param([string]$Compiler = $env:FPC)

$ErrorActionPreference = 'Stop'
if (-not $Compiler) {
  $Compiler = 'fpc'
}
$Compiler = (Get-Command $Compiler -CommandType Application).Source

function Read-CompilerProbe([string]$Option) {
  $value = & $Compiler $Option
  if ($LASTEXITCODE -ne 0) {
    throw "Compiler probe failed for $Option"
  }
  $value.Trim()
}

$version = Read-CompilerProbe '-iV'
$cpu = Read-CompilerProbe '-iTP'
$os = Read-CompilerProbe '-iTO'
$experiment = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$source = Join-Path $PSScriptRoot 'foodexperiment.coveragequeue.lpr'
$tools = Join-Path $experiment 'tools'
$run = Join-Path $experiment "build/coverage-queue/$cpu-$os-$version"
$units = Join-Path $run 'units'
$bin = Join-Path $run 'bin'
$output = Join-Path $run 'output'
New-Item -ItemType Directory -Force $units, $bin, $output | Out-Null

$inputs = 'freeze.tsv', 'freeze.sha256', 'verdicts.tsv', 'followup/assessments.tsv',
  'followup/claim-depth.tsv'
function Read-InputFingerprints {
  foreach ($inputFile in $inputs) {
    $hash = (Get-FileHash -LiteralPath (Join-Path $experiment $inputFile)).Hash.ToLowerInvariant()
    "$inputFile`t$hash"
  }
}
$before = Read-InputFingerprints
$flags = @('-B', '-Mdelphi', "-P$cpu", "-T$os", '-Sa', '-Cr', '-Co', '-Ci', '-gl',
  "-Fu$tools", "-FU$units", "-FE$bin")
$receipt = Join-Path $run 'build-receipt.txt'
@("Compiler $Compiler", "FPC $version $cpu-$os", ('Flags ' + ($flags -join ' '))) |
  Set-Content -LiteralPath $receipt -Encoding utf8NoBOM
Write-Output "$Compiler | $version | $cpu-$os"
& $Compiler @flags $source 2>&1 | Tee-Object -FilePath (Join-Path $run 'compile.log')
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$program = Join-Path $bin 'foodexperiment.coveragequeue'
if ($os -like 'win*') {
  $program += '.exe'
}
& $program $experiment $output 2>&1 | Tee-Object -FilePath (Join-Path $run 'run.log')
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
$after = Read-InputFingerprints
if (Compare-Object $before $after) {
  throw 'Input ledgers changed during replay. Re-run before using the outputs.'
}
@("experiment_relative_path`tsha256") + $before |
  Set-Content -LiteralPath (Join-Path $run 'input-sha256.tsv') -Encoding utf8NoBOM
Add-Content -LiteralPath $receipt -Value 'Input SHA-256 unchanged through compilation and replay.'
