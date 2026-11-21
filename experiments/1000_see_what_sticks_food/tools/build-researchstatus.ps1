$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ExpDir = Split-Path -Parent $ScriptDir
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ExpDir)

$Fpc = (Get-Command fpc -ErrorAction SilentlyContinue).Source
if (-not $Fpc) {
  $Fpc = 'C:\fpcupdeluxe\trunk\fpc\bin\i386-win32\fpc.exe'
}
$Ver = (& $Fpc -iV).Trim()
$Target = (& $Fpc -iTP).Trim() + '-' + (& $Fpc -iTO).Trim()
Write-Output ("FPC: $Fpc ($Ver, $Target)")

$BuildDir = Join-Path $ExpDir "build\researchstatus-$Ver-$Target"
$UnitsDir = Join-Path $BuildDir 'units'
$BinDir = Join-Path $BuildDir 'bin'
$FixtureDir = Join-Path $BuildDir 'fixtures'
if (Test-Path $FixtureDir) { Remove-Item -Recurse -Force $FixtureDir }
New-Item -ItemType Directory -Force -Path $UnitsDir, $BinDir, $FixtureDir | Out-Null

$OracleDir = Join-Path $RepoRoot 'experiments\tools\parkinsons-oracle'
$Flags = @(
  '-B', '-Sa', '-Cr', '-Co', '-Ci', '-gl',
  "-Fu$ScriptDir",
  "-Fu$OracleDir",
  "-FU$UnitsDir",
  "-FE$BinDir"
)

& $Fpc @Flags (Join-Path $ScriptDir 'foodexperiment.researchstatus.lpr')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $Fpc @Flags (Join-Path $ScriptDir 'foodexperiment.researchstatus.tests.lpr')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& (Join-Path $BinDir 'foodexperiment.researchstatus.tests.exe') $FixtureDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
