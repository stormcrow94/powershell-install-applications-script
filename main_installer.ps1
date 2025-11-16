# ============================================
# Main Installer Script - Application Manager
# ============================================

#Requires -Version 5.1

# Function to check for administrator privileges
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to display header
function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "                                                                " -ForegroundColor Cyan
    Write-Host "          APPLICATION INSTALLATION MANAGER                      " -ForegroundColor Cyan
    Write-Host "                                                                " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# Function to display menu
function Show-Menu {
    Write-Host "Available Operations:" -ForegroundColor White
    Write-Host ""
    Write-Host "  [1] Install Zabbix Agent" -ForegroundColor Green
    Write-Host "  [2] Install Sophos" -ForegroundColor Green
    Write-Host "  [3] Install Wazuh" -ForegroundColor Green
    Write-Host "  [4] Remove Zabbix Agent" -ForegroundColor Yellow
    Write-Host "  [5] Install All (Zabbix, Sophos, Wazuh)" -ForegroundColor Cyan
    Write-Host "  [0] Exit" -ForegroundColor Red
    Write-Host ""
}

# Function to execute script with timeout and error handling
function Invoke-ScriptWithTimeout {
    param(
        [string]$ScriptPath,
        [string]$ScriptName,
        [int]$TimeoutSeconds = 1800
    )
    
    $result = @{
        Success = $false
        Message = ""
        ExitCode = -1
    }
    
    if (-not (Test-Path $ScriptPath)) {
        $result.Message = "Script not found: $ScriptPath"
        return $result
    }
    
    # Check if script is empty
    $scriptContent = Get-Content $ScriptPath -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($scriptContent)) {
        $result.Message = "Script is empty"
        return $result
    }
    
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "Executing: $ScriptName" -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Use Start-Process to run script with timeout handling
        $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPath`"" -PassThru -WindowStyle Normal
        
        # Wait for process with timeout
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        
        if (-not $completed) {
            # Timeout - kill the process
            try {
                if (-not $process.HasExited) {
                    $process.Kill()
                    $process.WaitForExit(5000)
                }
            } catch {
                # Process might have already exited
            }
            $result.Success = $false
            $result.Message = "Script execution timed out after $TimeoutSeconds seconds"
            $result.ExitCode = -2
        } else {
            # Process completed
            $exitCode = $process.ExitCode
            
            if ($exitCode -eq 0) {
                $result.Success = $true
                $result.Message = "Completed successfully"
                $result.ExitCode = $exitCode
            } else {
                $result.Success = $false
                $result.Message = "Failed with exit code: $exitCode"
                $result.ExitCode = $exitCode
            }
        }
    } catch {
        $result.Success = $false
        $result.Message = "Error executing script: $_"
        $result.ExitCode = -1
    }
    
    return $result
}

# Function to display result
function Show-Result {
    param(
        [string]$ScriptName,
        [hashtable]$Result
    )
    
    Write-Host ""
    if ($Result.Success) {
        Write-Host "SUCCESS: $ScriptName - $($Result.Message)" -ForegroundColor Green
    } else {
        Write-Host "FAILED: $ScriptName - $($Result.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# Main execution
function Main {
    # Check for administrator privileges
    if (-not (Test-Administrator)) {
        Write-Host ""
        Write-Host "WARNING: This script requires administrator privileges!" -ForegroundColor Yellow
        Write-Host "Restarting with elevated rights..." -ForegroundColor Yellow
        Write-Host ""
        Start-Sleep -Seconds 2
        
        # Get script path
        if ($PSCommandPath) {
            $scriptPath = $PSCommandPath
        } elseif ($MyInvocation.MyCommand.Path) {
            $scriptPath = $MyInvocation.MyCommand.Path
        } else {
            $scriptPath = $MyInvocation.PSCommandPath
        }
        
        if (-not $scriptPath) {
            Write-Host "Error: Could not determine script path. Please run this script directly." -ForegroundColor Red
            Write-Host "Press any key to exit..."
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            exit 1
        }
        
        Start-Process PowerShell.exe -Verb RunAs -ArgumentList "-NoExit", "-File", "`"$scriptPath`""
        exit
    }
    
    # Get script directory
    if ($MyInvocation.MyCommand.Path) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    } elseif ($PSCommandPath) {
        $scriptDir = Split-Path -Parent $PSCommandPath
    } else {
        $scriptDir = Split-Path -Parent $MyInvocation.PSCommandPath
    }
    
    if (-not $scriptDir) {
        Write-Host "Error: Could not determine script directory." -ForegroundColor Red
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        exit 1
    }
    
    # Define script paths
    $scripts = @{
        "Zabbix" = Join-Path $scriptDir "install_zabbix_silent.ps1"
        "Sophos" = Join-Path $scriptDir "install_sophos.ps1"
        "Wazuh" = Join-Path $scriptDir "install_wazuh.ps1"
        "RemoveZabbix" = Join-Path $scriptDir "remove_zabbix.ps1"
    }
    
    # Main loop
    do {
        Show-Header
        Show-Menu
        
        $choice = Read-Host "Select an option"
        
        switch ($choice) {
            "1" {
                Show-Header
                $result = Invoke-ScriptWithTimeout -ScriptPath $scripts.Zabbix -ScriptName "Install Zabbix Agent" -TimeoutSeconds 1800
                Show-Result -ScriptName "Install Zabbix Agent" -Result $result
                Write-Host "Press any key to continue..."
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            }
            "2" {
                Show-Header
                if (Test-Path $scripts.Sophos) {
                    $result = Invoke-ScriptWithTimeout -ScriptPath $scripts.Sophos -ScriptName "Install Sophos" -TimeoutSeconds 1800
                    Show-Result -ScriptName "Install Sophos" -Result $result
                } else {
                    Write-Host "WARNING: Sophos installation script not found or is empty." -ForegroundColor Yellow
                }
                Write-Host "Press any key to continue..."
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            }
            "3" {
                Show-Header
                if (Test-Path $scripts.Wazuh) {
                    $result = Invoke-ScriptWithTimeout -ScriptPath $scripts.Wazuh -ScriptName "Install Wazuh" -TimeoutSeconds 1800
                    Show-Result -ScriptName "Install Wazuh" -Result $result
                } else {
                    Write-Host "WARNING: Wazuh installation script not found or is empty." -ForegroundColor Yellow
                }
                Write-Host "Press any key to continue..."
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            }
            "4" {
                Show-Header
                $result = Invoke-ScriptWithTimeout -ScriptPath $scripts.RemoveZabbix -ScriptName "Remove Zabbix Agent" -TimeoutSeconds 600
                Show-Result -ScriptName "Remove Zabbix Agent" -Result $result
                Write-Host "Press any key to continue..."
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            }
            "5" {
                Show-Header
                Write-Host "Installing all applications..." -ForegroundColor Cyan
                Write-Host ""
                
                $results = @()
                
                # Install Zabbix
                Write-Host "Step 1/3: Installing Zabbix Agent..." -ForegroundColor Yellow
                $result = Invoke-ScriptWithTimeout -ScriptPath $scripts.Zabbix -ScriptName "Install Zabbix Agent" -TimeoutSeconds 1800
                $results += @{Name = "Zabbix Agent"; Result = $result}
                Show-Result -ScriptName "Install Zabbix Agent" -Result $result
                Start-Sleep -Seconds 3
                
                # Install Sophos
                if (Test-Path $scripts.Sophos) {
                    Write-Host "Step 2/3: Installing Sophos..." -ForegroundColor Yellow
                    $result = Invoke-ScriptWithTimeout -ScriptPath $scripts.Sophos -ScriptName "Install Sophos" -TimeoutSeconds 1800
                    $results += @{Name = "Sophos"; Result = $result}
                    Show-Result -ScriptName "Install Sophos" -Result $result
                } else {
                    Write-Host "WARNING: Step 2/3: Sophos installation script not found or is empty." -ForegroundColor Yellow
                }
                Start-Sleep -Seconds 3
                
                # Install Wazuh
                if (Test-Path $scripts.Wazuh) {
                    Write-Host "Step 3/3: Installing Wazuh..." -ForegroundColor Yellow
                    $result = Invoke-ScriptWithTimeout -ScriptPath $scripts.Wazuh -ScriptName "Install Wazuh" -TimeoutSeconds 1800
                    $results += @{Name = "Wazuh"; Result = $result}
                    Show-Result -ScriptName "Install Wazuh" -Result $result
                } else {
                    Write-Host "WARNING: Step 3/3: Wazuh installation script not found or is empty." -ForegroundColor Yellow
                }
                
                # Summary
                Write-Host ""
                Write-Host "================================================================" -ForegroundColor Cyan
                Write-Host "Installation Summary" -ForegroundColor Cyan
                Write-Host "================================================================" -ForegroundColor Cyan
                foreach ($item in $results) {
                    if ($item.Result.Success) {
                        Write-Host "  SUCCESS: $($item.Name)" -ForegroundColor Green
                    } else {
                        Write-Host "  FAILED: $($item.Name) - $($item.Result.Message)" -ForegroundColor Red
                    }
                }
                Write-Host ""
                
                Write-Host "Press any key to continue..."
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            }
            "0" {
                Show-Header
                Write-Host "Exiting..." -ForegroundColor Yellow
                Write-Host ""
                exit 0
            }
            default {
                Write-Host ""
                Write-Host "Invalid option. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    } while ($true)
}

# Run main function
try {
    Main
} catch {
    Write-Host ""
    Write-Host "Fatal error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}
