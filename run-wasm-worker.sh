#!/bin/bash

# Run WASM-compiled RemoteRepo worker using Dana native runtime
# 
# This script runs WASM-compiled workers (compiled with -os ubc -chip 64)
# using Dana's native runtime. Workers are compiled with -chip 64 (Architecture 8.1)
# to be compatible with the native Dana runtime, while still using WASM format.
# WASM-compiled files can use TCP sockets when run with the native runtime.
#
# Usage: ./run-wasm-worker.sh [PORT]
#   PORT: Port for the HTTP server (default: 8081)

# Set default port if not provided
# Check environment variable first, then command line argument, then default
PORT=${PORT:-${1:-8081}}

# Check if dana command is available
if ! command -v dana &> /dev/null; then
    echo "Error: dana command not found. Please ensure Dana runtime is installed and in PATH."
    exit 1
fi

# Check if WASM-compiled RemoteRepo exists
if [ ! -f "wasm_output/app/RemoteRepo.o" ]; then
    echo "Error: wasm_output/app/RemoteRepo.o not found"
    echo "Please run ./compile-wasm.sh first to compile RemoteRepo.dn to WASM format"
    exit 1
fi

echo "=== Starting WASM-compiled RemoteRepo worker ==="
echo "Port: $PORT"
echo ""
echo "This worker:"
echo "  - Is compiled to WASM format (wasm_output/app/RemoteRepo.o)"
echo "  - Runs using Dana native runtime"
echo "  - Can listen on TCP sockets (running natively, not in browser)"
echo "  - Accepts HTTP requests on port $PORT"
echo "  - Processes RPC requests from WASM applications"
echo ""

# Run WASM-compiled worker with Dana runtime
dana wasm_output/app/RemoteRepo.o $PORT

