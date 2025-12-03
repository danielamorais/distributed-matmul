#!/bin/bash

# Package Dana WASM Main App with file_packager
# Creates file_system.js containing all components

set -e

echo "=== Packaging Dana WASM Main App ==="

# Check if file_packager is available
if ! command -v file_packager &> /dev/null; then
    echo "Error: file_packager not found. Please install emsdk."
    echo "See: https://emscripten.org/docs/getting_started/downloads.html"
    exit 1
fi

# Check if wasm_output exists
if [ ! -d "wasm_output" ]; then
    echo "Error: wasm_output directory not found."
    echo "Run ./compile-main-wasm.sh first."
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

# Create file_system.js with all components
echo "Creating file_system.js..."

file_packager "$DANA_WASM_DIR/dana.wasm" \
    --embed wasm_output/app/main.o@app/main.o \
    --embed wasm_output/app/MainAppLoop.o@app/MainAppLoop.o \
    --embed wasm_output/matmul/Matmul.o@matmul/Matmul.o \
    --embed resources/MainAppLoop.dn@resources/MainAppLoop.dn \
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
echo "  - file_system.js"
echo ""
echo "Ready to run!"
echo "  1. cd webserver && node server.js"
echo "  2. Open http://localhost:8080/xdana.html"
echo "  3. The UI will be handled entirely by Dana WASM"

