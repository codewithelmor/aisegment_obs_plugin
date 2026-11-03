<#
.SYNOPSIS
    Installs the AI_remove_bg OBS plugin by copying data\ and obs-plugins\ into the OBS Studio directory.

.DESCRIPTION
    Detects the Windows (OS) drive and locates the OBS Studio installation (registry first, then
    Program Files on the OS drive, then Program Files on every other fixed drive), then copies the
    'data' and 'obs-plugins' folders that sit next to this script into it.
    Re-launches itself elevated when the OBS directory is not writable.

.PARAMETER ObsPath
    Explicit OBS Studio directory. Skips auto-detection.

.PARAMETER Force
    Install even if OBS is currently running (plugin DLLs may be locked and the copy may fail).

.EXAMPLE
    .\install.ps1
.EXAMPLE
    .\install.ps1 -ObsPath 'D:\Apps\obs-studio'
#>
[CmdletBinding()]
param(
    [string]$ObsPath,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$source = $PSScriptRoot
$folders = @('data', 'obs-plugins')

function Test-ObsDir([string]$Path) {
    $Path -and (Test-Path (Join-Path $Path 'bin\64bit\obs64.exe'))
}

function Find-ObsDir {
    $osDrive = $env:SystemDrive
    Write-Host "OS drive: $osDrive"

    # 1. Registry (installer writes the install dir as the default value)
    $regKeys = @(
        'HKLM:\SOFTWARE\OBS Studio',
        'HKLM:\SOFTWARE\WOW6432Node\OBS Studio',
        'HKCU:\SOFTWARE\OBS Studio'
    )
    foreach ($key in $regKeys) {
        $item = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
        if ($item) {
            $path = $item.'(default)'
            if (-not $path) { $path = ($item.PSObject.Properties | Where-Object Name -eq '(default)').Value }
            if (Test-ObsDir $path) { return $path }
        }
    }
    $uninstall = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like 'OBS Studio*' }
    foreach ($u in $uninstall) {
        if (Test-ObsDir $u.InstallLocation) { return $u.InstallLocation }
    }

    # 2. Standard locations: OS drive first, then other fixed drives
    $drives = @($osDrive) + @(
        Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' |
            ForEach-Object DeviceID | Where-Object { $_ -ne $osDrive }
    )
    foreach ($d in $drives) {
        foreach ($rel in 'Program Files\obs-studio', 'Program Files (x86)\obs-studio', 'obs-studio') {
            $p = Join-Path "$d\" $rel
            if (Test-ObsDir $p) { return $p }
        }
    }

    # 3. Running OBS process
    $proc = Get-Process obs64 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc -and $proc.Path) {
        $p = Split-Path (Split-Path (Split-Path $proc.Path))
        if (Test-ObsDir $p) { return $p }
    }
    return $null
}

# ---- validate package ----
foreach ($f in $folders) {
    if (-not (Test-Path (Join-Path $source $f))) {
        throw "'$f' folder not found next to install.ps1 ($source). Extract the whole zip first."
    }
}

# ---- locate OBS ----
if ($ObsPath) {
    if (-not (Test-ObsDir $ObsPath)) { throw "No OBS Studio found at '$ObsPath' (bin\64bit\obs64.exe missing)." }
} else {
    $ObsPath = Find-ObsDir
    if (-not $ObsPath) { throw 'OBS Studio installation not found. Re-run with -ObsPath <dir>.' }
}
$ObsPath = (Resolve-Path $ObsPath).Path
Write-Host "OBS directory: $ObsPath"

# ---- elevate if needed ----
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
    IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$writable = try {
    $t = Join-Path $ObsPath ".w$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType File $t -ErrorAction Stop | Out-Null; Remove-Item $t -Force; $true
} catch { $false }
if (-not $writable -and -not $isAdmin) {
    Write-Host 'Administrator rights required, relaunching elevated...'
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-ObsPath', "`"$ObsPath`"")
    if ($Force) { $argList += '-Force' }
    $exe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
    $p = Start-Process $exe -ArgumentList $argList -Verb RunAs -Wait -PassThru
    exit $p.ExitCode
}

# ---- OBS must be closed ----
if ((Get-Process obs64 -ErrorAction SilentlyContinue) -and -not $Force) {
    throw 'OBS is running. Close it and re-run (or use -Force).'
}

# ---- copy ----
foreach ($f in $folders) {
    Write-Host "Copying $f -> $ObsPath\$f"
    Copy-Item -Path (Join-Path $source $f) -Destination $ObsPath -Recurse -Force
}

$dll = Join-Path $ObsPath 'obs-plugins\64bit\wx_seg_obs.dll'
if (-not (Test-Path $dll)) { throw 'Install verification failed: wx_seg_obs.dll missing.' }
Write-Host 'AI_remove_bg plugin installed. Start OBS and add the filter to a video source.'
