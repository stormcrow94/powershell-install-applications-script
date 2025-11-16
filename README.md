# PowerShell Install Applications Script

Conjunto simples de scripts em PowerShell para instalar ou remover rapidamente agentes (Zabbix, Sophos e Wazuh) em estações Windows a partir de um menu interativo.

## Pré-requisitos
- Windows com PowerShell 5.1 ou superior
- Prompt elevado (o `main_installer.ps1` tenta se relançar como administrador, mas abrir o PowerShell como **Run as administrator** evita problemas)
- Conexão com a internet para que o instalador do Zabbix baixe o pacote oficial
- Política de execução liberada para o processo atual (`Set-ExecutionPolicy -Scope Process Bypass -Force`)

## Como executar
1. Baixe ou clone o repositório para a máquina que receberá os agentes.
2. Abra o PowerShell como administrador e navegue até a pasta baixada.
3. Execute `.\main_installer.ps1`.
4. Escolha a opção desejada no menu (instalar Zabbix, Sophos, Wazuh, remover Zabbix ou instalar tudo de uma vez) e aguarde o resultado exibido no console.

## Scripts incluídos
- `main_installer.ps1`: apresenta o menu, verifica privilégios e chama os demais scripts com controle de timeout.
- `install_zabbix_silent.ps1`: faz o download do agente oficial, configura servidor/proxy e inicia o serviço.
- `install_sophos.ps1`: baixa o `SophosSetup.exe`, detecta automaticamente se o host é servidor ou estação e executa a instalação silenciosa (`--quiet`), limpando o instalador ao final.
- `install_wazuh.ps1`: baixa o pacote MSI 4.14.0-1, instala apontando para `wazuh.vantix.com.br` e tenta iniciar o serviço `Wazuh`.
- `remove_zabbix.ps1`: remove serviços, pacotes e entradas de registro relacionadas ao Zabbix Agent.

## Personalização rápida
- Ajuste URLs, IPs ou parâmetros específicos (Zabbix, Sophos, Wazuh) diretamente em cada script dedicado.
- Substitua os endpoints/versões conforme sua organização mantenha os pacotes e, se necessário, adicione switches extras aos argumentos de instalação.
- Adicione novos itens ao menu incluindo o script correspondente e registrando-o no dicionário `$scripts` em `main_installer.ps1`.

## Dúvidas comuns
- **Erros de permissão**: garanta que o console esteja em modo administrador e que a política de execução esteja liberada para o processo.
- **Instaladores adicionais**: mantenha os arquivos `.ps1` na mesma pasta do `main_installer.ps1` para que os caminhos relativos funcionem sem ajustes.

