# Silently uninstall Rippling and delete the specific enrollment key for RipplingMDM

function Remove-RipplingMDM {
    # Uninstall Rippling MDM
    Write-Host "Starting the Rippling uninstaller..." -ForegroundColor Cyan
    $uninstallerPath = "C:\Program Files\Rippling\App\Uninstall Rippling.exe"
    $serviceName = "rippling-daemon"

    # Stop and remove Rippling-daemon Service
    Write-Host "Stopping and removing the Rippling-daemon Service..." -ForegroundColor Cyan
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

function Remove-SpecificRegistryKey {
    param (
        [string]$RootPath = "HKLM:\SOFTWARE\Microsoft\Enrollments", # Root registry path to search
        [string]$TargetString = "RipplingMDM" # String to identify the specific key
    )

    Write-Host "Searching for registry keys related to $TargetString under $RootPath..." -ForegroundColor Cyan

    try {
        # Get all child keys under the root path
        $subKeys = Get-ChildItem -Path $RootPath -ErrorAction SilentlyContinue

        if ($subKeys) {
            foreach ($subKey in $subKeys) {
                # Check the key's name or properties for a match
                $subKeyPath = $subKey.PSPath
                $keyValues = Get-ItemProperty -Path $subKey.PSPath -ErrorAction SilentlyContinue

                if ($keyValues -and $keyValues.PSObject.Properties.Match("$TargetString")) {
                    try {
                        # Remove the specific key
                        Remove-Item -Path $subKeyPath -Recurse -Force
                        Write-Host "Deleted registry key: $subKeyPath" -ForegroundColor Green
                    } catch {
                        Write-Host "Failed to delete registry key: $subKeyPath. Error: $($_.Exception.Message)" -ForegroundColor Red
                    }
                } else {
                    Write-Host "Key does not match the target string: $TargetString" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "No keys found under $RootPath." -ForegroundColor Yellow
        }

        Write-Host "Search for $TargetString completed." -ForegroundColor Green
    } catch {
        Write-Host "An error occurred while searching for registry keys. Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Remove-LockedDirectory {
    param (
        [string]$Path
    )

    Write-Host "Attempting to remove directory: $Path" -ForegroundColor Cyan

    # Stop any processes using the directory
    try {
        Get-Process | Where-Object { $_.Path -like "$Path*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "No processes found using the directory or error stopping processes. Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Take ownership and grant full control to the current user
    try {
        Write-Host "Taking ownership of directory: $Path" -ForegroundColor Yellow
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        icacls "$Path" /grant "${currentUser}:(OI)(CI)F" /T /C | Out-Null
    } catch {
        Write-Host "Failed to adjust permissions for $Path. Error: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Retry deletion
    try {
        Remove-Item -Path $Path -Recurse -Force
        Write-Host "Successfully removed directory: $Path" -ForegroundColor Green
    } catch {
        Write-Host "Failed to remove directory $Path. Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Remove-RipplingDirectories {
    $ripplingDirectories = @("C:\Rippling", "C:\Program Files\Rippling")

    foreach ($dir in $ripplingDirectories) {
        if (Test-Path $dir) {
            Remove-LockedDirectory -Path $dir
        } else {
            Write-Host "Directory not found: $dir" -ForegroundColor Yellow
        }
    }
}

function Add-LocalUsersToAdministrators {
    Write-Host "Adding local user accounts to the Administrators group..." -ForegroundColor Cyan

    try {
        # Get all local user accounts (excluding service accounts)
        $localUsers = Get-LocalUser | Where-Object {
            $_.Enabled -and
            -not ($_.Name -match '^\$') # Exclude service accounts starting with '$'
        }

        if ($localUsers) {
            foreach ($user in $localUsers) {
                try {
                    # Add the user to the Administrators group
                    Add-LocalGroupMember -Group "Administrators" -Member $user.Name -ErrorAction Stop
                    Write-Host "Added user $($user.Name) to Administrators group." -ForegroundColor Green
                } catch {
                    Write-Host "Failed to add user $($user.Name) to Administrators group. Error: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "No eligible local user accounts found." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "An error occurred while adding users. Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Call the functions
Remove-RipplingMDM
Remove-RipplingDirectories
Remove-SpecificRegistryKey
Add-LocalUsersToAdministrators