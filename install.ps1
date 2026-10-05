# Installs Firefox Classic Theme into Firefox profiles on Windows.
#
#   irm https://raw.githubusercontent.com/axelberardino/firefox-classic-theme/main/install.ps1 | iex
#
# Run with -Help for options.

[CmdletBinding()]
param(
  [string]$ProfileDir,
  [switch]$All,
  [switch]$List,
  [switch]$Uninstall,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'

$Repo = if ($env:CLASSIC_THEME_REPO) { $env:CLASSIC_THEME_REPO } else { 'axelberardino/firefox-classic-theme' }
$Branch = if ($env:CLASSIC_THEME_BRANCH) { $env:CLASSIC_THEME_BRANCH } else { 'main' }
$OriginalSuffix = 'before-classic-theme'
$UserJsMarker = "// Written by Firefox Classic Theme (https://github.com/$Repo)"
$OverrideFiles = @('userChrome-overrides.css', 'userContent-overrides.css')

$ProfileRoots = @(
  (Join-Path $env:APPDATA 'Mozilla\Firefox'),
  (Join-Path $env:APPDATA 'librewolf'),
  (Join-Path $env:APPDATA 'Waterfox')
)

function Write-Info($Message) { Write-Host "==> $Message" -ForegroundColor Blue }
function Write-Note($Message) { Write-Host "    $Message" }
function Write-Warn($Message) { Write-Host "warning: $Message" -ForegroundColor Yellow }

function Show-Usage {
  @'
Usage: install.ps1 [options]

Installs Firefox Classic Theme (Lepton Photon-Style plus a few fixes) into
your Firefox profile. With no option, it picks the profile Firefox starts with.

Options:
  -ProfileDir DIR  Install into this profile folder
  -All             Install into every profile found
  -List            List the profiles found and exit
  -Uninstall       Remove the theme and bring back what was there before
  -Help            Show this help

Your own tweaks survive updates when you put them in these files:
  <profile>\chrome\userChrome-overrides.css
  <profile>\chrome\userContent-overrides.css
  <profile>\user-overrides.js
'@
}

# Reads profiles.ini into an ordered list of sections, each a hashtable.
function Read-Ini($Path) {
  $sections = [System.Collections.Generic.List[object]]::new()
  $current = $null
  foreach ($line in Get-Content -LiteralPath $Path) {
    $line = $line.Trim()
    if ($line -match '^\[(.+)\]$') {
      $current = @{ Name = $Matches[1] }
      $sections.Add($current)
    } elseif ($current -and $line -match '^([^=]+)=(.*)$') {
      $current[$Matches[1]] = $Matches[2]
    }
  }
  return $sections
}

function Resolve-ProfileDir($Root, $Path, $IsRelative) {
  if ($IsRelative -eq '0') { return $Path }
  return Join-Path $Root ($Path -replace '/', '\')
}

function Get-AllProfiles {
  foreach ($root in $ProfileRoots) {
    $ini = Join-Path $root 'profiles.ini'
    if (-not (Test-Path -LiteralPath $ini)) { continue }
    foreach ($section in Read-Ini $ini) {
      if ($section.Name -like 'Profile*' -and $section.Path) {
        Resolve-ProfileDir $root $section.Path $section.IsRelative
      }
    }
  }
}

# The profile a plain launch opens: the [Install...] default first (used by
# Firefox since version 67), then the profile flagged Default=1.
function Get-DefaultProfiles {
  foreach ($root in $ProfileRoots) {
    $ini = Join-Path $root 'profiles.ini'
    if (-not (Test-Path -LiteralPath $ini)) { continue }
    $sections = Read-Ini $ini
    $install = $sections | Where-Object { $_.Name -like 'Install*' -and $_.Default } | Select-Object -First 1
    if ($install) {
      if ([System.IO.Path]::IsPathRooted($install.Default)) { $install.Default }
      else { Join-Path $root ($install.Default -replace '/', '\') }
      continue
    }
    $flagged = $sections | Where-Object { $_.Name -like 'Profile*' -and $_.Default -eq '1' } | Select-Object -First 1
    if ($flagged) { Resolve-ProfileDir $root $flagged.Path $flagged.IsRelative }
  }
}

# Finds the theme files: next to this script when run from a clone, otherwise
# downloaded from GitHub (the irm | iex case).
function Get-Source {
  if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'chrome\classic.css'))) {
    return $PSScriptRoot
  }
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("classic-theme-" + [guid]::NewGuid())
  New-Item -ItemType Directory -Path $tmp | Out-Null
  $zip = Join-Path $tmp 'theme.zip'
  Write-Info "Downloading $Repo ($Branch)"
  Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$Repo/archive/refs/heads/$Branch.zip" -OutFile $zip
  Expand-Archive -LiteralPath $zip -DestinationPath $tmp
  $source = Get-ChildItem -LiteralPath $tmp -Directory | Select-Object -First 1
  if (-not $source -or -not (Test-Path -LiteralPath (Join-Path $source.FullName 'chrome\classic.css'))) {
    throw 'The download does not look like Firefox Classic Theme'
  }
  $script:TempDir = $tmp
  return $source.FullName
}

function Test-OurUserJs($Path) {
  return (Test-Path -LiteralPath $Path) -and (Select-String -LiteralPath $Path -SimpleMatch $UserJsMarker -Quiet)
}

function Install-Profile($ProfileDir, $Source) {
  if (-not (Test-Path -LiteralPath $ProfileDir)) { throw "Profile folder not found: $ProfileDir" }
  Write-Info "Installing into $ProfileDir"
  $chrome = Join-Path $ProfileDir 'chrome'
  $original = Join-Path $ProfileDir "chrome.$OriginalSuffix"
  $userJs = Join-Path $ProfileDir 'user.js'
  $originalUserJs = Join-Path $ProfileDir "user.js.$OriginalSuffix"
  $oldChrome = $null
  $scratch = $null

  # The first time, keep the user's own setup aside so uninstall can bring it
  # back. Later runs are updates of this theme, so only the overrides matter.
  if (Test-Path -LiteralPath $chrome) {
    if ((Test-Path -LiteralPath (Join-Path $chrome 'classic.css')) -or (Test-Path -LiteralPath $original)) {
      $scratch = Join-Path ([System.IO.Path]::GetTempPath()) ("classic-theme-old-" + [guid]::NewGuid())
      New-Item -ItemType Directory -Path $scratch | Out-Null
      $oldChrome = Join-Path $scratch 'chrome'
    } else {
      $oldChrome = $original
      Write-Note "your previous chrome folder is saved as chrome.$OriginalSuffix"
    }
    Move-Item -LiteralPath $chrome -Destination $oldChrome
  }
  if ((Test-Path -LiteralPath $userJs) -and -not (Test-Path -LiteralPath $originalUserJs) -and -not (Test-OurUserJs $userJs)) {
    Copy-Item -LiteralPath $userJs -Destination $originalUserJs
    Write-Note "your previous user.js is saved as user.js.$OriginalSuffix"
  }

  Copy-Item -LiteralPath (Join-Path $Source 'chrome') -Destination $chrome -Recurse

  if ($oldChrome) {
    foreach ($file in $OverrideFiles) {
      $kept = Join-Path $oldChrome $file
      if (Test-Path -LiteralPath $kept) {
        Copy-Item -LiteralPath $kept -Destination (Join-Path $chrome $file)
        Write-Note "kept your $file"
      }
    }
  }
  if ($scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }

  $content = @($UserJsMarker) + (Get-Content -LiteralPath (Join-Path $Source 'user.js'))
  $overrides = Join-Path $ProfileDir 'user-overrides.js'
  if (Test-Path -LiteralPath $overrides) {
    $content += ''
    $content += '// ** user-overrides.js ********************************************************'
    $content += Get-Content -LiteralPath $overrides
    Write-Note 'applied your user-overrides.js'
  }
  [System.IO.File]::WriteAllLines($userJs, [string[]]$content)
}

function Uninstall-Profile($ProfileDir) {
  if (-not (Test-Path -LiteralPath $ProfileDir)) { throw "Profile folder not found: $ProfileDir" }
  $chrome = Join-Path $ProfileDir 'chrome'
  if (-not (Test-Path -LiteralPath (Join-Path $chrome 'classic.css'))) {
    Write-Warn "Firefox Classic Theme is not installed in $ProfileDir, skipping"
    return
  }
  Write-Info "Uninstalling from $ProfileDir"
  Remove-Item -LiteralPath $chrome -Recurse -Force
  $original = Join-Path $ProfileDir "chrome.$OriginalSuffix"
  if (Test-Path -LiteralPath $original) {
    Move-Item -LiteralPath $original -Destination $chrome
    Write-Note 'restored your previous chrome folder'
  }
  $userJs = Join-Path $ProfileDir 'user.js'
  if (Test-OurUserJs $userJs) { Remove-Item -LiteralPath $userJs -Force }
  $originalUserJs = Join-Path $ProfileDir "user.js.$OriginalSuffix"
  if (Test-Path -LiteralPath $originalUserJs) {
    Move-Item -LiteralPath $originalUserJs -Destination $userJs
    Write-Note 'restored your previous user.js'
  }
}

if ($Help) { Show-Usage; return }
if ($List) { Get-AllProfiles; return }

$profiles = @(
  if ($ProfileDir) { $ProfileDir }
  elseif ($All) { Get-AllProfiles }
  else { Get-DefaultProfiles }
)
if ($profiles.Count -eq 0) { throw 'No Firefox profile found. Open Firefox once, or pass -ProfileDir DIR' }

try {
  if ($Uninstall) {
    foreach ($p in $profiles) { Uninstall-Profile $p }
  } else {
    $source = Get-Source
    foreach ($p in $profiles) { Install-Profile $p $source }
  }
} finally {
  if ($script:TempDir) { Remove-Item -LiteralPath $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue }
}

if (Get-Process -Name firefox -ErrorAction SilentlyContinue) {
  Write-Warn 'Firefox is running. Restart it to see the changes.'
}
Write-Info 'Done. Restart Firefox to apply.'
