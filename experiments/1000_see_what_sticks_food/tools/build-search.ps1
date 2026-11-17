# Copyright (c) 2026 beat-parkinsons contributors. All rights reserved.
param([string]$Compiler = $env:FPC)

$ErrorActionPreference = 'Stop'
if (-not $Compiler) {
  $Compiler = 'fpc'
}
$Compiler = (Get-Command $Compiler -CommandType Application).Source
$version = (& $Compiler '-iV').Trim()
if ($LASTEXITCODE -ne 0) {
  throw 'FPC version probe failed.'
}
Write-Output "$Compiler | $version | i386-win32"

$experiment = Split-Path -Parent $PSScriptRoot
$build = Join-Path $experiment "build/search-$version-i386-win32"
$units = Join-Path $build 'units'
$bin = Join-Path $build 'bin'
New-Item -ItemType Directory -Force $units, $bin | Out-Null
$source = Join-Path $PSScriptRoot 'foodexperiment.search.lpr'
$flags = @('-B', '-Pi386', '-Twin32', '-Sa', '-Cr', '-Co', '-Ci', '-gl', '-O2',
  "-Fu$PSScriptRoot", "-FU$units", "-FE$bin")
& $Compiler @flags $source
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
Write-Output (Join-Path $bin 'foodexperiment.search.exe')
