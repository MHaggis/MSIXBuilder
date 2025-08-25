#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Creates a functional MSIX package for security testing and red team exercises.

.DESCRIPTION
    This script creates a complete MSIX package with embedded test applications that can be used
    for security testing, detection validation, and red team exercises. It handles all dependencies,
    prompts for configuration, and provides comprehensive error handling with automatic downloads.

    Features:
    - Automatic dependency detection and installation
    - Interactive configuration prompts
    - Creates both C# and PowerShell test applications
    - Generates self-signed certificates for testing
    - Builds and signs the MSIX package
    - Provides installation instructions

.PARAMETER PackageName
    Name of the MSIX package (default: prompts user)

.PARAMETER Publisher
    Publisher name for the certificate (default: prompts user)

.PARAMETER OutputPath
    Directory to create the package in (default: prompts user)

.PARAMETER AppType
    Type of test application: 'CSharp', 'PowerShell', or 'Both' (default: prompts user)

.PARAMETER SkipDownloads
    Skip automatic downloading of missing dependencies

.PARAMETER TelemetryMode
    Switch to enable telemetry mode

.PARAMETER GenerateDetectionLogs
    Switch to enable generation of detection logs

.EXAMPLE
    .\Create-MSIXPackage.ps1
    # Interactive mode with prompts

.EXAMPLE
    .\Create-MSIXPackage.ps1 -PackageName "SecurityTest" -Publisher "RedTeam" -OutputPath "C:\Output" -AppType "Both"
    # Non-interactive mode

.NOTES
    Author: The Haag
    Requires: Windows 10/11 or Windows Server 2016+
    Requires: PowerShell 5.1+ running as Administrator
    Version: 2.0
#>

param(
    [string]$PackageName,
    [string]$Publisher,
    [string]$OutputPath,
    [ValidateSet('CSharp', 'PowerShell', 'Both')]
    [string]$AppType,
    [switch]$SkipDownloads,
    [switch]$TelemetryMode,
    [switch]$GenerateDetectionLogs
)

# Global configuration with download URLs
$script:Config = @{
    RequiredDotNetVersion = "4.7.2"
    RequiredPowerShellVersion = "5.1"
    WindowsSDKMinVersion = "10.0.17763"
    
    # Download URLs (these are the official Microsoft redirect links)
    Downloads = @{
        # .NET Framework Developer Pack - official Microsoft download redirects
        DotNetFramework48DevPack = "https://download.microsoft.com/download/7/4/0/740c7986-6595-4293-9e5f-96b1bb1e7e85/ndp48-devpack-enu.exe"
        DotNetFramework481DevPack = "https://download.microsoft.com/download/f/1/d/f1da7c85-4d1c-4b6d-ae3a-8ad0b1dae54a/ndp481-devpack-enu.exe"
        
        # Windows SDK - official Microsoft download redirects
        WindowsSDKInstaller = "https://go.microsoft.com/fwlink/?linkid=2317808"
        WindowsSDKISO = "https://go.microsoft.com/fwlink/?linkid=2317714"
        
        # Fallback URLs for manual downloads
        DotNetFrameworkPage = "https://dotnet.microsoft.com/download/dotnet-framework/net481"
        WindowsSDKPage = "https://developer.microsoft.com/windows/downloads/windows-sdk/"
    }
}

# Non-interactive mode detection: Script runs in non-interactive mode when all required parameters are provided
# This prevents GUI hanging on Read-Host prompts and enables seamless automation
$script:IsNonInteractive = $PackageName -and $Publisher -and $OutputPath -and $AppType

#region Helper Functions

function Write-Banner {
    param([string]$Text, [string]$Color = "Cyan")
    
    $border = "=" * 80
    Write-Host $border -ForegroundColor $Color
    Write-Host "  $Text" -ForegroundColor $Color
    Write-Host $border -ForegroundColor $Color
    Write-Host ""
}

function Write-Step {
    param([string]$Text, [int]$Step, [int]$Total)
    Write-Host "`n[$Step/$Total] $Text" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Text)
    Write-Host "✓ $Text" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Text)
    Write-Host "⚠ $Text" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Text)
    Write-Host "✗ $Text" -ForegroundColor Red
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-DotNetFramework {
    param([string]$MinVersion = "4.7.2")
    
    try {
        # Primary check - registry key for .NET Framework 4.x
        $regKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -Name "Release" -ErrorAction SilentlyContinue
        
        if ($regKey -and $regKey.Release) {
            # .NET 4.7.2 = Release 461808, .NET 4.8 = Release 528040, .NET 4.8.1 = Release 533320
            $requiredRelease = switch ($MinVersion) {
                "4.7.2" { 461808 }
                "4.8" { 528040 }
                "4.8.1" { 533320 }
                default { 461808 }
            }
            
            if ($regKey.Release -ge $requiredRelease) {
                Write-Host "✓ .NET Framework detected (Release: $($regKey.Release))" -ForegroundColor Green
                return $true
            }
        }
        
        # Fallback check - look for version-specific subkeys
        $dotNetVersions = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -ErrorAction SilentlyContinue |
            Get-ItemProperty -Name Release -ErrorAction SilentlyContinue |
            Where-Object { $_.Release } |
            Select-Object @{Name="Version"; Expression={$_.PSChildName}}, Release
        
        if ($dotNetVersions) {
            $requiredRelease = switch ($MinVersion) {
                "4.7.2" { 461808 }
                "4.8" { 528040 }
                "4.8.1" { 533320 }
                default { 461808 }
            }
            
            $latestRelease = ($dotNetVersions | Measure-Object Release -Maximum).Maximum
            if ($latestRelease -ge $requiredRelease) {
                Write-Host "✓ .NET Framework detected via subkeys (Release: $latestRelease)" -ForegroundColor Green
                return $true
            }
        }
        
        # Additional runtime check
        if ([System.Environment]::Version.Major -eq 4 -and [System.Environment]::Version.Build -ge 30319) {
            Write-Host "✓ .NET Framework 4.8+ detected via runtime version" -ForegroundColor Green
            return $true
        }
        
        return $false
    }
    catch {
        Write-Warning "Error checking .NET Framework: $($_.Exception.Message)"
        return $false
    }
}

