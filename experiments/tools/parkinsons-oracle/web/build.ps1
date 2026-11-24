# Copyright (c) 2026 beat-parkinsons contributors. All rights reserved.
[CmdletBinding()]
param(
    [string] $Compiler = $env:PAS2JS,
    [string] $Runtime = $env:PAS2JS_RTL,
    [string] $UnitRoot = $env:PAS2JS_UNITS,
    [string] $NativeCompiler = $env:FPC,
    [string] $OutputDirectory,
    [switch] $StaticModel
)

$ErrorActionPreference = 'Stop'
$Repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../../..')).Path
$LocalPas2jsDir = Join-Path $Repo 'build/parkinsons-oracle/pas2js-aug'
$LocalPas2jsExe = Join-Path $LocalPas2jsDir ($(if ($IsWindows -or $env:OS -eq 'Windows_NT') { 'pas2js.exe' } else { 'pas2js' }))
$LocalRtl = Join-Path $Repo 'build/parkinsons-oracle/pas2js-aug-source/utils/pas2js/dist/rtl.js'
$LocalPackages = Join-Path $Repo 'build/parkinsons-oracle/pas2js-source/packages'
if (!$Compiler) {
    if (Test-Path -LiteralPath $LocalPas2jsExe -PathType Leaf) {
        $Compiler = $LocalPas2jsExe
    } else {
        $Compiler = (Get-Command pas2js -ErrorAction Stop).Source
    }
}
if (!$Runtime) {
    $Candidate = Join-Path (Split-Path -Parent (Get-Command $Compiler).Source) 'rtl.js'
    if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
        $Runtime = $Candidate
    } elseif (Test-Path -LiteralPath $LocalRtl -PathType Leaf) {
        $Runtime = $LocalRtl
    } else {
        throw 'Pass -Runtime with the rtl.js distributed with this pas2js compiler.'
    }
}
if (!$UnitRoot -and (Test-Path -LiteralPath $LocalPackages -PathType Container)) {
    $UnitRoot = $LocalPackages
}
$Vendor = Join-Path $Repo 'experiments/tools/vendor/nyx/src'
$SharedUnits = Split-Path -Parent $PSScriptRoot
$Output = $OutputDirectory
if (!$Output) {
    $Output = Join-Path $Repo 'build/parkinsons-oracle/web'
}
New-Item -ItemType Directory -Path $Output -Force | Out-Null
if (!$NativeCompiler) {
    $NativeCompiler = (Get-Command fpc -ErrorAction Stop).Source
}
$GlyphBuild = Join-Path $Repo ('build/parkinsons-oracle/glyph-tools/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path "$GlyphBuild/bin", "$GlyphBuild/units" -Force | Out-Null
if (!$StaticModel) {
    $GraphArgs = @('-Mdelphi', '-Sa', '-Cr', '-Co', '-Ci', '-gl', "-Fu$SharedUnits",
        "-Fu$Repo/experiments/tools/vendor/wfc/src",
        "-Fu$Repo/experiments/1000_see_what_sticks_food/tools",
        "-FU$GlyphBuild/units", "-FE$GlyphBuild/bin", (Join-Path $SharedUnits 'graph.embed.lpr'))
    & $NativeCompiler @GraphArgs
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
    $GraphExe = Join-Path $GlyphBuild 'bin/graph.embed.exe'
    if (!(Test-Path -LiteralPath $GraphExe)) { $GraphExe = Join-Path $GlyphBuild 'bin/graph.embed' }
    & $GraphExe $Repo (Join-Path $Output 'graph.json')
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
}
$RecipesArgs = @('-Mdelphi', '-Sa', '-Cr', '-Co', '-Ci', '-gl', "-Fu$SharedUnits",
    "-Fu$Repo/experiments/tools/vendor/wfc/src",
    "-FU$GlyphBuild/units", "-FE$GlyphBuild/bin", (Join-Path $SharedUnits 'recipes.embed.lpr'))
& $NativeCompiler @RecipesArgs
if ($LASTEXITCODE) { exit $LASTEXITCODE }
$RecipesExe = Join-Path $GlyphBuild 'bin/recipes.embed.exe'
if (!(Test-Path -LiteralPath $RecipesExe)) { $RecipesExe = Join-Path $GlyphBuild 'bin/recipes.embed' }
& $RecipesExe $Repo (Join-Path $Output 'recipes.json')
if ($LASTEXITCODE) { exit $LASTEXITCODE }

$CompilerArgs = @(
    '-Mdelphi', '-Tbrowser', '-Jc',
    "-Fu$Vendor", "-Fi$Vendor", "-Fu$Repo/experiments/tools/vendor/wfc/src",
    "-Fu$SharedUnits", "-FE$Output"
)
if ($UnitRoot) {
    $Packages = (Resolve-Path -LiteralPath $UnitRoot).Path
    $CompilerArgs += "-Fu$Packages/*/src"
}
$CompilerArgs += (Join-Path $PSScriptRoot 'oracleweb.lpr')
& $Compiler @CompilerArgs
if ($LASTEXITCODE) {
    exit $LASTEXITCODE
}
Move-Item -LiteralPath (Join-Path $Output 'oracleweb.js') -Destination (Join-Path $Output 'app.js') -Force
Copy-Item -LiteralPath $Runtime -Destination (Join-Path $Output 'rtl.js') -Force
foreach ($Name in @('index.html', 'oracle.css')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $Name) -Destination $Output -Force
}
& $NativeCompiler -Mdelphi -Sa -Cr -Co -Ci -gl "-FU$GlyphBuild/units" "-FE$GlyphBuild/bin" (Join-Path $SharedUnits 'glyphs.embed.lpr')
if ($LASTEXITCODE) { exit $LASTEXITCODE }
$GlyphExe = Join-Path $GlyphBuild 'bin/glyphs.embed.exe'
if (!(Test-Path -LiteralPath $GlyphExe)) { $GlyphExe = Join-Path $GlyphBuild 'bin/glyphs.embed' }
$InlineCss = Join-Path $GlyphBuild 'glyphs.css'
& $GlyphExe (Join-Path $PSScriptRoot 'assets/glyphs') $InlineCss
if ($LASTEXITCODE) { exit $LASTEXITCODE }
[IO.File]::AppendAllText((Join-Path $Output 'oracle.css'), [IO.File]::ReadAllText($InlineCss), [Text.UTF8Encoding]::new($false))

