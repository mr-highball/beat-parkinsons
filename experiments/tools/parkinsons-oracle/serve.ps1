# Copyright (c) 2026 beat-parkinsons contributors. All rights reserved.
$ErrorActionPreference = 'Stop'
$Repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$Name = if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    'parkinsons-oracle.exe'
} else {
    'parkinsons-oracle'
}
$Executable = Join-Path $Repo "build/parkinsons-oracle/bin/$Name"
if (!(Test-Path -LiteralPath $Executable -PathType Leaf)) {
    [Console]::Error.WriteLine('Build the oracle with experiments/tools/parkinsons-oracle/build.ps1.')
    exit 1
}
& $Executable serve $Repo
exit $LASTEXITCODE
