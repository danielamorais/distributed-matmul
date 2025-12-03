#!/bin/bash
# Start all servers for the distributed matrix multiplication system
# - Coordinator on port 8080
# - Static file server on port 8081 (serves both main and worker)

set -e

COORDINATOR_PORT=${1:-8080}
STATIC_PORT=${2:-8081}

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🚀 Starting Distributed Matrix Multiplication System${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if coordinator is compiled
if [ ! -f "ws/Web.o" ]; then
    echo -e "${YELLOW}⚠ Coordinator not compiled. Compiling...${NC}"
    dnc ws/CoordinatorWeb.dn -o ws/Web.o 2>&1 | grep -v "^$" || true
    dnc server/CoordinatorController.dn 2>&1 | grep -v "^$" || true
fi

# Kill any existing servers on these ports
echo -e "${BLUE}▶ Cleaning up existing servers...${NC}"
lsof -ti:$COORDINATOR_PORT | xargs kill -9 2>/dev/null || true
lsof -ti:$STATIC_PORT | xargs kill -9 2>/dev/null || true
sleep 1

# Start coordinator
echo -e "${BLUE}▶ Starting Coordinator (port $COORDINATOR_PORT)...${NC}"
cd /home/danielamorais/Documents/distributed-matmul
dana ws.core -p $COORDINATOR_PORT > /tmp/coordinator.log 2>&1 &
COORDINATOR_PID=$!
sleep 2

# Check if coordinator started
if ! kill -0 $COORDINATOR_PID 2>/dev/null; then
    echo -e "${YELLOW}⚠ Coordinator failed to start. Check /tmp/coordinator.log${NC}"
    cat /tmp/coordinator.log
    exit 1
fi

# Test coordinator
if curl -s http://localhost:$COORDINATOR_PORT/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Coordinator is running on port $COORDINATOR_PORT${NC}"
else
    echo -e "${YELLOW}⚠ Coordinator may not be ready yet${NC}"
fi

# Start static file server
echo -e "${BLUE}▶ Starting Static File Server (port $STATIC_PORT)...${NC}"
cd webserver
python3 -m http.server $STATIC_PORT > /tmp/static-server.log 2>&1 &
STATIC_PID=$!
sleep 1

# Check if static server started
if ! kill -0 $STATIC_PID 2>/dev/null; then
    echo -e "${YELLOW}⚠ Static server failed to start${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Static file server is running on port $STATIC_PORT${NC}"
echo ""

# Display status
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All Servers Running${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Coordinator API:${NC}  http://localhost:$COORDINATOR_PORT"
echo -e "${BLUE}Static Files:${NC}     http://localhost:$STATIC_PORT"
echo ""
echo -e "${BLUE}Main App:${NC}         http://localhost:$STATIC_PORT/xdana.html"
echo -e "${BLUE}Worker:${NC}          http://localhost:$STATIC_PORT/worker-dana-wasm.html"
echo ""
echo -e "${YELLOW}Note:${NC} Both apps can run simultaneously - no switching needed!"
echo ""
echo -e "${BLUE}To stop servers:${NC}"
echo "  kill $COORDINATOR_PID $STATIC_PID"
echo "  or: pkill -f 'ws.core|python3.*http.server.*$STATIC_PORT'"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"

