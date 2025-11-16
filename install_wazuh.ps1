# Script de instalação do Wazuh Agent
# Versão: 4.14.0-1
# Manager: wazuh.vantix.com.br

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Instalação do Wazuh Agent" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se está sendo executado como Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERRO: Este script precisa ser executado como Administrador!" -ForegroundColor Red
    exit 1
}

# Definir variáveis
$wazuhInstallerUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.0-1.msi"
$installerPath = "$env:TEMP\wazuh-agent.msi"
$wazuhManager = "wazuh.vantix.com.br"

try {
    # Baixar o instalador
    Write-Host "[1/3] Baixando Wazuh Agent..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $wazuhInstallerUrl -OutFile $installerPath -ErrorAction Stop
    Write-Host "      Download concluído com sucesso!" -ForegroundColor Green
    
    # Instalar o Wazuh Agent
    Write-Host "[2/3] Instalando Wazuh Agent..." -ForegroundColor Yellow
    $installArgs = "/i `"$installerPath`" /q WAZUH_MANAGER='$wazuhManager'"
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Host "      Instalação concluída com sucesso!" -ForegroundColor Green
    } else {
        throw "Falha na instalação. Código de saída: $($process.ExitCode)"
    }
    
    # Iniciar o serviço
    Write-Host "[3/3] Iniciando serviço Wazuh..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    
    # Tentar iniciar o serviço usando NET START
    $startService = Start-Process -FilePath "net" -ArgumentList "start Wazuh" -Wait -PassThru -NoNewWindow
    
    if ($startService.ExitCode -eq 0) {
        Write-Host "      Serviço iniciado com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "      Aviso: Falha ao iniciar o serviço automaticamente." -ForegroundColor Yellow
        Write-Host "      Tente iniciar manualmente com: NET START Wazuh" -ForegroundColor Yellow
    }
    
    # Limpar arquivo temporário
    if (Test-Path $installerPath) {
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Instalação do Wazuh Agent concluída!" -ForegroundColor Green
    Write-Host "Manager: $wazuhManager" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    exit 0
}
catch {
    Write-Host ""
    Write-Host "ERRO durante a instalação: $_" -ForegroundColor Red
    
    # Limpar arquivo temporário em caso de erro
    if (Test-Path $installerPath) {
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    }
    
    exit 1
}