function Find-CSCCompiler {
    $possiblePaths = @(
        # Visual Studio 2019/2022 locations
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\*\MSBuild\Current\Bin\Roslyn\csc.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\*\MSBuild\Current\Bin\Roslyn\csc.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2019\*\MSBuild\Current\Bin\Roslyn\csc.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\*\MSBuild\Current\Bin\Roslyn\csc.exe",
        
        # .NET Framework SDK locations
        "${env:ProgramFiles(x86)}\Microsoft SDKs\Windows\*\bin\*\csc.exe",
        "${env:ProgramFiles}\Microsoft SDKs\Windows\*\bin\*\csc.exe",
        
        # .NET Framework locations
        "${env:WINDIR}\Microsoft.NET\Framework64\v*\csc.exe",
        "${env:WINDIR}\Microsoft.NET\Framework\v*\csc.exe"
    )
    
    foreach ($pattern in $possiblePaths) {
        $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | 
                 Sort-Object Name -Descending | 
                 Select-Object -First 1
        if ($found) {
            return $found.FullName
        }
    }
    return $null
}

function Find-WindowsSDKTools {
    $tools = @{
        MakeAppx = $null
        SignTool = $null
    }
    
    $sdkPaths = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64",
        "${env:ProgramFiles}\Windows Kits\10\bin\*\x64",
        "${env:ProgramFiles(x86)}\Windows Kits\10\App Certification Kit",
        "${env:ProgramFiles}\Windows Kits\10\App Certification Kit"
    )
    
    foreach ($pattern in $sdkPaths) {
        # Find MakeAppx
        if (-not $tools.MakeAppx) {
            $makeappx = Get-ChildItem -Path "$pattern\makeappx.exe" -ErrorAction SilentlyContinue |
                       Sort-Object Name -Descending | Select-Object -First 1
            if ($makeappx) { $tools.MakeAppx = $makeappx.FullName }
        }
        
        # Find SignTool
        if (-not $tools.SignTool) {
            $signtool = Get-ChildItem -Path "$pattern\signtool.exe" -ErrorAction SilentlyContinue |
                       Sort-Object Name -Descending | Select-Object -First 1
            if ($signtool) { $tools.SignTool = $signtool.FullName }
        }
    }
    
    return $tools
}

function Invoke-WebDownload {
    param(
        [string]$Url,
        [string]$OutputPath,
        [string]$Description
    )
    
    try {
        Write-Host "Downloading $Description..." -ForegroundColor Gray
        
        # Use System.Net.WebClient for compatibility
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)
        $webClient.Dispose()
        
        if (Test-Path $OutputPath) {
            Write-Success "Downloaded $Description to: $OutputPath"
            return $true
        } else {
            Write-Error "Failed to download $Description"
            return $false
        }
    }
    catch {
        Write-Error "Download failed: $($_.Exception.Message)"
        return $false
    }
}

function Install-DotNetFrameworkDevPack {
    if ($SkipDownloads) {
        Write-Warning "Skipping .NET Framework Developer Pack download"
        return $false
    }
    
    Write-Host "Downloading and installing .NET Framework 4.8.1 Developer Pack..." -ForegroundColor Yellow
    
    $tempDir = Join-Path $env:TEMP "MSIXBuilder"
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }
    
    $installerPath = Join-Path $tempDir "ndp481-devpack-enu.exe"
    
    # Download .NET Framework 4.8.1 Developer Pack
    if (Invoke-WebDownload -Url $script:Config.Downloads.DotNetFramework481DevPack -OutputPath $installerPath -Description ".NET Framework 4.8.1 Developer Pack") {
        Write-Host "Running installer..." -ForegroundColor Gray
        
        # Run installer silently
        $process = Start-Process -FilePath $installerPath -ArgumentList "/quiet" -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Success ".NET Framework Developer Pack installed successfully"
            
            # Clean up
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            
            # Verify installation
            Start-Sleep -Seconds 5
            return (Test-DotNetFramework "4.8")
        } else {
            Write-Error "Installer failed with exit code: $($process.ExitCode)"
            return $false
        }
    }
    
    return $false
}

