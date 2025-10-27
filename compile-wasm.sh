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

# echo "Generating proxy files..."
# python3 proxy_generator

echo "Compiling main application to WASM..."
dnc app/mainWasm.dn -os ubc -chip 32 -o wasm_output/App.o

# echo "Compiling additional components..."

# if [ -f "server/ServerWasm.dn" ]; then
#      echo "Compiling Server component..."
#      dnc server/ServerWasm.dn -os ubc -chip 32 -o wasm_output/server/ServerWasm.o
# fi

# Compile all .dn files to WASM
echo "Compiling all .dn files to WASM..."
find . -name "*.dn" -type f \
    ! -path "./wasm_output/*" \
    ! -path "./webserver/*" \
    ! -path "./.git/*" \
    ! -path "./results/*" \
    ! -path "./testing/*" \
    ! -path "./proxy_generator/*" \
    ! -name "mainWasm.dn" | while read file; do
    # Get the relative path without extension
    rel_path="${file%.dn}"
    rel_path="${rel_path#./}"
    
    # Create output directory structure
    output_dir="wasm_output/$(dirname "$rel_path")"
    mkdir -p "$output_dir"
    
    # Get the output filename
    base_name=$(basename "$rel_path")
    output_file="$output_dir/$base_name.o"
    
    echo "Compiling $file -> $output_file"
    dnc "$file" -os ubc -chip 32 -o "$output_file"
done

# Compile other necessary components
# if [ -f "matmul/Matmul.dn" ]; then
#     echo "Compiling Matmul component..."
#     dnc matmul/Matmul.dn -os ubc -chip 32 -o wasm_output/Matmul.o
# fi

# if [ -f "server/MatmulController.dn" ]; then
#     echo "Compiling MatmulController component..."
#     dnc server/MatmulController.dn -os ubc -chip 32 -o wasm_output/MatmulController.o
# fi

# # Compile network utilities
# if [ -f "network/http/HTTPUtil.dn" ]; then
#     echo "Compiling HTTPUtil component..."
#     dnc network/http/HTTPUtil.dn -os ubc -chip 32 -o wasm_output/HTTPUtil.o
# fi

# if [ -f "network/rpc/RPCUtil.dn" ]; then
#     echo "Compiling RPCUtil component..."
#     dnc network/rpc/RPCUtil.dn -os ubc -chip 32 -o wasm_output/RPCUtil.o
# fi

# if [ -f "network/tcp/TCPUtil.dn" ]; then
#     echo "Compiling TCPUtil component..."
#     dnc network/tcp/TCPUtil.dn -os ubc -chip 32 -o wasm_output/TCPUtil.o
# fi

# # Compile monitoring components
# if [ -f "monitoring/ResponseTime.dn" ]; then
#     echo "Compiling ResponseTime component..."
#     dnc monitoring/ResponseTime.dn -os ubc -chip 32 -o wasm_output/ResponseTime.o
# fi

echo "=== WASM compilation complete ==="
echo "Output files are in the 'wasm_output' directory:"
ls -la wasm_output/

echo ""
echo "Main application compiled as: wasm_output/App.o"
echo "You can now use this WASM module in your web application."
