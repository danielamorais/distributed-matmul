#!/bin/bash

# Full System Test Script
# Tests: Coordinator (Native Dana) + Main (WASM) + Worker (WASM)
# 
# This script:
# 1. Compiles coordinator (native Dana)
# 2. Compiles main app (WASM)
# 3. Compiles worker (WASM)
# 4. Packages both WASM apps
# 5. Starts coordinator server
# 6. Provides browser testing instructions

set -e

echo "═══════════════════════════════════════════════════════════"
echo "🧪 Full System Test: Coordinator + Main + Worker"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Configuration
COORDINATOR_PORT=${1:-8080}
DANA_WASM_DIR="${DANA_WASM_DIR:-$HOME/Downloads/dana_wasm_32_[272]}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check prerequisites
print_step "Checking prerequisites..."

if ! command -v dnc &> /dev/null; then
    print_error "dnc command not found. Please install Dana compiler."
    exit 1
fi
print_success "Dana compiler found"

if ! command -v file_packager &> /dev/null; then
    print_error "file_packager not found. Please install emsdk."
    echo "See: https://emscripten.org/docs/getting_started/downloads.html"
    exit 1
fi
print_success "file_packager found"

if [ ! -f "$DANA_WASM_DIR/dana.wasm" ]; then
    print_error "dana.wasm not found at $DANA_WASM_DIR"
    echo "Set DANA_WASM_DIR environment variable to the location of Dana WASM runtime."
    exit 1
fi
print_success "Dana WASM runtime found at $DANA_WASM_DIR"

echo ""

# Step 1: Compile Coordinator (Native Dana with ws.core)
print_step "Step 1: Compiling Coordinator (Native Dana with ws.core)..."

if [ ! -f "ws/CoordinatorWeb.dn" ]; then
    print_error "ws/CoordinatorWeb.dn not found"
    exit 1
fi

if [ ! -f "server/CoordinatorController.dn" ]; then
    print_error "server/CoordinatorController.dn not found"
    exit 1
fi

echo "  Compiling CoordinatorWeb (ws.core component)..."
dnc ws/CoordinatorWeb.dn -o ws/Web.o 2>&1 | grep -v "^$" || true

echo "  Compiling CoordinatorController..."
dnc server/CoordinatorController.dn 2>&1 | grep -v "^$" || true

if [ -f "ws/Web.o" ] && [ -f "server/CoordinatorController.o" ]; then
    print_success "Coordinator compiled successfully"
else
    print_error "Coordinator compilation failed - missing .o files"
    echo "  Expected: ws/Web.o, server/CoordinatorController.o"
    exit 1
fi

echo ""

# Step 2: Compile Main App (WASM)
print_step "Step 2: Compiling Main App (WASM)..."

if [ ! -f "compile-main-wasm.sh" ]; then
    print_error "compile-main-wasm.sh not found"
    exit 1
fi

chmod +x compile-main-wasm.sh
./compile-main-wasm.sh

if [ -f "wasm_output/app/main.o" ]; then
    print_success "Main app compiled successfully"
else
    print_error "Main app compilation failed"
    exit 1
fi

echo ""

# Step 3: Compile Worker (WASM)
print_step "Step 3: Compiling Worker (WASM)..."

if [ ! -f "compile-worker-wasm.sh" ]; then
    print_error "compile-worker-wasm.sh not found"
    exit 1
fi

chmod +x compile-worker-wasm.sh
./compile-worker-wasm.sh

if [ -f "wasm_output/app/BrowserWorkerWasm.o" ]; then
    print_success "Worker compiled successfully"
else
    print_error "Worker compilation failed"
    exit 1
fi

echo ""

# Step 4: Package Main App (WASM)
print_step "Step 4: Packaging Main App (WASM)..."

chmod +x package-main-wasm.sh
./package-main-wasm.sh

if [ -f "webserver/file_system.js" ]; then
    print_success "Main app packaged successfully"
    # Backup main app's file_system.js
    cp webserver/file_system.js webserver/file_system_main.js
else
    print_error "Main app packaging failed"
    exit 1
fi

echo ""

# Step 5: Package Worker (WASM)
print_step "Step 5: Packaging Worker (WASM)..."

chmod +x package-worker-wasm.sh

