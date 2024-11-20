# Silently uninstall Rippling and delete the enrollment keys

function Remove-RipplingMDM {
    # Uninstall Rippling MDM
    Write-Host "Starting the Rippling uninstaller..." -ForegroundColor Cyan
    $uninstallerPath = "C:\Program Files\Rippling\App\Uninstall Rippling.exe"
    if (Test-Path $uninstallerPath) {
        try {
            Start-Process -FilePath $uninstallerPath -ArgumentList "/S" -Wait -NoNewWindow
            Write-Host "Rippling uninstaller executed successfully." -ForegroundColor Green
        } catch {
            Write-Host "Failed to execute Rippling uninstaller: $($Error[0])" -ForegroundColor Red
        }
    } else {
        Write-Host "Rippling uninstaller not found at $uninstallerPath" -ForegroundColor Yellow
    }
}

# Call the function to remove Rippling MDM
Remove-RipplingMDM
