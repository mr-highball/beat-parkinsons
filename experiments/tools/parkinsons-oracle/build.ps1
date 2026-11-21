# Copyright (c) 2026 beat-parkinsons contributors. All rights reserved.
[CmdletBinding()]
param(
    [string] $Compiler = $env:FPC,
    [switch] $RefreshCatalog,
    [string] $BuildRoot,
    [string] $Pas2js = $env:PAS2JS,
    [string] $Runtime = $env:PAS2JS_RTL,
    [string] $UnitRoot = $env:PAS2JS_UNITS,
    [switch] $SkipWeb
)

$ErrorActionPreference = 'Stop'
$Repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
if (!$Compiler) {
    $Command = Get-Command fpc -ErrorAction SilentlyContinue
    if (!$Command) {
        throw 'Set FPC or pass -Compiler with a native Free Pascal compiler.'
    }
    $Compiler = $Command.Source
}

$Vendor = Join-Path $Repo 'experiments/tools/vendor/wfc/src'
if (!(Test-Path -LiteralPath (Join-Path $Vendor 'wfc.pas') -PathType Leaf)) {
    throw 'Initialize experiments/tools/vendor/wfc before building the oracle.'
}
if (!$BuildRoot) {
    $BuildRoot = Join-Path $Repo 'build/parkinsons-oracle'
}
$Units = Join-Path $BuildRoot 'units'
$Bin = Join-Path $BuildRoot 'bin'
New-Item -ItemType Directory -Path $Units, $Bin -Force | Out-Null
$CompilerArgs = @(
    "-Fu$PSScriptRoot",
    "-Fu$Vendor",
    "-Fu$Repo/experiments/1000_see_what_sticks_food/tools",
    "-FU$Units",
    "-FE$Bin",
    (Join-Path $PSScriptRoot 'parkinsons-oracle.lpr')
)
& $Compiler @CompilerArgs
if ($LASTEXITCODE) {
    exit $LASTEXITCODE
}
if ($RefreshCatalog) {
    $Name = if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        'parkinsons-oracle.exe'
    } else {
        'parkinsons-oracle'
    }
    $Executable = Join-Path $Bin $Name
    & $Executable index $Repo
    if ($LASTEXITCODE) {
        exit $LASTEXITCODE
    }
}
if (!$SkipWeb) {
    $WebBuild = Join-Path $PSScriptRoot 'web/build.ps1'
    if (Test-Path -LiteralPath $WebBuild -PathType Leaf) {
        $WebArgs = @{
            NativeCompiler  = $Compiler
            OutputDirectory = (Join-Path $BuildRoot 'web')
        }
        if ($Pas2js) { $WebArgs.Compiler = $Pas2js }
        if ($Runtime) { $WebArgs.Runtime = $Runtime }
        if ($UnitRoot) { $WebArgs.UnitRoot = $UnitRoot }
        & $WebBuild @WebArgs
        if ($LASTEXITCODE) {
            exit $LASTEXITCODE
        }
    }
}
