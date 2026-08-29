<#
.SYNOPSIS
    Gerador de projetos do PADRAO-AJF.

.DESCRIPTION
    Monta um novo projeto (Web e/ou API e/ou Mobile, com banco opcional)
    combinando os módulos de templates/ conforme as opções escolhidas.
    Não copia node_modules, não cria .env real e não copia credenciais.

.EXAMPLE
    .\scripts\create-project.ps1

.EXAMPLE
    .\scripts\create-project.ps1 -Name "gestao-frota" -Web -Api -Mobile -Database postgresql

.EXAMPLE
    .\scripts\create-project.ps1 -Name "site-institucional" -Web -Pwa -Database none

.EXAMPLE
    .\scripts\create-project.ps1 -Name "gestao-frota" -Web -Api -Mobile `
      -Database postgresql -WebPort 3100 -ApiPort 3101

.NOTES
    Mobile exige API separada (Mobile nunca acessa o banco diretamente — ver
    ARCHITECTURE-STANDARD.md). No modo interativo, API é habilitada
    automaticamente com um aviso; no modo por argumentos (-Mobile sem -Api),
    o script para com um erro claro em vez de mudar silenciosamente o que foi
    pedido.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Name,

    [switch]$Web,
    [switch]$Api,
    [switch]$Mobile,
    [switch]$Pwa,

    [ValidateSet('postgresql', 'supabase', 'none')]
    [string]$Database,

    [ValidateSet('embedded', 'external')]
    [string]$DatabaseMode,

    [switch]$Storage,
    [switch]$Auth,

    # Porta publicada no HOST (fora do container). A porta interna do
    # container continua fixa (3000/3001) — só o mapeamento host:container
    # muda, para evitar colisão quando há vários projetos no mesmo servidor.
    [ValidateRange(1, 65535)]
    [int]$WebPort = 3000,

    [ValidateRange(1, 65535)]
    [int]$ApiPort = 3001,

    # Publica a porta da API no host (fora da rede Docker). Só é necessário
    # quando algo FORA do docker-compose precisa falar com a API diretamente
    # (app mobile, integração externa). Se só o Web (no mesmo compose) usa a
    # API, ela pode ficar só na rede interna. Mobile força isto para $true.
    [switch]$PublicApi,

    [string]$GhcrOwner,
    [string]$DomainWeb,
    [string]$DomainApi,
    [string]$OutputPath,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================================
# Helpers
# ============================================================================

function ConvertTo-Slug {
    param([Parameter(Mandatory)][string]$Text)
    $normalized = $Text.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $normalized.ToCharArray()) {
        $category = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
        if ($category -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }
    $ascii = $sb.ToString().Normalize([System.Text.NormalizationForm]::FormC)
    $slug = $ascii.ToLowerInvariant()
    $slug = [regex]::Replace($slug, '[^a-z0-9]+', '-')
    $slug = $slug.Trim('-')
    $slug = [regex]::Replace($slug, '-{2,}', '-')
    return $slug
}

function Read-YesNo {
    param([Parameter(Mandatory)][string]$Prompt, [bool]$Default = $false)
    $suffix = if ($Default) { '[S/n]' } else { '[s/N]' }
    while ($true) {
        $answer = Read-Host "$Prompt $suffix"
        if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
        switch -Regex ($answer.Trim().ToLowerInvariant()) {
            '^(s|sim|y|yes)$' { return $true }
            '^(n|nao|não|no)$' { return $false }
            default { Write-Host '  Responda com S ou N.' -ForegroundColor Yellow }
        }
    }
}

function Read-DatabaseChoice {
    Write-Host 'Banco:'
    Write-Host '  1) PostgreSQL'
    Write-Host '  2) Supabase'
    Write-Host '  3) Nenhum'
    while ($true) {
        $choice = Read-Host 'Escolha [1-3] (padrão: 3)'
        switch ($choice.Trim()) {
            '1' { return 'postgresql' }
            '2' { return 'supabase' }
            '3' { return 'none' }
            '' { return 'none' }
            default { Write-Host '  Escolha 1, 2 ou 3.' -ForegroundColor Yellow }
        }
    }
}

function Read-DatabaseModeChoice {
    Write-Host 'PostgreSQL:'
    Write-Host '  1) Embutido (o projeto sobe seu próprio container de banco)'
    Write-Host '  2) Externo (banco já existe: compartilhado, gerenciado, VPS, etc.)'
    while ($true) {
        $choice = Read-Host 'Escolha [1-2] (padrão: 1)'
        switch ($choice.Trim()) {
            '1' { return 'embedded' }
            '2' { return 'external' }
            '' { return 'embedded' }
            default { Write-Host '  Escolha 1 ou 2.' -ForegroundColor Yellow }
        }
    }
}

function Read-PortPrompt {
    param([Parameter(Mandatory)][string]$Prompt, [Parameter(Mandatory)][int]$Default)
    while ($true) {
        $answer = Read-Host "$Prompt [$Default]"
        if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
        $parsed = 0
        if ([int]::TryParse($answer.Trim(), [ref]$parsed) -and $parsed -ge 1 -and $parsed -le 65535) {
            return $parsed
        }
        Write-Host '  Informe um número de porta válido (1-65535).' -ForegroundColor Yellow
    }
}

function Copy-TemplateTree {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [string[]]$ExcludeDirNames = @()
    )
    if (-not (Test-Path -LiteralPath $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }
    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        if ($_.PSIsContainer) {
            if ($ExcludeDirNames -contains $_.Name) { return }
            Copy-TemplateTree -Source $_.FullName -Destination (Join-Path $Destination $_.Name) -ExcludeDirNames $ExcludeDirNames
        }
        else {
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $Destination $_.Name) -Force
        }
    }
}

$script:TextExtensions = @('.ts', '.tsx', '.js', '.mjs', '.cjs', '.json', '.md', '.yml', '.yaml', '.css', '.txt', '')
$script:TextNames = @('.env.example', '.dockerignore', '.gitignore', '.gitkeep', 'Dockerfile')

function Test-IsTextFile {
    param([System.IO.FileInfo]$File)
    if ($script:TextNames -contains $File.Name) { return $true }
    if ($File.Name -like '.env*') { return $true }
    return $script:TextExtensions -contains $File.Extension.ToLowerInvariant()
}

function Expand-TokensInFile {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][hashtable]$Tokens)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $content = [System.Text.Encoding]::UTF8.GetString($bytes)
    $original = $content
    foreach ($key in $Tokens.Keys) {
        $content = $content.Replace($key, [string]$Tokens[$key])
    }
    if ($content -ne $original) {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($Path, $content, $utf8NoBom)
    }
}

$script:PruneDirNames = @('node_modules', '.git', '.next', '.expo', '.pnpm-store', 'dist', 'coverage')

function Expand-TokensInTree {
    # Não desce em node_modules/.git/.next/etc — evita: (a) milhares de
    # arquivos irrelevantes deixando isto extremamente lento quando o
    # destino já foi instalado/buildado antes (regeneração com -Force), e
    # (b) qualquer risco de reescrever algo dentro de uma dependência.
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][hashtable]$Tokens)
    if (-not (Test-Path -LiteralPath $Root)) { return }
    Get-ChildItem -LiteralPath $Root -Force | ForEach-Object {
        if ($_.PSIsContainer) {
            if ($script:PruneDirNames -contains $_.Name) { return }
            Expand-TokensInTree -Root $_.FullName -Tokens $Tokens
        }
        elseif (Test-IsTextFile -File $_) {
            Expand-TokensInFile -Path $_.FullName -Tokens $Tokens
        }
    }
}

function Write-TextFile {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Content)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Set-JsonFile {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Object)
    $json = $Object | ConvertTo-Json -Depth 30
    Write-TextFile -Path $Path -Content ($json + "`n")
}