function Install-WindowsSDK {
    if ($SkipDownloads) {
        Write-Warning "Skipping Windows SDK download"
        return $false
    }
    
    Write-Host "Attempting to download Windows SDK installer..." -ForegroundColor Yellow
    
    $tempDir = Join-Path $env:TEMP "MSIXBuilder"
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }
    
    $installerPath = Join-Path $tempDir "winsdksetup.exe"
    
    # Try to download the Windows SDK installer directly
    Write-Host "Downloading Windows SDK installer..." -ForegroundColor Gray
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($script:Config.Downloads.WindowsSDKInstaller, $installerPath)
        $webClient.Dispose()
        
        if (Test-Path $installerPath) {
            Write-Success "Downloaded Windows SDK installer"
            
            # Launch the installer
            Write-Host "Launching Windows SDK installer..." -ForegroundColor Gray
            Write-Host "Please install the following components:" -ForegroundColor Cyan
            Write-Host "- Windows SDK for UWP Managed Apps"
            Write-Host "- Windows SDK for UWP C++ Apps"
            Write-Host "- Windows SDK Signing Tools for Desktop Apps"
            Write-Host ""
            
            Start-Process -FilePath $installerPath -Wait
            
            # Clean up
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            
            # Check if tools are now available
            $sdkTools = Find-WindowsSDKTools
            return ($sdkTools.MakeAppx -and $sdkTools.SignTool)
        }
    }
    catch {
        Write-Warning "Direct download failed: $($_.Exception.Message)"
    }
    
    # Fallback to opening browser
    Write-Host "Opening Windows SDK download page in browser..." -ForegroundColor Yellow
    Write-Host "Please download and install the Windows SDK manually." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Required SDK components:" -ForegroundColor Cyan
    Write-Host "- Windows SDK for UWP Managed Apps"
    Write-Host "- Windows SDK for UWP C++ Apps" 
    Write-Host "- Windows SDK Signing Tools for Desktop Apps"
    Write-Host ""
    
    try {
        Start-Process $script:Config.Downloads.WindowsSDKPage
    }
    catch {
        Write-Host "Please manually navigate to: $($script:Config.Downloads.WindowsSDKPage)" -ForegroundColor Cyan
    }
    
    # Skip prompt in non-interactive mode
    if (-not ($script:PackageName -and $script:Publisher -and $script:OutputPath -and $script:AppType)) {
        Read-Host "Press Enter after installing the Windows SDK"
    } else {
        Write-Host "Non-interactive mode: Skipping Windows SDK installation prompt" -ForegroundColor Yellow
    }
    
    # Check if tools are now available
    $sdkTools = Find-WindowsSDKTools
    return ($sdkTools.MakeAppx -and $sdkTools.SignTool)
}

function Get-UserConfiguration {
    Write-Banner "MSIX Package Configuration"
    
    # Check if running non-interactively (all required parameters provided)
    $isNonInteractive = $script:PackageName -and $script:Publisher -and $script:OutputPath -and $script:AppType
    
    if (-not $script:PackageName) {
        do {
            $script:PackageName = Read-Host "Package Name (e.g. SecurityTestApp)"
        } while ([string]::IsNullOrWhiteSpace($script:PackageName))
    }
    
    if (-not $script:Publisher) {
        do {
            $script:Publisher = Read-Host "Publisher/Organization (e.g. RedTeam, SecurityResearch)"
        } while ([string]::IsNullOrWhiteSpace($script:Publisher))
    }
    
    if (-not $script:OutputPath) {
        $defaultPath = "C:\MSIXBuild"
        $script:OutputPath = Read-Host "Output Directory (default: $defaultPath)"
        if ([string]::IsNullOrWhiteSpace($script:OutputPath)) {
            $script:OutputPath = $defaultPath
        }
    }
    
    if (-not $script:AppType) {
        Write-Host ""
        Write-Host "Application Types:"
        Write-Host "1. C# Application (requires .NET Framework and compiler)"
        Write-Host "2. PowerShell Application (uses PowerShell only)"
        Write-Host "3. Both (recommended for comprehensive testing)"
        Write-Host ""
        
        do {
            $choice = Read-Host "Select application type (1-3)"
            switch ($choice) {
                "1" { $script:AppType = "CSharp" }
                "2" { $script:AppType = "PowerShell" }
                "3" { $script:AppType = "Both" }
                default { Write-Host "Please select 1, 2, or 3" -ForegroundColor Red }
            }
        } while (-not $script:AppType)
    }
    
    Write-Host ""
    Write-Host "Configuration Summary:" -ForegroundColor Cyan
    Write-Host "- Package Name: $($script:PackageName)"
    Write-Host "- Publisher: $($script:Publisher)"
    Write-Host "- Output Path: $($script:OutputPath)"
    Write-Host "- App Type: $($script:AppType)"
    Write-Host ""
    
    # Skip confirmation prompt if running non-interactively
    if (-not $isNonInteractive) {
        $confirm = Read-Host "Continue with this configuration? (Y/n)"
        if ($confirm -eq 'n' -or $confirm -eq 'N') {
            Write-Host "Configuration cancelled." -ForegroundColor Yellow
            exit 0
        }
    } else {
        Write-Host "Running in non-interactive mode - proceeding with configuration..." -ForegroundColor Green
    }
}

