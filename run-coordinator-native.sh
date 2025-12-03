#!/bin/bash

# Run the native Dana coordinator server
# Usage: ./run-coordinator-native.sh [PORT]

PORT=${1:-8080}

echo "═══════════════════════════════════════════════════════════"
echo "🚀 Starting Native Dana Coordinator"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Port: $PORT"
echo ""

# Check if CoordinatorApp.o exists
if [ ! -f "CoordinatorApp.o" ]; then
    echo "❌ Error: CoordinatorApp.o not found"
    echo ""
    echo "Please compile first:"
    echo "  dnc app/CoordinatorApp.dn"
    echo "  dnc server/CoordinatorServer.dn"
    exit 1
fi

# Check if port is already in use
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo "⚠️  Warning: Port $PORT is already in use"
    echo ""
    echo "To find the process using this port:"
    echo "  lsof -i :$PORT"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Starting coordinator..."
echo ""

# Run the coordinator
dana CoordinatorApp.o $PORT