function Read-TextFileUtf8 {
    # Get-Content, sem -Encoding explícito, no Windows PowerShell 5.1 detecta mal
    # arquivos UTF-8 sem BOM (como os que Write-TextFile gera) e corrompe acentos.
    # Lemos os bytes manualmente e decodificamos como UTF-8 para evitar isso.
    param([Parameter(Mandatory)][string]$Path)
    return [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($Path))
}

function Add-WorkspaceDependency {
    param([Parameter(Mandatory)][string]$PackageJsonPath, [Parameter(Mandatory)][string]$DependencyName)
    if (-not (Test-Path -LiteralPath $PackageJsonPath)) { return }
    $json = Read-TextFileUtf8 -Path $PackageJsonPath | ConvertFrom-Json
    if (-not (Get-Member -InputObject $json -Name 'dependencies' -MemberType NoteProperty)) {
        $json | Add-Member -MemberType NoteProperty -Name 'dependencies' -Value ([pscustomobject]@{})
    }
    $json.dependencies | Add-Member -MemberType NoteProperty -Name $DependencyName -Value 'workspace:*' -Force
    Set-JsonFile -Path $PackageJsonPath -Object $json
}

# ============================================================================
# Modo interativo x modo por argumentos
# ============================================================================

$explicitArgs = @('Web', 'Api', 'Mobile', 'Pwa', 'Database', 'Storage', 'Auth') |
    Where-Object { $PSBoundParameters.ContainsKey($_) }
$interactive = -not $Name -or $explicitArgs.Count -eq 0

if ($interactive) {
    Write-Host ''
    Write-Host '=== PADRAO-AJF — gerador de projetos ===' -ForegroundColor Cyan
    Write-Host ''
    if (-not $Name) { $Name = Read-Host 'Nome do projeto' }
    $Web = Read-YesNo -Prompt 'Deseja Web?' -Default $true
    $Api = Read-YesNo -Prompt 'Deseja API separada?' -Default $false
    $Mobile = Read-YesNo -Prompt 'Deseja App Mobile?' -Default $false

    if ($Mobile -and -not $Api) {
        Write-Host ''
        Write-Host 'Mobile exige uma API separada (Mobile nunca acessa o banco diretamente).' -ForegroundColor Yellow
        Write-Host 'Habilitando API automaticamente.' -ForegroundColor Yellow
        Write-Host ''
        $Api = $true
    }

    $Pwa = if ($Web) { Read-YesNo -Prompt 'Deseja PWA?' -Default $false } else { $false }
    $Database = Read-DatabaseChoice
    if ($Database -eq 'postgresql') {
        $DatabaseMode = Read-DatabaseModeChoice
    }
    $Storage = Read-YesNo -Prompt 'Deseja storage de arquivos?' -Default $false
    $Auth = Read-YesNo -Prompt 'Deseja autenticação?' -Default $false

    if ($Web) { $WebPort = Read-PortPrompt -Prompt 'Porta Web (host)' -Default $WebPort }
    if ($Api) { $ApiPort = Read-PortPrompt -Prompt 'Porta API (host)' -Default $ApiPort }

    if ($Api -and -not $Mobile) {
        $PublicApi = Read-YesNo -Prompt 'A API deve ficar acessível publicamente (fora da rede Docker — necessário para apps externos)?' -Default $false
    }
}

if (-not $Database) { $Database = 'none' }
if (-not $DatabaseMode) { $DatabaseMode = 'embedded' }
if ($Database -ne 'postgresql' -and $PSBoundParameters.ContainsKey('DatabaseMode')) {
    Write-Host 'Aviso: -DatabaseMode só se aplica a -Database postgresql — ignorado.' -ForegroundColor Yellow
}

if ([string]::IsNullOrWhiteSpace($Name)) {
    throw 'Nome do projeto é obrigatório.'
}
if (-not ($Web -or $Api -or $Mobile)) {
    throw 'Selecione ao menos um: -Web, -Api ou -Mobile.'
}
if ($Pwa -and -not $Web) {
    Write-Host 'Aviso: -Pwa ignorado (requer -Web).' -ForegroundColor Yellow
    $Pwa = $false
}