if (!$StaticModel) {
    foreach ($Name in @('app.js', 'rtl.js', 'oracle.css', 'graph.json', 'recipes.json')) {
        $Asset = Join-Path $Output $Name
        $InputStream = [IO.File]::OpenRead($Asset)
        try {
            $Compressed = [IO.File]::Create("$Asset.gz")
            try {
                $Gzip = [IO.Compression.GZipStream]::new($Compressed, [IO.Compression.CompressionLevel]::Optimal)
                try {
                    $InputStream.CopyTo($Gzip)
                } finally {
                    $Gzip.Dispose()
                }
            } finally {
                $Compressed.Dispose()
            }
        } finally {
            $InputStream.Dispose()
        }
    }
}

$IngredientAssets = Join-Path $PSScriptRoot 'assets/ingredients'
$GalleryArgs = @('-Mdelphi', '-Sa', '-Cr', '-Co', '-Ci', '-gl', "-Fu$SharedUnits",
    "-Fu$Repo/experiments/1000_see_what_sticks_food/tools",
    "-FU$GlyphBuild/units", "-FE$GlyphBuild/bin", (Join-Path $SharedUnits 'ingredients.gallery.check.lpr'))
& $NativeCompiler @GalleryArgs
if ($LASTEXITCODE) { exit $LASTEXITCODE }
$GalleryExe = Join-Path $GlyphBuild 'bin/ingredients.gallery.check.exe'
if (!(Test-Path -LiteralPath $GalleryExe)) {
    $GalleryExe = Join-Path $GlyphBuild 'bin/ingredients.gallery.check'
}
$IngredientOutput = Join-Path $Output 'ingredients'
& $GalleryExe (Join-Path $Repo 'experiments/1000_see_what_sticks_food_round_2/ingredients.tsv') $IngredientAssets $IngredientOutput
if ($LASTEXITCODE) { exit $LASTEXITCODE }
New-Item -ItemType Directory -Path $IngredientOutput -Force | Out-Null
Get-ChildItem -LiteralPath $IngredientAssets -File -Filter '*.jpg' | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $IngredientOutput -Force
}
