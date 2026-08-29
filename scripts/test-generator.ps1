<#
.SYNOPSIS
    Testa as principais combinações de scripts/create-project.ps1.

.DESCRIPTION
    Gera projetos temporários para os 8 cenários de referência do PADRAO-AJF
    e roda scripts/validate-standard.ps1 em cada um (sempre).

    Com -Full, também roda:
    - pnpm install
    - lint
    - typecheck
    - test
    - build
    - docker compose config

    Com -DockerBuild (implica -Full), também builda as imagens
    Docker de cada app presente.

    Docker indisponível nunca é tratado como falha do padrão.
    Nesse caso, o resultado será WARN.

.EXAMPLE
    .\scripts\test-generator.ps1

.EXAMPLE
    .\scripts\test-generator.ps1 -Full

.EXAMPLE
    .\scripts\test-generator.ps1 -DockerBuild

.EXAMPLE
    .\scripts\test-generator.ps1 `
        -DockerBuild `
        -Scenario cenario04-web-api-postgres-embedded
#>

[CmdletBinding()]
param(
    [switch]$Full,

    [switch]$DockerBuild,

    [string]$OutputRoot,

    [string[]]$Scenario
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

if ($DockerBuild) {
    $Full = $true
}

$ScriptDir = $PSScriptRoot
$CreateProjectScript = Join-Path $ScriptDir 'create-project.ps1'
$ValidateScript = Join-Path $ScriptDir 'validate-standard.ps1'

if (-not (Test-Path -LiteralPath $CreateProjectScript)) {
    throw "create-project.ps1 não encontrado em: $CreateProjectScript"
}

if (-not (Test-Path -LiteralPath $ValidateScript)) {
    throw "validate-standard.ps1 não encontrado em: $ValidateScript"
}

if (-not $OutputRoot) {
    $OutputRoot = Join-Path $env:SystemDrive 'padrao-ajf-scenarios'
}

$allScenarios = @(
    [ordered]@{
        Name = 'cenario01-web-somente'
        Args = @{
            Web      = $true
            Database = 'none'
        }
    }

    [ordered]@{
        Name = 'cenario02-web-postgres-embedded'
        Args = @{
            Web          = $true
            Database     = 'postgresql'
            DatabaseMode = 'embedded'
        }
    }

    [ordered]@{
        Name = 'cenario03-web-postgres-external'
        Args = @{
            Web          = $true
            Database     = 'postgresql'
            DatabaseMode = 'external'
        }
    }

    [ordered]@{
        Name = 'cenario04-web-api-postgres-embedded'
        Args = @{
            Web          = $true
            Api          = $true
            Database     = 'postgresql'
            DatabaseMode = 'embedded'
        }
    }

    [ordered]@{
        Name = 'cenario05-web-api-supabase'
        Args = @{
            Web      = $true
            Api      = $true
            Database = 'supabase'
        }
    }

    [ordered]@{
        Name = 'cenario06-web-api-mobile-postgres'
        Args = @{
            Web      = $true
            Api      = $true
            Mobile   = $true
            Database = 'postgresql'
        }
    }

    [ordered]@{
        Name = 'cenario07-web-pwa'
        Args = @{
            Web      = $true
            Pwa      = $true
            Database = 'none'
        }
    }

    [ordered]@{
        Name = 'cenario08-api-somente-postgres'
        Args = @{
            Api      = $true
            Database = 'postgresql'
        }
    }
)

$scenarios = if ($Scenario) {
    $allScenarios | Where-Object {
        $Scenario -contains $_.Name
    }
}
else {
    $allScenarios
}

if (@($scenarios).Count -eq 0) {
    throw "Nenhum cenário encontrado para -Scenario $($Scenario -join ', ')."
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null

Write-Host ''
Write-Host '============================================================'
Write-Host ' PADRAO-AJF - TEST GENERATOR'
Write-Host '============================================================' -ForegroundColor Cyan

$mode = if ($DockerBuild) {
    'DockerBuild'
}
elseif ($Full) {
    'Full'
}
else {
    'Estrutural'
}

Write-Host "Cenários : $(@($scenarios).Count)"
Write-Host "Modo     : $mode"
Write-Host "Saída    : $OutputRoot"
Write-Host ''

$dockerCmd = Get-Command 'docker' -ErrorAction SilentlyContinue
$pnpmCmd = Get-Command 'pnpm' -ErrorAction SilentlyContinue

if ($Full -and -not $pnpmCmd) {
    Write-Host 'WARN: pnpm não encontrado. Etapas pnpm ficarão como WARN.' -ForegroundColor Yellow
}

if ($Full -and -not $dockerCmd) {
    Write-Host 'WARN: Docker não encontrado. Compose/DockerBuild ficarão como WARN.' -ForegroundColor Yellow
}

$rows = New-Object System.Collections.Generic.List[pscustomobject]

foreach ($sc in $scenarios) {
    Write-Host "------------------------------------------------------------"
    Write-Host "-> $($sc.Name)" -ForegroundColor Yellow

    $dest = Join-Path $OutputRoot $sc.Name

    if (Test-Path -LiteralPath $dest) {
        Remove-Item -LiteralPath $dest -Recurse -Force
    }

    $params = @{
        Name       = $sc.Name
        OutputPath = $dest
        GhcrOwner  = 'test-owner'
        Force      = $true
    }

    foreach ($k in $sc.Args.Keys) {
        $params[$k] = $sc.Args[$k]
    }

    $row = [ordered]@{
        Scenario      = $sc.Name
        Generated     = 'FAIL'
        Validate      = '-'
        PnpmInstall   = '-'
        Lint          = '-'
        Typecheck     = '-'
        Test          = '-'
        Build         = '-'
        ComposeConfig = '-'
        DockerBuild   = '-'
        Notes         = ''
    }

    try {
        & $CreateProjectScript @params 2>&1 | Out-Null
        $row.Generated = 'PASS'
    }
    catch {
        $row.Generated = 'FAIL'
        $row.Notes = $_.Exception.Message
    }

    if ($row.Generated -eq 'PASS') {
        & $ValidateScript -Path $dest *> $null
        $row.Validate = if ($LASTEXITCODE -eq 0) { 'PASS' } else { 'FAIL' }

        if ($Full) {
            Push-Location $dest

            try {
                if ($pnpmCmd) {
                    pnpm install 2>&1 | Out-Null
                    $row.PnpmInstall = if ($LASTEXITCODE -eq 0) { 'PASS' } else { 'FAIL' }
                }
                else {
                    $row.PnpmInstall = 'WARN (pnpm indisponível)'
                    $row.Lint = 'WARN (pnpm indisponível)'
                    $row.Typecheck = 'WARN (pnpm indisponível)'
                    $row.Test = 'WARN (pnpm indisponível)'
                    $row.Build = 'WARN (pnpm indisponível)'
                }

                if ($row.PnpmInstall -eq 'PASS') {
                    pnpm run lint 2>&1 | Out-Null
                    $row.Lint = if ($LASTEXITCODE -eq 0) { 'PASS' } else { 'FAIL' }

                    pnpm run typecheck 2>&1 | Out-Null
                    $row.Typecheck = if ($LASTEXITCODE -eq 0) { 'PASS' } else { 'FAIL' }

                    pnpm run test 2>&1 | Out-Null
                    $row.Test = if ($LASTEXITCODE -eq 0) { 'PASS' } else { 'FAIL' }

                    pnpm run build 2>&1 | Out-Null
                    $row.Build = if ($LASTEXITCODE -eq 0) { 'PASS' } else { 'FAIL' }
                }

                $composePath = Join-Path $dest 'docker-compose.yml'

                if (Test-Path $composePath) {
                    if ($dockerCmd) {
                        $tempEnvCreated = $false
                        $envPath = Join-Path $dest '.env'

                        if (-not (Test-Path $envPath)) {
                            @"
POSTGRES_USER=postgres
POSTGRES_PASSWORD=test-only
POSTGRES_DB=test
DATABASE_URL=postgres://postgres:test-only@db:5432/test
"@ | Out-File -FilePath $envPath -Encoding utf8 -NoNewline

                            $tempEnvCreated = $true
                        }

                        docker compose config 2>&1 | Out-Null
                        $row.ComposeConfig = if ($LASTEXITCODE -eq 0) { 'PASS' } else { 'FAIL' }

                        if ($DockerBuild) {
                            $buildOk = $true
                            $buildCount = 0

                            foreach ($df in @(
                                    'apps/web/Dockerfile',
                                    'apps/api/Dockerfile'
                                )) {
                                $dockerFilePath = Join-Path $dest $df

                                if (Test-Path $dockerFilePath) {
                                    $buildCount++

                                    $appName = Split-Path (Split-Path $df -Parent) -Leaf
                                    $imageTag = "$($sc.Name)-$appName`:test-generator"

                                    Write-Host "   Docker build: $appName"

                                    docker build -f $df -t $imageTag . 2>&1 | Out-Null

                                    if ($LASTEXITCODE -ne 0) {
                                        $buildOk = $false
                                    }

                                    docker rmi -f $imageTag 2>&1 | Out-Null
                                }
                            }

                            if ($buildCount -eq 0) {
                                $row.DockerBuild = 'n/a'
                            }
                            elseif ($buildOk) {
                                $row.DockerBuild = 'PASS'
                            }
                            else {
                                $row.DockerBuild = 'FAIL'
                            }
                        }
                        else {
                            $row.DockerBuild = 'skipped'
                        }

                        if ($tempEnvCreated -and (Test-Path $envPath)) {
                            Remove-Item -LiteralPath $envPath -Force -ErrorAction SilentlyContinue
                        }
                    }
                    else {
                        $row.ComposeConfig = 'WARN (docker indisponível)'

                        if ($DockerBuild) {
                            $row.DockerBuild = 'WARN (docker indisponível)'
                        }
                        else {
                            $row.DockerBuild = 'skipped'
                        }
                    }
                }
                else {
                    $row.ComposeConfig = 'n/a'
                    $row.DockerBuild = 'n/a'
                }
            }
            finally {
                Pop-Location
            }
        }
    }

    $rows.Add([pscustomobject]$row)
}

Write-Host ''
Write-Host '============================================================'
Write-Host ' RESULTADO'
Write-Host '============================================================' -ForegroundColor Cyan

$rows |
Format-Table -AutoSize |
Out-String -Width 240 |
Write-Host

function Test-RowHasFailure {
    param(
        [Parameter(Mandatory)]
        $Row
    )

    foreach ($prop in $Row.PSObject.Properties) {
        if ($prop.Name -in @('Scenario', 'Notes')) {
            continue
        }

        if ($prop.Value -eq 'FAIL') {
            return $true
        }
    }

    return $false
}

$failedRows = @(
    $rows |
    Where-Object {
        Test-RowHasFailure $_
    }
)

Write-Host ''

if ($failedRows.Count -eq 0) {
    Write-Host "Todos os $($rows.Count) cenários passaram em todas as etapas executadas." -ForegroundColor Green
    exit 0
}
else {
    Write-Host "$($failedRows.Count) de $($rows.Count) cenário(s) tiveram ao menos uma etapa com FAIL:" -ForegroundColor Red

    foreach ($failed in $failedRows) {
        Write-Host " - $($failed.Scenario)" -ForegroundColor Red
    }

    exit 1
}