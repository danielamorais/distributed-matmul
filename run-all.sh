#!/bin/bash

# This script packages all WASM components into a single file and runs the native Coordinator server.

# Exit immediately if a command exits with a non-zero status.
set -e

# Use the first command-line argument as the port, or default to 8080
PORT=${1:-8080}

echo "========================================="
echo " STEP 1: Packaging all WASM components..."
echo "========================================="

# Check if file_packager is available
if ! command -v file_packager &> /dev/null; then
    echo "Error: file_packager not found. Please install the Emscripten SDK (emsdk)."
    echo "See: https://emscripten.org/docs/getting_started/downloads.html"
    exit 1
fi

# Check if wasm_output exists
if [ ! -d "wasm_output" ]; then
    echo "Error: wasm_output directory not found. Run ./compile-all.sh first."
    exit 1
fi

# Get Dana WASM runtime location
DANA_WASM_DIR="${DANA_WASM_DIR:-$HOME/Downloads/dana_wasm_32_[272]}"

if [ ! -f "$DANA_WASM_DIR/dana.wasm" ]; then
    echo "Error: dana.wasm not found at $DANA_WASM_DIR"
    echo "Set DANA_WASM_DIR environment variable to the location of the Dana WASM runtime."
    exit 1
fi

echo "Using Dana WASM runtime from: $DANA_WASM_DIR"

# Create a unified file_system.js with all components
echo "Creating unified file_system.js..."

file_packager "$DANA_WASM_DIR/dana.wasm" \
    --embed wasm_output/app/main.o@app/main.o \
    --embed wasm_output/app/MainAppLoop.o@app/MainAppLoop.o \
    --embed wasm_output/app/BrowserWorkerWasm.o@app/BrowserWorkerWasm.o \
    --embed wasm_output/app/BrowserWorkerLoop.o@app/BrowserWorkerLoop.o \
    --embed wasm_output/matmul/Matmul.o@matmul/Matmul.o \
    --embed resources/MainAppLoop.dn@resources/MainAppLoop.dn \
    --embed wasm_output/resources/BrowserWorkerLoop.dn@resources/BrowserWorkerLoop.dn \
    --embed "$DANA_WASM_DIR/components/@components" \
    --js-output=webserver/file_system.js

echo "Copying Dana runtime files to webserver..."
cp "$DANA_WASM_DIR/dana.js" webserver/
cp "$DANA_WASM_DIR/dana.wasm" webserver/

echo "✅ All WASM components packaged successfully into file_system.js."
echo ""

echo "========================================="
echo " STEP 2: Starting the Coordinator Server..."
echo "========================================="
if [ -f ws/CoordinatorWeb.o ]; then
    echo "Starting server on port $PORT..."
    echo "Access the application at http://localhost:$PORT/xdana.html"
    echo "Access the worker at http://localhost:$PORT/worker-dana-wasm.html"
    echo "Press Ctrl+C to stop the server."
    dana ws.core "$PORT"
else
    echo "Error: ws/CoordinatorWeb.o not found. Please compile the project first using compile-all.sh"
    exit 1
fi
