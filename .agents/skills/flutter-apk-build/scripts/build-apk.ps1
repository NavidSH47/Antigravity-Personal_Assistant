<#
.SYNOPSIS
    Builds, optimizes, and verifies Flutter Android APKs for pulse-assistant and Flutter projects.

.DESCRIPTION
    Runs optimized flutter build apk commands with options for release/debug, targeted ABIs,
    skipping redundant pub resolution, and automatic output verification (hash, size, path).

.PARAMETER ProjectPath
    Path to the Flutter project root (defaults to C:\Users\XMART\pulse-assistant).

.PARAMETER BuildType
    Build mode: release (default), debug, or profile.

.PARAMETER TargetPlatform
    Optional target platform (e.g. android-arm64 for modern devices, or leave empty for universal).

.PARAMETER SplitPerAbi
    Switch to generate split APKs per ABI (smaller size).

.PARAMETER NoPub
    Switch to skip 'flutter pub get' step if dependencies are already up-to-date.

.EXAMPLE
    .\build-apk.ps1
    .\build-apk.ps1 -BuildType release -NoPub
    .\build-apk.ps1 -TargetPlatform android-arm64
#>

[CmdletBinding()]
param (
    [string]$ProjectPath = "C:\Users\XMART\pulse-assistant",
    [ValidateSet("release", "debug", "profile")]
    [string]$BuildType = "release",
    [string]$TargetPlatform = "",
    [switch]$SplitPerAbi,
    [switch]$NoPub
)

$ErrorActionPreference = "Stop"

# Auto-resolve relative paths if run from different working directory
if (-not (Test-Path $ProjectPath)) {
    $candidates = @(
        (Join-Path $PSScriptRoot "..\..\..\pulse-assistant"),
        (Join-Path (Get-Location) "pulse-assistant"),
        (Get-Location).Path
    )
    $found = $false
    foreach ($cand in $candidates) {
        if (Test-Path (Join-Path $cand "pubspec.yaml")) {
            $ProjectPath = (Resolve-Path $cand).Path
            $found = $true
            break
        }
    }
    if (-not $found) {
        Write-Error "Cannot locate Flutter project at '$ProjectPath'. Specify -ProjectPath."
        exit 1
    }
}

Push-Location $ProjectPath
try {
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "  Flutter APK Build Helper" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "Project:   $ProjectPath"
    Write-Host "Mode:      $BuildType"
    if ($TargetPlatform) { Write-Host "Platform:  $TargetPlatform" }
    if ($SplitPerAbi)    { Write-Host "Split ABI: Yes" }
    if ($NoPub)          { Write-Host "No Pub:    Yes (Fast build)" }
    Write-Host "--------------------------------------------------"

    $buildArgs = @("build", "apk", "--$BuildType")

    if ($SplitPerAbi) {
        $buildArgs += "--split-per-abi"
    }

    if ($TargetPlatform) {
        $buildArgs += "--target-platform"
        $buildArgs += $TargetPlatform
    }

    if ($NoPub) {
        $buildArgs += "--no-pub"
    }

    Write-Host "Executing: flutter $($buildArgs -join ' ')`n" -ForegroundColor Yellow
    $startTime = Get-Date

    & flutter.bat @buildArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Flutter build failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }

    $elapsed = (Get-Date) - $startTime
    Write-Host "`nBuild completed successfully in $([math]::Round($elapsed.TotalSeconds, 1))s!" -ForegroundColor Green

    $apkDir = Join-Path $ProjectPath "build\app\outputs\flutter-apk"
    if (Test-Path $apkDir) {
        $apks = Get-ChildItem -Path $apkDir -Filter "*.apk" | Sort-Object LastWriteTime -Descending
        Write-Host "`nGenerated APK Artifacts:" -ForegroundColor Cyan
        foreach ($apk in $apks) {
            $sizeMb = [math]::Round($apk.Length / 1MB, 2)
            $hash = (Get-FileHash -Path $apk.FullName -Algorithm SHA256).Hash
            Write-Host "--------------------------------------------------"
            Write-Host "File:       $($apk.FullName)"
            Write-Host "Size:       $sizeMb MB ($($apk.Length) bytes)"
            Write-Host "Timestamp:  $($apk.LastWriteTime)"
            Write-Host "SHA-256:    $hash"
        }
        Write-Host "--------------------------------------------------`n"
    }
}
finally {
    Pop-Location
}
