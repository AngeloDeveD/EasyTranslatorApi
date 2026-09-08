@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
title EasyTranslator Docker Logs

where docker >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker не найден в PATH.
    pause
    exit /b 1
)

docker compose version >nul 2>&1
if errorlevel 1 (
    docker-compose version >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Docker Compose не установлен.
        pause
        exit /b 1
    )
    set "COMPOSE=docker-compose"
) else (
    set "COMPOSE=docker compose"
)

:menu
cls
echo ======================================================
echo              EasyTranslator Docker Logs
echo ======================================================
echo.
echo  [1] Все сервисы
echo  [2] api
echo  [3] db
echo  [4] scanner
echo  [5] clamav
echo  [6] Статус контейнеров
echo  ----------------------------------------------------
echo  [0] Закрыть это окно
echo.
echo ======================================================
set /p choice="Выберите логи [0-6]: "

if "%choice%"=="1" goto logs_all
if "%choice%"=="2" goto logs_api
if "%choice%"=="3" goto logs_db
if "%choice%"=="4" goto logs_scanner
if "%choice%"=="5" goto logs_clamav
if "%choice%"=="6" goto ps
if "%choice%"=="0" exit
goto menu

:logs_all
call :follow_logs ""
goto menu

:logs_api
call :follow_logs "api"
goto menu

:logs_db
call :follow_logs "db"
goto menu

:logs_scanner
call :follow_logs "scanner"
goto menu

:logs_clamav
call :follow_logs "clamav"
goto menu

:ps
cls
echo [INFO] docker compose ps
echo.
%COMPOSE% ps
echo.
pause
goto menu

:follow_logs
cls
set "SERVICE=%~1"
if "%SERVICE%"=="" (
    echo [INFO] Показываю все логи. Ctrl+C остановит просмотр.
    echo.
    %COMPOSE% logs -f --tail=200
) else (
    echo [INFO] Показываю логи сервиса: %SERVICE%. Ctrl+C остановит просмотр.
    echo.
    %COMPOSE% logs -f --tail=200 %SERVICE%
)
echo.
echo [INFO] Просмотр логов завершён.
pause
exit /b 0