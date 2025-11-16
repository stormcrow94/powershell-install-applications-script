# Script de Instalação Silenciosa do Zabbix Agent
# Baseado no script original com dados do proxy

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
    Write-Host "Este script requer privilégios de administrador para continuar." -ForegroundColor Yellow
    Start-Process PowerShell.exe -Verb runAs -ArgumentList "-NoExit", "-File", "`"$PSCommandPath`""
    Exit
}

# Variáveis de configuração (baseadas no script original)
$zabbixAgentUrl = "https://cdn.zabbix.com/zabbix/binaries/stable/6.4/6.4.14/zabbix_agent-6.4.14-windows-amd64-openssl.msi"
$downloadPath = "$env:TEMP\zabbix_agent-6.4.14-windows-amd64-openssl.msi"
$zabbixProxyIp = "10.130.3.201"
$zabbixServerIp = "10.130.3.201"
$serviceName = "Zabbix Agent"

# Obter hostname automaticamente
# Primeiro tenta COMPUTERNAME, depois Hostname via WMI, e por último via .NET
if ($env:COMPUTERNAME) {
    $zabbixHostname = $env:COMPUTERNAME
} elseif (Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue) {
    $zabbixHostname = (Get-WmiObject -Class Win32_ComputerSystem).Name
} else {
    $zabbixHostname = [System.Net.Dns]::GetHostName()
}

# Validação do hostname
if ([string]::IsNullOrWhiteSpace($zabbixHostname)) {
    Write-Error "Não foi possível determinar o hostname do computador. Abortando instalação."
    exit 1
}

# Caminhos possíveis do arquivo de configuração
$configPaths = @(
    "C:\Program Files\Zabbix Agent\zabbix_agentd.conf",
    "C:\Program Files (x86)\Zabbix Agent\zabbix_agentd.conf",
    "C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf",
    "C:\Program Files (x86)\Zabbix Agent 2\zabbix_agent2.conf"
)

# Função para verificar se o Zabbix já está instalado
function Test-ZabbixInstalled {
    $zabbixService = Get-Service -Name "Zabbix*" -ErrorAction SilentlyContinue
    if ($zabbixService) {
        return $true
    }
    return $false
}

# Função para remover instalação anterior
function Remove-ZabbixPrevious {
    Write-Host "Instalação anterior do Zabbix detectada. Removendo..." -ForegroundColor Yellow
    
    # Parar serviços do Zabbix
    $services = Get-Service -Name "Zabbix*" -ErrorAction SilentlyContinue
    foreach ($service in $services) {
        if ($service.Status -eq "Running") {
            Stop-Service -Name $service.Name -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Desinstalar pacotes do Zabbix
    $packages = Get-Package -Name "*Zabbix*" -ErrorAction SilentlyContinue
    foreach ($package in $packages) {
        try {
            Uninstall-Package -Name $package.Name -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "Pacote $($package.Name) removido." -ForegroundColor Green
        } catch {
            Write-Warning "Não foi possível remover o pacote $($package.Name): $_"
        }
    }
    
    Start-Sleep -Seconds 2
}

# Função principal de instalação
function Install-ZabbixSilent {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Instalação Silenciosa do Zabbix Agent" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Configurações detectadas:" -ForegroundColor White
    Write-Host "  - Servidor Zabbix: $zabbixServerIp" -ForegroundColor Gray
    Write-Host "  - Proxy Zabbix: $zabbixProxyIp" -ForegroundColor Gray
    Write-Host "  - Hostname: $zabbixHostname" -ForegroundColor Green
    Write-Host ""
    
    # Verificar se já está instalado
    if (Test-ZabbixInstalled) {
        Write-Host "Zabbix já está instalado. Removendo instalação anterior..." -ForegroundColor Yellow
        Remove-ZabbixPrevious
        Start-Sleep -Seconds 3
    }
    
    # Download do agente Zabbix
    Write-Host "[1/5] Baixando o agente Zabbix..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $zabbixAgentUrl -OutFile $downloadPath -UseBasicParsing -ErrorAction Stop
        Write-Host "Download concluído com sucesso." -ForegroundColor Green
    } catch {
        Write-Error "Erro ao baixar o agente Zabbix: $_"
        return $false
    }
    
    # Instalação silenciosa
    Write-Host "[2/5] Instalando o agente Zabbix (modo silencioso)..." -ForegroundColor Yellow
    try {
        $installArgs = @(
            "/i",
            "`"$downloadPath`"",
            "/qn",                                    # Modo silencioso (sem interface)
            "/norestart",                             # Não reiniciar
            "SERVER=$zabbixServerIp",                 # IP do servidor Zabbix
            "SERVERACTIVE=$zabbixProxyIp",            # IP do proxy Zabbix
            "HOSTNAME=$zabbixHostname"                # Hostname do computador
        )
        
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
            Write-Host "Instalação concluída com sucesso." -ForegroundColor Green
        } else {
            Write-Warning "Instalação concluída com código de saída: $($process.ExitCode)"
        }
    } catch {
        Write-Error "Erro durante a instalação: $_"
        return $false
    }
    
    Start-Sleep -Seconds 3
    
    # Localizar arquivo de configuração
    Write-Host "[3/5] Localizando arquivo de configuração..." -ForegroundColor Yellow
    $configPath = $null
    foreach ($path in $configPaths) {
        if (Test-Path -Path $path) {
            $configPath = $path
            Write-Host "Arquivo de configuração encontrado: $configPath" -ForegroundColor Green
            break
        }
    }
    
    if (-not $configPath) {
        Write-Warning "Arquivo de configuração não encontrado nos caminhos esperados."
        Write-Host "Tentando localizar manualmente..." -ForegroundColor Yellow
        
        # Buscar em todos os diretórios do Zabbix
        $zabbixDirs = @(
            "C:\Program Files\Zabbix*",
            "C:\Program Files (x86)\Zabbix*"
        )
        
        foreach ($dirPattern in $zabbixDirs) {
            $dirs = Get-ChildItem -Path $dirPattern -Directory -ErrorAction SilentlyContinue
            foreach ($dir in $dirs) {
                $possibleConfig = Join-Path $dir.FullName "*agent*.conf"
                $found = Get-ChildItem -Path $possibleConfig -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) {
                    $configPath = $found.FullName
                    Write-Host "Arquivo de configuração encontrado: $configPath" -ForegroundColor Green
                    break
                }
            }
            if ($configPath) { break }
        }
    }
    
    # Configurar o agente Zabbix
    if ($configPath) {
        Write-Host "[4/5] Configurando o agente Zabbix..." -ForegroundColor Yellow
        try {
            $configContent = Get-Content -Path $configPath -Raw
            
            # Atualizar configurações
            $configContent = $configContent -replace "(?m)^Server=.*", "Server=$zabbixServerIp"
            $configContent = $configContent -replace "(?m)^ServerActive=.*", "ServerActive=$zabbixProxyIp"
            $configContent = $configContent -replace "(?m)^Hostname=.*", "Hostname=$zabbixHostname"
            
            # Remover comentários das linhas se necessário
            $configContent = $configContent -replace "(?m)^#\s*Server=.*", "Server=$zabbixServerIp"
            $configContent = $configContent -replace "(?m)^#\s*ServerActive=.*", "ServerActive=$zabbixProxyIp"
            $configContent = $configContent -replace "(?m)^#\s*Hostname=.*", "Hostname=$zabbixHostname"
            
            # Salvar configuração
            Set-Content -Path $configPath -Value $configContent -NoNewline
            
            Write-Host "Configuração atualizada:" -ForegroundColor Green
            Write-Host "  - Server: $zabbixServerIp" -ForegroundColor Gray
            Write-Host "  - ServerActive: $zabbixProxyIp" -ForegroundColor Gray
            Write-Host "  - Hostname: $zabbixHostname" -ForegroundColor Gray
        } catch {
            Write-Error "Erro ao configurar o agente Zabbix: $_"
            return $false
        }
    } else {
        Write-Warning "Não foi possível localizar o arquivo de configuração. A configuração pode precisar ser feita manualmente."
    }
    
    # Iniciar/Reiniciar serviço
    Write-Host "[5/5] Iniciando serviço do Zabbix Agent..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    
    try {
        $zabbixService = Get-Service -Name "Zabbix*" -ErrorAction Stop
        
        if ($zabbixService.Status -ne "Running") {
            Start-Service -Name $zabbixService.Name -ErrorAction Stop
            Write-Host "Serviço iniciado com sucesso." -ForegroundColor Green
        } else {
            Restart-Service -Name $zabbixService.Name -ErrorAction Stop
            Write-Host "Serviço reiniciado com sucesso." -ForegroundColor Green
        }
        
        Start-Sleep -Seconds 2
        $finalStatus = (Get-Service -Name $zabbixService.Name).Status
        Write-Host "Status do serviço: $finalStatus" -ForegroundColor $(if ($finalStatus -eq "Running") { "Green" } else { "Yellow" })
    } catch {
        Write-Warning "Não foi possível iniciar o serviço automaticamente. Verifique manualmente: $_"
    }
    
    # Limpeza
    Write-Host ""
    Write-Host "Limpando arquivos temporários..." -ForegroundColor Yellow
    if (Test-Path $downloadPath) {
        Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Instalação concluída!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Resumo da instalação:" -ForegroundColor White
    Write-Host "  - Servidor Zabbix: $zabbixServerIp" -ForegroundColor Gray
    Write-Host "  - Proxy Zabbix: $zabbixProxyIp" -ForegroundColor Gray
    Write-Host "  - Hostname: $zabbixHostname" -ForegroundColor Gray
    Write-Host ""
    
    return $true
}

# Executar instalação
try {
    $result = Install-ZabbixSilent
    if ($result) {
        exit 0
    } else {
        exit 1
    }
} catch {
    Write-Error "Erro fatal durante a instalação: $_"
    exit 1
}

