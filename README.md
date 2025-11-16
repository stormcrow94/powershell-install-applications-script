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
- `install_sophos.ps1` e `install_wazuh.ps1`: placeholders prontos para receber os comandos dos respectivos instaladores (adicione os passos internos antes de usar as opções 2 ou 3 do menu).
- `remove_zabbix.ps1`: remove serviços, pacotes e entradas de registro relacionadas ao Zabbix Agent.

## Personalização rápida
- Ajuste URLs, IPs ou parâmetros do Zabbix editando `install_zabbix_silent.ps1`.
- Complete os scripts de Sophos e Wazuh conforme o instalador fornecido pela sua organização.
- Adicione novos itens ao menu incluindo o script correspondente e registrando-o no dicionário `$scripts` em `main_installer.ps1`.

## Dúvidas comuns
- **Erros de permissão**: garanta que o console esteja em modo administrador e que a política de execução esteja liberada para o processo.
- **Instaladores adicionais**: mantenha os arquivos `.ps1` na mesma pasta do `main_installer.ps1` para que os caminhos relativos funcionem sem ajustes.