# Regra obrigatória: Mobile → API HTTPS → Banco. Mobile nunca acessa o banco
# diretamente. No modo interativo já resolvemos isso acima (auto-habilita a
# API); no modo por argumentos, paramos com erro em vez de mudar
# silenciosamente o que foi pedido — mais seguro para uso em automação/CI.
if ($Mobile -and -not $Api) {
    throw 'Projetos Mobile exigem uma API separada (Mobile nunca acessa o banco diretamente — ver ARCHITECTURE-STANDARD.md). Adicione -Api.'
}

# Mobile é sempre um consumidor externo à rede Docker do projeto — a API
# precisa necessariamente estar publicamente acessível para ele.
if ($Mobile) { $PublicApi = $true }

if ($Web -and $Api -and $PublicApi -and $WebPort -eq $ApiPort) {
    throw "WebPort e ApiPort não podem ser iguais quando ambos são publicados no host (WebPort=$WebPort, ApiPort=$ApiPort)."
}

$Slug = ConvertTo-Slug -Text $Name
if ([string]::IsNullOrWhiteSpace($Slug) -or $Slug -notmatch '^[a-z][a-z0-9-]*$') {
    throw "Nome de projeto inválido — não foi possível gerar um slug válido a partir de '$Name'."
}
$SlugUnderscore = $Slug -replace '-', '_'

# Owner padrão do GHCR deste PADRAO-AJF. Pode ser sobrescrito com -GhcrOwner.
if ([string]::IsNullOrWhiteSpace($GhcrOwner)) {
    $GhcrOwner = 'alefejaf'
}
$GhcrOwner = $GhcrOwner.Trim().ToLowerInvariant()
if (-not $DomainWeb) { $DomainWeb = "$Slug.exemplo.com.br" }
if (-not $DomainApi) { $DomainApi = "api-$Slug.exemplo.com.br" }

# ============================================================================
# Caminhos
# ============================================================================

$ScriptDir = $PSScriptRoot
$StandardRoot = Split-Path -Parent $ScriptDir
$WorkspaceRoot = Split-Path -Parent $StandardRoot
$TemplatesRoot = Join-Path $StandardRoot 'templates'

if (-not $OutputPath) {
    $OutputPath = Join-Path $WorkspaceRoot $Slug
}
$Dest = $OutputPath

if (Test-Path -LiteralPath $Dest) {
    $existing = Get-ChildItem -LiteralPath $Dest -Force -ErrorAction SilentlyContinue
    if ($existing -and -not $Force) {
        throw "O diretório de destino '$Dest' já existe e não está vazio. Use -Force para gerar mesmo assim (arquivos existentes com o mesmo nome serão sobrescritos, nada é apagado) ou escolha outro -OutputPath."
    }
}
New-Item -ItemType Directory -Path $Dest -Force | Out-Null

Write-Host ''
Write-Host "Gerando '$Slug' em: $Dest" -ForegroundColor Cyan
Write-Host ''

# ============================================================================
# Tokens
# ============================================================================

$Tokens = @{
    '{{PROJECT_NAME}}'            = $Name
    '{{PROJECT_SLUG}}'            = $Slug
    '{{PROJECT_SLUG_UNDERSCORE}}' = $SlugUnderscore
    '{{GHCR_OWNER}}'              = $GhcrOwner
    '{{DOMAIN_WEB}}'              = $DomainWeb
    '{{DOMAIN_API}}'              = $DomainApi
    '{{YEAR}}'                    = (Get-Date).Year.ToString()
    '{{PWA_REGISTER_IMPORT}}'     = ''
    '{{PWA_REGISTER_COMPONENT}}'  = ''
    '{{PWA_MANIFEST_FIELD}}'      = ''
}
if ($Pwa) {
    $Tokens['{{PWA_REGISTER_IMPORT}}'] = 'import { PwaRegister } from "@/components/pwa-register";'
    $Tokens['{{PWA_REGISTER_COMPONENT}}'] = '<PwaRegister />'
    $Tokens['{{PWA_MANIFEST_FIELD}}'] = 'manifest: "/manifest.json",'
}

# ============================================================================
# Estrutura base
# ============================================================================

New-Item -ItemType Directory -Path (Join-Path $Dest 'apps') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Dest 'packages') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Dest 'infra\docker') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Dest 'infra\scripts') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Dest '.github\workflows') -Force | Out-Null

# ============================================================================
# Módulos
# ============================================================================

Write-Host '-> Copiando módulos...'

# shared é sempre necessário (web/api/mobile validam com os mesmos schemas)
Copy-TemplateTree -Source (Join-Path $TemplatesRoot 'shared') -Destination (Join-Path $Dest 'packages\shared') -ExcludeDirNames @('api-client')

if ($Web) {
    Copy-TemplateTree -Source (Join-Path $TemplatesRoot 'web') -Destination (Join-Path $Dest 'apps\web') -ExcludeDirNames @('pwa')
    if ($Pwa) {
        Copy-TemplateTree -Source (Join-Path $TemplatesRoot 'web\pwa') -Destination (Join-Path $Dest 'apps\web')
    }
}

if ($Api) {
    Copy-TemplateTree -Source (Join-Path $TemplatesRoot 'api') -Destination (Join-Path $Dest 'apps\api')
}

if ($Mobile) {
    Copy-TemplateTree -Source (Join-Path $TemplatesRoot 'mobile') -Destination (Join-Path $Dest 'apps\mobile')
}

if ($Database -eq 'postgresql') {
    Copy-TemplateTree -Source (Join-Path $TemplatesRoot 'database') -Destination (Join-Path $Dest 'packages\database')
}

if ($Api -and ($Web -or $Mobile)) {
    Copy-TemplateTree -Source (Join-Path $TemplatesRoot 'shared\api-client') -Destination (Join-Path $Dest 'packages\api-client')
}

