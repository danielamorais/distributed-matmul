#!/bin/bash

# Start Full System: Coordinator + Static File Server
# Usage: ./start-full-system.sh [COORDINATOR_PORT] [STATIC_PORT]

COORDINATOR_PORT=${1:-8080}
STATIC_PORT=${2:-8081}

echo "═══════════════════════════════════════════════════════════"
echo "🚀 Starting Full System"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Coordinator API: http://localhost:$COORDINATOR_PORT"
echo "Static Files:   http://localhost:$STATIC_PORT"
echo ""

# Check if coordinator is compiled
if [ ! -f "app/CoordinatorApp.o" ]; then
    echo "❌ Error: Coordinator not compiled"
    echo "Run: ./test-full-system.sh (compilation steps)"
    exit 1
fi

# Check if WASM files are packaged
if [ ! -f "webserver/file_system_main.js" ] || [ ! -f "webserver/file_system_worker.js" ]; then
    echo "❌ Error: WASM files not packaged"
    echo "Run: ./test-full-system.sh (packaging steps)"
    exit 1
fi

# Check ports
if lsof -Pi :$COORDINATOR_PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo "⚠️  Warning: Port $COORDINATOR_PORT is already in use"
    echo "   Process: $(lsof -Pi :$COORDINATOR_PORT -sTCP:LISTEN -t 2>/dev/null)"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

if lsof -Pi :$STATIC_PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo "⚠️  Warning: Port $STATIC_PORT is already in use"
    echo "   Process: $(lsof -Pi :$STATIC_PORT -sTCP:LISTEN -t 2>/dev/null)"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Set up main app file_system.js
cp webserver/file_system_main.js webserver/file_system.js
echo "✓ Set file_system.js to main app version"
echo ""

# Start coordinator in background
echo "Starting coordinator on port $COORDINATOR_PORT..."
dana app/CoordinatorApp.o $COORDINATOR_PORT > coordinator.log 2>&1 &
COORDINATOR_PID=$!

# Wait a moment for coordinator to start
sleep 2

# Check if coordinator started
if ! kill -0 $COORDINATOR_PID 2>/dev/null; then
    echo "❌ Error: Coordinator failed to start"
    echo "Check coordinator.log for details"
    exit 1
fi

echo "✓ Coordinator started (PID: $COORDINATOR_PID)"
echo ""

# Start static file server
echo "Starting static file server on port $STATIC_PORT..."
cd webserver
python3 -m http.server $STATIC_PORT > ../static-server.log 2>&1 &
STATIC_PID=$!
cd ..

# Wait a moment for static server to start
sleep 1

# Check if static server started
if ! kill -0 $STATIC_PID 2>/dev/null; then
    echo "❌ Error: Static file server failed to start"
    echo "Check static-server.log for details"
    kill $COORDINATOR_PID 2>/dev/null
    exit 1
fi

echo "✓ Static file server started (PID: $STATIC_PID)"
echo ""

# Save PIDs for cleanup
echo $COORDINATOR_PID > .coordinator.pid
echo $STATIC_PID > .static.pid

cat << EOF

═══════════════════════════════════════════════════════════
✅ System Started Successfully!
═══════════════════════════════════════════════════════════

Coordinator API:  http://localhost:$COORDINATOR_PORT
Static Files:     http://localhost:$STATIC_PORT

📋 Testing Instructions:

1. Open Main App:
   ${GREEN}http://localhost:$STATIC_PORT/xdana.html${NC}
   (file_system.js is already set to main app version)

2. Open Worker (in separate tab):
   First run: ${YELLOW}./switch-to-worker.sh${NC}
   Then open: ${GREEN}http://localhost:$STATIC_PORT/worker-dana-wasm.html${NC}

3. Test Flow:
   - Enter matrices in Main App and click "Submit"
   - Worker will poll and process the task
   - Main App will display the result

📝 Logs:
   - Coordinator: coordinator.log
   - Static Server: static-server.log

🛑 To Stop:
   ./stop-full-system.sh
   (or kill processes: kill $COORDINATOR_PID $STATIC_PID)

═══════════════════════════════════════════════════════════

EOF