function Test-Dependencies {
    Write-Step "Checking and Installing Dependencies" 1 8
    
    $issues = @()
    
    # Check administrator privileges
    if (-not (Test-Administrator)) {
        $issues += "This script must be run as Administrator"
    }
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $issues += "PowerShell 5.1 or later is required"
    }
    
    # Check .NET Framework for C# compilation
    if ($script:AppType -eq 'CSharp' -or $script:AppType -eq 'Both') {
        if (-not (Test-DotNetFramework $script:Config.RequiredDotNetVersion)) {
            Write-Warning ".NET Framework 4.7.2+ not detected"
            
            # Attempt automatic installation
            if (Install-DotNetFrameworkDevPack) {
                Write-Success ".NET Framework Developer Pack installed successfully"
            } else {
                Write-Warning "Automatic installation failed or was skipped"
                Write-Host "Please manually download from: https://dotnet.microsoft.com/download/dotnet-framework/net481" -ForegroundColor Cyan
                
                # Auto-continue in non-interactive mode, otherwise prompt
                if ($script:PackageName -and $script:Publisher -and $script:OutputPath -and $script:AppType) {
                    Write-Host "Non-interactive mode: Switching to PowerShell-only application..." -ForegroundColor Yellow
                    $script:AppType = "PowerShell"
                } else {
                    $continue = Read-Host "Continue without C# support? (Y/n)"
                    if ($continue -eq 'Y' -or $continue -eq 'y' -or [string]::IsNullOrEmpty($continue)) {
                        Write-Host "Switching to PowerShell-only application..." -ForegroundColor Yellow
                        $script:AppType = "PowerShell"
                    } else {
                        $issues += ".NET Framework 4.7.2+ is required for C# compilation"
                    }
                }
            }
        } else {
            Write-Success ".NET Framework 4.7.2+ detected"
        }
    }
    
    # Check for C# compiler
    if ($script:AppType -eq 'CSharp' -or $script:AppType -eq 'Both') {
        $cscPath = Find-CSCCompiler
        if (-not $cscPath) {
            Write-Warning "C# compiler not found"
            Write-Host "This usually means Visual Studio or .NET Framework SDK is not installed."
            Write-Host "Switching to PowerShell-only application..." -ForegroundColor Yellow
            $script:AppType = "PowerShell"
        } else {
            Write-Success "Found C# compiler: $cscPath"
            $script:CSCPath = $cscPath
        }
    }
    
    # Check Windows SDK tools
    $sdkTools = Find-WindowsSDKTools
    if (-not $sdkTools.MakeAppx -or -not $sdkTools.SignTool) {
        Write-Warning "Windows SDK tools not found"
        
        # Attempt automatic installation guidance
        if (Install-WindowsSDK) {
            Write-Success "Windows SDK tools are now available"
            $sdkTools = Find-WindowsSDKTools
        } else {
            Write-Warning "Windows SDK installation incomplete"
            $issues += "Windows SDK is required but MakeAppx.exe or SignTool.exe were not found"
        }
    }
    
    if ($sdkTools.MakeAppx) {
        Write-Success "Found MakeAppx: $($sdkTools.MakeAppx)"
        $script:MakeAppxPath = $sdkTools.MakeAppx
    }
    
    if ($sdkTools.SignTool) {
        Write-Success "Found SignTool: $($sdkTools.SignTool)"
        $script:SignToolPath = $sdkTools.SignTool
    }
    
    if ($issues.Count -gt 0) {
        Write-Error "Dependency check failed:"
        foreach ($issue in $issues) {
            Write-Host "  • $issue" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "Please resolve the above issues and run the script again." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Manual download links:" -ForegroundColor Cyan
        Write-Host "- .NET Framework 4.8.1 Developer Pack: https://dotnet.microsoft.com/download/dotnet-framework/net481"
        Write-Host "- Windows SDK: https://developer.microsoft.com/windows/downloads/windows-sdk/"
        exit 1
    }
    
    Write-Success "All dependencies satisfied"
}

function New-DirectoryStructure {
    Write-Step "Creating Directory Structure" 2 8
    
    $script:PackagePath = Join-Path $script:OutputPath "Package"
    $script:AppSourcePath = Join-Path $script:OutputPath "AppSource"
    $script:BuildOutputPath = Join-Path $script:OutputPath "Output"
    
    # Remove existing directories if they exist
    if (Test-Path $script:OutputPath) {
        Write-Host "Removing existing directory: $($script:OutputPath)"
        Remove-Item $script:OutputPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Create directory structure
    $directories = @(
        $script:PackagePath,
        "$($script:PackagePath)\Assets",
        "$($script:PackagePath)\VFS",
        "$($script:PackagePath)\VFS\ProgramFilesX64",
        "$($script:PackagePath)\VFS\ProgramFilesX64\$($script:PackageName)",
        $script:AppSourcePath,
        $script:BuildOutputPath
    )
    
    foreach ($dir in $directories) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    
    Write-Success "Directory structure created at: $($script:OutputPath)"
}

function New-CSharpApplication {
    Write-Host "Creating C# test application..." -ForegroundColor Gray
    
    $namespacePrefix = $script:PackageName.Replace(' ', '') + 'App'
    $testDirName = $script:PackageName.Replace(' ', '') + 'Test'
    $packageDisplayName = $script:PackageName
    
    $csharpContent = @"
using System;
using System.IO;
using System.Management;
using System.Security.Principal;
using System.Diagnostics;
using System.Threading;

namespace $namespacePrefix
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("======================================");
            Console.WriteLine("    MSIX Security Test Application    ");
            Console.WriteLine("======================================");
            Console.WriteLine();
            
            DisplaySystemInfo();
            CheckDomainMembership();
            CreateTestFiles();
            CheckMSIXContainer();
            
            Console.WriteLine("Test completed successfully!");
            // Remove interactive prompt for non-interactive execution
        }
        
        static void DisplaySystemInfo()
        {
            Console.WriteLine("System Information:");
            Console.WriteLine("- Current User: " + Environment.UserName);
            Console.WriteLine("- Machine Name: " + Environment.MachineName);
            Console.WriteLine("- Current Directory: " + Directory.GetCurrentDirectory());
            Console.WriteLine("- Process ID: " + Process.GetCurrentProcess().Id);
            Console.WriteLine("- OS Version: " + Environment.OSVersion);
            Console.WriteLine("- CLR Version: " + Environment.Version);
            Console.WriteLine();
        }
        
        static void CheckDomainMembership()
        {
            try
            {
                string domain = GetDomainName();
                Console.WriteLine("Domain Check:");
                Console.WriteLine("- Domain: " + domain);
                
                if (domain.Equals("WORKGROUP", StringComparison.OrdinalIgnoreCase))
                {
                    Console.WriteLine("- Status: Workgroup computer (not domain-joined)");
                }
                else
                {
                    Console.WriteLine("- Status: Domain-joined computer");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("- Domain check failed: " + ex.Message);
            }
            Console.WriteLine();
        }
        
        static string GetDomainName()
        {
            try
            {
                using (ManagementObject mo = new ManagementObject("Win32_ComputerSystem.Name=\"" + Environment.MachineName + "\""))
                {
                    return mo["Domain"].ToString();
                }
            }
            catch
            {
                return Environment.UserDomainName;
            }
        }
        
        static void CreateTestFiles()
        {
            try
            {
                Console.WriteLine("File Operations:");
                
                string testDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "$testDirName");
                Directory.CreateDirectory(testDir);
                Console.WriteLine("- Created directory: " + testDir);
                
                string testFile = Path.Combine(testDir, "test.txt");
                File.WriteAllText(testFile, 
                    "MSIX Security Test File" + Environment.NewLine +
                    "Package: $packageDisplayName" + Environment.NewLine +
                    "Created: " + DateTime.Now + Environment.NewLine +
                    "User: " + Environment.UserName + Environment.NewLine +
                    "Machine: " + Environment.MachineName + Environment.NewLine);
                Console.WriteLine("- Created file: " + testFile);
                
                string psScript = Path.Combine(testDir, "test-script.ps1");
                File.WriteAllText(psScript, 
                    "# MSIX Test PowerShell Script" + Environment.NewLine +
                    "Write-Host \"PowerShell execution from MSIX container\"" + Environment.NewLine +
                    "Get-Process | Select-Object -First 5" + Environment.NewLine);
                Console.WriteLine("- Created script: " + psScript);
            }
            catch (Exception ex)
            {
                Console.WriteLine("- File operation failed: " + ex.Message);
            }
            Console.WriteLine();
        }
        
        static void CheckMSIXContainer()
        {
            Console.WriteLine("MSIX Container Information:");
            bool inContainer = IsRunningInMSIXContainer();
            Console.WriteLine("- Running in MSIX container: " + inContainer);
            Console.WriteLine("- Current working directory: " + Environment.CurrentDirectory);
            Console.WriteLine();
        }
        
        static bool IsRunningInMSIXContainer()
        {
            try
            {
                string currentDir = Environment.CurrentDirectory;
                return currentDir.Contains("WindowsApps") || currentDir.Contains("Program Files\\WindowsApps");
            }
            catch
            {
                return false;
            }
        }
    }
}
"@
    
    $csharpFile = Join-Path $script:AppSourcePath "Program.cs"
    $csharpContent | Out-File -FilePath $csharpFile -Encoding UTF8
    
    # Compile the C# application
    if ($script:CSCPath) {
        $exePath = Join-Path $script:AppSourcePath "$($script:PackageName.Replace(' ', '')).exe"
        $compileArgs = @(
            "/out:$exePath",
            "/reference:${env:WINDIR}\Microsoft.NET\Framework64\v4.0.30319\System.Management.dll",
            $csharpFile
        )
        
        $compileResult = & $script:CSCPath @compileArgs 2>&1
        
        if (Test-Path $exePath) {
            Write-Success "C# application compiled successfully"
            return $true
        } else {
            Write-Warning "C# compilation failed: $compileResult"
            return $false
        }
    }
    
    return $false
}

