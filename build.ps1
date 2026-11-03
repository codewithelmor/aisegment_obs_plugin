<#
.SYNOPSIS
    Packages the AI_remove_bg OBS plugin into a zip that can be extracted into the OBS install directory.

.DESCRIPTION
    Zip layout (same as the original AI_remove_bg.zip):
      obs-plugins/64bit/wx_seg_obs.dll        <- compiled plugin (you must supply it, or use -Build)
      obs-plugins/64bit/wx_video_seg.dll      <- vendor runtime from 3rd/lh320_windows_1.2.2/bin/x64
      data/obs-plugins/wx_seg_obs/bkg.jpg, obs.lic, locale/*.ini

.PARAMETER PluginDll
    Path to the compiled wx_seg_obs.dll. If omitted, common build output folders are searched.

.PARAMETER Build
    Run CMake first. The CMakeLists.txt needs libobs (setup_plugin_target / OBS::libobs), so this only works
    when this folder is part of an OBS / obs-plugintemplate tree or you pass the needed options in -CMakeArgs.

.PARAMETER CMakeArgs
    Extra arguments for the CMake configure step, e.g. '-DCMAKE_PREFIX_PATH=C:/obs-deps'.

.PARAMETER Config
    Build configuration (default Release).

.PARAMETER Output
    Output zip path (default dist\AI_remove_bg.zip, so the tracked AI_remove_bg.zip is not overwritten).

.EXAMPLE
    .\build.ps1 -PluginDll C:\path\to\wx_seg_obs.dll
.EXAMPLE
    .\build.ps1 -Build -CMakeArgs '-DCMAKE_PREFIX_PATH=C:/obs-deps'
#>
[CmdletBinding()]
param(
    [string]$PluginDll,
    [switch]$Build,
    [string[]]$CMakeArgs = @(),
    [string]$Config = 'Release',
    [string]$Output
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $Output) { $Output = Join-Path $root 'dist\AI_remove_bg.zip' }
$buildDir = Join-Path $root 'build'

# ---- 1. Optional CMake build -------------------------------------------------
if ($Build) {
    if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) { throw 'cmake not found in PATH.' }
    cmake -S $root -B $buildDir -A x64 @CMakeArgs
    if ($LASTEXITCODE -ne 0) { throw 'CMake configure failed.' }
    cmake --build $buildDir --config $Config
    if ($LASTEXITCODE -ne 0) { throw 'CMake build failed.' }
}

# ---- 2. Locate the plugin DLL ------------------------------------------------
if (-not $PluginDll) {
    $candidates = @(
        "build\$Config\wx_seg_obs.dll",
        "build\rundir\$Config\obs-plugins\64bit\wx_seg_obs.dll",
        "build_x64\rundir\$Config\obs-plugins\64bit\wx_seg_obs.dll",
        "build\plugins\wx_seg_obs\$Config\wx_seg_obs.dll",
        "wx_seg_obs.dll"
    ) | ForEach-Object { Join-Path $root $_ }
    $PluginDll = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $PluginDll -and (Test-Path $buildDir)) {
        $PluginDll = Get-ChildItem $buildDir -Recurse -Filter wx_seg_obs.dll -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    }
}
if (-not $PluginDll -or -not (Test-Path $PluginDll)) {
    throw 'wx_seg_obs.dll not found. Build the plugin and pass -PluginDll <path>, or use -Build.'
}

# ---- 3. Map zip entry -> source file -----------------------------------------
$vendorDll = Join-Path $root '3rd\lh320_windows_1.2.2\bin\x64\wx_video_seg.dll'
$files = [ordered]@{
    'obs-plugins/64bit/wx_seg_obs.dll'                = $PluginDll
    'obs-plugins/64bit/wx_video_seg.dll'              = $vendorDll
    'data/obs-plugins/wx_seg_obs/bkg.jpg'             = Join-Path $root 'data\bkg.jpg'
    'data/obs-plugins/wx_seg_obs/obs.lic'             = Join-Path $root 'data\obs.lic'
    'data/obs-plugins/wx_seg_obs/locale/en-US.ini'    = Join-Path $root 'data\locale\en-US.ini'
    'data/obs-plugins/wx_seg_obs/locale/zh-CN.ini'    = Join-Path $root 'data\locale\zh-CN.ini'
}
foreach ($entry in $files.Keys) {
    if (-not (Test-Path $files[$entry])) { throw "Missing file for '$entry': $($files[$entry])" }
}

# ---- 4. Create the zip (forward-slash entry names, works on Windows PowerShell 5.1 too) ----
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$outDir = Split-Path -Parent $Output
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
if (Test-Path $Output) { Remove-Item $Output -Force }

$zip = [System.IO.Compression.ZipFile]::Open($Output, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($entry in $files.Keys) {
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, (Resolve-Path $files[$entry]).Path, $entry, [System.IO.Compression.CompressionLevel]::Optimal)
        Write-Host "  + $entry"
    }
}
finally {
    $zip.Dispose()
}

$size = '{0:N1} MB' -f ((Get-Item $Output).Length / 1MB)
Write-Host "Created $Output ($size)"
Write-Host "Install: Expand-Archive '$Output' -DestinationPath 'C:\Program Files\obs-studio' -Force"
