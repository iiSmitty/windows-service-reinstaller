<#
.SYNOPSIS
    Automates the process of uninstalling and reinstalling Windows Services.

.DESCRIPTION
    This script simplifies the development and testing of Windows Services by automating
    the process of stopping, uninstalling, reinstalling, and starting services using InstallUtil.

.PARAMETER ServicePath
    Full path to the service executable file.

.PARAMETER ServiceName
    Name of the service as registered with Windows. This is crucial when the service name
    in your service.cs file (ServiceName attribute or installer) differs from the executable name.
    If not specified, script will try to use the executable filename, which might not work.

.PARAMETER DotNetPath
    Path to the .NET Framework that contains InstallUtil.exe.
    Default is "C:\Windows\Microsoft.NET\Framework\v4.0.30319".

.PARAMETER StartAfterInstall
    Whether to start the service after installation.
    Default is $true.

.PARAMETER WaitTime
    Number of seconds to wait after installation before attempting to start the service.
    Default is 5 seconds.

.EXAMPLE
    .\Reinstall-WindowsService.ps1 -ServicePath "C:\MyService\MyService.exe"

.EXAMPLE
    .\Reinstall-WindowsService.ps1 -ServicePath "C:\MyService\DataProcessor.exe" -ServiceName "DataProcessingService"

.EXAMPLE
    .\Reinstall-WindowsService.ps1 -ServicePath "C:\MyService\MyService.exe" -DotNetPath "C:\Windows\Microsoft.NET\Framework64\v4.0.30319" -WaitTime 10

.NOTES
    Author: Your Name
    Version: 1.0
    Created: March 12, 2025
    
    This script requires administrator privileges to run.
#>

# Parameters allow for easy customization when calling the script
param (
    [Parameter(Mandatory=$true, HelpMessage="Full path to the service executable file")]
    [string]$ServicePath,
    
    [Parameter(Mandatory=$false, HelpMessage="Service name as registered with Windows (important if different from executable name)")]
    [string]$ServiceName = "",
    
    [Parameter(Mandatory=$false, HelpMessage="Path to the .NET Framework containing InstallUtil.exe")]
    [string]$DotNetPath = "C:\Windows\Microsoft.NET\Framework\v4.0.30319",
    
    [Parameter(Mandatory=$false, HelpMessage="Whether to start the service after installation")]
    [switch]$StartAfterInstall = $true,
    
    [Parameter(Mandatory=$false, HelpMessage="Seconds to wait after installation before starting the service")]
    [int]$WaitTime = 5
)

# Banner function for consistent formatting
function Write-Banner {
    param (
        [string]$Text
    )
    
    Write-Host "`n================================================" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "================================================`n" -ForegroundColor Cyan
}

# Check if running as administrator
function Test-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to check if service exists
function Test-ServiceExists {
    param (
        [string]$ServiceNameToCheck
    )
    
    return Get-Service -Name $ServiceNameToCheck -ErrorAction SilentlyContinue
}

# Validate input and environment
if (-not (Test-Administrator)) {
    Write-Host "This script requires administrator privileges. Please run as administrator." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $DotNetPath)) {
    Write-Host "The specified .NET Framework path does not exist: $DotNetPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "$DotNetPath\InstallUtil.exe")) {
    Write-Host "InstallUtil.exe not found at: $DotNetPath\InstallUtil.exe" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $ServicePath)) {
    Write-Host "The specified service executable does not exist: $ServicePath" -ForegroundColor Red
    exit 1
}

# If service name not explicitly provided, extract from executable path
if ([string]::IsNullOrEmpty($ServiceName)) {
    $ServiceName = [System.IO.Path]::GetFileNameWithoutExtension($ServicePath)
}

# Begin execution
Write-Banner "Windows Service Reinstall Script"

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Service Path: $ServicePath" -ForegroundColor Yellow
Write-Host "  Service Name: $ServiceName" -ForegroundColor Yellow
if ([string]::IsNullOrEmpty($ServiceName)) {
    Write-Host "  [WARNING] No service name provided - will attempt to use executable name" -ForegroundColor Red
    Write-Host "  This may fail if the service name in service.cs differs from the executable name" -ForegroundColor Red
    Write-Host "  Consider using -ServiceName parameter if this script fails" -ForegroundColor Red
}
Write-Host "  .NET Framework Path: $DotNetPath" -ForegroundColor Yellow
Write-Host "  Start After Install: $StartAfterInstall" -ForegroundColor Yellow
Write-Host "  Wait Time: $WaitTime seconds" -ForegroundColor Yellow
Write-Host ""

