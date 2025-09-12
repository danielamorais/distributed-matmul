#!/bin/bash

# Compile Dana application to WASM
# Usage: ./compile-wasm.sh

set -e  # Exit on any error

echo "=== Compiling Dana application to WASM ==="

# Check if dnc is available
if ! command -v dnc &> /dev/null; then
    echo "Error: dnc command not found. Please ensure Dana compiler is installed and in PATH."
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p wasm_output

echo "Generating proxy files..."
python3 proxy_generator

echo "Compiling main application to WASM..."
dnc app/main.dn -os ubc -chip 32 -o wasm_output/App.o

echo "Compiling additional components..."

# Compile other necessary components
if [ -f "matmul/Matmul.dn" ]; then
    echo "Compiling Matmul component..."
    dnc matmul/Matmul.dn -os ubc -chip 32 -o wasm_output/Matmul.o
fi

if [ -f "server/Server.dn" ]; then
    echo "Compiling Server component..."
    dnc server/Server.dn -os ubc -chip 32 -o wasm_output/Server.o
fi

if [ -f "server/MatmulController.dn" ]; then
    echo "Compiling MatmulController component..."
    dnc server/MatmulController.dn -os ubc -chip 32 -o wasm_output/MatmulController.o
fi

# Compile network utilities
if [ -f "network/http/HTTPUtil.dn" ]; then
    echo "Compiling HTTPUtil component..."
    dnc network/http/HTTPUtil.dn -os ubc -chip 32 -o wasm_output/HTTPUtil.o
fi

if [ -f "network/rpc/RPCUtil.dn" ]; then
    echo "Compiling RPCUtil component..."
    dnc network/rpc/RPCUtil.dn -os ubc -chip 32 -o wasm_output/RPCUtil.o
fi

if [ -f "network/tcp/TCPUtil.dn" ]; then
    echo "Compiling TCPUtil component..."
    dnc network/tcp/TCPUtil.dn -os ubc -chip 32 -o wasm_output/TCPUtil.o
fi

# Compile monitoring components
if [ -f "monitoring/ResponseTime.dn" ]; then
    echo "Compiling ResponseTime component..."
    dnc monitoring/ResponseTime.dn -os ubc -chip 32 -o wasm_output/ResponseTime.o
fi

echo "=== WASM compilation complete ==="
echo "Output files are in the 'wasm_output' directory:"
ls -la wasm_output/

echo ""
echo "Main application compiled as: wasm_output/App.o"
echo "You can now use this WASM module in your web application."
