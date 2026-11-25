# Copyright (c) 2026 beat-parkinsons contributors. All rights reserved.
<#
.SYNOPSIS
    Bootstraps the Beat Parkinson's / Parkinson's Oracle toolchain on Windows.

.DESCRIPTION
    Initializes required Git submodules (wfc, nyx), verifies or installs Free Pascal,
    builds the pinned SHA-256-verified pas2js 3.3.1 browser compiler into build/,
    compiles parkinsons-oracle.exe and the Nyx web application, optionally indexes
    the local SQLite FTS5 research catalog, and optionally runs all portability unit tests.

.EXAMPLE
    ./scripts/bootstrap.ps1
    ./scripts/bootstrap.ps1 -RefreshCatalog -RunTests
    ./scripts/bootstrap.ps1 -InstallFpc -RefreshCatalog -RunTests
#>
[CmdletBinding()]
param(
    [string] $Compiler = $env:FPC,
    [switch] $InstallFpc,
    [switch] $SkipSubmodules,
    [switch] $SkipPas2js,
    [switch] $SkipBuild,
    [switch] $RefreshCatalog,
    [switch] $RunTests,
    [string] $BuildRoot
)

$ErrorActionPreference = 'Stop'

$FpcVersion = '3.2.2'
$FpcInstallerUrl = 'https://downloads.freepascal.org/fpc/dist/3.2.2/i386-win32/fpc-3.2.2.i386-win32.exe'
$FpcInstallerSha256 = '7ec78b1790ecac7685f440b17f9e03865bc09846b7c068a9270c4d37704b5ac8'
$Pas2jsRevision = 'fa10c59214cd226c60af465c831d66a7321f0214'
$Pas2jsSourceSha256 = '5a2ad292c8606b899ba384d81b97e789171a335759b67e338d4a37903dbe18f1'
$FpcSourceRevision = 'd7f522a5611b13f37164c5eac87ade49b2f5b324'
$FpcSourceSha256 = '84c70c67fd6b7da2be53bfc2613da2710a302432505489abdc732f89485fdc18'

$Repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (!$BuildRoot) {
    $BuildRoot = Join-Path $Repo 'build/parkinsons-oracle'
}
$BuildRoot = [IO.Path]::GetFullPath($BuildRoot)
New-Item -ItemType Directory -Path $BuildRoot -Force | Out-Null

function Resolve-FpcBinary {
    param([string] $Preferred)
    if ($Preferred) {
        if (Test-Path -LiteralPath $Preferred -PathType Leaf) {
            return (Resolve-Path -LiteralPath $Preferred).Path
        }
        $Cmd = Get-Command $Preferred -ErrorAction SilentlyContinue
        if ($Cmd) { return $Cmd.Source }
        throw "Configured Free Pascal compiler not found: $Preferred"
    }
    $Cmd = Get-Command fpc -ErrorAction SilentlyContinue
    if ($Cmd) { return $Cmd.Source }

    $Candidates = @(
        (Join-Path $BuildRoot 'fpc-3.2.2/bin/i386-win32/fpc.exe'),
        'C:\FPC\3.2.2\bin\i386-win32\fpc.exe'
    )
    foreach ($Path in $Candidates) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            return (Resolve-Path -LiteralPath $Path).Path
        }
    }
    return $null
}

function Ensure-VerifiedDownload {
    param(
        [string] $Url,
        [string] $Destination,
        [string] $ExpectedSha256,
        [string] $Label
    )
    Write-Host "Downloading $Label..."
    $Curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($Curl) {
        & $Curl.Source --fail --location --retry 3 --output $Destination $Url
        if ($LASTEXITCODE) { throw "Failed to download $Label (curl exit $LASTEXITCODE)." }
    } else {
        Invoke-WebRequest -Uri $Url -OutFile $Destination
    }
    $Actual = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($Actual -ne $ExpectedSha256) {
        Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
        throw "$Label SHA-256 mismatch: expected $ExpectedSha256, got $Actual"
    }
}

