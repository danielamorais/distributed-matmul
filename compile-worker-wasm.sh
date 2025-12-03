#!/bin/bash

# Compile Dana Browser Worker for WASM
# This worker runs entirely within Dana's ProcessLoop

set -e

echo "=== Compiling Dana WASM Worker ==="

# Check if dnc is available
if ! command -v dnc &> /dev/null; then
    echo "Error: dnc command not found. Please ensure Dana compiler is installed and in PATH."
    exit 1
fi

# Create output directory
mkdir -p wasm_output/app
mkdir -p wasm_output/resources
mkdir -p wasm_output/matmul

echo "Compiling Matmul component..."
dnc matmul/Matmul.dn -os ubc -chip 32 -sp resources -o wasm_output/matmul/Matmul.o

echo "Compiling BrowserWorkerLoop component..."
dnc app/BrowserWorkerLoop.dn -os ubc -chip 32 -sp resources -o wasm_output/app/BrowserWorkerLoop.o

echo "Compiling BrowserWorkerWasm (App entry point)..."
dnc app/BrowserWorkerWasm.dn -os ubc -chip 32 -sp resources -o wasm_output/app/BrowserWorkerWasm.o

echo ""
echo "=== Compilation Complete ==="
echo "Output files:"
echo "  - wasm_output/resources/BrowserWorkerLoop.o"
echo "  - wasm_output/app/BrowserWorkerLoopImpl.o"
echo "  - wasm_output/app/BrowserWorkerWasm.o"
echo ""
echo "Next steps:"
echo "  1. Package with file_packager (see package-worker-wasm.sh)"
echo "  2. Copy dana.js, dana.wasm, file_system.js to webserver/"
echo "  3. Open http://localhost:8080/worker-dana-wasm.html"

