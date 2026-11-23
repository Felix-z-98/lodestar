# Lodestar installer for Windows 10 and 11. Installs for the current user only; no admin rights.
#
#   irm https://raw.githubusercontent.com/Felix-z-98/lodestar/main/install.ps1 | iex
#
# Run the same line again to update. Everything goes in %LOCALAPPDATA%\Lodestar2, plus a
# Start menu shortcut. Each download is checked against a known SHA-256 before it is used.
# To remove Lodestar afterwards, run "Uninstall Lodestar.cmd" in that folder.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # the progress bar makes downloads many times slower
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo      = 'Felix-z-98/lodestar'
$Electron  = '45.3.1'
$Legendary = '0.21.1'
$Ludusavi  = '0.31.0'
# Known SHA-256 of every outside download.
$SumElectron  = 'd92d1aa4700e3a7e7f174731f5086ebd9c21f9773e642b260160fe0a6ebe12d2'
$SumLegendary = '6be77857dc0a6dd33ea7442ce8b5291944ec6da53757f81ca95b57ce794baf5b'
$SumLudusavi  = 'f47a8ad8c708f01d2eb124704973beffab205e292f5287a10fc4a101f8d68706'

$Root  = Join-Path $env:LOCALAPPDATA 'Lodestar2'
$Tools = Join-Path $Root 'tools'
$EDir  = Join-Path $Root "electron-$Electron"
$Base  = if ($env:LODESTAR_BASE_URL) { $env:LODESTAR_BASE_URL } else { "https://github.com/$Repo/releases/latest/download" }
$Menu  = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'

function Say($text) { Write-Host $text }
function Fetch($url, $file) { Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing }
function Sum($file) { (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLower() }
function Check($file, $want, $name) {
  if ((Sum $file) -ne $want.ToLower()) { throw "$name did not match its checksum (download damaged or changed). Nothing was installed from it." }
}

if (-not [Environment]::Is64BitOperatingSystem) { throw 'Lodestar needs 64-bit Windows.' }
$tar = Join-Path $env:SystemRoot 'System32\tar.exe'
if (-not (Test-Path $tar)) { throw 'This Windows is too old: Lodestar needs Windows 10 (version 1803) or newer.' }
if (Get-Process -Name electron -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$Root\*" }) {
  throw 'Lodestar is open. Close it, then run this again.'
}

$Tmp = Join-Path ([IO.Path]::GetTempPath()) ("lodestar-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $Tmp, $Root, $Tools | Out-Null
try {
  # ---- 1. the app itself ----
  Say 'Lodestar: fetching the app...'
  $pkg = Join-Path $Tmp 'lodestar.tar.gz'
  Fetch "$Base/lodestar.tar.gz" $pkg
  Fetch "$Base/lodestar.tar.gz.sha256" (Join-Path $Tmp 'lodestar.sum')
  $want = ((Get-Content (Join-Path $Tmp 'lodestar.sum') -Raw).Trim() -split '\s+')[0]
  Check $pkg $want 'The Lodestar package'
  $newApp = Join-Path $Tmp 'app'
  New-Item -ItemType Directory -Force -Path $newApp | Out-Null
  & $tar -xzf $pkg -C $newApp --strip-components=1
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $newApp 'src\main.js'))) { throw 'The package is not a Lodestar package.' }
  $version = (Get-Content (Join-Path $newApp 'package.json') -Raw | ConvertFrom-Json).version

  # ---- 2. Electron, the program that runs it (only when this version is not here yet) ----
  if (-not (Test-Path (Join-Path $EDir 'electron.exe'))) {
    Say "Lodestar: fetching Electron $Electron (about 130 MB, first time only)..."
    $zip = Join-Path $Tmp 'electron.zip'
    Fetch "https://github.com/electron/electron/releases/download/v$Electron/electron-v$Electron-win32-x64.zip" $zip
    Check $zip $SumElectron 'Electron'
    $newE = Join-Path $Tmp 'electron'
    New-Item -ItemType Directory -Force -Path $newE | Out-Null
    & $tar -xf $zip -C $newE
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $newE 'electron.exe'))) { throw 'Electron did not unpack properly.' }
    if (Test-Path $EDir) { Remove-Item -Recurse -Force $EDir }
    Move-Item $newE $EDir
  }
  Get-ChildItem $Root -Directory -Filter 'electron-*' | Where-Object { $_.FullName -ne $EDir } | Remove-Item -Recurse -Force

  # Swap the app in only once everything it needs is in place.
  $app = Join-Path $Root 'app'
  if (Test-Path $app) { Remove-Item -Recurse -Force $app }
  Move-Item $newApp $app

  # ---- 3. helpers (optional; a failed helper does not stop the install) ----
  if (-not (Test-Path (Join-Path $Tools 'legendary.exe'))) {
    Say "Lodestar: fetching Legendary $Legendary (for Epic Games)..."
    try {
      $f = Join-Path $Tmp 'legendary.exe'
      Fetch "https://github.com/derrod/legendary/releases/download/$Legendary/legendary_windows_x64.exe" $f
      Check $f $SumLegendary 'Legendary'
      Move-Item $f (Join-Path $Tools 'legendary.exe')
    } catch { Say '  Could not fetch Legendary (Epic Games will not work until it is). Carrying on.' }
  }
  if (-not (Test-Path (Join-Path $Tools 'ludusavi.exe'))) {
    Say "Lodestar: fetching Ludusavi $Ludusavi (finds your game saves)..."
    try {
      $f = Join-Path $Tmp 'ludusavi.zip'
      Fetch "https://github.com/mtkennerly/ludusavi/releases/download/v$Ludusavi/ludusavi-v$Ludusavi-win64.zip" $f
      Check $f $SumLudusavi 'Ludusavi'
      $d = Join-Path $Tmp 'ludusavi'
      New-Item -ItemType Directory -Force -Path $d | Out-Null
      & $tar -xf $f -C $d
      Move-Item (Join-Path $d 'ludusavi.exe') (Join-Path $Tools 'ludusavi.exe')
    } catch { Say '  Could not fetch Ludusavi (saves of non-Steam games will not be found until it is). Carrying on.' }
  }

  # ---- 4. Start menu shortcut and the remover ----
  $shell = New-Object -ComObject WScript.Shell
  $link = $shell.CreateShortcut((Join-Path $Menu 'Lodestar.lnk'))
  $link.TargetPath = Join-Path $EDir 'electron.exe'
  $link.Arguments = '"' + $app + '"'
  $link.WorkingDirectory = $app
  $link.Description = 'Lodestar game launcher'
  $link.Save()

  $remover = @"
@echo off
echo This removes Lodestar. Your settings, themes, sign-ins and games are kept.
pause
rmdir /s /q "$app"
rmdir /s /q "$Tools"
rmdir /s /q "$EDir"
del "$Menu\Lodestar.lnk"
echo Lodestar is removed. You can delete this folder now.
pause
"@
  Set-Content -LiteralPath (Join-Path $Root 'Uninstall Lodestar.cmd') -Value $remover -Encoding ASCII

  Say ''
  Say "Lodestar $version is installed. Start it from the Start menu."
  Say 'To update later, run the same install line again.'
} finally {
  Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}
