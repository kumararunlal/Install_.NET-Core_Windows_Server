# List of target servers
$servers = Get-Content -Path "C:\Installers\DotNet\servers.txt"

# Source server (where setup files are stored)
$sourceServer = "vmwus31swtds205"

# Path on source server containing installers
$sourcePath = "\\$sourceServer\C$\Installers\DotNet"

# Path on remote target where installers will be copied
$targetPath = "C:\Temp\DotNetInstallers"

# Output log file path on remote servers
$logPath = "C:\Temp\dotnet_install_log.txt"

# Script block to execute on remote servers (installation logic)
$installScript = {
    param($targetPath, $logPath)

    if (-not (Test-Path -Path "C:\Temp")) {
        New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
    }

    $installers = @(
        "dotnet-hosting-9.0.10-win.exe",
        "aspnetcore-runtime-9.0.10-win-x64.exe",
        "aspnetcore-runtime-9.0.10-win-x86.exe",
        "dotnet-runtime-9.0.10-win-x64.exe",
        "dotnet-runtime-9.0.10-win-x86.exe"
        
    )

    foreach ($installer in $installers) {
        $fullPath = Join-Path $targetPath $installer

        if (Test-Path $fullPath) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Add-Content -Path $logPath -Value "$timestamp - Installing $installer"

            # Install silently and prevent reboot
            $exitCode = (Start-Process -FilePath $fullPath -ArgumentList "/quiet /norestart" -Wait -PassThru).ExitCode

            $result = if ($exitCode -eq 0) { "SUCCESS" } else { "FAILED (Exit Code: $exitCode)" }
            Add-Content -Path $logPath -Value "$timestamp - $installer install result: $result"
        }
        else {
            Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - MISSING: $fullPath"
        }
    }
}

# Cleanup script to run after install
$cleanupScript = {
    param($targetPath, $logPath)
    if (Test-Path $targetPath) {
        try {
            Remove-Item -Path $targetPath -Recurse -Force
            Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - CLEANUP: Deleted $targetPath"
        }
        catch {
            Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - CLEANUP FAILED: $_"
        }
    }
}

# Main loop to process each server
foreach ($server in $servers) {
    Write-Host ">>> Processing $server..."

    # Ensure target directory exists
    Invoke-Command -ComputerName $server -ScriptBlock {
        param($targetPath)
        if (-not (Test-Path -Path $targetPath)) {
            New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
        }
    } -ArgumentList $targetPath

    # Copy files to remote server
    Copy-Item -Path "$sourcePath\*" -Destination "\\$server\C$\Temp\DotNetInstallers" -Recurse -Force

    # Run installation
    Invoke-Command -ComputerName $server -ScriptBlock $installScript -ArgumentList $targetPath, $logPath

    # Run cleanup
    Invoke-Command -ComputerName $server -ScriptBlock $cleanupScript -ArgumentList $targetPath, $logPath

    Write-Host ">>> Completed $server`n"
}
