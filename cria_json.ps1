# Script aprimorado para mapear pastas, grupos de AD e usuários com saída em JSON
# Estrutura hierárquica com blocos "Grupos" e "Pastas"

# Importa o módulo do Active Directory (se necessário)
if (-not (Get-Module -Name ActiveDirectory)) {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
    }
    catch {
        Write-Error "Não foi possível carregar o módulo ActiveDirectory. Verifique se está instalado e se você tem permissões adequadas."
        exit
    }
}

# Função para obter os grupos de segurança com acesso a uma pasta
function Get-FolderACL {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        $Acl = Get-Acl -Path $Path -ErrorAction Stop
        $AccessRules = $Acl.Access | Where-Object { 
            $_.IsInherited -eq $false -and
            $_.IdentityReference -like "*\*" -and 
            $_.IdentityReference -notlike "NT AUTHORITY\*" -and 
            $_.IdentityReference -notlike "BUILTIN\*" -and 
            $_.IdentityReference -notlike "CREATOR OWNER" -and
            $_.IdentityReference -notlike "Everyone"
        }
        
        $GroupsList = @()
        foreach ($AccessRule in $AccessRules) {
            $Identity = $AccessRule.IdentityReference.Value
            $Domain, $Account = $Identity -split "\\"
            
            # Verifica se é um grupo diretamente usando Get-ADGroup
            $IsGroup = $false
            $GroupObject = $null
            
            try {
                # Tenta obter o grupo diretamente - método mais confiável
                $GroupObject = Get-ADGroup -Identity $Account -ErrorAction SilentlyContinue
                if ($GroupObject) {
                    $IsGroup = $true
                }
            }
            catch {
                Write-Verbose "Não é um grupo de AD ou não foi possível verificar: $Account"
                $IsGroup = $false
            }
            
            $GroupInfo = [PSCustomObject]@{
                Identity = $Identity
                Name = $Account
                Domain = $Domain
                Rights = $AccessRule.FileSystemRights
                AccessType = $AccessRule.AccessControlType
                IsGroup = $IsGroup
                GroupObject = $GroupObject
            }
            
            $GroupsList += $GroupInfo
        }
        
        return $GroupsList
    }
    catch {
        Write-Warning "Erro ao acessar ACL para $Path : $_"
        return @()
    }
}

# Modified function to get AD group members with disabled user detection
function Get-ADGroupMembersRecursive {
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupName,
        
        [Parameter(Mandatory = $false)]
        [System.Collections.Hashtable]$ProcessedUsers = @{},
        
        [Parameter(Mandatory = $false)]
        [System.Collections.Hashtable]$ProcessedGroups = @{},
        
        [Parameter(Mandatory = $false)]
        [string]$Path = ""
    )
    
    # If group already processed, return empty to avoid infinite loops
    if ($ProcessedGroups.ContainsKey($GroupName)) {
        return @()
    }
    
    # Mark group as processed
    $ProcessedGroups[$GroupName] = $true
    
    try {
        $Users = @()
        $NestedGroups = @()
        $Group = Get-ADGroup -Identity $GroupName -ErrorAction Stop
        $GroupDisplayName = $Group.Name
        
        # Update group path
        $CurrentPath = if ([string]::IsNullOrEmpty($Path)) { $GroupDisplayName } else { "$Path > $GroupDisplayName" }
        
        $Members = Get-ADGroupMember -Identity $Group -ErrorAction Stop
        
        foreach ($Member in $Members) {
            if ($Member.objectClass -eq "user") {
                $UserKey = $Member.SamAccountName
                
                # Check if user already processed
                if (-not $ProcessedUsers.ContainsKey($UserKey)) {
                    $UserInfo = Get-ADUser -Identity $Member.distinguishedName -Properties DisplayName, mail, department, Enabled -ErrorAction SilentlyContinue
                    
                    $UserObject = [PSCustomObject]@{
                        SamAccountName = $UserInfo.SamAccountName
                        DisplayName = $UserInfo.DisplayName
                        Email = $UserInfo.mail
                        Department = $UserInfo.department
                        SourceGroup = $CurrentPath
                        Enabled = $UserInfo.Enabled
                    }
                    
                    $Users += $UserObject
                    $ProcessedUsers[$UserKey] = $true
                }
            }
            elseif ($Member.objectClass -eq "group") {
                # Add nested group to list
                $NestedGroup = Get-ADGroup -Identity $Member.distinguishedName -Properties Description
                $NestedGroups += [PSCustomObject]@{
                    Name = $NestedGroup.Name
                    Description = $NestedGroup.Description
                    DistinguishedName = $NestedGroup.DistinguishedName
                }
                
                # Process nested groups recursively
                $NestedUsers = Get-ADGroupMembersRecursive -GroupName $Member.distinguishedName -ProcessedUsers $ProcessedUsers -ProcessedGroups $ProcessedGroups -Path $CurrentPath
                $Users += $NestedUsers
            }
        }
        
        return [PSCustomObject]@{
            Users = $Users
            NestedGroups = $NestedGroups
        }
    }
    catch {
        Write-Warning "Error processing group $GroupName : $_"
        return [PSCustomObject]@{
            Users = @()
            NestedGroups = @()
        }
    }
}