Write-Host '-> Aplicando nomes/placeholders...'
Expand-TokensInTree -Root $Dest -Tokens $Tokens

Write-Host '-> Conectando dependências entre pacotes...'
if ($Database -eq 'postgresql' -and $Api) {
    # API separada é quem fala com o banco.
    Add-WorkspaceDependency -PackageJsonPath (Join-Path $Dest 'apps\api\package.json') -DependencyName "@$Slug/database"
}
if ($Database -eq 'postgresql' -and $Web -and -not $Api) {
    # Sem API separada, o próprio Web (Server Actions/Route Handlers) usa
    # packages/database diretamente — ver DATABASE-STANDARD.md.
    Add-WorkspaceDependency -PackageJsonPath (Join-Path $Dest 'apps\web\package.json') -DependencyName "@$Slug/database"

    # apps/web/.env.example não tem DATABASE_URL por padrão (só existe
    # quando não há API) — adiciona para pnpm run dev funcionar sem Docker.
    $webEnvExamplePath = Join-Path $Dest 'apps\web\.env.example'
    if (Test-Path -LiteralPath $webEnvExamplePath) {
        $webEnvExtra = "`n# Necessário: sem apps/api, o próprio Web fala com packages/database.`nDATABASE_URL=postgres://postgres:changeme@localhost:5432/$SlugUnderscore`n"
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::AppendAllText($webEnvExamplePath, $webEnvExtra, $utf8NoBom)
    }
}
if ($Api -and $Web) {
    Add-WorkspaceDependency -PackageJsonPath (Join-Path $Dest 'apps\web\package.json') -DependencyName "@$Slug/api-client"
}
if ($Api -and $Mobile) {
    Add-WorkspaceDependency -PackageJsonPath (Join-Path $Dest 'apps\mobile\package.json') -DependencyName "@$Slug/api-client"
}

# ============================================================================
# Arquivos de raiz
# ============================================================================

Write-Host '-> Gerando arquivos de raiz (package.json, workspace, Docker, CI, README)...'

# --- pnpm-workspace.yaml ---
Write-TextFile -Path (Join-Path $Dest 'pnpm-workspace.yaml') -Content @"
packages:
  - "apps/*"
  - "packages/*"
"@

# --- package.json raiz ---
$rootScripts = [ordered]@{
    dev       = 'pnpm -r --if-present --parallel run dev'
    build     = 'pnpm -r --if-present run build'
    lint      = 'pnpm -r --if-present run lint'
    typecheck = 'pnpm -r --if-present run typecheck'
    test      = 'pnpm -r --if-present run test'
}
if ($Database -eq 'postgresql') {
    $rootScripts['db:generate'] = "pnpm --filter @$Slug/database run generate"
    $rootScripts['db:migrate'] = "pnpm --filter @$Slug/database run migrate"
    $rootScripts['db:check'] = "pnpm --filter @$Slug/database run check"
    $rootScripts['db:studio'] = "pnpm --filter @$Slug/database run studio"
}
$rootPkg = [ordered]@{
    name            = $Slug
    version         = '0.1.0'
    private         = $true
    description     = "$Name — gerado a partir do PADRAO-AJF."
    scripts         = $rootScripts
    devDependencies = [ordered]@{ typescript = '^6.0.3' }
    packageManager  = 'pnpm@9.15.0'
}
Set-JsonFile -Path (Join-Path $Dest 'package.json') -Object $rootPkg

# --- .gitignore ---
Write-TextFile -Path (Join-Path $Dest '.gitignore') -Content @"
node_modules/
**/node_modules/

.env
.env.local
.env.*.local
**/.env
**/.env.local
**/.env.*.local

.next/
**/.next/
dist/
**/dist/
coverage/
**/coverage/
.expo/
**/.expo/

*.tsbuildinfo
.DS_Store
Thumbs.db

.pnpm-store/
"@

# --- docker-compose.yml ---
#
# Decisões (ver DEPLOY-STANDARD.md / NAMING-STANDARD.md):
#  - Sem container_name: o nome do projeto compose (`name: $Slug`) já nomeia
#    os containers de forma previsível e sem conflito (`$Slug-web-1`, etc).
#    Serviços continuam endereçáveis por nome (`docker compose exec api ...`).
#  - Sem env_file: a configuração vem de variáveis de ambiente com valor
#    padrão (`${VAR:-default}`), lidas automaticamente do .env na raiz pelo
#    próprio `docker compose`. `docker compose config` funciona mesmo sem
#    nenhum .env real ainda existir. Só o que é realmente obrigatório
#    (senha do banco / DATABASE_URL externo) usa `${VAR:?mensagem}` e força
#    um erro claro, nunca um valor padrão inseguro.
#  - depends_on usa "condition: service_healthy" (não só a lista simples) —
#    depois de um restart do servidor, quem depende de um serviço espera ele
#    responder saudável antes de subir, não só "estar rodando".
$storageOwner = $null
if ($Storage) {
    if ($Api) { $storageOwner = 'api' } elseif ($Web) { $storageOwner = 'web' }
}
$dbEmbedded = ($Database -eq 'postgresql' -and $DatabaseMode -eq 'embedded')
$dbExternal = ($Database -eq 'postgresql' -and $DatabaseMode -eq 'external')

$lines = New-Object System.Collections.Generic.List[string]

