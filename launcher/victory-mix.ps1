<#
  victory-mix launcher: pick your game folder once, choose a preset, play.
  Nothing here is machine specific: the game folder is asked on first run and kept in
  %LOCALAPPDATA%\victory-mix\config.json (only on your PC). Logs go to %LOCALAPPDATA%\victory-mix\logs.

  Usage: double-click victory-mix.cmd
         .\victory-mix.ps1 [-Preset turbo|balanced|quality|seriess|clean] [-GameDir <folder>] [-Build] [-DryRun]
#>
[CmdletBinding()]
param(
    [string]$Preset = '',
    [string]$GameDir = '',
    [switch]$Build,
    [switch]$DryRun,
    [switch]$ResetConfig
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$dataDir = Join-Path $env:LOCALAPPDATA 'victory-mix'
$cfgPath = Join-Path $dataDir 'config.json'
New-Item -ItemType Directory -Force $dataDir | Out-Null

# ---------------------------------------------------------------- presets
# Each preset: what it is for, the console profile and the VICTORY_* variables it sets.
$presets = [ordered]@{
    quality = @{
        name = 'Quality (recommended)'
        what = 'Ray-tracing translation on 32-lane GPUs (NVIDIA RTX) + tuned waits. Best image so far, ~2-4 fps.'
        console = 'series-x'
        env = [ordered]@{
            VICTORY_HOST_WAVE = '32'; VICTORY_SHADER_LOOP_LIMIT = '256'; VICTORY_LATE_WAIT = '3'; VICTORY_WIDE_BACK = '1'
            VICTORY_CARD_BUFFERS_MIN_MB = '1'; VICTORY_CARD_BUFFERS_MB = '1024'
        }
    }
    turbo = @{
        name = 'Turbo (fps first)'
        what = 'Quality + the xboxmericavi TURBO set: smaller texture budget per frame, relay, 256 lists in flight. More fps, textures stream in slower.'
        console = 'series-x'
        env = [ordered]@{
            VICTORY_HOST_WAVE = '32'; VICTORY_SHADER_LOOP_LIMIT = '256'; VICTORY_LATE_WAIT = '3'; VICTORY_WIDE_BACK = '1'
            VICTORY_CARD_BUFFERS_MIN_MB = '1'; VICTORY_CARD_BUFFERS_MB = '1024'; VICTORY_RELAY = '1'
            VICTORY_TEXTURE_STAGE_MS = '80'; VICTORY_TEXTURE_STAGE_MB = '64'; VICTORY_TEXTURE_NO_WAIT = '1'
            VICTORY_JOIN_COPIES = '1'; VICTORY_UNWATCHED_FRAMES = '2'; VICTORY_CARD_REHASH_RUNS = '1'
            VICTORY_LATE_WAIT_LISTS = '256'; VICTORY_RELAY_MERGE_THREADS = '1'
        }
        high = $true
    }
    balanced = @{
        name = 'Balanced (no ray tracing)'
        what = 'The AnyXboxX tuned settings without the ray-tracing wave mode. Use it if Quality crashes on your GPU.'
        console = 'series-x'
        env = [ordered]@{
            VICTORY_SHADER_LOOP_LIMIT = '256'; VICTORY_LATE_WAIT = '3'; VICTORY_WIDE_BACK = '1'
            VICTORY_CARD_BUFFERS_MIN_MB = '1'; VICTORY_CARD_BUFFERS_MB = '1024'
        }
    }
    seriess = @{
        name = 'Series S profile (experimental)'
        what = 'Lower render resolution. Without the Series S present fix the picture is black on many GPUs.'
        console = 'series-s'
        env = [ordered]@{ VICTORY_HOST_WAVE = '32'; VICTORY_SHADER_LOOP_LIMIT = '256'; VICTORY_LATE_WAIT = '3'; VICTORY_WIDE_BACK = '1' }
    }
    clean = @{
        name = 'Clean (no variables)'
        what = 'Engine defaults, for bug reports and comparisons.'
        console = 'series-x'
        env = [ordered]@{}
    }
}
$allVars = $presets.Values | ForEach-Object { $_.env.Keys } | Sort-Object -Unique

function Write-Title($t) { Write-Host ''; Write-Host "  $t" -ForegroundColor Cyan; Write-Host ('  ' + ('-' * $t.Length)) -ForegroundColor DarkCyan }

# ---------------------------------------------------------------- game folder
$cfg = @{}
if ((Test-Path $cfgPath) -and -not $ResetConfig) { (Get-Content $cfgPath -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $cfg[$_.Name] = $_.Value } }
function Test-GameDir($d) { $d -and (Test-Path -LiteralPath (Join-Path $d 'game_scarlett_master.exe')) }

if ($GameDir) { $cfg.gameDir = $GameDir.TrimEnd('\', '/') }
while (-not (Test-GameDir $cfg.gameDir)) {
    Write-Title 'Game folder'
    Write-Host '  Point to the folder of YOUR copy of the game (the one with game_scarlett_master.exe).'
    Write-Host '  No game files are included in this project.'
    Write-Host '   1) choose it in a window'
    Write-Host '   2) type or paste the path'
    $c = Read-Host '  Option'
    if ($c -eq '1') {
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = 'Folder with game_scarlett_master.exe'
        if ($dlg.ShowDialog() -eq 'OK') { $cfg.gameDir = $dlg.SelectedPath }
    } else {
        $cfg.gameDir = (Read-Host '  Path').Trim('"', ' ').TrimEnd('\', '/')
    }
    if ($cfg.gameDir -and $cfg.gameDir.ToLower().EndsWith('.exe')) { $cfg.gameDir = Split-Path -Parent $cfg.gameDir }
    if (-not (Test-GameDir $cfg.gameDir)) { Write-Host '  game_scarlett_master.exe not found there, try again.' -ForegroundColor Red }
}
$cfg | ConvertTo-Json | Set-Content $cfgPath -Encoding UTF8

# ---------------------------------------------------------------- build
$exe = Join-Path $repo 'target\release\victory.exe'
if ($Build -or -not (Test-Path $exe)) {
    if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) { throw 'Rust is not installed: winget install Rustlang.Rustup (and Visual Studio Build Tools with the C++ workload).' }
    Write-Host '  Building (first build takes a few minutes)...' -ForegroundColor Yellow
    Push-Location $repo; try { cargo build --release -p victory; if ($LASTEXITCODE) { throw "cargo build failed ($LASTEXITCODE)" } } finally { Pop-Location }
}

# ---------------------------------------------------------------- preset menu
if (-not $Preset) {
    Write-Title 'victory-mix'
    Write-Host "  Game: $($cfg.gameDir)" -ForegroundColor DarkGray
    $keys = @($presets.Keys)
    for ($i = 0; $i -lt $keys.Count; $i++) {
        $p = $presets[$keys[$i]]
        Write-Host ('   {0}) {1}' -f ($i + 1), $p.name)
        Write-Host "      $($p.what)" -ForegroundColor DarkGray
    }
    Write-Host '   c) change game folder' -ForegroundColor DarkGray
    $r = Read-Host '  Preset (Enter = 1)'
    if ($r -eq 'c') { Remove-Item $cfgPath -Force; & $PSCommandPath; return }
    $n = 1; if ($r) { [int]::TryParse($r, [ref]$n) | Out-Null }
    if ($n -lt 1 -or $n -gt $keys.Count) { $n = 1 }
    $Preset = $keys[$n - 1]
}
if (-not $presets.Contains($Preset)) { throw "Unknown preset '$Preset'. Presets: $($presets.Keys -join ', ')" }
$sel = $presets[$Preset]

# ---------------------------------------------------------------- environment
foreach ($v in $allVars) { Remove-Item "Env:$v" -ErrorAction SilentlyContinue }
foreach ($k in $sel.env.Keys) { Set-Item "Env:$k" $sel.env[$k] }
$env:VICTORY_GAME_DIR = $cfg.gameDir
$env:VICTORY_CACHE_DIR = Join-Path $dataDir 'cache'
$env:NO_COLOR = '1'

$logDir = Join-Path $dataDir 'logs'; New-Item -ItemType Directory -Force $logDir | Out-Null
$log = Join-Path $logDir ("{0}_{1}.log" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'), $Preset)
$gameExe = Join-Path $cfg.gameDir 'game_scarlett_master.exe'
$args2 = @('run', '--console', $sel.console, $gameExe, '--execute')

Write-Host ''
Write-Host "  Preset: $($sel.name) | console: $($sel.console)" -ForegroundColor Green
Write-Host "  Log: $log" -ForegroundColor DarkGray
Write-Host '  The first launch stays black for a few minutes while shaders compile. Press A / Enter at the start screen.' -ForegroundColor Yellow
if ($DryRun) { Write-Host "  [DryRun] $exe $($args2 -join ' ')"; ($sel.env.GetEnumerator() | ForEach-Object { "  $($_.Key)=$($_.Value)" }); return }

$p = Start-Process -FilePath $exe -ArgumentList ($args2 | ForEach-Object { if ($_ -match ' ') { "`"$_`"" } else { $_ } }) -RedirectStandardError $log -RedirectStandardOutput "$log.out" -NoNewWindow -PassThru
if ($sel.high) { try { $p.PriorityClass = 'High' } catch {} }
$p.WaitForExit()
Write-Host ''
if (Select-String -Path $log, "$log.out" -Pattern 'device removed|host GPU failure|panicked' -Quiet) {
    Write-Host "  The game stopped with a GPU error. Attach this log to your report: $log" -ForegroundColor Red
} else {
    Write-Host "  Closed. Log: $log" -ForegroundColor Cyan
}
