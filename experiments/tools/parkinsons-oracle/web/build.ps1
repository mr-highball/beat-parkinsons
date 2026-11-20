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
if (!$Compiler) {
    $Compiler = (Get-Command pas2js -ErrorAction Stop).Source
}
if (!$Runtime) {
    $Candidate = Join-Path (Split-Path -Parent (Get-Command $Compiler).Source) 'rtl.js'
    if (!(Test-Path -LiteralPath $Candidate -PathType Leaf)) {
        throw 'Pass -Runtime with the rtl.js distributed with this pas2js compiler.'
    }
    $Runtime = $Candidate
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
    & $GraphExe $Repo (Join-Path $GlyphBuild 'oraclegraph.inc')
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
}
$CompilerArgs = @(
    '-Mdelphi', '-Tbrowser', '-Jc',
    "-Fu$Vendor", "-Fi$Vendor", "-Fu$SharedUnits", "-Fi$GlyphBuild", "-FE$Output"
)
if ($StaticModel) { $CompilerArgs += '-dORACLE_STATIC' }
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