function Add-ComposeEnvLine {
    param([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$Value)
    $lines.Add("      ${Key}: $Value")
}

function Add-ComposeDatabaseUrlLine {
    # Usado tanto pela API quanto (sem API) pelo próprio Web — quem quer que
    # seja o consumidor direto de packages/database precisa de DATABASE_URL
    # no ambiente do container, não só da dependência no package.json.
    if ($dbEmbedded) {
        # ${POSTGRES_PASSWORD:?...} repetido de propósito (mesma variável do
        # serviço "db") — a URL nunca deve montar com senha vazia mesmo que
        # a checagem obrigatória do "db" não rode primeiro.
        Add-ComposeEnvLine 'DATABASE_URL' ('postgres://${POSTGRES_USER:-postgres}:${POSTGRES_PASSWORD:?POSTGRES_PASSWORD obrigatorio - defina em .env}@db:5432/${POSTGRES_DB:-' + $SlugUnderscore + '}')
    }
    elseif ($dbExternal) {
        Add-ComposeEnvLine 'DATABASE_URL' '${DATABASE_URL:?DATABASE_URL obrigatorio (PostgreSQL externo) - defina em .env}'
    }
}

$lines.Add("name: $Slug")
$lines.Add('')
$lines.Add('services:')

if ($Web) {
    $lines.Add('  web:')
    $lines.Add('    build:')
    $lines.Add('      context: .')
    $lines.Add('      dockerfile: apps/web/Dockerfile')
    $lines.Add("    image: ghcr.io/$GhcrOwner/$Slug-web:latest")
    $lines.Add('    restart: unless-stopped')
    $lines.Add('    environment:')
    Add-ComposeEnvLine 'NODE_ENV' '${NODE_ENV:-production}'
    Add-ComposeEnvLine 'PORT' '"3000"'
    Add-ComposeEnvLine 'LOG_LEVEL' '${LOG_LEVEL:-info}'
    if ($Api) {
        # Server-side (Server Actions/Route Handlers/Server Components) fala
        # com a API pelo nome do serviço na rede Docker — nunca por
        # "localhost". Código que roda no BROWSER precisa de uma URL
        # pública — nunca "api:3001" (isso só existe dentro da rede Docker).
        Add-ComposeEnvLine 'API_INTERNAL_URL' 'http://api:3001'
        Add-ComposeEnvLine 'NEXT_PUBLIC_API_URL' ('${NEXT_PUBLIC_API_URL:-http://localhost:' + $ApiPort + '}')
    }
    elseif ($Database -eq 'postgresql') {
        # Sem API separada: o próprio Web fala direto com packages/database
        # (Server Actions/Route Handlers) — ver DATABASE-STANDARD.md.
        Add-ComposeDatabaseUrlLine
    }
    Add-ComposeEnvLine 'APP_VERSION' '${APP_VERSION:-0.0.0}'
    Add-ComposeEnvLine 'GIT_COMMIT_SHA' '${GIT_COMMIT_SHA:-local}'
    $lines.Add('    ports:')
    $lines.Add('      - "' + $WebPort + ':3000"')
    $lines.Add('    networks:')
    $lines.Add("      - $Slug-network")
    if ($storageOwner -eq 'web') {
        $lines.Add('    volumes:')
        $lines.Add("      - $Slug-uploads-data:/data/uploads")
    }
    if ($Api) {
        $lines.Add('    depends_on:')
        $lines.Add('      api:')
        $lines.Add('        condition: service_healthy')
    }
    elseif ($dbEmbedded) {
        $lines.Add('    depends_on:')
        $lines.Add('      db:')
        $lines.Add('        condition: service_healthy')
    }
    $lines.Add('')
}

if ($Api) {
    $lines.Add('  api:')
    $lines.Add('    build:')
    $lines.Add('      context: .')
    $lines.Add('      dockerfile: apps/api/Dockerfile')
    $lines.Add("    image: ghcr.io/$GhcrOwner/$Slug-api:latest")
    $lines.Add('    restart: unless-stopped')
    $lines.Add('    environment:')
    Add-ComposeEnvLine 'NODE_ENV' '${NODE_ENV:-production}'
    Add-ComposeEnvLine 'PORT' '"3001"'
    Add-ComposeEnvLine 'HOST' '"0.0.0.0"'
    Add-ComposeEnvLine 'LOG_LEVEL' '${LOG_LEVEL:-info}'
    Add-ComposeEnvLine 'CORS_ORIGIN' ('${CORS_ORIGIN:-http://localhost:' + $WebPort + '}')
    Add-ComposeEnvLine 'RATE_LIMIT_MAX' '${RATE_LIMIT_MAX:-100}'
    Add-ComposeEnvLine 'RATE_LIMIT_WINDOW' '${RATE_LIMIT_WINDOW:-1 minute}'
    Add-ComposeDatabaseUrlLine
    Add-ComposeEnvLine 'APP_VERSION' '${APP_VERSION:-0.0.0}'
    Add-ComposeEnvLine 'GIT_COMMIT_SHA' '${GIT_COMMIT_SHA:-local}'
    if ($PublicApi) {
        $lines.Add('    ports:')
        $lines.Add('      - "' + $ApiPort + ':3001"')
    }
    else {
        # Só o Web (no mesmo compose) fala com a API — fica só na rede
        # Docker interna, sem publicar porta no host. "expose" é só
        # documentação (containers na mesma rede já se enxergam), a
        # ausência de "ports" é o que de fato impede o acesso pelo host.
        $lines.Add('    expose:')
        $lines.Add('      - "3001"')
    }
    $lines.Add('    networks:')
    $lines.Add("      - $Slug-network")
    if ($storageOwner -eq 'api') {
        $lines.Add('    volumes:')
        $lines.Add("      - $Slug-uploads-data:/data/uploads")
    }
    if ($dbEmbedded) {
        $lines.Add('    depends_on:')
        $lines.Add('      db:')
        $lines.Add('        condition: service_healthy')
    }
    $lines.Add('')
}

if ($dbEmbedded) {
    $lines.Add('  db:')
    $lines.Add('    image: postgres:16-alpine')
    $lines.Add('    restart: unless-stopped')
    $lines.Add('    environment:')
    Add-ComposeEnvLine 'POSTGRES_USER' '${POSTGRES_USER:-postgres}'
    Add-ComposeEnvLine 'POSTGRES_PASSWORD' '${POSTGRES_PASSWORD:?POSTGRES_PASSWORD obrigatorio - defina em .env}'
    Add-ComposeEnvLine 'POSTGRES_DB' ('${POSTGRES_DB:-' + $SlugUnderscore + '}')
    $lines.Add('    volumes:')
    $lines.Add("      - $Slug-postgres-data:/var/lib/postgresql/data")
    $lines.Add('    networks:')
    $lines.Add("      - $Slug-network")
    $lines.Add('    healthcheck:')
    # O docker compose interpola "${VAR:-default}" em QUALQUER valor do
    # arquivo, incluindo dentro de "test:" — por isso usamos os MESMOS
    # nome/default do bloco "environment:" acima (nunca "postgres" fixo, e
    # nunca sem valor: uma referência sem ":-default" aqui resolveria para
    # string vazia sempre que POSTGRES_USER/POSTGRES_DB não estiverem no
    # .env, quebrando o healthcheck no caso mais comum — já aconteceu
    # durante os testes desta correção).
    $healthcheckTest = 'pg_isready -U \"${POSTGRES_USER:-postgres}\" -d \"${POSTGRES_DB:-' + $SlugUnderscore + '}\"'
    $lines.Add('      test: ["CMD-SHELL", "' + $healthcheckTest + '"]')
    $lines.Add('      interval: 10s')
    $lines.Add('      timeout: 5s')
    $lines.Add('      retries: 5')
    $lines.Add('    # Sem "ports:" — não exposto ao host. Acesso local via:')
    $lines.Add('    #   docker compose exec db psql -U "${POSTGRES_USER:-postgres}" "${POSTGRES_DB:-' + $SlugUnderscore + '}"')
    $lines.Add('')
}
elseif ($dbExternal) {
    $lines.Add('# Banco PostgreSQL "external": nenhum serviço "db" é criado aqui de')
    $lines.Add('# propósito — a API se conecta a um Postgres já existente (compartilhado,')
    $lines.Add('# gerenciado, Supabase, VPS, etc.) via DATABASE_URL. Ver DATABASE-STANDARD.md.')
    $lines.Add('')
}

$lines.Add('networks:')
$lines.Add("  $Slug-network:")
$lines.Add("    name: $Slug-network")

$hasVolumes = $dbEmbedded -or $storageOwner
if ($hasVolumes) {
    $lines.Add('')
    $lines.Add('volumes:')
    if ($dbEmbedded) {
        $lines.Add("  $Slug-postgres-data:")
        $lines.Add("    name: $Slug-postgres-data")
    }
    if ($storageOwner) {
        $lines.Add("  $Slug-uploads-data:")
        $lines.Add("    name: $Slug-uploads-data")
    }
}

Write-TextFile -Path (Join-Path $Dest 'docker-compose.yml') -Content ($lines -join "`n")

# --- .env.example raiz (usado SOMENTE pelo docker compose) ---
# Os .env.example de apps/packages ficam separados para desenvolvimento local.
$envSections = New-Object System.Collections.Generic.List[string]
$envSections.Add('# .env.example — copie para .env NA RAIZ do projeto (cp .env.example .env).')
$envSections.Add('# O `docker compose` carrega este arquivo automaticamente para preencher os')
$envSections.Add('# "${VAR}" do docker-compose.yml. NUNCA versione o .env real.')
$envSections.Add('#')
$envSections.Add('# Rodando sem Docker (`pnpm run dev`)? Cada app lê o SEU PRÓPRIO .env: copie')
$envSections.Add('# também apps/web/.env.example -> apps/web/.env.local, apps/api/.env.example')
$envSections.Add('# -> apps/api/.env, etc. Esses arquivos NÃO são agregados na raiz.')
$envSections.Add('')

if ($dbEmbedded) {
    $envSections.Add('# ==== docker compose — PostgreSQL (embedded) ====')
    $envSections.Add('POSTGRES_USER=postgres')
    $envSections.Add('# Obrigatório: o compose falha com uma mensagem clara se ficar em branco.')
    $envSections.Add('# Nunca use uma senha fraca/padrão em produção.')
    $envSections.Add('POSTGRES_PASSWORD=')
    $envSections.Add("POSTGRES_DB=$SlugUnderscore")
    $envSections.Add('')
}
elseif ($dbExternal) {
    $envSections.Add('# ==== docker compose — PostgreSQL (external) ====')
    $envSections.Add('# Nenhum container de banco é criado por este compose. Aponte para um')
    $envSections.Add('# PostgreSQL já existente (compartilhado, gerenciado, VPS, etc).')
    $envSections.Add('# Obrigatório: o compose falha com uma mensagem clara se ficar em branco.')
    $envSections.Add('DATABASE_URL=postgres://usuario:senha@host:5432/banco')
    $envSections.Add('')
}

if ($Web -or $Api) {
    $envSections.Add('# ==== docker compose — geral ====')
    $envSections.Add('NODE_ENV=production')
    $envSections.Add('LOG_LEVEL=info')
    if ($Api) {
        $envSections.Add("# Origem(ns) permitida(s) por CORS na API. Em produção, use o domínio HTTPS público do Web (${DomainWeb}), não localhost.")
        $envSections.Add("CORS_ORIGIN=http://localhost:$WebPort")
        $envSections.Add('RATE_LIMIT_MAX=100')
        $envSections.Add('RATE_LIMIT_WINDOW=1 minute')
    }
    if ($Web -and $Api) {
        $envSections.Add('# Usada pelo BROWSER (client-side) — precisa ser uma URL pública em produção,')
        $envSections.Add('# nunca "http://api:3001" (só existe dentro da rede Docker) nem localhost.')
        $envSections.Add("NEXT_PUBLIC_API_URL=http://localhost:$ApiPort")
    }
    $envSections.Add('# Preenchidos automaticamente no build da imagem (ver .github/workflows).')
    $envSections.Add('APP_VERSION=0.0.0')
    $envSections.Add('GIT_COMMIT_SHA=local')
    $envSections.Add('')
}

if ($Database -eq 'supabase') {
    $envSections.Add('# ==== Supabase ====')
    $envSections.Add('SUPABASE_URL=https://SEU-PROJETO.supabase.co')
    $envSections.Add('SUPABASE_ANON_KEY=')
    $envSections.Add('# Somente no servidor (API/Route Handlers) — NUNCA no client/browser.')
    $envSections.Add('SUPABASE_SERVICE_ROLE_KEY=')
    $envSections.Add('')
}

if ($Storage) {
    $envSections.Add('# ==== Storage (arquivos) ====')
    $envSections.Add('# Nunca salve arquivos importantes no filesystem efêmero do container.')
    $envSections.Add('# Use um volume persistente (local) ou um bucket externo (S3-compatible).')
    $envSections.Add('STORAGE_DRIVER=local')
    $envSections.Add('STORAGE_LOCAL_PATH=/data/uploads')
    $envSections.Add('# STORAGE_S3_BUCKET=')
    $envSections.Add('# STORAGE_S3_REGION=')
    $envSections.Add('# STORAGE_S3_ACCESS_KEY_ID=')
    $envSections.Add('# STORAGE_S3_SECRET_ACCESS_KEY=')
    $envSections.Add('')
}

if ($Auth) {
    $envSections.Add('# ==== Autenticação (ver AUTH-STANDARD.md) ====')
    $envSections.Add('# Escolha um provedor (Supabase Auth, Auth.js, etc). O backend SEMPRE valida')
    $envSections.Add('# a sessão/token e o papel do usuário — nunca confie somente no frontend.')
    $envSections.Add('AUTH_PROVIDER=')
    $envSections.Add('AUTH_SECRET=')
    $envSections.Add('')
}

Write-TextFile -Path (Join-Path $Dest '.env.example') -Content ($envSections -join "`n")

# --- GitHub Actions ---
$workflowsSource = Join-Path $StandardRoot 'infra-template\github-workflows'
Copy-TemplateTree -Source $workflowsSource -Destination (Join-Path $Dest '.github\workflows')
Expand-TokensInTree -Root (Join-Path $Dest '.github\workflows') -Tokens $Tokens

# --- scripts/validate-standard.ps1 (viaja com o projeto: uso local e no CI) ---
$validateStandardSrc = Join-Path $ScriptDir 'validate-standard.ps1'
if (Test-Path -LiteralPath $validateStandardSrc) {
    New-Item -ItemType Directory -Path (Join-Path $Dest 'scripts') -Force | Out-Null
    Copy-Item -LiteralPath $validateStandardSrc -Destination (Join-Path $Dest 'scripts\validate-standard.ps1') -Force
}

# --- Documentos padrão (copiados para o projeto ficar autocontido/portátil) ---
$standardDocs = @(
    'PROJECT-STANDARD.md', 'ARCHITECTURE-STANDARD.md', 'SECURITY-STANDARD.md',
    'DATABASE-STANDARD.md', 'DEPLOY-STANDARD.md', 'BACKUP-STANDARD.md',
    'NAMING-STANDARD.md', 'AUTH-STANDARD.md', 'TESTING-STANDARD.md',
    'CHECKLIST-PRODUCAO.md', 'MIGRATION-STANDARD.md'
)
foreach ($doc in $standardDocs) {
    $src = Join-Path $StandardRoot $doc
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $Dest $doc) -Force
    }
}
Expand-TokensInTree -Root $Dest -Tokens $Tokens