# Temporarily fix the dana.wasm path in package-worker-wasm.sh
# The script uses "dana.wasm" but should use the full path
TEMP_SCRIPT=$(mktemp)
sed "s|file_packager dana.wasm|file_packager \"$DANA_WASM_DIR/dana.wasm\"|" package-worker-wasm.sh > "$TEMP_SCRIPT"
chmod +x "$TEMP_SCRIPT"

# Run the modified script
bash "$TEMP_SCRIPT"

# Clean up
rm "$TEMP_SCRIPT"

if [ -f "webserver/file_system.js" ]; then
    print_success "Worker packaged successfully"
    # Backup worker's file_system.js
    cp webserver/file_system.js webserver/file_system_worker.js
else
    print_error "Worker packaging failed"
    exit 1
fi

echo ""

# Step 6: Setup file_system.js for main app
print_step "Step 6: Setting up file_system.js for main app..."

cp webserver/file_system_main.js webserver/file_system.js
print_success "Main app file_system.js ready"

echo ""

# Step 7: Check if coordinator port is available
print_step "Step 7: Checking coordinator port availability..."

if lsof -Pi :$COORDINATOR_PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    print_warning "Port $COORDINATOR_PORT is already in use"
    echo ""
    echo "To find the process using this port:"
    echo "  lsof -i :$COORDINATOR_PORT"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    print_success "Port $COORDINATOR_PORT is available"
fi

echo ""

# Step 8: Start Coordinator Server
print_step "Step 8: Starting Coordinator Server..."

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "🚀 Coordinator Server Starting..."
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Port: $COORDINATOR_PORT"
echo ""
echo "The coordinator will run in the foreground."
echo "Press Ctrl+C to stop it."
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""

# Instructions for testing
cat << EOF

${GREEN}═══════════════════════════════════════════════════════════${NC}
${GREEN}📋 Testing Instructions${NC}
${GREEN}═══════════════════════════════════════════════════════════${NC}

${YELLOW}The coordinator server is now running on port $COORDINATOR_PORT.${NC}

${BLUE}Step 1: Start Static File Server${NC}

${YELLOW}Open a NEW terminal window and run:${NC}

  ${GREEN}cd webserver${NC}
  ${GREEN}python3 -m http.server 8081${NC}

${BLUE}This serves the HTML and WASM files.${NC}

${BLUE}Step 2: Test the System${NC}

${GREEN}2a. Open Main App (in browser):${NC}
   - Open: ${GREEN}http://localhost:8081/xdana.html${NC}
   - This loads the main app (WASM) which will submit tasks to coordinator
   - Uses file_system_main.js automatically

${GREEN}2b. Open Worker (in separate browser tab/window):${NC}
   - Open: ${GREEN}http://localhost:8081/worker-dana-wasm.html${NC}
   - This loads the worker (WASM) which will poll coordinator for tasks
   - Uses file_system_worker.js automatically

${GREEN}2c. Test Flow:${NC}
   - In Main App: Enter matrices and click "Submit"
   - Main App submits task to coordinator at http://localhost:$COORDINATOR_PORT/task
   - Worker polls coordinator at http://localhost:$COORDINATOR_PORT/task/next
   - Worker receives task and computes result using Dana Matmul component
   - Worker submits result to http://localhost:$COORDINATOR_PORT/task/:id/result
   - Main App polls for result at http://localhost:$COORDINATOR_PORT/result/:id
   - Main App displays the result

${BLUE}Architecture:${NC}
- Coordinator API: http://localhost:$COORDINATOR_PORT (handles /task, /result, etc.)
- Static Files: http://localhost:8081 (serves HTML, WASM, file_system.js)
- Main App: Connects to coordinator API for task submission and result polling
- Worker: Connects to coordinator API for task polling and result submission

${BLUE}Note:${NC}
- Both apps can run simultaneously - no switching needed!
- Each HTML file uses its own file_system.js file automatically
- The static file server (port 8081) serves the HTML/WASM files
- The coordinator (port $COORDINATOR_PORT) handles the API endpoints
- Both WASM apps make HTTP requests to the coordinator API

${GREEN}═══════════════════════════════════════════════════════════${NC}

EOF

# Start coordinator using ws.core
dana ws.core -p $COORDINATOR_PORT