# Função principal para mapear pastas, grupos e usuários em formato JSON
function Invoke-FolderPermissionMappingJson {
    param (
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 3,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputJSON = "$(Get-Location)\FolderPermissionMapping_$(Get-Date -Format 'yyyyMMdd_HHmmss').json",
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeInherited = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$Detailed = $false
    )
    
    # Valida o caminho raiz
    if (-not (Test-Path -Path $RootPath)) {
        Write-Error "O caminho raiz '$RootPath' não existe ou não está acessível."
        return
    }
    
    Write-Host "Iniciando mapeamento de permissões de pasta em formato JSON..." -ForegroundColor Cyan
    Write-Host "Pasta raiz: $RootPath" -ForegroundColor Cyan
    Write-Host "Profundidade máxima: $MaxDepth" -ForegroundColor Cyan
    Write-Host "Arquivo de saída: $OutputJSON" -ForegroundColor Cyan
    
    $ProcessedFolders = 0
    $ProcessedGroups = 0
    $ProcessedUsers = 0
    $DisabledUsers = 0
    $StartTime = Get-Date
    
    # Estruturas para armazenar dados estruturados
    $FoldersData = @{}
    $GroupsData = @{}
    
    # Dicionário para rastrear grupos já processados
    $ProcessedGroupsTracker = @{}
    
    # Função recursiva para processar pastas
    function Process-Folder {
        param (
            [Parameter(Mandatory = $true)]
            [string]$FolderPath,
            
            [Parameter(Mandatory = $false)]
            [int]$CurrentDepth = 0,
            
            [Parameter(Mandatory = $false)]
            [string]$ParentPath = ""
        )
        
        $RelativePath = $FolderPath.Replace($RootPath, "").TrimStart("\")
        if ([string]::IsNullOrEmpty($RelativePath)) {
            $RelativePath = "\"
        }
        
        Write-Progress -Activity "Mapeando permissões de pasta" -Status "Processando: $RelativePath" -PercentComplete -1
        $script:ProcessedFolders++
        
        # Estrutura para esta pasta
        $FolderInfo = [ordered]@{
            FullPath = $FolderPath
            RelativePath = $RelativePath
            Depth = $CurrentDepth
            ParentPath = $ParentPath
            Groups = @()
            Subfolders = @()
        }
        
        # Obtém os grupos com acesso a esta pasta
        $FolderGroups = Get-FolderACL -Path $FolderPath
        $FolderGroupsFiltered = $FolderGroups | Where-Object { $_.IsGroup -eq $true }
        
        if ($Detailed) {
            Write-Host "Pasta: $RelativePath - Encontrados $($FolderGroupsFiltered.Count) grupos de AD" -ForegroundColor Yellow
        }
        
        foreach ($Group in $FolderGroupsFiltered) {
            $script:ProcessedGroups++
            
            # Adiciona grupo à pasta
            $FolderInfo.Groups += [ordered]@{
                Name = $Group.Name
                Identity = $Group.Identity
                Rights = $Group.Rights.ToString()
                AccessType = $Group.AccessType.ToString()
            }
            
            # Se o grupo ainda não foi processado, obtenha seus membros
            if (-not $ProcessedGroupsTracker.ContainsKey($Group.Name)) {
                # Processa o grupo
                $ProcessedGroupsTracker[$Group.Name] = $true
                
                # Obtém membros e grupos aninhados
                $GroupResult = Get-ADGroupMembersRecursive -GroupName $Group.Name
                $GroupMembers = $GroupResult.Users
                $NestedGroups = $GroupResult.NestedGroups
                
                # Cria estrutura do grupo
                $GroupInfo = [ordered]@{
                    Name = $Group.Name
                    Domain = $Group.Domain
                    Users = @()
                    NestedGroups = @()
                    DisabledUsersCount = 0
                }
                
                # Adiciona usuários
                foreach ($Member in $GroupMembers) {
                    $script:ProcessedUsers++
                    
                    # Conta usuários desabilitados
                    if ($Member.Enabled -eq $false) {
                        $script:DisabledUsers++
                        $GroupInfo.DisabledUsersCount++
                    }
                    
                    $GroupInfo.Users += [ordered]@{
                        SamAccountName = $Member.SamAccountName
                        DisplayName = $Member.DisplayName
                        Email = $Member.Email
                        Department = $Member.Department
                        MembershipPath = $Member.SourceGroup
                        Enabled = $Member.Enabled
                        Status = if ($Member.Enabled -eq $true) { "Ativo" } else { "Desativado" }
                    }
                }
                
                # Adiciona grupos aninhados
                foreach ($NestedGroup in $NestedGroups) {
                    $GroupInfo.NestedGroups += [ordered]@{
                        Name = $NestedGroup.Name
                        Description = $NestedGroup.Description
                        DistinguishedName = $NestedGroup.DistinguishedName
                    }
                }
                
                # Armazena informações do grupo
                $GroupsData[$Group.Name] = $GroupInfo
                
                if ($Detailed) {
                    Write-Host "  Grupo: $($Group.Name) - $($GroupMembers.Count) membros encontrados, $($GroupInfo.DisabledUsersCount) desativados" -ForegroundColor Gray
                }
            }
        }
        
        # Armazena informações da pasta
        $FoldersData[$RelativePath] = $FolderInfo
        
        # Processa subpastas se não atingiu a profundidade máxima
        if ($CurrentDepth -lt $MaxDepth) {
            try {
                $Subfolders = Get-ChildItem -Path $FolderPath -Directory -ErrorAction SilentlyContinue
                foreach ($Subfolder in $Subfolders) {
                    # Adiciona à lista de subpastas
                    $FolderInfo.Subfolders += $Subfolder.Name
                    
                    # Processa recursivamente
                    Process-Folder -FolderPath $Subfolder.FullName -CurrentDepth ($CurrentDepth + 1) -ParentPath $RelativePath
                }
            }
            catch {
                Write-Warning "Erro ao listar subpastas de $FolderPath : $_"
            }
        }
    }
    
    # Inicia o processamento
    Process-Folder -FolderPath $RootPath
    
    # Cria estrutura final de JSON
    $ResultJSON = [ordered]@{
        Metadata = [ordered]@{
            GeneratedOn = (Get-Date).ToString()
            RootPath = $RootPath
            MaxDepth = $MaxDepth
        }
        Summary = [ordered]@{
            FoldersProcessed = $ProcessedFolders
            GroupsIdentified = $ProcessedGroups
            UsersProcessed = $ProcessedUsers
            DisabledUsers = $DisabledUsers
            ActiveUsers = ($ProcessedUsers - $DisabledUsers)
        }
        Folders = $FoldersData
        Groups = $GroupsData
    }
    
    # Exporta para JSON
    try {
        $ResultJSON | ConvertTo-Json -Depth 10 -Compress:$false | Set-Content -Path $OutputJSON -Encoding UTF8
        Write-Host "`nExportado com sucesso para: $OutputJSON" -ForegroundColor Green
    }
    catch {
        Write-Error "Erro ao exportar para JSON: $_"
    }
    
    # Exibe estatísticas
    $EndTime = Get-Date
    $Duration = $EndTime - $StartTime
    Write-Host "`nResumo do mapeamento:" -ForegroundColor Cyan
    Write-Host "- Pastas processadas: $ProcessedFolders" -ForegroundColor White
    Write-Host "- Grupos identificados: $ProcessedGroups" -ForegroundColor White
    Write-Host "- Usuários processados: $ProcessedUsers" -ForegroundColor White
    Write-Host "  - Usuários ativos: $($ProcessedUsers - $DisabledUsers)" -ForegroundColor White
    Write-Host "  - Usuários desativados: $DisabledUsers" -ForegroundColor Yellow
    Write-Host "- Tempo total: $($Duration.Minutes) minutos e $($Duration.Seconds) segundos" -ForegroundColor White
    
    # Retorna um objeto com os resultados
    return [PSCustomObject]@{
        JSON = $ResultJSON
        Statistics = [PSCustomObject]@{
            FoldersProcessed = $ProcessedFolders
            GroupsIdentified = $ProcessedGroups
            UsersProcessed = $ProcessedUsers
            DisabledUsers = $DisabledUsers
            ActiveUsers = ($ProcessedUsers - $DisabledUsers)
            Duration = $Duration
        }
    }
}

# Execução do script
Write-Host "=== Configuração do Mapeamento em JSON ===" -ForegroundColor Cyan
$RootPathInput = Read-Host "Digite o caminho da pasta raiz (ex: \\servidor\share)"

# Adiciona verificação para garantir que o caminho existe
if (-not (Test-Path -Path $RootPathInput)) {
    Write-Error "O caminho '$RootPathInput' não existe ou não está acessível. Script será encerrado."
    exit
}

$OutputFileInput = Read-Host "Digite o caminho para o arquivo JSON (ex: C:\temp\mapeamento_ad.json)"
$MaxDepthInput = Read-Host "Digite a profundidade máxima de pastas (Pode botar 1, por favor)"
$DetailedInput = Read-Host "Exibir informações detalhadas durante o processamernto? (Aqui Joga S)"

# Valida e define valores padrão se necessário
if ([string]::IsNullOrWhiteSpace($RootPathInput)) {
    Write-Error "Caminho da pasta raiz é obrigatório. Script será encerrado."
    exit
}

if ([string]::IsNullOrWhiteSpace($OutputFileInput)) {
    $OutputFileInput = "$(Get-Location)\FolderPermissionMapping_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    Write-Host "Usando caminho padrão para saída: $OutputFileInput" -ForegroundColor Yellow
}

# Validação e conversão para inteiro do parâmetro MaxDepth
$MaxDepthValue = 3
if (-not [string]::IsNullOrWhiteSpace($MaxDepthInput)) {
    try {
        $MaxDepthValue = [int]$MaxDepthInput
    }
    catch {
        Write-Host "Valor de profundidade inválido. Usando o padrão: 3" -ForegroundColor Yellow
        $MaxDepthValue = 3
    }
}

# Configura parâmetros
$DetailedOutput = $false
if (-not [string]::IsNullOrWhiteSpace($DetailedInput) -and $DetailedInput.ToUpper() -eq "S") {
    $DetailedOutput = $true
    Write-Host "Exibindo informações detalhadas durante o processamento" -ForegroundColor Yellow
}

# Executa o mapeamento com saída JSON
Invoke-FolderPermissionMappingJson `
    -RootPath $RootPathInput `
    -OutputJSON $OutputFileInput `
    -MaxDepth $MaxDepthValue `
    -Detailed:$DetailedOutput