# --- README.md do projeto ---
$structureLines = New-Object System.Collections.Generic.List[string]
$structureLines.Add("$Slug/")
if ($Web) { $structureLines.Add('├── apps/web        # Next.js (App Router) + TypeScript') }
if ($Api) { $structureLines.Add('├── apps/api        # Fastify + TypeScript') }
if ($Mobile) { $structureLines.Add('├── apps/mobile     # Expo (React Native) + TypeScript') }
$structureLines.Add('├── packages/shared # types, schemas Zod e constantes compartilhadas')
if ($Database -eq 'postgresql') { $structureLines.Add('├── packages/database # schema + migrations (Drizzle ORM / PostgreSQL)') }
if ($Api -and ($Web -or $Mobile)) { $structureLines.Add('├── packages/api-client # cliente HTTP tipado para apps/api') }
$structureLines.Add('├── infra/          # scripts e assets de infraestrutura')
$structureLines.Add('├── scripts/validate-standard.ps1 # validação PASS/WARN/FAIL (usado no CI)')
$structureLines.Add('├── .github/workflows/ # CI + publicação de imagens no GHCR')
$structureLines.Add('├── docker-compose.yml')
$structureLines.Add('├── pnpm-workspace.yaml')
$structureLines.Add('└── package.json')

$archLines = New-Object System.Collections.Generic.List[string]
if ($Mobile -and $Api) { $archLines.Add('Mobile → HTTPS → API → Banco') }
if ($Web -and $Api) { $archLines.Add('Web → API → Banco') }
if ($Web -and -not $Api) { $archLines.Add('Web (Server Actions / Route Handlers) → Banco') }
if ($Api -and -not $Web -and -not $Mobile) { $archLines.Add('API → Banco') }

