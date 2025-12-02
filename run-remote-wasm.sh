#!/bin/bash

# Run RemoteRepo worker for WASM setup
# Usage: ./run-remote-wasm.sh [PORT] [APP_PORT]
#   PORT: Port for the HTTP server (default: 8081)
#   APP_PORT: Application port (optional, default: same as PORT)

# Set default port if not provided
PORT=${1:-8081}
APP_PORT=${2:-$PORT}

# Check if dana command is available
if ! command -v dana &> /dev/null; then
    echo "Error: dana command not found. Please ensure Dana runtime is installed and in PATH."
    exit 1
fi

# Check if RemoteRepo.o exists, if not compile it
if [ ! -f "app/RemoteRepo.o" ]; then
    echo "RemoteRepo.o not found. Compiling RemoteRepo.dn..."
    
    # Check if dnc is available
    if ! command -v dnc &> /dev/null; then
        echo "Error: dnc command not found. Cannot compile RemoteRepo.dn."
        echo "Please ensure Dana compiler is installed and in PATH."
        exit 1
    fi
    
    # Compile RemoteRepo.dn natively (NOT WASM)
    echo "Compiling app/RemoteRepo.dn to native binary..."
    dnc app/RemoteRepo.dn -o app/RemoteRepo.o
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to compile RemoteRepo.dn"
        exit 1
    fi
    
    echo "RemoteRepo.dn compiled successfully."
fi

# Check if required dependencies are compiled
# RemoteRepo depends on server/Remote.matmul.dn and matmul/Matmul.dn
if [ ! -f "server/Remote.matmul.o" ]; then
    echo "Warning: server/Remote.matmul.o not found. Compiling dependencies..."
    if command -v dnc &> /dev/null; then
        dnc server/Remote.matmul.dn -o server/Remote.matmul.o 2>/dev/null || true
    fi
fi

if [ ! -f "matmul/Matmul.o" ]; then
    echo "Warning: matmul/Matmul.o not found. Compiling dependencies..."
    if command -v dnc &> /dev/null; then
        dnc matmul/Matmul.dn -o matmul/Matmul.o 2>/dev/null || true
    fi
fi

echo "=== Starting RemoteRepo worker for WASM setup ==="
echo "Port: $PORT"
echo "App Port: $APP_PORT"
echo ""
echo "This worker will:"
echo "  - Listen for HTTP requests on port $PORT"
echo "  - Accept RPC requests from WASM applications"
echo "  - Process matrix multiplication requests"
echo ""
echo "Note: This is a NATIVE Dana process (not WASM)."
echo "      WASM apps in the browser will make HTTP requests to this worker."
echo ""

# Run RemoteRepo with specified ports
dana app/RemoteRepo.o $PORT $APP_PORT

