<#
.SYNOPSIS
    Validação estática básica do PADRAO-AJF (não é um scanner de segurança completo).

.DESCRIPTION
    Procura problemas comuns antes do deploy: .env versionado, possíveis
    segredos, IPs privados hardcoded, arquivos essenciais ausentes,
    Dockerfile sem healthcheck, etc. Gera PASS / WARN / FAIL por checagem.

.EXAMPLE
    .\scripts\validate-standard.ps1
    .\scripts\validate-standard.ps1 -Path ..\gestao-frota
#>

[CmdletBinding()]
param(
    [string]$Path = '.'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path -LiteralPath $Path).Path
$results = New-Object System.Collections.Generic.List[pscustomobject]

# O PADRAO-AJF (fonte) tem placeholders {{...}} de propósito em templates/ e
# nos *-STANDARD.md — isso é esperado e não é validado como "esquecido". Um
# PROJETO GERADO não deve ter nenhum {{...}} sobrando (create-project.ps1
# substitui todos). Detectamos "isto é a fonte" pela presença de templates/
# + scripts/create-project.ps1 na raiz avaliada.
$isStandardRoot = (Test-Path (Join-Path $Root 'templates')) -and (Test-Path (Join-Path $Root 'scripts\create-project.ps1'))

function Add-Result {
    param([string]$Status, [string]$Check, [string]$Message)
    $results.Add([pscustomobject]@{ Status = $Status; Check = $Check; Message = $Message })
}

function Read-TextFileUtf8Local {
    # Get-Content, sem -Encoding explícito, no Windows PowerShell 5.1 detecta
    # mal arquivos UTF-8 sem BOM e corrompe acentos — lemos os bytes
    # manualmente e decodificamos como UTF-8.
    param([Parameter(Mandatory)][string]$Path)
    return [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($Path))
}

function Get-TrackedFiles {
    if (-not (Test-Path (Join-Path $Root '.git'))) { return $null }
    Push-Location $Root
    try {
        $tracked = git ls-files 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        return $tracked
    }
    finally {
        Pop-Location
    }
}

$excludeDirs = @('node_modules', '.git', '.next', 'dist', 'coverage', '.expo', '.pnpm-store')

