Write-Host "======================================"
Write-Host "    MSIX Security Test Application    "
Write-Host "======================================"
Write-Host ""

function Show-SystemInfo {
    Write-Host "System Information:"
    Write-Host "- Current User: $env:USERNAME"
    Write-Host "- Machine Name: $env:COMPUTERNAME"
    Write-Host "- Current Directory: $PWD"
    Write-Host "- Process ID: $PID"
    Write-Host "- PowerShell Version: $($PSVersionTable.PSVersion)"
    Write-Host "- OS Version: $([Environment]::OSVersion)"
    Write-Host ""
}

function Test-DomainMembership {
    try {
        $domain = (Get-WmiObject Win32_ComputerSystem).Domain
        Write-Host "Domain Check:"
        Write-Host "- Domain: $domain"
        
        if ($domain -eq "WORKGROUP") {
            Write-Host "- Status: Workgroup computer (not domain-joined)"
        } else {
            Write-Host "- Status: Domain-joined computer"
        }
    } catch {
        Write-Host "- Domain check failed: $($_.Exception.Message)"
    }
    Write-Host ""
}

function New-TestFiles {
    try {
        Write-Host "File Operations:"
        $testDir = "$env:LOCALAPPDATA\HaagerTest"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        Write-Host "- Created directory: $testDir"
        
        $testFile = "$testDir\test.txt"
        $content = "MSIX Security Test File`nPackage: Haager`nCreated: " + (Get-Date) + "`nUser: $env:USERNAME`nMachine: $env:COMPUTERNAME"
        $content | Out-File -FilePath $testFile
        Write-Host "- Created file: $testFile"
        
        $psScript = "$testDir\test-nested.ps1"
        "# Nested PowerShell Script`nWrite-Host 'Nested execution from MSIX container'" | Out-File -FilePath $psScript
        Write-Host "- Created script: $psScript"
    } catch {
        Write-Host "- File operation failed: $($_.Exception.Message)"
    }
    Write-Host ""
}

function Test-MSIXContainer {
    Write-Host "MSIX Container Information:"
    $inContainer = $PWD -like "*WindowsApps*" -or $PWD -like "*Program Files\WindowsApps*"
    Write-Host "- Running in MSIX container: $inContainer"
    Write-Host "- Current working directory: $PWD"
    Write-Host ""
}

# Main execution
Show-SystemInfo
Test-DomainMembership
New-TestFiles
Test-MSIXContainer

Write-Host "Test completed successfully!"
Write-Host "Press any key to exit..."
Read-Host