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
$build = Join-Path $experiment "build/followup-$version-i386-win32"
$units = Join-Path $build 'units'
$bin = Join-Path $build 'bin'
New-Item -ItemType Directory -Force $units, $bin | Out-Null
$flags = @('-B', '-Pi386', '-Twin32', '-Sa', '-Cr', '-Co', '-Ci', '-gl', '-O2',
  "-Fu$PSScriptRoot", "-FU$units", "-FE$bin")
foreach ($tool in @('registry', 'registryclaimscreen', 'depth', 'eudract', 'pmctext', 'kim', 'archiveaudit', 'whoexport',
  'abstractaudit', 'openalex', 'crossref', 'hal', 'theses', 'proceedings', 'mds', 'mdsassets',
  'mdsocr', 'jsdr', 'assessmentmerge')) {
  & $Compiler @flags (Join-Path $PSScriptRoot "foodexperiment.$tool.lpr")
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
  Write-Output (Join-Path $bin "foodexperiment.$tool.exe")
}
