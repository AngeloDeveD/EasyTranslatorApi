param(
    [string]$OutputDir = "backups",
    [int]$Keep = 14
)

$ErrorActionPreference = "Stop"

function Fail($message) {
    Write-Host "[ERROR] $message" -ForegroundColor Red
    exit 1
}

function Info($message) {
    Write-Host "[INFO] $message" -ForegroundColor Cyan
}

function Ok($message) {
    Write-Host "[OK] $message" -ForegroundColor Green
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Fail "Docker не найден в PATH."
}

try {
    docker compose version *> $null
} catch {
    Fail "Docker Compose недоступен."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$backupRoot = Join-Path $projectRoot $OutputDir
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $backupRoot $timestamp
$dbDumpName = "postgres.dump"
$dbDumpContainerPath = "/tmp/easytranslator_${timestamp}.dump"
$dbDumpLocalPath = Join-Path $backupDir $dbDumpName
$uploadsPath = Join-Path $projectRoot "uploads"
$uploadsArchivePath = Join-Path $backupDir "uploads.zip"
$manifestPath = Join-Path $backupDir "manifest.txt"

New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

Push-Location $projectRoot
try {
    Info "Проверка контейнера PostgreSQL..."
    docker compose ps db | Out-Host
    if ($LASTEXITCODE -ne 0) { Fail "Не удалось получить статус контейнера db." }

    Info "Создание pg_dump внутри контейнера db..."
    docker compose exec -T db sh -c "pg_dump -U `"`$POSTGRES_USER`" -d `"`$POSTGRES_DB`" -Fc -f '$dbDumpContainerPath'"
    if ($LASTEXITCODE -ne 0) { Fail "pg_dump завершился с ошибкой." }

    Info "Копирование дампа PostgreSQL в $dbDumpLocalPath..."
    docker compose cp "db:$dbDumpContainerPath" "$dbDumpLocalPath"
    if ($LASTEXITCODE -ne 0) { Fail "Не удалось скопировать дамп PostgreSQL." }

    docker compose exec -T db rm -f "$dbDumpContainerPath" *> $null

    if (Test-Path $uploadsPath) {
        Info "Архивация uploads в $uploadsArchivePath..."
        $uploadItems = Get-ChildItem -LiteralPath $uploadsPath -Force
        if ($uploadItems.Count -gt 0) {
            Compress-Archive -Path (Join-Path $uploadsPath "*") -DestinationPath $uploadsArchivePath -Force
        } else {
            Info "Папка uploads пуста, архив uploads не создавался."
        }
    } else {
        Info "Папка uploads не найдена, архив uploads не создавался."
    }

    $manifest = @(
        "created_at=$(Get-Date -Format o)",
        "project_root=$projectRoot",
        "database_dump=$dbDumpName",
        "uploads_archive=$(if (Test-Path $uploadsArchivePath) { 'uploads.zip' } else { '' })",
        "docker_compose_project=$(Split-Path -Leaf $projectRoot)"
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($manifestPath, $manifest, $utf8NoBom)

    if ($Keep -gt 0) {
        Info "Очистка старых бэкапов, оставляем последних $Keep..."
        $resolvedBackupRoot = [System.IO.Path]::GetFullPath($backupRoot)
        $resolvedProjectRoot = [System.IO.Path]::GetFullPath($projectRoot)
        if (-not $resolvedBackupRoot.StartsWith($resolvedProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            Fail "Папка бэкапов находится вне проекта, автоматическая очистка отключена."
        }

        Get-ChildItem -Path $backupRoot -Directory |
            Sort-Object Name -Descending |
            Select-Object -Skip $Keep |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
    }

    Ok "Бэкап создан: $backupDir"
    exit 0
} finally {
    Pop-Location
}
