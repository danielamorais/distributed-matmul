#!/bin/bash

# Browser Workers Coordinator - PoC
# 
# For this PoC, the coordinator logic is implemented directly in the Express server.
# This keeps things simple and avoids running multiple processes.
#
# Usage: ./run-coordinator.sh [PORT]
#   PORT: Port for the Express server (default: 8080)

PORT=${PORT:-${1:-8080}}

echo "═══════════════════════════════════════════════════════════"
echo "🚀 Starting Browser Workers Coordinator (PoC)"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Note: For this PoC, the coordinator is implemented in Express."
echo "      No separate Dana coordinator process is needed."
echo ""
echo "Starting Express server on port $PORT..."
echo ""

# Change to webserver directory and start Express
cd webserver
PORT=$PORT npm start

