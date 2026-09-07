#!/usr/bin/env bash
set -u

OUTPUT_DIR="${1:-backups}"
KEEP="${KEEP_BACKUPS:-14}"

GREEN="\033[0;32m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
ok() { echo -e "${GREEN}[OK]${RESET} $1"; }
fail() { echo -e "${RED}[ERROR]${RESET} $1"; exit 1; }

if docker compose version &>/dev/null; then
    DOCKER_COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null; then
    DOCKER_COMPOSE="docker-compose"
else
    fail "Docker Compose не установлен."
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_ROOT="$PROJECT_ROOT/$OUTPUT_DIR"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
DB_DUMP_NAME="postgres.dump"
DB_DUMP_CONTAINER_PATH="/tmp/easytranslator_${TIMESTAMP}.dump"
DB_DUMP_LOCAL_PATH="$BACKUP_DIR/$DB_DUMP_NAME"
UPLOADS_PATH="$PROJECT_ROOT/uploads"
UPLOADS_ARCHIVE_PATH="$BACKUP_DIR/uploads.tar.gz"
MANIFEST_PATH="$BACKUP_DIR/manifest.txt"

mkdir -p "$BACKUP_DIR"
cd "$PROJECT_ROOT" || fail "Не удалось перейти в корень проекта."

info "Проверка контейнера PostgreSQL..."
$DOCKER_COMPOSE ps db || fail "Не удалось получить статус контейнера db."

info "Создание pg_dump внутри контейнера db..."
$DOCKER_COMPOSE exec -T db sh -c "pg_dump -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -Fc -f '$DB_DUMP_CONTAINER_PATH'" || fail "pg_dump завершился с ошибкой."

info "Копирование дампа PostgreSQL в $DB_DUMP_LOCAL_PATH..."
$DOCKER_COMPOSE cp "db:$DB_DUMP_CONTAINER_PATH" "$DB_DUMP_LOCAL_PATH" || fail "Не удалось скопировать дамп PostgreSQL."
$DOCKER_COMPOSE exec -T db rm -f "$DB_DUMP_CONTAINER_PATH" >/dev/null 2>&1 || true

if [ -d "$UPLOADS_PATH" ]; then
    info "Архивация uploads в $UPLOADS_ARCHIVE_PATH..."
    tar -czf "$UPLOADS_ARCHIVE_PATH" -C "$PROJECT_ROOT" uploads || fail "Не удалось создать архив uploads."
else
    info "Папка uploads не найдена, архив uploads не создавался."
fi

{
    echo "created_at=$(date -Iseconds)"
    echo "project_root=$PROJECT_ROOT"
    echo "database_dump=$DB_DUMP_NAME"
    if [ -f "$UPLOADS_ARCHIVE_PATH" ]; then
        echo "uploads_archive=uploads.tar.gz"
    else
        echo "uploads_archive="
    fi
    echo "docker_compose_project=$(basename "$PROJECT_ROOT")"
} > "$MANIFEST_PATH"

if [ "$KEEP" -gt 0 ] 2>/dev/null; then
    info "Очистка старых бэкапов, оставляем последних $KEEP..."
    case "$(cd "$BACKUP_ROOT" && pwd)" in
        "$PROJECT_ROOT"/*)
            find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | sort -r | tail -n +$((KEEP + 1)) | xargs -r rm -rf
            ;;
        *)
            fail "Папка бэкапов находится вне проекта, автоматическая очистка отключена."
            ;;
    esac
fi

ok "Бэкап создан: $BACKUP_DIR"