function Check-Admin {
    try {
        # Get the current user identity
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        # Check if the user belongs to the Local Administrators group
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        # Fallback if initial checks fail (unlikely, but good to be safe)
        return $false
    }
}

if (-Not (Check-Admin)) {
    # Script requires elevation, restart with elevated rights
    Write-Host "This script requires administrator privileges to continue."
    Start-Process PowerShell.exe -Verb runAs -ArgumentList "-NoExit", "-File", $PSCommandPath
    Exit
}

# Call the Check-Admin function at the beginning
Check-Admin

function Show-Menu {
    Clear-Host
    Write-Host "*** Instalação de Softwares ***"
    Write-Host "1) Instalar Agente Zabbix"
    Write-Host "2) Instalar Agente Wazuh"
    Write-Host "3) Registrar Equipamento no Domínio"
    Write-Host "4) Instalar Karspersky"
    Write-Host "0) Sair"
}

function Install-Zabbix {
    function SolicitarEntrada {
        param (
            [string]$mensagem
        )
        Write-Host $mensagem -ForegroundColor Yellow
        Read-Host
    }

    $tmpDir = $env:tmp
    $zabbixAgentUrl = "https://cdn.zabbix.com/zabbix/binaries/stable/6.4/6.4.14/zabbix_agent-6.4.14-windows-amd64-openssl.msi"
    $zabbixMsiFile = "$tmpDir\zabbix_agent.msi"

    # Check for an existing Zabbix installation
    if (Get-Service -Name Zabbix* -ErrorAction SilentlyContinue) {
        Write-Host "Previous Zabbix agent installation detected."
        Write-Host "Removing existing Zabbix agent installation..."

        # Uninstall existing Zabbix agent
        $uninstallCommand = "msiexec.exe /x `"$zabbixMsiFile`" /quiet"
        Invoke-Expression $uninstallCommand

        # Wait for the uninstallation to complete
        Start-Sleep -Seconds 10
    }

    # Prompting for user inputs
    $ZabbixServer = SolicitarEntrada "Digite o endereço IP ou hostname do servidor Zabbix"
    $Hostname = SolicitarEntrada "Digite o nome do host para este agente"

    # Proceed with the fresh installation
    Write-Host "Downloading Zabbix agent..."
    Invoke-WebRequest -Uri $zabbixAgentUrl -OutFile $zabbixMsiFile

    # Check if the download was successful
    if (-Not (Test-Path $zabbixMsiFile)) {
        Write-Error "Failed to download Zabbix agent. Please check the URL and try again."
        return
    }

    Write-Host "Installing Zabbix agent with detailed output..."
    Start-Process -FilePath msiexec.exe -ArgumentList "/i $zabbixMsiFile /quiet /log $tmpDir\zabbix_install_log.txt" -Wait

    # Check if installation was successful
    if (Test-Path "C:\Program Files\Zabbix Agent\zabbix_agentd.conf") {
        # Modify Configuration
        $configFile = "C:\Program Files\Zabbix Agent\zabbix_agentd.conf"

        Write-Host "Modifying Zabbix configuration file: $configFile"

        try {
            $configContent = Get-Content $configFile
            $configContent = $configContent -replace 'Server=127.0.0.1', "Server=$ZabbixServer"
            $configContent = $configContent -replace 'ServerActive=127.0.0.1', "ServerActive=$ZabbixServer"
            $configContent = $configContent -replace 'Hostname=Windows host', "Hostname=$Hostname"
            $configContent = $configContent -replace '# Hostname=', "Hostname=$Hostname"

            $configContent | Set-Content $configFile

            Write-Host "Zabbix configuration updated with hostname: $Hostname"
        } catch {
            Write-Error "Failed to modify Zabbix configuration: $_"
        }
    } else {
        Write-Warning "Zabbix agent installation might have failed. Please check logs."
    }

    # Check if the service is running
    Write-Host "Checking Zabbix service status..."
    try {
        $zabbixService = Get-Service -Name Zabbix* -ErrorAction Stop
        if ($zabbixService.Status -eq "Running") {
            Write-Host "Zabbix service is running."
        } else {
            Write-Warning "Zabbix service might not be running."
        }
    } catch {
        Write-Warning "Failed to check Zabbix service status. Please check manually."
    }
}

function Install-Wazuh {
    # Define the PowerShell commands to execute
    $cmd = @"
    try {
        $wazuhInstallerPath = `$env:TEMP\wazuh-agent.msi`
        Invoke-WebRequest -Uri https://packages.wazuh.com/4.x/windows/wazuh-agent-4.7.2-1.msi -OutFile $wazuhInstallerPath
        msiexec.exe /i $wazuhInstallerPath /quiet WAZUH_MANAGER='wazuh.commcenter.com.br' WAZUH_AGENT_GROUP='servidores_comm' WAZUH_REGISTRATION_SERVER='wazuh.commcenter.com.br'
        Start-Service -Name WazuhSvc
    } catch {
        Write-Error 'Wazuh installation failed: $($_)'
    }
"@
    # Start a new PowerShell instance and execute the specified commands
    Start-Process powershell.exe -ArgumentList "-NoProfile", "-Command", $cmd -Wait
}

function Register-ComputerInDomain {
    # Get Domain Administrator Credentials
    $domainCred = Get-Credential -Message "Enter domain administrator credentials:"

    # Get Domain Name
    $domainName = Read-Host -Prompt "Enter the domain name to join"

    # Attempt to Join the Domain
    try {
        Add-Computer -DomainName $domainName -Credential $domainCred -ErrorAction Stop
        Write-Host "Computer joined the domain $domainName successfully!"

        # Optional Restart Prompt
        $restartChoice = Read-Host -Prompt "A restart might be required. Restart now? (y/n)"
        if ($restartChoice.ToLower() -eq 'y') {
            Restart-Computer -Force
        }
    } catch {
        Write-Error "Failed to join the domain: $_"
    }
}

function Install-KasperskyEDR {
    # Network Share Details
    $networkSharePath = "\\10.130.2.10\kaspersky-stand-alone-install"
    $kesInstallerFilename = "KES 12.4 ( Instalador padrao para Lojas e Matriz).exe"
    $tempDir = $env:TEMP

    # Get Network Credentials
    $netCred = Get-Credential -Message "Enter credentials to connect to $networkSharePath"

    # Map Network Drive (temporarily)
    try {
        New-PSDrive -Name "KEDR" -PSProvider FileSystem -Root $networkSharePath -Credential $netCred -ErrorAction Stop
        $kesInstallerSource = Join-Path "KEDR:" $kesInstallerFilename
        $kesInstallerDestination = Join-Path $tempDir $kesInstallerFilename

        # Copy the Installer to Temp
        Write-Host "Copying Kaspersky installer to local temp directory..."
        Copy-Item $kesInstallerSource $kesInstallerDestination -ErrorAction Stop

        # Execute Kaspersky Installer from Temp
        Write-Host "Starting Kaspersky EDR installation..."
        Start-Process -FilePath $kesInstallerDestination -ArgumentList "/s /pSKIPPRODUCTCHECK=1 /pPRIVACYPOLICY=1" -Wait -ErrorAction Stop

    } catch {
        Write-Error "Error connecting to network share, copying installer, or executing installer: $_"
    } finally {
        # Optional: Remove the mapped drive
        if (Test-Path "KEDR:") { Remove-PSDrive -Name "KEDR" }
    }
}

do {
    Show-Menu
    $choice = Read-Host "Escolha uma opção"

    switch ($choice) {
        '1' { Install-Zabbix }
        '2' { Install-Wazuh }
        '3' { Register-ComputerInDomain }
        '4' { Install-KasperskyEDR }
        '0' { Write-Host "Exiting..." }
        default { Write-Host "Invalid choice. Please try again." }
    }
} while ($choice -ne '0')
