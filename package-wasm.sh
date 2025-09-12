#!/bin/bash

# Package Dana WASM application for web deployment
# Usage: ./package-wasm.sh

set -e  # Exit on any error

echo "=== Packaging Dana WASM application ==="

# Check if file_packager is available
if ! command -v file_packager &> /dev/null; then
    echo "Error: file_packager command not found."
    echo "Please ensure Emscripten is installed and file_packager is in PATH."
    echo "You can install Emscripten from: https://emscripten.org/docs/getting_started/downloads.html"
    exit 1
fi

# Check if wasm_output directory exists
if [ ! -d "wasm_output" ]; then
    echo "Error: wasm_output directory not found."
    echo "Please run ./compile-wasm.sh first to compile the application."
    exit 1
fi

# Check if components directory exists
if [ ! -d "$DANA_WASM_HOME/components" ]; then
    echo "Error: Dana components directory not found."
    echo "Expected path: $DANA_WASM_HOME/components"
    exit 1
fi


echo "Packaging WASM files..."

# Run file_packager command
file_packager dana.wasm \
    --embed wasm_output/App.o@App.o \
    --embed $DANA_WASM_HOME/components@components \
    --js-output=webserver/file_system.js

echo "=== WASM packaging complete ==="
echo "Packaged files are in the 'wasm_package' directory:"
ls -la webserver/

echo ""
echo "Main WASM package: webserver/dana.wasm"
echo "File system JS: webserver/file_system.js"
echo ""
echo "You can now use these files in your web application."
