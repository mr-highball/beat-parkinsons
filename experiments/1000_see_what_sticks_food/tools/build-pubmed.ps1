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
$build = Join-Path $experiment "build/pubmed-$version-i386-win32"
$units = Join-Path $build 'units'
$bin = Join-Path $build 'bin'
New-Item -ItemType Directory -Force $units, $bin | Out-Null
$flags = @('-B', '-Pi386', '-Twin32', '-Sa', '-Cr', '-Co', '-Ci', '-gl', '-O2',
  "-Fu$PSScriptRoot", "-FU$units", "-FE$bin")
foreach ($program in 'foodexperiment.pubmed', 'foodexperiment.pubmedabstracts', 'foodexperiment.pubmedaudit',
    'foodexperiment.pubmedquery.tests') {
  $source = Join-Path $PSScriptRoot "$program.lpr"
  & $Compiler @flags $source
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
  Write-Output (Join-Path $bin "$program.exe")
}

& (Join-Path $bin 'foodexperiment.pubmedquery.tests.exe')
exit $LASTEXITCODE
