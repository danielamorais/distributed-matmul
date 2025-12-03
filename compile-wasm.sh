#!/bin/bash

# Compile Dana application to WASM
# Usage: ./compile-wasm.sh

# Don't exit on error - we want to collect all errors first
# set -e is removed to allow continuing after errors

echo "=== Compiling Dana application to WASM ==="

# Check if dnc is available
if ! command -v dnc &> /dev/null; then
    echo "Error: dnc command not found. Please ensure Dana compiler is installed and in PATH."
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p wasm_output

# Temporary file to store errors
ERROR_FILE=$(mktemp)
trap "rm -f $ERROR_FILE" EXIT

# echo "Generating proxy files..."
# python3 proxy_generator

#echo "Compiling main application to WASM..."
# dnc app/mainWasm.dn -os ubc -chip 32 -o wasm_output/App.o

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
    ! -path "./resources/*" | while read file; do
    # Get the relative path without extension
    rel_path="${file%.dn}"
    rel_path="${rel_path#./}"
    
    # Create output directory structure
    output_dir="wasm_output/$(dirname "$rel_path")"
    mkdir -p "$output_dir"
    
    # Get the output filename
    base_name=$(basename "$rel_path")
    output_file="$output_dir/$base_name.o"
    
    # Determine chip architecture:
    # - Workers (RemoteRepo.dn) need -chip 64 to run with native runtime (Architecture 8.1)
    # - Browser components need -chip 32 for browser WASM runtime (Architecture 4.1)
    CHIP_FLAG="-chip 32"
    if [[ "$file" == *"RemoteRepo.dn" ]]; then
        CHIP_FLAG="-chip 64"
        echo "Compiling worker $file -> $output_file (using -chip 64 for native runtime)"
    else
        echo "Compiling $file -> $output_file (using -chip 32 for browser WASM)"
    fi
    
    # Compile and capture errors directly to error file
    # Redirect stderr to stdout, then filter for error lines and append to error file
    dnc "$file" -os ubc $CHIP_FLAG -o "$output_file" 2>&1 | grep -i "error" >> "$ERROR_FILE" || true
done

# Print all errors at the end
if [ -s "$ERROR_FILE" ]; then
    echo ""
    # Print the error message in red
    echo -e "\033[0;31m=== Compilation Errors ===\033[0m"
    # Print the actual error contents in red as well
    while IFS= read -r line; do
        echo -e "\033[0;31m$line\033[0m"
    done < "$ERROR_FILE"
    echo ""
fi

echo "=== WASM compilation complete ==="
echo "Output files are in the 'wasm_output' directory:"
ls -la wasm_output/

echo ""
echo "Main application compiled as: wasm_output/App.o"
if [ -f "wasm_output/app/RemoteRepo.o" ]; then
    echo "Worker compiled as: wasm_output/app/RemoteRepo.o"
    echo "  Run with: ./run-wasm-worker.sh [PORT]"
fi
echo ""
echo "For Browser Workers PoC:"
echo "  1. Start Node.js server: cd webserver && node server.js"
echo "  2. Open workers: http://localhost:8080/worker-wasm.html"
echo "  3. Open main app: http://localhost:8080/xdana.html"