Write-Host "==> Repository root: $Repo"
Write-Host "==> Build directory: $BuildRoot"

# 1. Verify Git & initialize required submodules
if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git is required on PATH.'
}
if (!$SkipSubmodules) {
    Write-Host '==> Initializing submodules (wfc, nyx)...'
    Push-Location $Repo
    try {
        & git submodule update --init --recursive -- experiments/tools/vendor/wfc experiments/tools/vendor/nyx
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
    } finally {
        Pop-Location
    }
}

# 2. Locate or install Free Pascal Compiler
$FpcBin = Resolve-FpcBinary -Preferred $Compiler
if (!$FpcBin -and $InstallFpc) {
    $FpcDir = Join-Path $BuildRoot "fpc-$FpcVersion"
    $Installer = Join-Path $BuildRoot "fpc-$FpcVersion.i386-win32.exe"
    Ensure-VerifiedDownload -Url $FpcInstallerUrl -Destination $Installer -ExpectedSha256 $FpcInstallerSha256 -Label "FPC $FpcVersion installer"
    Write-Host "==> Installing verified FPC $FpcVersion into $FpcDir..."
    $Proc = Start-Process -FilePath $Installer -Wait -PassThru -WindowStyle Hidden -ArgumentList @(
        '/SP-', '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/DIR=$FpcDir"
    )
    Remove-Item -LiteralPath $Installer -Force -ErrorAction SilentlyContinue
    if ($Proc.ExitCode -ne 0) {
        throw "FPC installer exited with code $($Proc.ExitCode)."
    }
    $FpcBin = Resolve-FpcBinary -Preferred (Join-Path $FpcDir 'bin/i386-win32/fpc.exe')
}
if (!$FpcBin) {
    throw @"
Free Pascal (fpc) was not found on PATH or in standard install paths.
Install Free Pascal 3.2.2+ or re-run with -InstallFpc to install verified FPC $FpcVersion into the local ignored build/ directory:
  ./scripts/bootstrap.ps1 -InstallFpc
Or specify an existing compiler:
  ./scripts/bootstrap.ps1 -Compiler 'C:\FPC\3.2.2\bin\i386-win32\fpc.exe'
"@
}
$FoundFpcVersion = (& $FpcBin -iV).Trim()
Write-Host "==> Using Free Pascal: $FpcBin (version $FoundFpcVersion)"

# 3. Verify system SQLite on Windows
if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    $SqliteDll = Join-Path $env:SystemRoot 'System32\winsqlite3.dll'
    if (!(Test-Path -LiteralPath $SqliteDll -PathType Leaf)) {
        throw "Missing Windows system SQLite library at $SqliteDll (SQLite 3.43+ with FTS5 is required)."
    }
    $SqliteVer = (Get-Item -LiteralPath $SqliteDll).VersionInfo.ProductVersion
    Write-Host "==> System winsqlite3.dll: $SqliteVer"
}

# 4. Build or reuse the pinned pas2js 3.3.1 toolchain in the paths auto-discovered by web/build.ps1
$DefaultToolchainRoot = Join-Path $Repo 'build/parkinsons-oracle'
$Pas2jsExeName = if ($IsWindows -or $env:OS -eq 'Windows_NT') { 'pas2js.exe' } else { 'pas2js' }
$Pas2jsDir = Join-Path $BuildRoot 'pas2js-aug'
$Pas2jsExe = Join-Path $Pas2jsDir $Pas2jsExeName
$Pas2jsRtl = Join-Path $BuildRoot 'pas2js-aug-source/utils/pas2js/dist/rtl.js'
$Pas2jsPackages = Join-Path $BuildRoot 'pas2js-source/packages'

