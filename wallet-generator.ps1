#!/usr/bin/env pwsh

param()

$ErrorActionPreference = "Stop"

$RepoOwner = "octra-labs"
$RepoName = "wallet-gen"
$InstallDir = "${Home}\.octra"
$TempDir = "${env:TEMP}\octra-wallet-gen-install"

Write-Host "=== ⚠️  SECURITY WARNING ⚠️  ==="
Write-Host ""
Write-Host "This tool generates real cryptographic keys. Always:"
Write-Host "  - Keep your private keys secure"
Write-Host "  - Never share your mnemonic phrase"
Write-Host "  - Don't store wallet files on cloud services"
Write-Host "  - Use on a secure, offline computer for production wallets"
Write-Host ""
Read-Host "Press Enter to continue..."
Write-Host ""
Write-Host "=== octra wallet generator installer ==="
Write-Host ""

function Install-Bun {
    if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
        $installScript = Invoke-RestMethod -Uri 'https://bun.sh/install.ps1'
        Invoke-Expression $installScript
        # Add bun to PATH for the current session
        $env:PATH = "${Home}\.bun\bin;$($env:PATH)"
    }
}

function Get-LatestReleaseTag {
    Write-Host "Fetching latest release information..."
    try {
        $apiUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/tags"
        $tags = Invoke-RestMethod -Uri $apiUrl
        return $tags[0].name
    } catch {
        Write-Host "❌ Error: Could not fetch release information from GitHub."
        Write-Host $_.Exception.Message
        exit 1
    }
}

function Download-And-Extract {
    param(
        [string]$Tag
    )
    
    Write-Host "Downloading octra wallet generator..."
    
    if (Test-Path $TempDir) {
        Remove-Item -Recurse -Force -Path $TempDir
    }
    New-Item -ItemType Directory -Path $TempDir | Out-Null
    
    $zipballUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/zipball/refs/tags/$Tag"
    $outputFile = Join-Path $TempDir "release.zip"
    
    Invoke-WebRequest -Uri $zipballUrl -OutFile $outputFile

    Set-Location $TempDir
    
    Expand-Archive -Path $outputFile -DestinationPath . -Force
    
    $extractedDir = Get-ChildItem -Directory | Select-Object -First 1
    if ($extractedDir) {
        Get-ChildItem -Path $extractedDir.FullName -Force | Move-Item -Destination . -Force
        Remove-Item -Recurse -Force -Path $extractedDir.FullName
    }
}

$latestTag = Get-LatestReleaseTag

Download-And-Extract -Tag $latestTag

Set-Location $TempDir

Install-Bun

bun install

Write-Host ""
Write-Host "Building standalone executable..."
bun run build

$executableName = "wallet-generator"
$executablePath = Join-Path $TempDir $executableName

if (-not (Test-Path -Path $executablePath)) {
    Write-Host "❌ Error: wallet-generator executable not found after build!"
    Write-Host "Build may have failed. Please check the build output above."
    exit 1
}

Write-Host "Installing to $InstallDir..."
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -Path $executablePath -Destination $InstallDir -Force

$installedExecutablePath = Join-Path $InstallDir $executableName

Write-Host ""
Write-Host "Starting wallet generator server..."

Set-Location $InstallDir

if (Test-Path $TempDir) {
    Remove-Item -Recurse -Force -Path $TempDir
}

$process = Start-Process -FilePath $installedExecutablePath -PassThru

Start-Sleep -Seconds 2

try {
    Start-Process "http://localhost:8888"
} catch {
}

Write-Host ""
Write-Host "=== Installation Complete! ==="
Write-Host "Wallet generator is running at http://localhost:8888"
Write-Host "To run again later, use: $installedExecutablePath"
Write-Host "To stop the wallet generator, press Ctrl+C in this window or close it."
Write-Host ""

try {
    Wait-Process -Id $process.Id
} catch {
} 