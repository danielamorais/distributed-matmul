#!/bin/bash

# Compile Dana Main App for WASM
# This main app runs entirely within Dana's ProcessLoop with UI

set -e

echo "=== Compiling Dana WASM Main App ==="

# Check if dnc is available
if ! command -v dnc &> /dev/null; then
    echo "Error: dnc command not found. Please ensure Dana compiler is installed and in PATH."
    exit 1
fi

# Create output directory
mkdir -p wasm_output/app
mkdir -p wasm_output/matmul

echo "Compiling Matmul component..."
dnc matmul/Matmul.dn -os ubc -chip 32 -sp resources -o wasm_output/matmul/Matmul.o

echo "Compiling MainAppLoop component..."
dnc app/MainAppLoop.dn -os ubc -chip 32 -sp resources -o wasm_output/app/MainAppLoop.o

echo "Compiling main (App entry point)..."
dnc app/main.dn -os ubc -chip 32 -sp resources -o wasm_output/app/main.o

echo ""
echo "=== Compilation Complete ==="
echo "Output files:"
echo "  - wasm_output/matmul/Matmul.o"
echo "  - wasm_output/app/MainAppLoop.o"
echo "  - wasm_output/app/main.o"
echo ""
echo "Next steps:"
echo "  1. Package with file_packager (see package-main-wasm.sh)"
echo "  2. Copy dana.js, dana.wasm, file_system.js to webserver/"
echo "  3. Open http://localhost:8080/xdana.html"

