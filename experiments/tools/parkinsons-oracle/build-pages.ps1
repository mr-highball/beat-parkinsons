# Copyright (c) 2026 beat-parkinsons contributors. All rights reserved.
[CmdletBinding()]
param(
    [string] $Compiler = $env:FPC,
    [string] $Pas2js = $env:PAS2JS,
    [string] $Runtime = $env:PAS2JS_RTL,
    [string] $UnitRoot = $env:PAS2JS_UNITS,
    [string] $RepositoryUrl
)

$ErrorActionPreference = 'Stop'
$Repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$OracleBuild = Join-Path $Repo 'build/parkinsons-oracle'
Push-Location $Repo
try {
    $Revision = (git rev-parse --verify HEAD)
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
    git diff --quiet HEAD -- research
    if ($LASTEXITCODE -or @(git ls-files --others -- research).Count -ne 0) {
        throw 'Commit the research changes before building a model linked to a Git revision.'
    }
    if ($RepositoryUrl) {
        $RepositoryUrl = ($RepositoryUrl.TrimEnd('/')) -replace '\.git$', ''
        if ($RepositoryUrl -notmatch '^https://github\.com/[\w.-]+/[\w.-]+$') {
            throw 'Use -RepositoryUrl with the GitHub repository URL for published citations.'
        }
    }
    $Id = '{0}-{1}' -f $Revision.Substring(0, 12), [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $BuildRoot = Join-Path $OracleBuild "pages-work/$Id"
    $Stage = Join-Path $BuildRoot 'site'
    $Pages = Join-Path $OracleBuild 'pages'
    $Published = Join-Path $Pages $Id
    New-Item -ItemType Directory -Path $BuildRoot, $Pages -Force | Out-Null

    & (Join-Path $PSScriptRoot 'build.ps1') -Compiler $Compiler -BuildRoot $BuildRoot
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
    & (Join-Path $PSScriptRoot 'web/build.ps1') -Compiler $Pas2js -Runtime $Runtime -UnitRoot $UnitRoot -OutputDirectory $Stage
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
    $Notices = (New-Item -ItemType Directory -Path (Join-Path $Stage 'licenses')).FullName
    $Nyx = Join-Path $Repo 'experiments/tools/vendor/nyx'
    Copy-Item -LiteralPath (Join-Path $Nyx 'LICENSE') -Destination (Join-Path $Notices 'nyx.txt')
    Copy-Item -LiteralPath (Join-Path $Nyx 'data/unicode/17.0.0/LICENSE.txt') -Destination (Join-Path $Notices 'unicode.txt')
    if ($UnitRoot) {
        $Pas2jsDistribution = Split-Path -Parent (Resolve-Path -LiteralPath $UnitRoot).Path
        foreach ($Notice in @('LICENSE', 'COPYING.txt')) {
            $From = Join-Path $Pas2jsDistribution $Notice
            if (Test-Path -LiteralPath $From -PathType Leaf) {
                $Name = 'pas2js-' + [IO.Path]::GetFileNameWithoutExtension($Notice) + '.txt'
                Copy-Item -LiteralPath $From -Destination (Join-Path $Notices $Name)
            }
        }
    }
    $ExecutableName = if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        'parkinsons-oracle.exe'
    } else {
        'parkinsons-oracle'
    }
    $Exe = Join-Path $BuildRoot "bin/$ExecutableName"
    $Model = "model/$Revision"
    $Arguments = @('model', $Repo, (Join-Path $Stage $Model))
    if ($RepositoryUrl) {
        $Arguments += $RepositoryUrl
    }
    & $Exe @Arguments
    if ($LASTEXITCODE) { exit $LASTEXITCODE }

    $CurrentRevision = git rev-parse --verify HEAD
    if ($LASTEXITCODE -or $CurrentRevision -ne $Revision) {
        throw 'The committed revision changed during the build. Build the new revision again.'
    }
    git diff --quiet HEAD -- research
    if ($LASTEXITCODE -or @(git ls-files --others -- research).Count -ne 0) {
        throw 'The research working tree changed during the build.'
    }
    $Assets = @('index.html', 'app.js', 'rtl.js', 'oracle.css', "$Model/claims.json",
        "$Model/search/manifest.json", "$Model/search/documents.json")
    foreach ($Asset in $Assets) {
        if (!(Test-Path -LiteralPath (Join-Path $Stage $Asset) -PathType Leaf)) {
            throw "Published asset missing: $Asset"
        }
    }
    $Html = Join-Path $Stage 'index.html'
    $Markup = [IO.File]::ReadAllText($Html)
    if (!$Markup.Contains('<head>')) {
        throw 'Unable to configure the static Nyx entry point.'
    }
    $Meta = "<meta name=""oracle-revision"" content=""$Revision"">"
    [IO.File]::WriteAllText($Html, $Markup.Replace('<head>', "<head>$([char]10)  $Meta"),
        [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $Stage '.nojekyll'), '')
    $Bytes = (Get-ChildItem -LiteralPath $Stage -File -Recurse | Measure-Object Length -Sum).Sum
    if ($Bytes -gt 1000000000) {
        throw "The complete $Bytes-byte site exceeds the GitHub Pages size limit."
    }

    $Stage = (Resolve-Path -LiteralPath $Stage).Path
    $OracleBuild = (Resolve-Path -LiteralPath $OracleBuild).Path
    $Pages = (Resolve-Path -LiteralPath $Pages).Path
    $Published = Join-Path $Pages $Id
    if (!$Stage.StartsWith($OracleBuild + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or
        !$Published.StartsWith($Pages + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
        throw 'The Pages artifact directories must remain under the ignored oracle build directory.'
    }
    Move-Item -LiteralPath $Stage -Destination $Published
    [pscustomobject]@{ Path = $Published; Revision = $Revision; Bytes = $Bytes; Repository = $RepositoryUrl }
}
finally {
    Pop-Location
}
