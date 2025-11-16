# Script de instalação do Sophos Endpoint Protection
# Suporta detecção automática de Servidor vs Workstation

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Instalação do Sophos Endpoint" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se está sendo executado como Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERRO: Este script precisa ser executado como Administrador!" -ForegroundColor Red
    exit 1
}

# Definir variáveis
$sophosInstallerUrl = "https://api.stn100gru.ctr.sophos.com/api/download/6872c0211ed96b33ffab2d1c31ce3754/SophosSetup.exe"
$installerPath = "$env:TEMP\SophosSetup.exe"

try {
    # Detectar tipo de sistema operacional
    Write-Host "[INFO] Detectando tipo de sistema operacional..." -ForegroundColor Yellow
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $productType = $osInfo.ProductType
    
    # ProductType: 1 = Workstation, 2 = Domain Controller, 3 = Server
    $isServer = $productType -ne 1
    
    if ($isServer) {
        Write-Host "       Sistema detectado: SERVIDOR" -ForegroundColor Cyan
        $systemType = "Servidor"
    } else {
        Write-Host "       Sistema detectado: ESTAÇÃO DE TRABALHO" -ForegroundColor Cyan
        $systemType = "Workstation"
    }
    
    # Baixar o instalador
    Write-Host ""
    Write-Host "[1/2] Baixando Sophos Endpoint Setup..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $sophosInstallerUrl -OutFile $installerPath -ErrorAction Stop
    Write-Host "      Download concluído com sucesso!" -ForegroundColor Green
    
    # Instalar o Sophos
    Write-Host "[2/2] Instalando Sophos Endpoint..." -ForegroundColor Yellow
    Write-Host "      Aguarde, este processo pode levar alguns minutos..." -ForegroundColor Yellow
    
    # Parâmetros para instalação silenciosa
    # --quiet: Instalação silenciosa sem interface gráfica
    $installArgs = "--quiet"
    
    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Host "      Instalação concluída com sucesso!" -ForegroundColor Green
    } elseif ($process.ExitCode -eq 3010) {
        Write-Host "      Instalação concluída! Reinicialização necessária." -ForegroundColor Yellow
    } else {
        throw "Falha na instalação. Código de saída: $($process.ExitCode)"
    }
    
    # Limpar arquivo temporário
    if (Test-Path $installerPath) {
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Instalação do Sophos Endpoint concluída!" -ForegroundColor Green
    Write-Host "Tipo de sistema: $systemType" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # Verificar se reinicialização é necessária
    if ($process.ExitCode -eq 3010) {
        Write-Host ""
        Write-Host "ATENÇÃO: É necessário reiniciar o sistema para concluir a instalação." -ForegroundColor Yellow
    }
    
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

