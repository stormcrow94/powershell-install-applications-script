#remove all zabbix cleint and local dir

Write-Host "Detecting current Zabbix Agents"
Start-Sleep -Seconds 2

$searchString = "Zabbix"

try {
    $packages = Get-Package -Name "*$searchString*" -ErrorAction SilentlyContinue
} catch {
    $packages = @()
}
Clear-Host

if ($null -eq $packages -or $packages.Count -eq 0) {
    Write-Host "No packages containin $searchString found"
    Start-Sleep -Seconds 2
} else {
    Write-Host "The following packages were found::"
    Start-Sleep -Seconds 2
    $packages | Format-Table -AutoSize

    foreach ($package in $packages) {
        Uninstall-Package -Name $package.Name -Confirm:$false
        Write-Host "Pakiet $($package.Name) został odinstalowany."
        Start-Sleep -Seconds 2
        Clear-Host

        # Delete related directories
        $installPath = $package.InstallLocation
        if ($installPath) {
            Remove-Item -Path $installPath -Recurse -Force
            Write-Host "Directory $installPath has been deleted."
            Start-Sleep -Seconds 2
            Clear-Host
        } else {
            Write-Host "Installation directory for package $($package.Name). not found."
            Start-Sleep -Seconds 2
            Clear-Host
        }
    }
}
Write-Host "Removing Zabbix Agent keys from the registry"
Start-Sleep -Seconds 2
Clear-Host
# Remove registry keys if they exist
try {
    Remove-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application\Zabbix Agent 2" -Recurse -ErrorAction SilentlyContinue
} catch {
    # Key may not exist
}
try {
    Remove-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\System\Zabbix Agent" -Recurse -ErrorAction SilentlyContinue
} catch {
    # Key may not exist
}
Clear-Host
Clear-Host
Write-Host "Zabbix Agent registry keys removed"
Start-Sleep -Seconds 2
Clear-Host
Clear-Host
Write-Host "Removing Zabbix service"
Start-Sleep -Seconds 2
# Remove services if they exist
$null = sc.exe delete "Zabbix Agent 2" 2>&1
Start-Sleep -Seconds 1
Clear-Host
$null = sc.exe delete "Zabbix Agent" 2>&1
Clear-Host
Write-Host "Service removed"
Start-Sleep -Seconds 2
Clear-Host​

exit 0