$readme = New-Object System.Collections.Generic.List[string]
$readme.Add("# $Name")
$readme.Add('')
$readme.Add('Projeto gerado a partir do **PADRAO-AJF**.')
$readme.Add('')
$readme.Add('## Objetivo')
$readme.Add('')
$readme.Add('_Descreva aqui o objetivo de negócio deste projeto._')
$readme.Add('')
$readme.Add('## Arquitetura')
$readme.Add('')
$readme.Add('```')
$readme.AddRange($archLines)
$readme.Add('```')
$readme.Add('')
$readme.Add('Ver [`ARCHITECTURE-STANDARD.md`](./ARCHITECTURE-STANDARD.md) e [`PROJECT-STANDARD.md`](./PROJECT-STANDARD.md)')
$readme.Add('(leia este último **antes** de alterar arquitetura/infraestrutura — inclui regras para IAs).')
$readme.Add('')
$readme.Add('## Tecnologias')
$readme.Add('')
if ($Web) { $readme.Add('- **Web**: Next.js + TypeScript' + $(if ($Pwa) { ' (PWA habilitado)' } else { '' })) }
if ($Api) { $readme.Add('- **API**: Fastify + TypeScript') }
if ($Mobile) { $readme.Add('- **Mobile**: Expo (React Native) + TypeScript') }
$readme.Add('- **Validação**: Zod (compartilhada via `packages/shared`)')
if ($Database -eq 'postgresql') { $readme.Add('- **Banco**: PostgreSQL + Drizzle ORM') }
if ($Database -eq 'supabase') { $readme.Add('- **Banco**: Supabase') }
$readme.Add('- **Monorepo**: pnpm workspaces')
$readme.Add('')
$readme.Add('## Estrutura')
$readme.Add('')
$readme.Add('```')
$readme.AddRange($structureLines)
$readme.Add('```')
$readme.Add('')
$readme.Add('## Instalação')
$readme.Add('')
$readme.Add('```bash')
$readme.Add('pnpm install')
$readme.Add('```')
$readme.Add('')
$readme.Add('## Variáveis de ambiente')
$readme.Add('')
$readme.Add('Duas cópias, dois propósitos:')
$readme.Add('')
$readme.Add('- **`.env` na raiz** (a partir de [`.env.example`](./.env.example)) — usado pelo `docker compose`.')
$readme.Add('- **`.env`/`.env.local` de cada app/pacote** — usado por `pnpm run dev` (sem Docker).')
$readme.Add('')
$readme.Add('Nunca versione um `.env` real. `docker compose config` funciona mesmo sem o `.env` da')
if ($dbEmbedded) {
    $readme.Add('raiz existir ainda — só falha (com mensagem clara) ao tentar subir os containers sem')
    $readme.Add('`POSTGRES_PASSWORD` definido.')
}
elseif ($dbExternal) {
    $readme.Add('raiz existir ainda — só falha (com mensagem clara) ao tentar subir os containers sem')
    $readme.Add('`DATABASE_URL` definido (banco externo).')
}
else {
    $readme.Add('raiz existir ainda.')
}
$readme.Add('')
$readme.Add('## Desenvolvimento')
$readme.Add('')
$readme.Add('```bash')
$readme.Add('pnpm run dev')
$readme.Add('```')
if ($Mobile) {
    $readme.Add('')
    $readme.Add("O app mobile roda separadamente (servidor Expo é interativo): `pnpm --filter $Slug-mobile run start`.")
}
$readme.Add('')
if ($Database -eq 'postgresql') {
    $readme.Add('## Banco de dados e migrations')
    $readme.Add('')
    $readme.Add('```bash')
    $readme.Add('pnpm run db:generate   # gera migration a partir de packages/database/src/schema')
    $readme.Add('pnpm run db:migrate    # aplica migrations pendentes')
    $readme.Add('pnpm run db:check      # verifica consistência do schema')
    $readme.Add('```')
    $readme.Add('')
    $readme.Add('Ver [`DATABASE-STANDARD.md`](./DATABASE-STANDARD.md). Migrations destrutivas exigem')
    $readme.Add('análise manual — nunca são aplicadas automaticamente.')
    $readme.Add('')
}
$readme.Add('## Docker')
$readme.Add('')
$readme.Add('```bash')
$readme.Add('cp .env.example .env   # ajuste os valores obrigatórios (ex.: POSTGRES_PASSWORD)')
$readme.Add('docker compose config  # valida o compose com as variáveis já resolvidas')
$readme.Add('docker compose build')
$readme.Add('docker compose up -d')
$readme.Add('docker compose ps')
$readme.Add('```')
$readme.Add('')
$portLines = New-Object System.Collections.Generic.List[string]
if ($Web) { $portLines.Add("- **Web**: host `$WebPort` -> container `3000`.") }
if ($Api) {
    if ($PublicApi) {
        $portLines.Add("- **API**: host `$ApiPort` -> container `3001` (publicada — Mobile e/ou consumidores externos precisam alcançá-la).")
    }
    else {
        $portLines.Add('- **API**: só na rede Docker interna (`expose`, sem `ports`) — nada fora do compose alcança a API diretamente. Ajuste com `-PublicApi` se isso mudar.')
    }
}
if ($portLines.Count -gt 0) {
    $readme.AddRange($portLines)
    $readme.Add('')
}
if ($Database -eq 'postgresql') {
    if ($dbEmbedded) {
        $readme.Add('Banco: **embedded** — este compose sobe o próprio container PostgreSQL (serviço `db`).')
    }
    else {
        $readme.Add('Banco: **external** — nenhum container de banco é criado; a API se conecta a um')
        $readme.Add('PostgreSQL já existente via `DATABASE_URL` (ver `.env.example`).')
    }
    $readme.Add('')
}
if ($storageOwner) {
    $readme.Add("Storage: volume persistente montado em `/data/uploads` no serviço **$storageOwner** (nunca no filesystem efêmero do container).")
    $readme.Add('')
}
$readme.Add('## Build e publicação (CI/CD)')
$readme.Add('')
$readme.Add('`git push` roda, nessa ordem: `scripts/validate-standard.ps1` (para o build se retornar')
$readme.Add('`FAIL`) → install → lint → typecheck → test → build (`.github/workflows/ci.yml`) → build e')
$readme.Add('push das imagens existentes para o GHCR, sempre com as tags `latest` **e** o SHA do commit')
$readme.Add('(`.github/workflows/docker-publish.yml`). Um `validate-standard` com `FAIL` também bloqueia')
$readme.Add('a publicação da imagem.')
$readme.Add('')
$readme.Add('Rode a mesma validação localmente a qualquer momento:')
$readme.Add('')
$readme.Add('```powershell')
$readme.Add('.\scripts\validate-standard.ps1')
$readme.Add('```')
$readme.Add('')
$readme.Add('## Deploy, rollback, backup e restore')
$readme.Add('')