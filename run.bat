@echo off
REM Tri-Game-Odyssey - Run Script (Windows Batch)
REM This script sets up and runs the Tic-Tac-Toe WebSocket game

setlocal enabledelayedexpansion

echo.
echo ===========================================
echo   Tri-Game-Odyssey - Tic Tac Toe
echo ===========================================
echo.

cd /d "%~dp0"

REM Check if virtual environment exists
if not exist ".venv" (
    echo Creating virtual environment...
    python -m venv .venv
    echo Virtual environment created
)

REM Activate virtual environment
echo Activating virtual environment...
call .venv\Scripts\activate.bat
echo Virtual environment activated

REM Install/update dependencies
echo Checking dependencies...
pip install -q -r requirements.txt
if errorlevel 1 (
    echo Failed to install dependencies
    exit /b 1
)
echo Dependencies ready

REM Check if Redis is running
echo Checking Redis connection...
powershell -NoProfile -Command "Get-Service -Name Redis -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Status | Where-Object { $_ -eq 'Running' }" >nul 2>&1
if errorlevel 1 (
    echo.
    echo WARNING: Redis service is not running
    echo Please start Redis manually or via Services
    echo Windows: Start Redis service or run: "C:\Program Files\Redis\redis-server.exe"
    echo.
    set /p continue="Continue anyway? (y/n): "
    if /i not "!continue!"=="y" exit /b 1
) else (
    echo Redis is running
)

REM Check if port 8000 is already in use
echo Checking port 8000...
netstat -ano | findstr ":8000.*LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo WARNING: Port 8000 is already in use
    echo Attempting to free port...
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8000.*LISTENING"') do (
        taskkill /PID %%a /F >nul 2>&1 || true
    )
    timeout /t 2 /nobreak
    echo Port freed
)

echo.
echo ===========================================
echo   Starting Daphne ASGI Server
echo ===========================================
echo.
echo Server will run on: http://localhost:8000
echo Open in two browser windows to play!
echo.
echo Press Ctrl+C to stop the server
echo.

REM Start Daphne server
python -m daphne firstProject.asgi:application --port 8000 --bind 127.0.0.1

endlocal