function Get-ProjectFiles {
    Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object {
        $rel = $_.FullName.Substring($Root.Length).TrimStart('\', '/')
        $segments = $rel -split '[\\/]'
        -not ($segments | Where-Object { $excludeDirs -contains $_ })
    }
}

Write-Host ''
Write-Host "=== Validando: $Root ===" -ForegroundColor Cyan
Write-Host ''

$allFiles = @(Get-ProjectFiles)
$tracked = Get-TrackedFiles

# ----------------------------------------------------------------------------
# 1) .env real versionado
# ----------------------------------------------------------------------------
$envFiles = $allFiles | Where-Object { $_.Name -match '^\.env(\..+)?$' -and $_.Name -notmatch '\.example$' -and $_.Name -notlike '*.example' }
if (-not $envFiles) {
    Add-Result 'PASS' 'env-not-committed' 'Nenhum arquivo .env real encontrado.'
}
else {
    foreach ($f in $envFiles) {
        $rel = $f.FullName.Substring($Root.Length).TrimStart('\', '/')
        if ($null -ne $tracked -and ($tracked -contains $rel.Replace('\', '/'))) {
            Add-Result 'FAIL' 'env-not-committed' "$rel está versionado no Git (contém segredos reais?)."
        }
        else {
            Add-Result 'WARN' 'env-not-committed' "$rel existe localmente — confirme que está no .gitignore."
        }
    }
}

# ----------------------------------------------------------------------------
# 2) node_modules versionado
# ----------------------------------------------------------------------------
if ($null -ne $tracked) {
    $trackedNodeModules = $tracked | Where-Object { $_ -match '(^|/)node_modules/' }
    if ($trackedNodeModules) {
        Add-Result 'FAIL' 'node-modules-not-committed' 'node_modules está versionado no Git.'
    }
    else {
        Add-Result 'PASS' 'node-modules-not-committed' 'node_modules não está versionado.'
    }
}

# ----------------------------------------------------------------------------
# 3) possíveis segredos hardcoded
# ----------------------------------------------------------------------------
$secretPatterns = @(
    'AKIA[0-9A-Z]{16}',
    '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----',
    '(?i)(secret|password|senha|token|api[_-]?key)\s*[:=]\s*["'']?[A-Za-z0-9/+_\-]{16,}["'']?'
)
$placeholderHints = @('changeme', 'seu_usuario', 'seu-projeto', 'example', 'placeholder', 'xxxxxxxx', '__preencher', 'localhost')
$secretHits = New-Object System.Collections.Generic.List[string]

foreach ($f in $allFiles) {
    if ($f.Extension.ToLowerInvariant() -in @('.png', '.jpg', '.jpeg', '.ico', '.gif', '.woff', '.woff2', '.ttf')) { continue }
    if ($f.Name -match '\.example$' -or $f.Name -like '*.example') { continue }
    if ($f.Length -gt 2MB) { continue }
    $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    foreach ($pattern in $secretPatterns) {
        $regexMatches = [regex]::Matches($content, $pattern)
        foreach ($m in $regexMatches) {
            $lower = $m.Value.ToLowerInvariant()
            if ($placeholderHints | Where-Object { $lower -like "*$_*" }) { continue }
            $rel = $f.FullName.Substring($Root.Length).TrimStart('\', '/')
            $secretHits.Add("${rel}: '$($m.Value.Substring(0, [Math]::Min(40, $m.Value.Length)))...'")
        }
    }
}
if ($secretHits.Count -eq 0) {
    Add-Result 'PASS' 'no-obvious-secrets' 'Nenhum padrão óbvio de segredo encontrado (não substitui revisão manual).'
}
else {
    foreach ($hit in ($secretHits | Select-Object -Unique)) {
        Add-Result 'WARN' 'no-obvious-secrets' "Possível segredo: $hit"
    }
}

# ----------------------------------------------------------------------------
# 4) IPs privados hardcoded
# ----------------------------------------------------------------------------
$ipPattern = '\b(10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3})\b'
$ipHits = New-Object System.Collections.Generic.List[string]
foreach ($f in $allFiles) {
    if ($f.Extension.ToLowerInvariant() -in @('.png', '.jpg', '.jpeg', '.ico', '.gif', '.woff', '.woff2', '.ttf')) { continue }
    if ($f.Length -gt 2MB) { continue }
    $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    $regexMatches = [regex]::Matches($content, $ipPattern)
    if ($regexMatches.Count -gt 0) {
        $rel = $f.FullName.Substring($Root.Length).TrimStart('\', '/')
        foreach ($m in ($regexMatches | Select-Object -Unique -Property Value)) {
            $ipHits.Add("${rel}: $($m.Value)")
        }
    }
}
if ($ipHits.Count -eq 0) {
    Add-Result 'PASS' 'no-hardcoded-private-ip' 'Nenhum IP privado hardcoded encontrado.'
}
else {
    foreach ($hit in ($ipHits | Select-Object -Unique)) {
        Add-Result 'FAIL' 'no-hardcoded-private-ip' "IP privado hardcoded: $hit"
    }
}

# ----------------------------------------------------------------------------
# 5) Arquivos essenciais
# ----------------------------------------------------------------------------
function Test-EssentialFile {
    param([string]$RelPath, [string]$Status = 'WARN')
    $full = Join-Path $Root $RelPath
    if (Test-Path -LiteralPath $full) {
        Add-Result 'PASS' 'essential-files' "$RelPath presente."
    }
    else {
        Add-Result $Status 'essential-files' "$RelPath ausente."
    }
}

Test-EssentialFile 'README.md' 'FAIL'
Test-EssentialFile '.env.example' 'WARN'
Test-EssentialFile '.gitignore' 'FAIL'

$hasWeb = Test-Path (Join-Path $Root 'apps\web')
$hasApi = Test-Path (Join-Path $Root 'apps\api')

if ($hasWeb -or $hasApi) {
    Test-EssentialFile 'package.json' 'FAIL'
    Test-EssentialFile 'pnpm-workspace.yaml' 'WARN'
    Test-EssentialFile 'docker-compose.yml' 'WARN'

    $workflowsDir = Join-Path $Root '.github\workflows'
    if ((Test-Path $workflowsDir) -and (Get-ChildItem $workflowsDir -Filter '*.yml' -ErrorAction SilentlyContinue)) {
        Add-Result 'PASS' 'github-actions' '.github/workflows presente e com workflows.'
    }
    else {
        Add-Result 'WARN' 'github-actions' '.github/workflows ausente ou vazio.'
    }
}

if ($hasWeb) {
    Test-EssentialFile 'apps\web\Dockerfile' 'FAIL'
    Test-EssentialFile 'apps\web\.dockerignore' 'WARN'
}
if ($hasApi) {
    Test-EssentialFile 'apps\api\Dockerfile' 'FAIL'
    Test-EssentialFile 'apps\api\.dockerignore' 'WARN'
}

# ----------------------------------------------------------------------------
# 6) Healthcheck nos Dockerfiles
# ----------------------------------------------------------------------------
foreach ($df in @('apps\web\Dockerfile', 'apps\api\Dockerfile')) {
    $full = Join-Path $Root $df
    if (Test-Path -LiteralPath $full) {
        $content = Get-Content -LiteralPath $full -Raw
        if ($content -match 'HEALTHCHECK') {
            Add-Result 'PASS' 'dockerfile-healthcheck' "$df define HEALTHCHECK."
        }
        else {
            Add-Result 'FAIL' 'dockerfile-healthcheck' "$df não define HEALTHCHECK."
        }
    }
}

# ----------------------------------------------------------------------------
# 7) docker-compose.yml — checagens específicas do arquivo
# ----------------------------------------------------------------------------
$composePath = Join-Path $Root 'docker-compose.yml'
$composeExists = Test-Path -LiteralPath $composePath
$composeContent = if ($composeExists) { Read-TextFileUtf8Local -Path $composePath } else { '' }

if ($composeExists) {
    # localhost em produção
    if ($composeContent -match 'localhost') {
        Add-Result 'WARN' 'compose-no-localhost' 'docker-compose.yml referencia "localhost" — confirme que é só um valor padrão de conveniência local, não a configuração real de produção.'
    }
    else {
        Add-Result 'PASS' 'compose-no-localhost' 'docker-compose.yml não referencia "localhost".'
    }

    # senha/URL de banco hardcoded (não usando ${VAR})
    $composeLines = $composeContent -split "`r?`n"
    $hardcodedDb = @($composeLines | Where-Object { $_ -match '^\s*POSTGRES_PASSWORD:\s*(?!\$\{)\S' })
    if ($hardcodedDb.Count -gt 0) {
        Add-Result 'FAIL' 'no-hardcoded-db-password' 'docker-compose.yml define POSTGRES_PASSWORD com valor fixo em vez de ${POSTGRES_PASSWORD:?...}.'
    }
    else {
        Add-Result 'PASS' 'no-hardcoded-db-password' 'POSTGRES_PASSWORD não está hardcoded em docker-compose.yml.'
    }

    $hardcodedUrl = @($composeLines | Where-Object { $_ -match '^\s*DATABASE_URL:\s*(?!\$\{)\S' -and $_ -notmatch '\$\{' })
    if ($hardcodedUrl.Count -gt 0) {
        Add-Result 'FAIL' 'no-hardcoded-database-url' 'docker-compose.yml define DATABASE_URL com valor fixo em vez de variável (${...}).'
    }
    else {
        Add-Result 'PASS' 'no-hardcoded-database-url' 'DATABASE_URL não está hardcoded em docker-compose.yml.'
    }

    # tag "latest" como única referência de imagem — informativo, não bloqueia
    $latestImages = @($composeLines | Where-Object { $_ -match '^\s*image:\s*.+:latest\s*$' })
    if ($latestImages.Count -gt 0) {
        Add-Result 'WARN' 'image-not-only-latest' 'docker-compose.yml referencia a imagem só por ":latest" — normal para build local; produção deve fixar por SHA/versão (ver DEPLOY-STANDARD.md).'
    }

    # portas do host duplicadas
    $hostPorts = New-Object System.Collections.Generic.List[string]
    foreach ($line in $composeLines) {
        if ($line -match '^\s*-\s*"?(\d{2,5}):\d{2,5}"?\s*$') {
            $hostPorts.Add($Matches[1])
        }
    }
    $duplicatePorts = @($hostPorts | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
    if ($duplicatePorts.Count -gt 0) {
        Add-Result 'FAIL' 'no-duplicate-host-ports' "Porta(s) de host duplicada(s) em docker-compose.yml: $($duplicatePorts -join ', ')."
    }
    else {
        Add-Result 'PASS' 'no-duplicate-host-ports' 'Nenhuma porta de host duplicada em docker-compose.yml.'
    }

    # docker compose config (ferramenta externa, best-effort)
    $dockerCmd = Get-Command 'docker' -ErrorAction SilentlyContinue
    if ($null -eq $dockerCmd) {
        Add-Result 'WARN' 'compose-config-valid' 'Docker não disponível neste ambiente — docker-compose.yml não foi validado com "docker compose config".'
    }
    else {
        Push-Location $Root
        # Com $ErrorActionPreference = 'Stop', redirecionar stderr de um
        # executável nativo (2>&1) vira um erro TERMINANTE em vez de só
        # preencher $LASTEXITCODE — por isso relaxamos localmente aqui.
        $previousEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $configOutput = docker compose config 2>&1
            if ($LASTEXITCODE -eq 0) {
                Add-Result 'PASS' 'compose-config-valid' '"docker compose config" resolveu o arquivo sem erros.'
            }
            else {
                # Pode falhar por falta de variável obrigatória (ex.: sem .env
                # ainda) num projeto recém-gerado — isso é esperado, não é
                # motivo para reprovar o projeto inteiro.
                $firstLine = ($configOutput | Select-Object -First 1)
                Add-Result 'WARN' 'compose-config-valid' "`"docker compose config`" retornou erro (pode ser só falta de .env ainda): $firstLine"
            }
        }
        finally {
            $ErrorActionPreference = $previousEap
            Pop-Location
        }
    }
}
else {
    Add-Result 'WARN' 'compose-config-valid' 'docker-compose.yml ausente — checagens específicas do compose puladas.'
}

# ----------------------------------------------------------------------------
# 8) pnpm-workspace.yaml — validade básica
# ----------------------------------------------------------------------------
$workspaceYamlPath = Join-Path $Root 'pnpm-workspace.yaml'
if (Test-Path -LiteralPath $workspaceYamlPath) {
    $workspaceContent = Read-TextFileUtf8Local -Path $workspaceYamlPath
    if ($workspaceContent -match 'apps' -and $workspaceContent -match 'packages') {
        Add-Result 'PASS' 'pnpm-workspace-valid' 'pnpm-workspace.yaml referencia apps/ e packages/.'
    }
    else {
        Add-Result 'FAIL' 'pnpm-workspace-valid' 'pnpm-workspace.yaml existe mas não referencia apps/ e/ou packages/ — monorepo pode não resolver.'
    }
}
elseif ($hasWeb -or $hasApi) {
    Add-Result 'FAIL' 'pnpm-workspace-valid' 'pnpm-workspace.yaml ausente num projeto com apps/web ou apps/api (monorepo).'
}

# ----------------------------------------------------------------------------
# 9) package.json — todos válidos (JSON parseável)
# ----------------------------------------------------------------------------
$packageJsonFiles = @($allFiles | Where-Object { $_.Name -eq 'package.json' })
$invalidPackageJson = New-Object System.Collections.Generic.List[string]
foreach ($pkg in $packageJsonFiles) {
    $rel = $pkg.FullName.Substring($Root.Length).TrimStart('\', '/')
    try {
        $null = (Read-TextFileUtf8Local -Path $pkg.FullName) | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $invalidPackageJson.Add($rel)
    }
}
if ($packageJsonFiles.Count -eq 0) {
    Add-Result 'WARN' 'package-json-valid' 'Nenhum package.json encontrado.'
}
elseif ($invalidPackageJson.Count -eq 0) {
    Add-Result 'PASS' 'package-json-valid' "Todos os $($packageJsonFiles.Count) package.json encontrados são JSON válido."
}
else {
    foreach ($bad in $invalidPackageJson) {
        Add-Result 'FAIL' 'package-json-valid' "package.json inválido (não é JSON parseável): $bad"
    }
}

# ----------------------------------------------------------------------------
# 10) Placeholders {{...}} esquecidos — só se aplica a um PROJETO GERADO.
#     No PADRAO-AJF (fonte), templates/ e os *-STANDARD.md têm {{...}} de
#     propósito — ver nota no topo do script.
# ----------------------------------------------------------------------------
if ($isStandardRoot) {
    Add-Result 'PASS' 'no-leftover-placeholders' 'Validando o PADRAO-AJF (fonte) — placeholders {{...}} são esperados em templates/ e nos *-STANDARD.md; checagem pulada.'
}
else {
    $placeholderHitsList = New-Object System.Collections.Generic.List[string]
    foreach ($f in $allFiles) {
        if ($f.Extension.ToLowerInvariant() -in @('.png', '.jpg', '.jpeg', '.ico', '.gif', '.woff', '.woff2', '.ttf')) { continue }
        if ($f.Length -gt 2MB) { continue }
        $content = Read-TextFileUtf8Local -Path $f.FullName
        $phMatches = [regex]::Matches($content, '\{\{\s*[A-Z0-9_]+\s*\}\}')
        if ($phMatches.Count -gt 0) {
            $rel = $f.FullName.Substring($Root.Length).TrimStart('\', '/')
            $unique = ($phMatches | ForEach-Object { $_.Value } | Select-Object -Unique) -join ', '
            $placeholderHitsList.Add("${rel}: $unique")
        }
    }
    if ($placeholderHitsList.Count -eq 0) {
        Add-Result 'PASS' 'no-leftover-placeholders' 'Nenhum placeholder {{...}} esquecido.'
    }
    else {
        foreach ($hit in $placeholderHitsList) {
            Add-Result 'FAIL' 'no-leftover-placeholders' "Placeholder não substituído: $hit"
        }
    }
}

# ----------------------------------------------------------------------------
# 11) Dockerfile rodando como root
# ----------------------------------------------------------------------------
foreach ($df in @('apps\web\Dockerfile', 'apps\api\Dockerfile')) {
    $full = Join-Path $Root $df
    if (Test-Path -LiteralPath $full) {
        $content = Read-TextFileUtf8Local -Path $full
        $userLines = @([regex]::Matches($content, '(?im)^\s*USER\s+(\S+)\s*$') | ForEach-Object { $_.Groups[1].Value })
        $lastUser = if ($userLines.Count -gt 0) { $userLines[-1] } else { $null }
        if ($lastUser -and $lastUser -ne 'root' -and $lastUser -ne '0') {
            Add-Result 'PASS' 'dockerfile-non-root' "$df roda como usuário não-root (`"$lastUser`")."
        }
        else {
            Add-Result 'WARN' 'dockerfile-non-root' "$df não define um usuário não-root (USER) — a imagem final roda como root."
        }
    }
}

# ----------------------------------------------------------------------------
# 12) Schema/migrations ausentes quando PostgreSQL/Drizzle está selecionado
# ----------------------------------------------------------------------------
$dbPackagePath = Join-Path $Root 'packages\database'
if (Test-Path -LiteralPath $dbPackagePath) {
    $schemaFiles = @(Get-ChildItem -LiteralPath (Join-Path $dbPackagePath 'src\schema') -Filter '*.ts' -ErrorAction SilentlyContinue)
    if ($schemaFiles.Count -gt 0) {
        Add-Result 'PASS' 'database-schema-present' 'packages/database/src/schema tem definição de tabelas.'
    }
    else {
        Add-Result 'WARN' 'database-schema-present' 'packages/database/src/schema está vazio.'
    }
    if (-not (Test-Path (Join-Path $dbPackagePath 'migrations'))) {
        Add-Result 'WARN' 'database-migrations-dir' 'packages/database/migrations ausente — rode "pnpm run db:generate" após definir o schema.'
    }
}

# ----------------------------------------------------------------------------
# 13) NEXT_PUBLIC_*/EXPO_PUBLIC_* com nome sugerindo segredo
# ----------------------------------------------------------------------------
$suspiciousPublicNames = 'password|secret|service[_-]?role|token|database[_-]?url|private[_-]?key'
$publicSecretHits = New-Object System.Collections.Generic.List[string]
$filesToScanForPublicVars = @($allFiles | Where-Object { $_.Name -like '.env*' -or $_.Name -eq 'docker-compose.yml' })
foreach ($f in $filesToScanForPublicVars) {
    $content = Read-TextFileUtf8Local -Path $f.FullName
    $publicMatches = [regex]::Matches($content, "(?im)^(NEXT_PUBLIC_[A-Z0-9_]*($suspiciousPublicNames)[A-Z0-9_]*|EXPO_PUBLIC_[A-Z0-9_]*($suspiciousPublicNames)[A-Z0-9_]*)\s*[:=]")
    foreach ($m in $publicMatches) {
        $rel = $f.FullName.Substring($Root.Length).TrimStart('\', '/')
        $publicSecretHits.Add("${rel}: $($m.Groups[1].Value)")
    }
}
if ($publicSecretHits.Count -eq 0) {
    Add-Result 'PASS' 'no-secret-like-public-vars' 'Nenhuma variável NEXT_PUBLIC_*/EXPO_PUBLIC_* com nome sugerindo segredo.'
}
else {
    foreach ($hit in ($publicSecretHits | Select-Object -Unique)) {
        Add-Result 'FAIL' 'no-secret-like-public-vars' "Variável pública com nome sugerindo segredo (nunca exponha ao browser/app): $hit"
    }
}

# ----------------------------------------------------------------------------
# 14) Workflows do GitHub Actions — sanidade estrutural básica
# ----------------------------------------------------------------------------
$workflowsDirCheck = Join-Path $Root '.github\workflows'
if (Test-Path -LiteralPath $workflowsDirCheck) {
    foreach ($wf in (Get-ChildItem -LiteralPath $workflowsDirCheck -Filter '*.yml' -ErrorAction SilentlyContinue)) {
        $wfContent = Read-TextFileUtf8Local -Path $wf.FullName
        if ($wfContent -match '(?m)^jobs:') {
            Add-Result 'PASS' 'workflow-structure' "$($wf.Name) tem a chave 'jobs:'."
        }
        else {
            Add-Result 'WARN' 'workflow-structure' "$($wf.Name) não parece ter a chave 'jobs:' — confira manualmente."
        }
    }
}

# ============================================================================
# Relatório
# ============================================================================

Write-Host ''
foreach ($r in $results) {
    $color = switch ($r.Status) {
        'PASS' { 'Green' }
        'WARN' { 'Yellow' }
        'FAIL' { 'Red' }
        default { 'White' }
    }
    Write-Host ("[{0,-4}] {1,-28} {2}" -f $r.Status, $r.Check, $r.Message) -ForegroundColor $color
}

$passCount = @($results | Where-Object Status -eq 'PASS').Count
$warnCount = @($results | Where-Object Status -eq 'WARN').Count
$failCount = @($results | Where-Object Status -eq 'FAIL').Count

Write-Host ''
Write-Host "=== Resumo: $passCount PASS, $warnCount WARN, $failCount FAIL ===" -ForegroundColor Cyan
Write-Host ''

if ($failCount -gt 0) {
    exit 1
}
exit 0