# Stop the service if it's running
$serviceToStop = Test-ServiceExists -ServiceNameToCheck $ServiceName
if ($serviceToStop) {
    Write-Host "Stopping service '$ServiceName'..." -ForegroundColor Yellow
    try {
        Stop-Service -Name $ServiceName -Force -ErrorAction Stop
        Write-Host "Service stopped successfully." -ForegroundColor Green
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Host "Error stopping service: $_" -ForegroundColor Red
        Write-Host "Continuing with uninstallation anyway..." -ForegroundColor Yellow
    }
}
else {
    Write-Host "Service '$ServiceName' is not currently installed or running." -ForegroundColor Yellow
}

# Uninstall the service
Write-Host "Uninstalling service..." -ForegroundColor Yellow
try {
    Push-Location $DotNetPath
    $uninstallOutput = & .\InstallUtil.exe -u $ServicePath 2>&1
    Pop-Location
    Write-Host "Uninstallation command completed." -ForegroundColor Green
}
catch {
    Write-Host "Error during uninstallation: $_" -ForegroundColor Red
    # Continue anyway as the service might not be installed
}

# Wait a moment for the uninstallation to complete
Start-Sleep -Seconds 2

# Install the service
Write-Host "Installing service..." -ForegroundColor Yellow
try {
    Push-Location $DotNetPath
    $installOutput = & .\InstallUtil.exe $ServicePath 2>&1
    Pop-Location
    Write-Host "Installation command completed." -ForegroundColor Green
}
catch {
    Write-Host "Error during installation: $_" -ForegroundColor Red
    exit 1
}

# Wait for installation to complete and service to register
Write-Host "Waiting $WaitTime seconds for service registration..." -ForegroundColor Yellow
Start-Sleep -Seconds $WaitTime

# Only attempt to start if the flag is set
if ($StartAfterInstall) {
    # List all services that might match our service
    Write-Host "Searching for services containing '$ServiceName' in the name..." -ForegroundColor Yellow
    $potentialServices = Get-Service | Where-Object { $_.DisplayName -like "*$ServiceName*" -or $_.Name -like "*$ServiceName*" }

    if ($potentialServices -and $potentialServices.Count -gt 0) {
        # Display found services
        Write-Host "Found these potential matching services:" -ForegroundColor Cyan
        $potentialServices | Format-Table Name, DisplayName, Status -AutoSize
        
        # Try to start each potential service
        foreach ($svc in $potentialServices) {
            try {
                Write-Host "Attempting to start service '$($svc.Name)' ($($svc.DisplayName))..." -ForegroundColor Yellow
                Start-Service -Name $svc.Name -ErrorAction Stop
                
                # Check if service started successfully
                $service = Get-Service -Name $svc.Name
                if ($service.Status -eq "Running") {
                    Write-Host "Service '$($svc.Name)' is now running." -ForegroundColor Green
                } else {
                    Write-Host "Failed to start service '$($svc.Name)'. Current status: $($service.Status)" -ForegroundColor Red
                }
            } catch {
                Write-Host "Error starting service '$($svc.Name)': $_" -ForegroundColor Red
            }
        }
    } elseif (Test-ServiceExists -ServiceNameToCheck $ServiceName) {
        # Try with the original service name
        Write-Host "Starting service '$ServiceName'..." -ForegroundColor Yellow
        try {
            Start-Service -Name $ServiceName -ErrorAction Stop
            
            # Check if service started successfully
            $service = Get-Service -Name $ServiceName
            if ($service.Status -eq "Running") {
                Write-Host "Service '$ServiceName' is now running." -ForegroundColor Green
            } else {
                Write-Host "Failed to start service '$ServiceName'. Current status: $($service.Status)" -ForegroundColor Red
            }
        } catch {
            Write-Host "Error starting service '$ServiceName': $_" -ForegroundColor Red
        }
    } else {
        Write-Host "No matching services were found. The service may:" -ForegroundColor Red
        Write-Host "1. Have a different name than expected" -ForegroundColor Red
        Write-Host "2. Not be properly registered after installation" -ForegroundColor Red
        Write-Host "3. Have an issue with the installation process" -ForegroundColor Red
        
        Write-Host "`nTry manually checking services with:" -ForegroundColor Yellow
        Write-Host "Get-Service | Where-Object { `$_.DisplayName -like '*$ServiceName*' }" -ForegroundColor Yellow
    }
}
else {
    Write-Host "Skipping service start as requested." -ForegroundColor Yellow
}

Write-Banner "Service Reinstallation Complete"
