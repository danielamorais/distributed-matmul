#!/bin/bash

# Run the Dana WebServer (replacing Express.js)
# This script compiles and runs the pure Dana web server

set -e

echo "========================================="
echo "  Dana Web Server Launcher"
echo "========================================="
echo ""

# Check if compiled
if [ ! -f "app/WebServerApp.o" ]; then
    echo "Compiling Dana WebServer..."
    dnc app/WebServerApp.dn
    echo "Compilation complete!"
    echo ""
fi

# Get mode from argument (default: local mode = 3)
MODE=${1:-3}

echo "Starting Dana Web Server (mode: $MODE)..."
echo "  Mode 1 = Proxy"
echo "  Mode 2 = Adaptive"
echo "  Mode 3 = Local"
echo ""

dana app/WebServerApp.o $MODE



