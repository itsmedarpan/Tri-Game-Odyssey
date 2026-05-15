#!/bin/bash

# Tri-Game-Odyssey - Run Script
# This script sets up and runs the Tic-Tac-Toe WebSocket game

set -e  # Exit on error

echo "==========================================="
echo "  Tri-Game-Odyssey - Tic Tac Toe"
echo "==========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if virtual environment exists
if [ ! -d ".venv" ]; then
    echo -e "${YELLOW}Virtual environment not found. Creating...${NC}"
    python -m venv .venv
    echo -e "${GREEN}✓ Virtual environment created${NC}"
fi

# Activate virtual environment
echo -e "${YELLOW}Activating virtual environment...${NC}"
source .venv/Scripts/activate
echo -e "${GREEN}✓ Virtual environment activated${NC}"

# Install/update dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"
pip install -q -r requirements.txt 2>/dev/null || {
    echo -e "${RED}✗ Failed to install dependencies${NC}"
    exit 1
}
echo -e "${GREEN}✓ Dependencies ready${NC}"

# Check if Redis is running
echo -e "${YELLOW}Checking Redis connection...${NC}"
if ! powershell.exe -NoProfile -Command "Get-Service -Name Redis -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Status | Where-Object { \$_ -eq 'Running' }" &>/dev/null; then
    echo -e "${YELLOW}⚠ Redis service is not running${NC}"
    echo -e "${YELLOW}Please start Redis manually or via Services${NC}"
    echo -e "${YELLOW}  Windows: Start Redis service or run: C:\\Program Files\\Redis\\redis-server.exe${NC}"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ Redis is running${NC}"
fi

# Check if port 8000 is already in use
echo -e "${YELLOW}Checking port 8000...${NC}"
if netstat -ano 2>/dev/null | grep -q ":8000.*LISTENING"; then
    echo -e "${YELLOW}⚠ Port 8000 is already in use${NC}"
    echo -e "${YELLOW}Attempting to free port...${NC}"
    PID=$(netstat -ano 2>/dev/null | grep ":8000.*LISTENING" | awk '{print $NF}' | head -1)
    if [ ! -z "$PID" ]; then
        powershell.exe -NoProfile -Command "Stop-Process -Id $PID -Force" 2>/dev/null || true
        sleep 2
        echo -e "${GREEN}✓ Port freed${NC}"
    fi
fi

echo ""
echo -e "${GREEN}==========================================="
echo "  Starting Daphne ASGI Server"
echo "==========================================${NC}"
echo ""
echo -e "${YELLOW}Server will run on: http://localhost:8000${NC}"
echo -e "${YELLOW}Open in two browser windows to play!${NC}"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
echo ""

# Start Daphne server
python -m daphne firstProject.asgi:application --port 8000 --bind 127.0.0.1
