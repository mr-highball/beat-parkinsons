# Copyright (c) 2026 beat-parkinsons contributors. All rights reserved.
param([string]$Compiler = $env:FPC)

$ErrorActionPreference = 'Stop'
if (-not $Compiler) {
  $Compiler = 'fpc'
}
$Compiler = (Get-Command $Compiler -ErrorAction Stop).Source
Write-Output $Compiler

function Read-CompilerValue([string]$Option) {
  $value = & $Compiler $Option
  if ($LASTEXITCODE -ne 0) {
    throw "Compiler probe failed: $Option"
  }
  return "$value".Trim()
}

$version = Read-CompilerValue '-iV'
$cpu = Read-CompilerValue '-iTP'
$target = Read-CompilerValue '-iTO'
Write-Output "$version $cpu $target"

$experiment = Split-Path -Parent $PSScriptRoot
$build = Join-Path $experiment "build/scan-$version-$cpu-$target"
$units = Join-Path $build 'units'
$bin = Join-Path $build 'bin'
New-Item -ItemType Directory -Force $units, $bin | Out-Null
$source = Join-Path $PSScriptRoot 'foodexperiment.scan.lpr'
$flags = @('-B', '-Sa', '-Cr', '-Co', '-Ci', '-gl', '-O2',
  "-Fu$PSScriptRoot", "-FU$units", "-FE$bin")
& $Compiler @flags $source
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$exe = Join-Path $bin 'foodexperiment.scan.exe'
& $exe 'check'
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$screen = Join-Path $PSScriptRoot 'foodexperiment.screen.lpr'
& $Compiler @flags $screen
exit $LASTEXITCODE
