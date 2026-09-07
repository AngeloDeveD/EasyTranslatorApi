#!/bin/bash

# Цвета для вывода
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Определение команды docker compose
if docker compose version &>/dev/null; then
    DOCKER_COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null; then
    DOCKER_COMPOSE="docker-compose"
else
    echo -e "${RED}[ERROR] Docker Compose не установлен!${RESET}"
    exit 1
fi

function check_compose_status() {
    local compose_cmd="$1"
    local ps_output

    echo ""
    echo -e "${BLUE}[INFO] Проверка состояния контейнеров...${RESET}"

    if ! ps_output=$(bash -c "$compose_cmd ps" 2>&1); then
        echo "$ps_output"
        echo -e "${RED}[ERROR] Не удалось проверить состояние контейнеров.${RESET}"
        return 1
    fi

    echo "$ps_output"
    if echo "$ps_output" | grep -Eiq 'Exit|Exited|unhealthy|Restarting|Dead'; then
        echo -e "${RED}[ERROR] Один или несколько контейнеров запущены с ошибкой.${RESET}"
        return 1
    fi

    return 0
}

function run_compose() {
    local cmd="$1"
    local mode_name="$2"
    local compose_cmd="$3"

    clear
    echo -e "${BLUE}======================================================${RESET}"
    echo -e " [INFO] Запуск в режиме: ${CYAN}${mode_name}${RESET}"
    echo -e "${BLUE}======================================================${RESET}"
    echo ""
    echo -e "${BLUE}[INFO] Выполняется:${RESET} $cmd"
    echo ""

    bash -c "$cmd"
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo ""
        echo -e "${RED}======================================================${RESET}"
        echo -e "${RED} [ERROR] Docker Compose завершился с кодом ${exit_code}.${RESET}"
        echo -e "${RED}======================================================${RESET}"
        return $exit_code
    fi

    if ! check_compose_status "$compose_cmd"; then
        echo -e "${RED}======================================================${RESET}"
        echo -e "${RED} [ERROR] Docker запущен с ошибкой.${RESET}"
        echo -e "${RED}======================================================${RESET}"
        return 1
    fi

    echo ""
    echo -e "${GREEN}======================================================${RESET}"
    echo -e "${GREEN} [OK] Все сервисы успешно собраны и запущены в фоне!  ${RESET}"
    echo -e " API доступен: ${CYAN}http://localhost:8080${RESET}"
    echo -e "${GREEN}======================================================${RESET}"
    return 0
}

function stop_all() {
    echo -e "${YELLOW}[INFO] Остановка контейнеров...${RESET}"
    if $DOCKER_COMPOSE down; then
        echo -e "${GREEN}[OK] Контейнеры остановлены.${RESET}"
    else
        echo -e "${RED}[ERROR] Docker не смог остановить контейнеры.${RESET}"
        return 1
    fi
}

function reset_db() {
    echo -e "${RED}[ВНИМАНИЕ] Это действие удалит все данные из PostgreSQL!${RESET}"
    read -p "Вы уверены? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if $DOCKER_COMPOSE down -v; then
            echo -e "${GREEN}[OK] База данных и тома удалены.${RESET}"
        else
            echo -e "${RED}[ERROR] Docker не смог удалить базу данных и тома.${RESET}"
            return 1
        fi
    fi
}

function create_backup() {
    bash "$SCRIPT_DIR/scripts/backup.sh"
}
function show_logs() {
    echo -e "${BLUE}[INFO] Открытие логов. Нажмите Ctrl+C для выхода...${RESET}"
    $DOCKER_COMPOSE logs -f
}

function set_admin() {
    local uid=$1
    if [ -z "$uid" ]; then
        read -p "Введите ID пользователя для назначения АДМИНОМ: " uid
    fi
    if [ -n "$uid" ]; then
        $DOCKER_COMPOSE exec api ./myapi --make-admin "$uid"
    fi
}

function set_mod() {
    local uid=$1
    if [ -z "$uid" ]; then
        read -p "Введите ID пользователя для назначения МОДЕРАТОРОМ: " uid
    fi
    if [ -n "$uid" ]; then
        $DOCKER_COMPOSE exec api ./myapi --make-moderator "$uid"
    fi
}

# Обработка аргументов CLI
case "$1" in
    dev)
        run_compose "$DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.no-av.yml up -d --build" "DEV (без ClamAV)" "$DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.no-av.yml"
        exit $?
        ;;
    full|prod)
        run_compose "$DOCKER_COMPOSE up -d --build" "PROD (с ClamAV)" "$DOCKER_COMPOSE"
        exit $?
        ;;
    stop) stop_all; exit $? ;;
    reset) reset_db; exit $? ;;
    logs) show_logs; exit $? ;;
    backup) create_backup; exit $? ;;
    admin) set_admin "$2"; exit $? ;;
    mod|moderator) set_mod "$2"; exit $? ;;
esac

# Главное интерактивное меню
while true; do
    clear
    echo -e "${BLUE}======================================================${RESET}"
    echo -e "           EasyTranslator Server Management           "
    echo -e "${BLUE}======================================================${RESET}"
    echo "  [1] Быстрый запуск DEV (Без ClamAV, ~120 MB RAM)"
    echo "  [2] Полный запуск PROD (С ClamAV, ~1 GB RAM)"
    echo "  [3] Остановить все контейнеры"
    echo "  [4] Полный сброс базы данных (Wipe Database)"
    echo "  [5] Просмотр логов в реальном времени"
    echo "  [8] Создать бэкап PostgreSQL и uploads"
    echo "  ----------------------------------------------------"
    echo "  [6] Назначить АДМИНИСТРАТОРА (--make-admin)"
    echo "  [7] Назначить МОДЕРАТОРА (--make-moderator)"
    echo "  ----------------------------------------------------"
    echo "  [0] Выход"
    echo -e "${BLUE}======================================================${RESET}"
    read -p "Выберите действие [0-8]: " choice

    case "$choice" in
        1)
            run_compose "$DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.no-av.yml up -d --build" "DEV (без ClamAV)" "$DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.no-av.yml"
            read -p "Нажмите Enter для возврата в меню..."
            ;;
        2)
            run_compose "$DOCKER_COMPOSE up -d --build" "PROD (с ClamAV)" "$DOCKER_COMPOSE"
            read -p "Нажмите Enter для возврата в меню..."
            ;;
        3) stop_all; read -p "Нажмите Enter для возврата в меню..." ;;
        4) reset_db; read -p "Нажмите Enter для возврата в меню..." ;;
        5) show_logs ;;
        6) set_admin; read -p "Нажмите Enter для возврата в меню..." ;;
        7) set_mod; read -p "Нажмите Enter для возврата в меню..." ;;
        8) create_backup; read -p "Нажмите Enter для возврата в меню..." ;;
        0) exit 0 ;;
        *) echo -e "${RED}Неверный выбор.${RESET}"; sleep 1 ;;
    esac
done
