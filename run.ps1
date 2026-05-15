# Tri-Game-Odyssey - Run Script (PowerShell)
# This script sets up and runs the Tic-Tac-Toe WebSocket game

param(
    [switch]$NoRedisCheck = $false
)

$ErrorActionPreference = "Stop"

# Colors
$Green = @{ForegroundColor = "Green"}
$Yellow = @{ForegroundColor = "Yellow"}
$Red = @{ForegroundColor = "Red"}

Write-Host ""
Write-Host "===========================================" @Green
Write-Host "  Tri-Game-Odyssey - Tic Tac Toe" @Green
Write-Host "==========================================" @Green
Write-Host ""

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Check if virtual environment exists
if (-not (Test-Path ".venv")) {
    Write-Host "Creating virtual environment..." @Yellow
    python -m venv .venv
    Write-Host "✓ Virtual environment created" @Green
}

# Activate virtual environment
Write-Host "Activating virtual environment..." @Yellow
& .\.venv\Scripts\Activate.ps1
Write-Host "✓ Virtual environment activated" @Green

# Install/update dependencies
Write-Host "Checking dependencies..." @Yellow
try {
    pip install -q -r requirements.txt 2>$null
    Write-Host "✓ Dependencies ready" @Green
} catch {
    Write-Host "✗ Failed to install dependencies" @Red
    exit 1
}

# Check if Redis is running (unless NoRedisCheck is set)
if (-not $NoRedisCheck) {
    Write-Host "Checking Redis connection..." @Yellow
    $redisService = Get-Service -Name Redis -ErrorAction SilentlyContinue
    if ($null -eq $redisService -or $redisService.Status -ne "Running") {
        Write-Host "⚠ Redis service is not running" @Yellow
        Write-Host "Please start Redis manually or via Services" @Yellow
        Write-Host "  Windows: Start Redis service or run: 'C:\Program Files\Redis\redis-server.exe'" @Yellow
        Write-Host ""
        $continue = Read-Host "Continue anyway? (y/n)"
        if ($continue -notmatch "^[Yy]$") {
            exit 1
        }
    } else {
        Write-Host "✓ Redis is running" @Green
    }
}

# Check if port 8000 is already in use
Write-Host "Checking port 8000..." @Yellow
$port8000 = netstat -ano | Select-String ":8000.*LISTENING"
if ($port8000) {
    Write-Host "⚠ Port 8000 is already in use" @Yellow
    Write-Host "Attempting to free port..." @Yellow
    $pid = $port8000 -split '\s+' | Select-Object -Last 1
    if ($pid) {
        try {
            Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Write-Host "✓ Port freed" @Green
        } catch {
            Write-Host "⚠ Could not free port automatically" @Yellow
        }
    }
}

Write-Host ""
Write-Host "===========================================" @Green
Write-Host "  Starting Daphne ASGI Server" @Green
Write-Host "==========================================" @Green
Write-Host ""
Write-Host "Server will run on: http://localhost:8000" @Yellow
Write-Host "Open in two browser windows to play!" @Yellow
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" @Yellow
Write-Host ""

# Start Daphne server
python -m daphne firstProject.asgi:application --port 8000 --bind 127.0.0.1
