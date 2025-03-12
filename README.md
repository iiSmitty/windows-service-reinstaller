# Windows Service Reinstall Script

A PowerShell script that automates the process of uninstalling and reinstalling Windows Services. This tool is especially useful for developers who frequently rebuild and test Windows Services during development.

## Features

- Automatically stops running services before uninstallation
- Uninstalls and reinstalls Windows Services using InstallUtil
- Intelligently finds and starts the service after installation
- Handles services with different registered names than their executable
- Provides detailed feedback with color-coded output
- Configurable via parameters for flexibility

## Requirements

- Windows operating system
- PowerShell 3.0 or later
- Administrator privileges
- .NET Framework installed (defaults to v4.0.30319)

## Installation

1. Download the `Reinstall-WindowsService.ps1` script
2. Save it to a location of your choice

No additional installation steps are required.

## Usage

### Basic Usage

Run PowerShell as Administrator and execute:

```powershell
.\Reinstall-WindowsService.ps1 -ServicePath "C:\path\to\your\service.exe"
```

### Parameters

The script accepts the following parameters:

| Parameter | Description | Default |
| --- | --- | --- |
| `-ServicePath` | Path to the service executable | Required |
| `-ServiceName` | Name of the service (if different from executable name) | Derived from executable |
| `-DotNetPath` | Path to .NET Framework with InstallUtil | C:\Windows\Microsoft.NET\Framework\v4.0.30319 |
| `-StartAfterInstall` | Whether to start the service after installation | $true |
| `-WaitTime` | Seconds to wait after installation before attempting to start | 5 |

> **Important Note**: The `-ServiceName` parameter is especially crucial when the service name specified in your service.cs (using ServiceName attribute or in the installer) differs from the executable filename. Windows will register the service using this configured name rather than the executable filename.

### Example with Parameters

```powershell
.\Reinstall-WindowsService.ps1 `
    -ServicePath "C:\MyServices\DataProcessor.exe" `
    -ServiceName "DataProcessingService" `
    -DotNetPath "C:\Windows\Microsoft.NET\Framework64\v4.0.30319" `
    -WaitTime 10
```

#### Finding Your Actual Service Name

When a Windows Service is created in code, the name registered with Windows is defined in the service class using the `ServiceName` attribute or in the installer. This can be different from the executable name. To find your actual service name:

1. Check your service class for a `[ServiceName("YourServiceName")]` attribute
2. Look in your installer class for `serviceInstaller.ServiceName = "YourServiceName"`
3. Or use PowerShell to list existing services:
   ```powershell
   Get-Service | Where-Object { $_.DisplayName -like "*keyword*" }
   ```

### Creating a Shortcut

To create a shortcut for easy access:

1. Right-click on your desktop and select **New > Shortcut**
2. Enter the location:
   ```
   powershell.exe -ExecutionPolicy Bypass -File "C:\path\to\Reinstall-WindowsService.ps1" -ServicePath "C:\path\to\your\service.exe"
   ```
3. Name your shortcut (e.g., "Reinstall MyService")
4. Right-click the new shortcut, select **Properties**
5. Click **Advanced** and check **Run as administrator**
6. Click **OK** and **Apply**

### Creating a Batch File

Alternatively, create a batch file (.bat) for easy execution:

```batch
@echo off
powershell.exe -ExecutionPolicy Bypass -File "C:\path\to\Reinstall-WindowsService.ps1" -ServicePath "C:\path\to\your\service.exe" -ServiceName "YourCustomServiceName"
pause
```

Save with a .bat extension and run as administrator when needed. This is especially important when your service name (as defined in service.cs) differs from the executable filename.

## Troubleshooting

### Execution Policy Restrictions

If you encounter execution policy restrictions:

```
File cannot be loaded because running scripts is disabled on this system.
```

Use one of these solutions:

1. **Temporary bypass** (recommended for one-time use):
   ```powershell
   powershell -ExecutionPolicy Bypass -File "C:\path\to\Reinstall-WindowsService.ps1"
   ```

2. **Change policy** (system-wide change, use with caution):
   ```powershell
   Set-ExecutionPolicy RemoteSigned
   ```

3. **Unblock the file**: Right-click the script, select Properties, and check "Unblock" if present

### Service Not Found After Installation

If the script cannot find the service after installation:

1. Verify the service was installed correctly (check event logs)
2. The service might have a different name than expected
   - Use the `-ServiceName` parameter to specify the exact name
3. Check if the service requires additional setup before starting

## Common Scenarios

### Using with Visual Studio Projects

For Visual Studio projects, you might set up a post-build event:

```
powershell.exe -ExecutionPolicy Bypass -File "$(SolutionDir)Scripts\Reinstall-WindowsService.ps1" -ServicePath "$(TargetPath)"
```

### Using with Multiple Services

Create different shortcuts or batch files for each service, or create a master script that calls this script multiple times with different parameters.

## Contributing

Feel free to fork and submit pull requests with improvements or additional features.

## License

This script is provided as-is under the MIT License. Feel free to use, modify, and distribute it as needed.

## Acknowledgments

- Inspired by the common challenge developers face when repeatedly reinstalling and testing Windows Services
- Created to save development time and reduce manual steps
