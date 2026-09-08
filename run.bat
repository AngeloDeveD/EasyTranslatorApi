@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
title Управление EasyTranslator Server

:: Проверка аргументов командной строки
if "%1"=="dev" (
    call :run_compose "docker compose -f docker-compose.yml -f docker-compose.no-av.yml up -d --build" "DEV (без ClamAV)" "docker compose -f docker-compose.yml -f docker-compose.no-av.yml"
    exit /b !ERRORLEVEL!
)
if "%1"=="full" (
    call :run_compose "docker compose up -d --build" "PROD (с ClamAV)" "docker compose"
    exit /b !ERRORLEVEL!
)
if "%1"=="prod" (
    call :run_compose "docker compose up -d --build" "PROD (с ClamAV)" "docker compose"
    exit /b !ERRORLEVEL!
)
if "%1"=="stop" goto stop
if "%1"=="reset" goto reset
if "%1"=="logs" goto logs
if "%1"=="backup" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\backup.ps1"
    exit /b !ERRORLEVEL!
)
if "%1"=="admin" goto cli_admin
if "%1"=="mod" goto cli_mod

:menu
cls
echo ======================================================
echo           EasyTranslator Server Management
echo ======================================================
echo.
echo  [1] Быстрый запуск DEV в фоне (Без ClamAV, ~120 MB RAM)
echo  [2] Полный запуск PROD в фоне (С ClamAV, ~1 GB RAM)
echo  [3] Остановить все контейнеры (down)
echo  [4] Полный сброс БД (Wipe Database)
echo  [5] Открыть отдельное окно выбора логов
echo  [8] Создать бэкап PostgreSQL и uploads
echo  ----------------------------------------------------
echo  [6] Назначить АДМИНИСТРАТОРА (--make-admin)
echo  [7] Назначить МОДЕРАТОРА (--make-moderator)
echo  ----------------------------------------------------
echo  [0] Выход
echo.
echo ======================================================
set /p choice="Выберите действие [0-8]: "

if "%choice%"=="1" (
    call :run_compose "docker compose -f docker-compose.yml -f docker-compose.no-av.yml up -d --build" "DEV (без ClamAV)" "docker compose -f docker-compose.yml -f docker-compose.no-av.yml"
    pause
    goto menu
)
if "%choice%"=="2" (
    call :run_compose "docker compose up -d --build" "PROD (с ClamAV)" "docker compose"
    pause
    goto menu
)
if "%choice%"=="3" goto stop
if "%choice%"=="4" goto reset
if "%choice%"=="5" goto logs
if "%choice%"=="6" goto menu_admin
if "%choice%"=="7" goto menu_mod
if "%choice%"=="8" goto backup
if "%choice%"=="0" exit /b
goto menu

:run_compose
cls
set "CMD_TO_RUN=%~1"
set "MODE_NAME=%~2"
set "COMPOSE_CMD=%~3"
set "PS_FILE=%TEMP%\easytranslator_ps.txt"
if "%COMPOSE_CMD%"=="" set "COMPOSE_CMD=docker compose"
del "%PS_FILE%" 2>nul

echo ======================================================
echo  [INFO] Запуск в режиме: %MODE_NAME%
echo ======================================================
echo.
echo [INFO] Выполняется: %CMD_TO_RUN%
echo.

%CMD_TO_RUN%
set "EXIT_CODE=!ERRORLEVEL!"

if not "!EXIT_CODE!"=="0" (
    echo.
    echo ======================================================
    echo  [ERROR] Docker Compose завершился с кодом !EXIT_CODE!.
    echo ======================================================
    echo.
    exit /b !EXIT_CODE!
)

echo.
echo [INFO] Проверка состояния контейнеров...
%COMPOSE_CMD% ps > "%PS_FILE%" 2>&1
set "PS_EXIT=!ERRORLEVEL!"
type "%PS_FILE%"

if not "!PS_EXIT!"=="0" (
    echo.
    echo ======================================================
    echo  [ERROR] Не удалось проверить состояние контейнеров.
    echo ======================================================
    del "%PS_FILE%" 2>nul
    exit /b !PS_EXIT!
)

findstr /i /c:"Exit" /c:"Exited" /c:"unhealthy" /c:"Restarting" /c:"Dead" "%PS_FILE%" >nul
if not errorlevel 1 (
    echo.
    echo ======================================================
    echo  [ERROR] Один или несколько контейнеров запущены с ошибкой.
    echo ======================================================
    del "%PS_FILE%" 2>nul
    exit /b 1
)

del "%PS_FILE%" 2>nul
echo.
echo ======================================================
echo  [OK] Все контейнеры успешно собраны и запущены в фоне!
echo  API доступен по адресу: http://localhost:8080
echo ======================================================
echo.
exit /b 0

:stop
cls
echo [INFO] Остановка всех сервисов...
docker compose down
if errorlevel 1 (
    echo [ERROR] Docker не смог остановить сервисы.
    pause
    goto menu
)
echo [OK] Все сервисы остановлены.
pause
goto menu

:reset
cls
echo [ВНИМАНИЕ] Это полностью удалит все данные из PostgreSQL!
set /p confirm="Вы уверены? (y/N): "
if /i "%confirm%"=="y" (
    docker compose down -v
    if errorlevel 1 (
        echo [ERROR] Docker не смог очистить базу данных и тома.
    ) else (
        echo [OK] База данных и тома очищены.
    )
)
pause
goto menu

:logs
cls
echo [INFO] Открываю отдельное окно выбора логов...
start "EasyTranslator Logs" cmd /c ""%~dp0scripts\logs.bat""
if errorlevel 1 (
    echo [ERROR] Не удалось открыть отдельное окно логов.
) else (
    echo [OK] Окно логов открыто.
)
echo.
echo Это основное окно оставлено открытым.
pause
goto menu

:backup
cls
echo [INFO] Создание бэкапа PostgreSQL и uploads...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\backup.ps1"
if errorlevel 1 (
    echo [ERROR] Бэкап завершился с ошибкой.
) else (
    echo [OK] Бэкап успешно создан.
)
pause
goto menu
:menu_admin
cls
set /p uid="Введите ID пользователя для назначения АДМИНОМ: "
if "%uid%"=="" goto menu
docker compose exec api ./myapi --make-admin %uid%
pause
goto menu

:menu_mod
cls
set /p uid="Введите ID пользователя для назначения МОДЕРАТОРОМ: "
if "%uid%"=="" goto menu
docker compose exec api ./myapi --make-moderator %uid%
pause
goto menu

:cli_admin
docker compose exec api ./myapi --make-admin %2
exit /b %ERRORLEVEL%

:cli_mod
docker compose exec api ./myapi --make-moderator %2
exit /b %ERRORLEVEL%