function New-PowerShellApplication {
    Write-Host "Creating PowerShell test application..." -ForegroundColor Gray
    
    $testDirName = $script:PackageName.Replace(' ', '') + 'Test'
    $packageDisplayName = $script:PackageName
    
    $psScriptContent = @"
Write-Host "======================================"
Write-Host "    MSIX Security Test Application    "
Write-Host "======================================"
Write-Host ""

function Show-SystemInfo {
    Write-Host "System Information:"
    Write-Host "- Current User: `$env:USERNAME"
    Write-Host "- Machine Name: `$env:COMPUTERNAME"
    Write-Host "- Current Directory: `$PWD"
    Write-Host "- Process ID: `$PID"
    Write-Host "- PowerShell Version: `$(`$PSVersionTable.PSVersion)"
    Write-Host "- OS Version: `$([Environment]::OSVersion)"
    Write-Host ""
}

function Test-DomainMembership {
    try {
        `$domain = (Get-WmiObject Win32_ComputerSystem).Domain
        Write-Host "Domain Check:"
        Write-Host "- Domain: `$domain"
        
        if (`$domain -eq "WORKGROUP") {
            Write-Host "- Status: Workgroup computer (not domain-joined)"
        } else {
            Write-Host "- Status: Domain-joined computer"
        }
    } catch {
        Write-Host "- Domain check failed: `$(`$_.Exception.Message)"
    }
    Write-Host ""
}

function New-TestFiles {
    try {
        Write-Host "File Operations:"
        `$testDir = "`$env:LOCALAPPDATA\$testDirName"
        New-Item -ItemType Directory -Path `$testDir -Force | Out-Null
        Write-Host "- Created directory: `$testDir"
        
        `$testFile = "`$testDir\test.txt"
        `$content = "MSIX Security Test File`nPackage: $packageDisplayName`nCreated: " + (Get-Date) + "`nUser: `$env:USERNAME`nMachine: `$env:COMPUTERNAME"
        `$content | Out-File -FilePath `$testFile
        Write-Host "- Created file: `$testFile"
        
        `$psScript = "`$testDir\test-nested.ps1"
        "# Nested PowerShell Script`nWrite-Host 'Nested execution from MSIX container'" | Out-File -FilePath `$psScript
        Write-Host "- Created script: `$psScript"
    } catch {
        Write-Host "- File operation failed: `$(`$_.Exception.Message)"
    }
    Write-Host ""
}

function Test-MSIXContainer {
    Write-Host "MSIX Container Information:"
    `$inContainer = `$PWD -like "*WindowsApps*" -or `$PWD -like "*Program Files\WindowsApps*"
    Write-Host "- Running in MSIX container: `$inContainer"
    Write-Host "- Current working directory: `$PWD"
    Write-Host ""
}

# Main execution
Show-SystemInfo
Test-DomainMembership
New-TestFiles
Test-MSIXContainer

Write-Host "Test completed successfully!"
# Remove interactive prompt for non-interactive execution
"@
    
    $psScriptFile = Join-Path $script:AppSourcePath "$($script:PackageName.Replace(' ', '')).ps1"
    $psScriptContent | Out-File -FilePath $psScriptFile -Encoding UTF8
    
    # Create C# wrapper executable for PowerShell (MSIX requires .exe, not .bat)
    $wrapperNamespace = $script:PackageName.Replace(' ', '') + 'Wrapper'
    $psScriptName = $script:PackageName.Replace(' ', '') + '.ps1'
    
    $wrapperContent = @"
using System;
using System.Diagnostics;
using System.IO;

namespace $wrapperNamespace
{
    class Program
    {
        static void Main(string[] args)
        {
            try
            {
                string currentDir = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
                string psScript = Path.Combine(currentDir, "$psScriptName");
                
                if (!File.Exists(psScript))
                {
                    Console.WriteLine("PowerShell script not found: " + psScript);
                    return;
                }
                
                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "powershell.exe";
                psi.Arguments = "-ExecutionPolicy Bypass -File \"" + psScript + "\"";
                psi.UseShellExecute = false;
                psi.CreateNoWindow = false;
                
                Process process = Process.Start(psi);
                process.WaitForExit();
            }
            catch (Exception ex)
            {
                Console.WriteLine("Error launching PowerShell script: " + ex.Message);
            }
        }
    }
}
"@
    
    $wrapperFile = Join-Path $script:AppSourcePath "PowerShellWrapper.cs"
    $wrapperContent | Out-File -FilePath $wrapperFile -Encoding UTF8
    
    # Try to compile the wrapper if we have a C# compiler
    $cscPath = Find-CSCCompiler
    if ($cscPath) {
        $exePath = Join-Path $script:AppSourcePath "$($script:PackageName.Replace(' ', '')).exe"
        $compileArgs = @(
            "/out:$exePath",
            $wrapperFile
        )
        
        $compileResult = & $cscPath @compileArgs 2>&1
        
        if (Test-Path $exePath) {
            Write-Success "PowerShell wrapper executable created"
            Remove-Item $wrapperFile -Force -ErrorAction SilentlyContinue
            return $true
        } else {
            Write-Warning "Failed to compile PowerShell wrapper: $compileResult"
        }
    }
    
    # MSIX requires .exe files - cannot use batch files
    Write-Error "Cannot create PowerShell application: C# compiler required for .exe wrapper but compilation failed"
    Write-Host "MSIX packages require executable (.exe) files and cannot use batch (.bat) files."
    Write-Host "Please ensure a working C# compiler is available or switch to CSharp-only application type."
    return $false
}

function New-TestApplications {
    Write-Step "Creating Test Applications" 3 8
    
    $success = $false
    
    switch ($script:AppType) {
        'CSharp' {
            $success = New-CSharpApplication
            $script:ExecutableName = "$($script:PackageName.Replace(' ', '')).exe"
        }
        'PowerShell' {
            $success = New-PowerShellApplication
            if ($success) {
                $script:ExecutableName = "$($script:PackageName.Replace(' ', '')).exe"
            }
        }
        'Both' {
            $csharpSuccess = New-CSharpApplication
            $psSuccess = New-PowerShellApplication
            
            if ($csharpSuccess) {
                $script:ExecutableName = "$($script:PackageName.Replace(' ', '')).exe"
                $success = $true
                Write-Success "Using C# application"
            } elseif ($psSuccess) {
                $script:ExecutableName = "$($script:PackageName.Replace(' ', '')).exe"
                $success = $true
                Write-Warning "Using PowerShell application as C# compilation failed"
            } else {
                Write-Error "Both C# and PowerShell application creation failed"
                $success = $false
            }
        }
    }
    
    if (-not $success) {
        throw "Failed to create test applications"
    }
    
    # Copy application files to package structure
    $targetPath = "$($script:PackagePath)\VFS\ProgramFilesX64\$($script:PackageName)"
    Copy-Item "$($script:AppSourcePath)\*" -Destination $targetPath -Recurse -Force
    
    Write-Success "Test applications created and packaged"
}

function New-PackageAssets {
    Write-Step "Creating Package Assets" 4 8
    
    # Create minimal 1x1 pixel PNG (base64 encoded transparent pixel)
    $pngBytes = [Convert]::FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==")
    
    # Create all required image files
    $imageFiles = @(
        "$($script:PackagePath)\Assets\StoreLogo.png",
        "$($script:PackagePath)\Assets\Square150x150Logo.png", 
        "$($script:PackagePath)\Assets\Square44x44Logo.png",
        "$($script:PackagePath)\Assets\Wide310x150Logo.png"
    )
    
    foreach ($imageFile in $imageFiles) {
        [System.IO.File]::WriteAllBytes($imageFile, $pngBytes)
    }
    
    Write-Success "Package assets created"
}

function New-AppxManifest {
    Write-Step "Creating MSIX Manifest" 5 8
    
    $publisherCN = "CN=$($script:Publisher)"
    $packageIdentity = $script:PackageName.Replace(' ', '') + "App"
    
    # Create manifest content as array to avoid parsing issues
    $manifestLines = @(
        '<?xml version="1.0" encoding="utf-8"?>',
        '<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"',
        '         xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"',
        '         xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities">',
        '  ',
        "  <Identity Name=`"$packageIdentity`"",
        "            Publisher=`"$publisherCN`"",
        '            Version="1.0.0.0" />',
        '  ',
        '  <Properties>',
        "    <DisplayName>$($script:PackageName)</DisplayName>",
        "    <PublisherDisplayName>$($script:Publisher)</PublisherDisplayName>",
        '    <Logo>Assets\StoreLogo.png</Logo>',
        "    <Description>MSIX package for security testing and detection validation</Description>",
        '  </Properties>',
        '  ',
        '  <Dependencies>',
        '    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.17763.0" MaxVersionTested="10.0.22000.0" />',
        '  </Dependencies>',
        '  ',
        '  <Applications>',
        "    <Application Id=`"$packageIdentity`" Executable=`"VFS\ProgramFilesX64\$($script:PackageName)\$($script:ExecutableName)`" EntryPoint=`"Windows.FullTrustApplication`">",
        "      <uap:VisualElements DisplayName=`"$($script:PackageName)`"",
        '                          BackgroundColor="transparent"',
        '                          Square150x150Logo="Assets\Square150x150Logo.png"',
        '                          Square44x44Logo="Assets\Square44x44Logo.png"',
        '                          Description="Security testing application for MSIX detection">',
        '        <uap:DefaultTile Wide310x150Logo="Assets\Wide310x150Logo.png" />',
        '      </uap:VisualElements>',
        '    </Application>',
        '  </Applications>',
        '  ',
        '  <Capabilities>',
        '    <rescap:Capability Name="runFullTrust" />',
        '  </Capabilities>',
        '</Package>'
    )
    
    $manifestPath = Join-Path $script:PackagePath "AppxManifest.xml"
    $manifestLines | Out-File -FilePath $manifestPath -Encoding UTF8
    
    Write-Success "MSIX manifest created"
}

function New-TestCertificate {
    Write-Step "Creating Test Certificate" 6 8
    
    $certSubject = "CN=$($script:Publisher)"
    $existingCert = Get-ChildItem -Path "Cert:\CurrentUser\My" -ErrorAction SilentlyContinue | 
                    Where-Object {$_.Subject -eq $certSubject} | 
                    Select-Object -First 1
    
    if ($existingCert) {
        Write-Host "Using existing certificate: $certSubject"
        $script:Certificate = $existingCert
    } else {
        Write-Host "Creating new certificate: $certSubject"
        $script:Certificate = New-SelfSignedCertificate -Type CodeSigningCert -Subject $certSubject -KeyUsage DigitalSignature -FriendlyName "MSIX Test Certificate - $($script:Publisher)" -CertStoreLocation "Cert:\CurrentUser\My"
    }
    
    # Export certificate
    $pwd = ConvertTo-SecureString -String "password123" -Force -AsPlainText
    $script:PfxPath = Join-Path $script:BuildOutputPath "TestCert.pfx"
    Export-PfxCertificate -Cert $script:Certificate -FilePath $script:PfxPath -Password $pwd | Out-Null
    
    # Export public certificate for installation
    $script:CerPath = Join-Path $script:BuildOutputPath "TestCert.cer"
    Export-Certificate -Cert $script:Certificate -FilePath $script:CerPath | Out-Null
    
    Write-Success "Certificate created and exported"
}

function Build-MSIXPackage {
    Write-Step "Building MSIX Package" 7 8
    
    $script:MsixPath = Join-Path $script:BuildOutputPath "$($script:PackageName.Replace(' ', '')).msix"
    
    Write-Host "Running MakeAppx..." -ForegroundColor Gray
    $buildResult = & $script:MakeAppxPath pack /d $script:PackagePath /p $script:MsixPath 2>&1
    
    if (Test-Path $script:MsixPath) {
        Write-Success "MSIX package built successfully"
    } else {
        Write-Error "Failed to build MSIX package"
        Write-Host "Error output: $buildResult" -ForegroundColor Red
        throw "MSIX package build failed"
    }
}

function Sign-MSIXPackage {
    Write-Step "Signing MSIX Package" 8 8
    
    if (-not $script:SignToolPath) {
        Write-Warning "SignTool not available - package will not be signed"
        return
    }
    
    Write-Host "Signing package with test certificate..." -ForegroundColor Gray
    $signResult = & $script:SignToolPath sign /fd SHA256 /f $script:PfxPath /p "password123" $script:MsixPath 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "MSIX package signed successfully"
    } else {
        Write-Warning "Package signing failed: $signResult"
        Write-Warning "Package created but not signed - can still be installed with -AllowUnsigned"
    }
}

function Show-CompletionSummary {
    Write-Banner "MSIX Package Creation Complete"
    
    Write-Host "Package Details:" -ForegroundColor Cyan
    Write-Host "- Package Name: $($script:PackageName)"
    Write-Host "- Publisher: $($script:Publisher)"
    Write-Host "- Application Type: $($script:AppType)"
    Write-Host "- Executable: $($script:ExecutableName)"
    Write-Host ""
    
    Write-Host "Output Files:" -ForegroundColor Cyan
    Write-Host "- MSIX Package: $($script:MsixPath)"
    Write-Host "- Certificate (for trust): $($script:CerPath)"
    Write-Host "- Source Code: $($script:AppSourcePath)"
    Write-Host "- Package Structure: $($script:PackagePath)"
    Write-Host ""
    
    Write-Host "Installation Instructions:" -ForegroundColor Green
    Write-Host ""
    Write-Host "Method 1 - Install certificate and package:"
    Write-Host "1. Import-Certificate -FilePath '$($script:CerPath)' -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople'"
    Write-Host "2. Add-AppPackage -Path '$($script:MsixPath)'"
    Write-Host ""
    Write-Host "Method 2 - Install unsigned (Windows 11 only):"
    Write-Host "   Add-AppPackage -Path '$($script:MsixPath)' -AllowUnsigned"
    Write-Host ""
    
    Write-Host "Testing the Application:" -ForegroundColor Yellow
    Write-Host "After installation, the application will be available in the Start Menu."
    Write-Host "It will create test files in: %LOCALAPPDATA%\$($script:PackageName.Replace(' ', ''))Test"
    Write-Host ""
    
    Write-Host "Security Research Notes:" -ForegroundColor Magenta
    Write-Host "- Monitor file system access in the LocalAppData directory"
    Write-Host "- Monitor WMI queries for domain membership checks"
    Write-Host "- Test detection rules for MSIX container identification"
    Write-Host "- Analyze PowerShell execution within MSIX context"
    Write-Host ""
    
    # Add telemetry mode output
    if ($TelemetryMode) {
        Write-Host "Telemetry Mode Information:" -ForegroundColor Cyan
        Write-Host "- Event logs to monitor: Application and Services Logs > Microsoft > Windows > AppxDeployment-Server"
        Write-Host "- PowerShell ScriptBlock logging: Event ID 4104"
        Write-Host "- Process creation: Event ID 4688 (if enabled)"
        Write-Host "- MSIX container detection: Check for WindowsApps path in process telemetry"
        Write-Host ""
        
        if ($GenerateDetectionLogs) {
            Generate-DetectionEventLog
        }
    }
}

function Generate-DetectionEventLog {
    Write-Host "Generating detection event log..." -ForegroundColor Gray
    
    $logData = @{
        Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
        PackageName = $script:PackageName
        Publisher = $script:Publisher
        InstallPath = $script:MsixPath
        CertificateThumbprint = if ($script:Certificate) { $script:Certificate.Thumbprint } else { "N/A" }
        PayloadType = $script:AppType
        DetectionPoints = @(
            "MSIX package installation",
            "Certificate installation to TrustedPeople store",
            "PowerShell execution from WindowsApps directory",
            "WMI queries for domain membership",
            "File creation in LocalAppData",
            "Process execution from MSIX container"
        )
        IOCs = @{
            FileHashes = @()
            RegistryKeys = @()
            NetworkConnections = @()
            ProcessNames = @($script:ExecutableName)
        }
    }
    
    # Add file hashes if available
    if (Test-Path $script:MsixPath) {
        $hash = Get-FileHash $script:MsixPath -Algorithm SHA256
        $logData.IOCs.FileHashes += @{
            File = $script:MsixPath
            SHA256 = $hash.Hash
        }
    }
    
    $logPath = Join-Path $script:BuildOutputPath "DetectionLog.json"
    $logData | ConvertTo-Json -Depth 4 | Out-File -FilePath $logPath -Encoding UTF8
    
    Write-Success "Detection log created: $logPath"
    
    # Create YARA rule for detection
    Create-YaraRule
}

function Create-YaraRule {
    $yaraRule = @"
rule MSIX_Security_Test_Package
{
    meta:
        description = "Detects MSIX security test package created by MSIXBuilder"
        author = "MSIXBuilder Tool"
        date = "$(Get-Date -Format 'yyyy-MM-dd')"
        reference = "https://github.com/MHaggis/MSIXBuilder"
        
    strings:
        `$msix_magic = { 50 4B 03 04 }
        `$appx_manifest = "AppxManifest.xml"
        `$package_name = "$($script:PackageName)"
        `$publisher = "$($script:Publisher)"
        
    condition:
        `$msix_magic at 0 and
        `$appx_manifest and
        (`$package_name or `$publisher)
}
"@
    
    $yaraPath = Join-Path $script:BuildOutputPath "DetectionRule.yar"
    $yaraRule | Out-File -FilePath $yaraPath -Encoding UTF8
    
    Write-Success "YARA rule created: $yaraPath"
}



function Test-DetectionCapabilities {
    Write-Host "Testing detection capabilities..." -ForegroundColor Yellow
    
    # Test PowerShell ScriptBlock logging
    try {
        $testScript = {
            Write-Host "Testing PowerShell execution from MSIX context"
            Get-Process | Select-Object -First 3
        }
        
        $testScript.Invoke()
        Write-Success "PowerShell execution test completed"
    }
    catch {
        Write-Warning "PowerShell test failed: $($_.Exception.Message)"
    }
    
    # Test WMI queries
    try {
        $domain = (Get-WmiObject Win32_ComputerSystem).Domain
        Write-Success "WMI query test completed (Domain: $domain)"
    }
    catch {
        Write-Warning "WMI test failed: $($_.Exception.Message)"
    }
    
    # Test file operations
    try {
        $testDir = Join-Path $env:TEMP "MSIXDetectionTest"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        "Test file for detection" | Out-File -FilePath "$testDir\test.txt"
        Remove-Item -Path $testDir -Recurse -Force
        Write-Success "File operation test completed"
    }
    catch {
        Write-Warning "File operation test failed: $($_.Exception.Message)"
    }
}

#endregion

#region Main Execution

try {
    # Initialize script variables
    $script:PackageName = $PackageName
    $script:Publisher = $Publisher
    $script:OutputPath = $OutputPath
    $script:AppType = $AppType

    Write-Banner "MSIX Security Test Package Creator v2.0"
    Write-Host "This script creates MSIX packages for security testing and red team exercises." -ForegroundColor Gray
    Write-Host "Includes automatic dependency checking and installation." -ForegroundColor Gray
    Write-Host ""

    # Add telemetry mode information
    if ($TelemetryMode) {
        Write-Host "🔍 TELEMETRY MODE ENABLED" -ForegroundColor Cyan
        Write-Host "Additional detection and logging features will be included." -ForegroundColor Gray
        Write-Host ""
    }

    # Get user configuration
    Get-UserConfiguration
    
    # Check all dependencies
    Test-Dependencies
    
    # Create directory structure
    New-DirectoryStructure
    
    # Create test applications
    New-TestApplications
    

    
    # Create package assets
    New-PackageAssets
    
    # Create manifest
    New-AppxManifest
    
    # Create certificate
    New-TestCertificate
    
    # Build package
    Build-MSIXPackage
    
    # Sign package
    Sign-MSIXPackage
    
    # Test detection capabilities if in telemetry mode
    if ($TelemetryMode) {
        Test-DetectionCapabilities
    }
    
    # Show completion summary
    Show-CompletionSummary
    
} catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

#endregion 