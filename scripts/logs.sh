#!/bin/bash

GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

if docker compose version &>/dev/null; then
    COMPOSE=(docker compose)
elif command -v docker-compose &>/dev/null; then
    COMPOSE=(docker-compose)
else
    echo -e "${RED}[ERROR] Docker Compose не установлен.${RESET}"
    read -r -p "Нажмите Enter для закрытия окна..."
    exit 1
fi

follow_logs() {
    local service="$1"
    clear
    if [ -z "$service" ]; then
        echo -e "${BLUE}[INFO] Показываю все логи. Ctrl+C остановит просмотр.${RESET}"
        echo ""
        "${COMPOSE[@]}" logs -f --tail=200
    else
        echo -e "${BLUE}[INFO] Показываю логи сервиса: ${CYAN}${service}${RESET}. Ctrl+C остановит просмотр."
        echo ""
        "${COMPOSE[@]}" logs -f --tail=200 "$service"
    fi
    echo ""
    echo -e "${YELLOW}[INFO] Просмотр логов завершён.${RESET}"
    read -r -p "Нажмите Enter для возврата в меню..."
}

show_ps() {
    clear
    echo -e "${BLUE}[INFO] docker compose ps${RESET}"
    echo ""
    "${COMPOSE[@]}" ps
    echo ""
    read -r -p "Нажмите Enter для возврата в меню..."
}

while true; do
    clear
    echo -e "${BLUE}======================================================${RESET}"
    echo "              EasyTranslator Docker Logs"
    echo -e "${BLUE}======================================================${RESET}"
    echo ""
    echo "  [1] Все сервисы"
    echo "  [2] api"
    echo "  [3] db"
    echo "  [4] scanner"
    echo "  [5] clamav"
    echo "  [6] Статус контейнеров"
    echo "  ----------------------------------------------------"
    echo "  [0] Закрыть это окно"
    echo ""
    echo -e "${BLUE}======================================================${RESET}"
    read -r -p "Выберите логи [0-6]: " choice

    case "$choice" in
        1) follow_logs "" ;;
        2) follow_logs "api" ;;
        3) follow_logs "db" ;;
        4) follow_logs "scanner" ;;
        5) follow_logs "clamav" ;;
        6) show_ps ;;
        0) exit 0 ;;
        *) echo -e "${RED}Неверный выбор.${RESET}"; sleep 1 ;;
    esac
done