<#
.SYNOPSIS
Script to completely remove Rippling MDM.

.DESCRIPTION
This script performs the following tasks:
1. Uninstalls Rippling MDM.
2. Removes related services and directories.
3. Deletes Rippling-specific registry keys.
4. Adds local user accounts to the Administrators group.

.NOTES
Ensure the script is executed with administrative privileges.
#>

# === FUNCTIONS: UNINSTALLATION AND CLEANUP ===

# Function: Remove Rippling MDM
function Remove-RipplingMDM {
    <#
    .SYNOPSIS
    Uninstall Rippling MDM.
    .DESCRIPTION
    Stops the Rippling service, uninstalls the application, and removes related services.
    #>
    Write-Host "Starting the Rippling uninstaller..." -ForegroundColor Cyan
    $uninstallerPath = "C:\Program Files\Rippling\App\Uninstall Rippling.exe"
    $serviceName = "rippling-daemon"

    # Stop and remove Rippling service
    Write-Host "Stopping the Rippling-daemon Service..." -ForegroundColor Cyan
    try {
        if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
            Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
            Write-Host "Stopped the Rippling-daemon Service." -ForegroundColor Green
            try {
                sc.exe delete $serviceName
                Write-Host "Removed the Rippling-daemon Service." -ForegroundColor Green
            } catch {
                Write-Host "Failed to remove the Rippling-daemon Service. Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "Rippling-daemon Service not found." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error managing the Rippling-daemon Service. Error: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Uninstall Rippling application
    if (Test-Path $uninstallerPath) {
        try {
            Start-Process -FilePath $uninstallerPath -ArgumentList "/S" -Wait -NoNewWindow
            Write-Host "Rippling uninstaller executed successfully." -ForegroundColor Green
        } catch {
            Write-Host "Failed to execute Rippling uninstaller. Error: $($Error[0])" -ForegroundColor Red
        }
    } else {
        Write-Host "Rippling uninstaller not found at $uninstallerPath" -ForegroundColor Yellow
    }
}

# Function: Remove Registry Keys
function Remove-SpecificRegistryKey {
    <#
    .SYNOPSIS
    Deletes Rippling-related registry keys.
    #>
    param (
        [string]$RootPath = "HKLM:\SOFTWARE\Microsoft\Enrollments",
        [string]$TargetString = "RipplingMDM"
    )

    Write-Host "Searching for registry keys related to $TargetString under $RootPath..." -ForegroundColor Cyan
    try {
        $subKeys = Get-ChildItem -Path $RootPath -ErrorAction SilentlyContinue
        if ($subKeys) {
            foreach ($subKey in $subKeys) {
                $subKeyPath = $subKey.PSPath
                $keyValues = Get-ItemProperty -Path $subKeyPath -ErrorAction SilentlyContinue
                if ($keyValues -and $keyValues.PSObject.Properties.Match("$TargetString")) {
                    try {
                        Remove-Item -Path $subKeyPath -Recurse -Force
                        Write-Host "Deleted registry key: $subKeyPath" -ForegroundColor Green
                    } catch {
                        Write-Host "Failed to delete registry key: $subKeyPath. Error: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
        } else {
            Write-Host "No keys found under $RootPath." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error searching for registry keys. Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# === FUNCTIONS: FILE AND DIRECTORY HANDLING ===

# Function: Remove Locked Directories
function Remove-LockedDirectory {
    <#
    .SYNOPSIS
    Removes directories, including locked or restricted ones.
    #>
    param (
        [string]$Path
    )

    Write-Host "Attempting to remove directory: $Path" -ForegroundColor Cyan
    try {
        Get-Process | Where-Object { $_.Path -like "$Path*" } | Stop-Process -Force -ErrorAction SilentlyContinue
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        icacls "$Path" /grant "${currentUser}:(OI)(CI)F" /T /C | Out-Null
        Remove-Item -Path $Path -Recurse -Force
        Write-Host "Successfully removed directory: $Path" -ForegroundColor Green
    } catch {
        Write-Host "Failed to remove directory $Path. Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function: Remove Rippling Directories
function Remove-RipplingDirectories {
    <#
    .SYNOPSIS
    Removes Rippling-related directories.
    #>
    $ripplingDirectories = @("C:\Rippling", "C:\Program Files\Rippling")
    foreach ($dir in $ripplingDirectories) {
        if (Test-Path $dir) {
            Remove-LockedDirectory -Path $dir
        } else {
            Write-Host "Directory not found: $dir" -ForegroundColor Yellow
        }
    }
}

# === FUNCTIONS: USER MANAGEMENT ===

# Function: Add Users to Administrators Group
function Add-LocalUsersToAdministrators {
    <#
    .SYNOPSIS
    Adds all local user accounts to the Administrators group.
    #>
    Write-Host "Adding local user accounts to the Administrators group..." -ForegroundColor Cyan
    try {
        $localUsers = Get-LocalUser | Where-Object { $_.Enabled -and -not ($_.Name -match '^\$') }
        foreach ($user in $localUsers) {
            try {
                Add-LocalGroupMember -Group "Administrators" -Member $user.Name -ErrorAction Stop
                Write-Host "Added user $($user.Name) to Administrators group." -ForegroundColor Green
            } catch {
                Write-Host "Failed to add user $($user.Name) to Administrators group. Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "Error adding users to Administrators group. Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# === MAIN EXECUTION ===

Write-Host "Starting Rippling Removal Script..." -ForegroundColor Cyan
Remove-RipplingMDM
Remove-RipplingDirectories
Remove-SpecificRegistryKey
Add-LocalUsersToAdministrators
Write-Host "Rippling Removal Script completed." -ForegroundColor Green