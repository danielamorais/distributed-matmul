#!/bin/bash

# Package BOTH Main App and Workers for WASM
# Creates a single file_system.js containing all components
# This allows both xdana.html and worker-dana-wasm.html to work

set -e

echo "=== Packaging Dana WASM (Main App + Workers) ==="

# Check if file_packager is available
if ! command -v file_packager &> /dev/null; then
    echo "Error: file_packager not found. Please install emsdk."
    echo "See: https://emscripten.org/docs/getting_started/downloads.html"
    exit 1
fi

# Check if wasm_output exists
if [ ! -d "wasm_output" ]; then
    echo "Error: wasm_output directory not found."
    echo "Run ./compile-main-wasm.sh and ./compile-worker-wasm.sh first."
    exit 1
fi

# Get Dana WASM runtime location (from Downloads or system)
DANA_WASM_DIR="${DANA_WASM_DIR:-$HOME/Downloads/dana_wasm_32_[272]}"

if [ ! -f "$DANA_WASM_DIR/dana.wasm" ]; then
    echo "Error: dana.wasm not found at $DANA_WASM_DIR"
    echo "Set DANA_WASM_DIR environment variable to the location of Dana WASM runtime."
    exit 1
fi

echo "Using Dana WASM runtime from: $DANA_WASM_DIR"

# Create file_system.js with ALL components (main app + workers)
echo "Creating combined file_system.js with main app and workers..."

file_packager "$DANA_WASM_DIR/dana.wasm" \
    --embed wasm_output/app/main.o@app/main.o \
    --embed wasm_output/app/MainAppLoop.o@app/MainAppLoop.o \
    --embed wasm_output/app/BrowserWorkerWasm.o@app/BrowserWorkerWasm.o \
    --embed wasm_output/app/BrowserWorkerLoop.o@app/BrowserWorkerLoop.o \
    --embed wasm_output/matmul/Matmul.o@matmul/Matmul.o \
    --embed resources/MainAppLoop.dn@resources/MainAppLoop.dn \
    --embed resources/BrowserWorkerLoop.dn@resources/BrowserWorkerLoop.dn \
    --embed "$DANA_WASM_DIR/components/@components" \
    --js-output=file_system.js

echo "Copying Dana runtime files to webserver..."
cp "$DANA_WASM_DIR/dana.js" webserver/
cp "$DANA_WASM_DIR/dana.wasm" webserver/
cp file_system.js webserver/

echo ""
echo "=== Packaging Complete ==="
echo "Files copied to webserver/:"
echo "  - dana.js"
echo "  - dana.wasm"
echo "  - file_system.js (contains both main app and workers)"
echo ""
echo "Ready to run!"
echo "  1. cd webserver && node server.js"
echo "  2. Open http://localhost:8080/xdana.html (main app)"
echo "  3. Open http://localhost:8080/worker-dana-wasm.html (worker)"
echo "  4. You can open multiple worker tabs for parallel processing!"

