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
    Write-Host "*** Instalacao de Softwares ***"
    Write-Host "1) Instalar Agente Zabbix"
    Write-Host "2) Instalar Agente Wazuh"
    Write-Host "3) Registrar Equipamento no Dominio"
    Write-Host "4) Instalar Karspersky"
    Write-Host "0) Sair"
}

function Install-Zabbix {
    # Define variables
    $zabbixAgentUrl = "https://cdn.zabbix.com/zabbix/binaries/stable/6.4/6.4.14/zabbix_agent-6.4.14-windows-amd64-openssl.msi"
    $downloadPath = "$env:TEMP\zabbix_agent-6.4.14-windows-amd64-openssl.msi"
    $zabbixProxyIp = "10.130.3.201"
    $serviceName = "Zabbix Agent"
    $zabbixHostname = $env:COMPUTERNAME

    # Download Zabbix agent
    Write-Host "Downloading Zabbix agent from $zabbixAgentUrl..."
    Invoke-WebRequest -Uri $zabbixAgentUrl -OutFile $downloadPath

    # Install Zabbix agent with configuration
    Write-Host "Installing Zabbix agent..."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$downloadPath`"", "/qn", "SERVER=$zabbixProxyIp", "SERVERACTIVE=$zabbixProxyIp", "HOSTNAME=$zabbixHostname" -Wait

    # Check potential configuration file paths
    $configPaths = @(
        "C:\Program Files\Zabbix Agent\zabbix_agentd.conf",
        "C:\Program Files (x86)\Zabbix Agent\zabbix_agentd.conf",
        "C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf",
        "C:\Program Files (x86)\Zabbix Agent 2\zabbix_agent2.conf"
    )

    # Find the correct configuration file path
    $configPath = $null
    foreach ($path in $configPaths) {
        if (Test-Path -Path $path) {
            $configPath = $path
            break
        }
    }

    # Configure Zabbix agent
    Write-Host "Configuring Zabbix agent..."
    if ($configPath) {
        $configContent = Get-Content -Path $configPath

        # Update configuration with Zabbix proxy details
        $configContent = $configContent -replace "Server=.*", "Server=$zabbixProxyIp"
        $configContent = $configContent -replace "ServerActive=.*", "ServerActive=$zabbixProxyIp"
        $configContent = $configContent -replace "Hostname=.*", "Hostname=$zabbixHostname"

        # Save updated configuration
        $configContent | Set-Content -Path $configPath

        # Restart Zabbix agent service
        Write-Host "Restarting Zabbix agent service..."
        Restart-Service -Name $serviceName

        Write-Host "Zabbix agent installation and configuration completed successfully."
    } else {
        Write-Host "Configuration file not found in expected paths."
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
    $choice = Read-Host "Escolha uma opcao"

    switch ($choice) {
        '1' { Install-Zabbix }
        '2' { Install-Wazuh }
        '3' { Register-ComputerInDomain }
        '4' { Install-KasperskyEDR }
        '0' { Write-Host "Exiting..." }
        default { Write-Host "Invalid choice. Please try again." }
    }
} while ($choice -ne '0')
