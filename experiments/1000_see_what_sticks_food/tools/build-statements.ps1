# Copyright (c) 2026 the beat-parkinsons contributors.
# All rights reserved.

[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$statementFpc = if ($env:FPC) { $env:FPC } else { 'fpc' }
$compiler = (Get-Command -Name $statementFpc -CommandType Application).Source

$version = & $compiler '-iV'
if ($LASTEXITCODE -ne 0) { throw 'FPC version probe failed' }
$cpu = & $compiler '-iTP'
if ($LASTEXITCODE -ne 0) { throw 'FPC CPU probe failed' }
$os = & $compiler '-iTO'
if ($LASTEXITCODE -ne 0) { throw 'FPC OS probe failed' }
Write-Host "FPC $version $cpu-$os from $compiler"

$experimentDir = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $experimentDir "build/statements/$version-$cpu-$os"
$unitDir = Join-Path $buildDir 'units'
$binDir = Join-Path $buildDir 'bin'
New-Item -ItemType Directory -Force -Path $unitDir, $binDir | Out-Null

$source = Join-Path $PSScriptRoot 'statement-tool.lpr'
$executable = Join-Path $binDir 'statement-tool.exe'
$compilerArgs = @('-B', '-Mdelphi', '-Sa', '-Cr', '-Co', '-Ci', '-gl',
    "-FU$unitDir", "-FE$binDir", '-ostatement-tool.exe', $source)
& $compiler @compilerArgs
if ($LASTEXITCODE -ne 0) { throw 'Statement tool build failed' }
if ($Check) {
    & $executable 'verify' $experimentDir
    if ($LASTEXITCODE -ne 0) { throw 'Statement verification failed' }
}
Write-Output $executable