if (!$SkipPas2js) {
    $HavePas2js = (Test-Path -LiteralPath $Pas2jsExe -PathType Leaf) -and
                  (Test-Path -LiteralPath $Pas2jsRtl -PathType Leaf) -and
                  (Test-Path -LiteralPath $Pas2jsPackages -PathType Container)
    if (!$HavePas2js) {
        $SharedExe = Join-Path $DefaultToolchainRoot "pas2js-aug/$Pas2jsExeName"
        $SharedRtl = Join-Path $DefaultToolchainRoot 'pas2js-aug-source/utils/pas2js/dist/rtl.js'
        $SharedPackages = Join-Path $DefaultToolchainRoot 'pas2js-source/packages'
        if ((Test-Path -LiteralPath $SharedExe -PathType Leaf) -and
            (Test-Path -LiteralPath $SharedRtl -PathType Leaf) -and
            (Test-Path -LiteralPath $SharedPackages -PathType Container)) {
            $Pas2jsExe = $SharedExe
            $Pas2jsRtl = $SharedRtl
            $Pas2jsPackages = $SharedPackages
            $HavePas2js = $true
        }
    }
    if ($HavePas2js) {
        $Pas2jsVer = (& $Pas2jsExe -iV).Trim()
        Write-Host "==> Reusing pinned pas2js toolchain: $Pas2jsExe (version $Pas2jsVer)"
    } else {
        if (!(Get-Command tar.exe -ErrorAction SilentlyContinue)) {
            throw 'tar.exe is required to extract the pinned pas2js source archives.'
        }
        $Work = Join-Path $BuildRoot ('pas2js-work-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $Work -Force | Out-Null
        try {
            $Pas2jsTar = Join-Path $Work 'pas2js.tar.gz'
            $FpcTar = Join-Path $Work 'fpc-source.tar.gz'
            $Pas2jsSrc = Join-Path $BuildRoot 'pas2js-source'
            $FpcSrc = Join-Path $BuildRoot 'pas2js-aug-source'
            $UnitsDir = Join-Path $Work 'units'
            New-Item -ItemType Directory -Path $Pas2jsSrc, $FpcSrc, $Pas2jsDir, $UnitsDir -Force | Out-Null

            $Pas2jsUrl = "https://gitlab.com/freepascal.org/fpc/pas2js/-/archive/$Pas2jsRevision/pas2js-$Pas2jsRevision.tar.gz"
            $FpcUrl = "https://gitlab.com/freepascal.org/fpc/source/-/archive/$FpcSourceRevision/source-$FpcSourceRevision.tar.gz"

            Ensure-VerifiedDownload -Url $Pas2jsUrl -Destination $Pas2jsTar -ExpectedSha256 $Pas2jsSourceSha256 -Label 'pas2js packages archive'
            Ensure-VerifiedDownload -Url $FpcUrl -Destination $FpcTar -ExpectedSha256 $FpcSourceSha256 -Label 'FPC pas2js compiler archive'

            Write-Host '==> Extracting pinned pas2js sources...'
            $Pas2jsPrefix = "pas2js-$Pas2jsRevision"
            $FpcPrefix = "source-$FpcSourceRevision"
            & tar.exe -xzf $Pas2jsTar --strip-components=1 -C $Pas2jsSrc `
                "$Pas2jsPrefix/packages" "$Pas2jsPrefix/COPYING.txt" "$Pas2jsPrefix/LICENSE"
            if ($LASTEXITCODE) { exit $LASTEXITCODE }
            & tar.exe -xzf $FpcTar --strip-components=1 -C $FpcSrc `
                "$FpcPrefix/packages/pastojs" `
                "$FpcPrefix/packages/fcl-passrc" `
                "$FpcPrefix/packages/fcl-js" `
                "$FpcPrefix/packages/fcl-json" `
                "$FpcPrefix/utils/pas2js"
            if ($LASTEXITCODE) { exit $LASTEXITCODE }

            Write-Host '==> Compiling pinned pas2js 3.3.1...'
            & $FpcBin -Mobjfpc -O2 `
                "-Fu$FpcSrc/packages/pastojs/src" "-Fi$FpcSrc/packages/pastojs/src" `
                "-Fu$FpcSrc/packages/fcl-passrc/src" "-Fi$FpcSrc/packages/fcl-passrc/src" `
                "-Fu$FpcSrc/packages/fcl-js/src" "-Fi$FpcSrc/packages/fcl-js/src" `
                "-Fu$FpcSrc/packages/fcl-json/src" "-Fi$FpcSrc/packages/fcl-json/src" `
                "-FU$UnitsDir" "-FE$Pas2jsDir" `
                "$FpcSrc/utils/pas2js/pas2js.pp"
            if ($LASTEXITCODE) { exit $LASTEXITCODE }

            $Pas2jsVer = (& $Pas2jsExe -iV).Trim()
            Write-Host "==> Built pinned pas2js: $Pas2jsExe (version $Pas2jsVer)"
        } finally {
            Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# 5. Build Parkinson's Oracle native server + Nyx web app
if (!$SkipBuild) {
    Write-Host '==> Building Parkinson''s Oracle server and Nyx web application...'
    $BuildScript = Join-Path $Repo 'experiments/tools/parkinsons-oracle/build.ps1'
    $BuildParams = @{
        Compiler  = $FpcBin
        BuildRoot = $BuildRoot
    }
    if ($RefreshCatalog) { $BuildParams.RefreshCatalog = $true }
    if ($SkipPas2js) {
        $BuildParams.SkipWeb = $true
    } else {
        $BuildParams.Pas2js = $Pas2jsExe
        $BuildParams.Runtime = $Pas2jsRtl
        $BuildParams.UnitRoot = $Pas2jsPackages
    }
    & $BuildScript @BuildParams
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
}

# 6. Run strict portability unit tests when requested
if ($RunTests) {
    Write-Host '==> Running strict portability unit tests (-Mdelphi -Sa -Cr -Co -Ci -gl)...'
    $TestOut = Join-Path $BuildRoot 'ci-tests'
    New-Item -ItemType Directory -Path "$TestOut/units", "$TestOut/bin" -Force | Out-Null
    Push-Location $Repo
    try {
        foreach ($Test in @(
            'compat.tests.lpr',
            'graph.tests.lpr',
            'presentation.tests.lpr',
            'selection.tests.lpr',
            'rubric.tests.lpr',
            'ingredients.tests.lpr',
            'recipes.tests.lpr'
        )) {
            Write-Host "  -> $Test"
            & $FpcBin -Mdelphi -Sa -Cr -Co -Ci -gl `
                -Fuexperiments/tools/parkinsons-oracle `
                -Fuexperiments/tools/vendor/wfc/src `
                -Fuexperiments/1000_see_what_sticks_food/tools `
                "-FU$TestOut/units" "-FE$TestOut/bin" `
                "experiments/tools/parkinsons-oracle/$Test"
            if ($LASTEXITCODE) { exit $LASTEXITCODE }
            $Exe = Join-Path "$TestOut/bin" ($Test -replace '\.lpr$', '.exe')
            & $Exe
            if ($LASTEXITCODE) { exit $LASTEXITCODE }
        }
    } finally {
        Pop-Location
    }
}

$OracleExe = Join-Path $BuildRoot 'bin/parkinsons-oracle.exe'
Write-Host ''
Write-Host 'Bootstrap complete.'
Write-Host "  Oracle binary: $OracleExe"
Write-Host "  Web bundle:    $(Join-Path $BuildRoot 'web')"
Write-Host ''
Write-Host 'Next steps:'
Write-Host "  1. Index/refresh the research catalog (if not already run with -RefreshCatalog):"
Write-Host "     & `"$OracleExe`" index `"$Repo`""
Write-Host "  2. Launch the local web workbench (http://127.0.0.1:8795/):"
Write-Host "     & `"$OracleExe`" web `"$Repo`" 8795"
Write-Host "  3. Connect Parkinson's Oracle as an MCP stdio server:"
Write-Host "     & `"$OracleExe`" serve `"$Repo`""
