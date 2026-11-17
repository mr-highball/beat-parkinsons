# Copyright (c) 2026 beat-parkinsons contributors. All rights reserved.
$ErrorActionPreference = 'Stop'
$Repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
# A compatibility checkout can link its Git metadata and build directory to the
# moved checkout. Bind the catalog to that physical checkout on a fresh launch.
$GitMetadata = Get-Item -LiteralPath (Join-Path $Repo '.git') -Force
if ($GitMetadata.LinkType -eq 'Junction') {
    $GitTarget = $GitMetadata.ResolveLinkTarget($true)
    if ($GitTarget -and $GitTarget.Name -eq '.git') {
        $PhysicalRepo = Split-Path -Parent $GitTarget.FullName
        if ((Test-Path -LiteralPath (Join-Path $PhysicalRepo 'research') -PathType Container) -and
            (Test-Path -LiteralPath (Join-Path $PhysicalRepo 'experiments') -PathType Container)) {
            $Repo = $PhysicalRepo
        }
    }
}
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
