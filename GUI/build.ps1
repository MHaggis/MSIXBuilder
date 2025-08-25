#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Build script for MSIXBuilder GUI application

.DESCRIPTION
    This script builds the WinUI3 GUI application for MSIXBuilder.
    Creates placeholder assets if they don't exist and builds the solution.

.PARAMETER Configuration
    Build configuration (Debug or Release)

.PARAMETER Platform
    Target platform (x64 or ARM64)

.PARAMETER CreateAssets
    Create placeholder assets if they don't exist

.EXAMPLE
    .\build.ps1
    # Builds in Debug configuration for x64

.EXAMPLE
    .\build.ps1 -Configuration Release -Platform x64 -CreateAssets
    # Builds Release version and creates placeholder assets
#>

param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',
    
    [ValidateSet('x64', 'ARM64')]
    [string]$Platform = 'x64',
    
    [switch]$CreateAssets
)

$ErrorActionPreference = 'Stop'

function Write-Header {
    param([string]$Text)
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Text)
    Write-Host "`n[STEP] $Text" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Text)
    Write-Host "✓ $Text" -ForegroundColor Green
}

function Write-Error {
    param([string]$Text)
    Write-Host "✗ $Text" -ForegroundColor Red
}

try {
    Write-Header "MSIXBuilder GUI Build Script"
    
    $scriptRoot = $PSScriptRoot
    Set-Location $scriptRoot
    
    if (-not (Test-Path "MSIXBuilderGUI.sln")) {
        throw "Solution file not found. Please run this script from the GUI directory. Current location: $PWD"
    }
    
    Write-Host "Configuration: $Configuration" -ForegroundColor Gray
    Write-Host "Platform: $Platform" -ForegroundColor Gray
    Write-Host "Location: $PWD" -ForegroundColor Gray
    
    $assetsPath = Join-Path $scriptRoot "MSIXBuilderGUI\Assets"
    $requiredAssets = @(
        "StoreLogo.png",
        "Square150x150Logo.png", 
        "Square44x44Logo.png",
        "Square44x44Logo.targetsize-24_altform-unplated.png",
        "Wide310x150Logo.png",
        "LockScreenLogo.png",
        "SplashScreen.png"
    )
    
    $missingAssets = $requiredAssets | Where-Object { -not (Test-Path (Join-Path $assetsPath $_)) }
    
    if ($CreateAssets -or $missingAssets.Count -gt 0) {
        Write-Step "Creating placeholder assets"
        Write-Host "Assets directory: $assetsPath" -ForegroundColor Gray
        
        if (-not (Test-Path $assetsPath)) {
            New-Item -ItemType Directory -Path $assetsPath -Force | Out-Null
            Write-Host "Created assets directory" -ForegroundColor Gray
        } else {
            Write-Host "Assets directory exists" -ForegroundColor Gray
        }
        
        $pngBytes = [Convert]::FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==")
        
        $imageFiles = @(
            "StoreLogo.png",
            "Square150x150Logo.png",
            "Square44x44Logo.png", 
            "Square44x44Logo.targetsize-24_altform-unplated.png",
            "Wide310x150Logo.png",
            "LockScreenLogo.png",
            "SplashScreen.png"
        )
        
        foreach ($imageFile in $imageFiles) {
            $imagePath = Join-Path $assetsPath $imageFile
            if (-not (Test-Path $imagePath) -or $CreateAssets) {
                try {
                    [System.IO.File]::WriteAllBytes($imagePath, $pngBytes)
                    Write-Host "  Created: $imageFile" -ForegroundColor Gray
                } catch {
                    Write-Host "  Failed to create $imageFile : $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "  Attempted path: $imagePath" -ForegroundColor Red
                }
            } else {
                Write-Host "  Exists: $imageFile" -ForegroundColor Green
            }
        }
        

        
        Write-Success "Assets created successfully"
    }
    
    Write-Step "Checking build dependencies"
    
    try {
        $dotnetVersion = & dotnet --version
        Write-Success "Found .NET SDK: $dotnetVersion"
    } catch {
        throw ".NET SDK not found. Please install .NET 8.0 or later."
    }
    
    # Check for MSBuild
    try {
        $msbuildPath = & where.exe msbuild.exe 2>$null | Select-Object -First 1
        if ($msbuildPath) {
            Write-Success "Found MSBuild: $msbuildPath"
        } else {
            throw "MSBuild not found"
        }
    } catch {
        throw "MSBuild not found. Please install Visual Studio or Build Tools for Visual Studio."
    }
    
    Write-Step "Restoring NuGet packages"
    & dotnet restore MSIXBuilderGUI.sln
    if ($LASTEXITCODE -ne 0) {
        throw "Package restore failed"
    }
    Write-Success "Packages restored successfully"
    
    Write-Step "Building solution"
    & dotnet build MSIXBuilderGUI.sln --configuration $Configuration --no-restore
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed"
    }
    Write-Success "Build completed successfully"
    
    $outputPath = Join-Path $scriptRoot "MSIXBuilderGUI\bin\$Platform\$Configuration\net8.0-windows10.0.19041.0"
    if (Test-Path $outputPath) {
        Write-Host "`nBuild Output Location:" -ForegroundColor Cyan
        Write-Host "  $outputPath" -ForegroundColor Gray
        
        $exePath = Join-Path $outputPath "MSIXBuilderGUI.exe"
        if (Test-Path $exePath) {
            Write-Host "`nTo run the application:" -ForegroundColor Cyan
            Write-Host "  & '$exePath'" -ForegroundColor Gray
        }
    }
    
    Write-Header "Build Completed Successfully! 🎉"
    
} catch {
    Write-Error "Build failed: $($_.Exception.Message)"
    Write-Host "`nFor help, check the following:" -ForegroundColor Yellow
    Write-Host "- Ensure you're running as Administrator" -ForegroundColor Gray
    Write-Host "- Install Visual Studio or Build Tools with WinUI3 workload" -ForegroundColor Gray
    Write-Host "- Install .NET 8.0 SDK" -ForegroundColor Gray
    Write-Host "- Check that Windows SDK 10.0.19041.0+ is installed" -ForegroundColor Gray
    exit 1
} 