# Explorador de Permissões de Pastas

Sistema para análise e visualização de permissões de pastas, grupos do Active Directory e usuários.

## Descrição

Este sistema é composto por duas partes principais:

1. **Script PowerShell para coleta de dados** - Percorre as pastas de um caminho especificado, coleta informações sobre permissões, grupos do Active Directory e seus usuários, exportando tudo para um arquivo JSON.
2. **Aplicação Web em Python** - Interface gráfica para visualização e análise dos dados coletados, permitindo explorar facilmente a relação entre pastas, grupos e usuários.

## Requisitos do Sistema

### Para o script PowerShell:

- Windows Server ou Windows Desktop com PowerShell 5.1+
- Módulo Active Directory PowerShell
- Permissões adequadas para ler ACLs das pastas e consultar o Active Directory

### Para a aplicação web:

- Python 3.6+
- Pacotes Python listados em `requirements.txt`

## Instalação

1. Clone este repositório ou baixe os arquivos para sua máquina.
2. Instale as dependências Python:

   ```
   pip install -r requirements.txt
   ```

## Como Usar

### Parte 1: Coletando dados com o PowerShell

1. Execute o script PowerShell `script_json_detalhado.ps1`.
2. Informe o caminho da pasta raiz que deseja analisar.
3. Especifique o local para salvar o arquivo JSON de saída.
4. Defina a profundidade máxima de subpastas a serem analisadas.
5. Aguarde o término da execução - o script irá mapear todas as pastas, identificar grupos com permissões e listar usuários de cada grupo.

```powershell
.\script_json_detalhado.ps1
```

### Parte 2: Visualizando os dados na interface web

1. Certifique-se de que o arquivo JSON gerado pelo script PowerShell esteja na mesma pasta que o script Python.
2. Atualize o nome do arquivo JSON na linha 12 do arquivo `consome_json.py` se necessário.
3. Execute o aplicativo Python:

```bash
python consome_json.py
```

4. Acesse a interface web através do navegador em `http://localhost:8050`

## Funcionalidades

### Script PowerShell:

- Análise recursiva de permissões em pastas com profundidade configurável
- Identificação de grupos do Active Directory com acesso às pastas
- Listagem de usuários em cada grupo, incluindo grupos aninhados
- Detecção de usuários desativados
- Exportação estruturada em formato JSON

### Interface Web:

- Visualização organizada por abas: Pastas e Grupos
- Exploração de permissões por pasta, mostrando grupos com acesso
- Exploração de grupos, mostrando todos os usuários membros
- Identificação visual de diferentes níveis de permissão (leitura, modificação, controle total)
- Identificação clara de usuários desativados

## Contribuições

Contribuições são bem-vindas! Sinta-se à vontade para abrir issues ou enviar pull requests.
