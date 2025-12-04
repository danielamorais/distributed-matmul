#!/bin/bash

# This script compiles all components for the project:
# 1. Native Dana components (like the Coordinator server)
# 2. Main App components for WASM
# 3. Worker components for WASM

# Exit immediately if a command exits with a non-zero status.
set -e

echo "========================================="
echo " STEP 1: Compiling all native Dana components..."
echo "========================================="
 dnc server/CoordinatorController.dn
    dnc server/StaticFileServerImpl.dn
    dnc ws/CoordinatorWeb.dn
echo "✅ Native components compiled successfully."
echo ""

echo "========================================="
echo " STEP 2: Compiling Main App for WASM..."
echo "========================================="
if [ -f ./compile-main-wasm.sh ]; then
    ./compile-main-wasm.sh
else
    echo "Error: compile-main-wasm.sh not found."
    exit 1
fi
echo "✅ Main App for WASM compiled successfully."
echo ""

echo "========================================="
echo " STEP 3: Compiling Worker for WASM..."
echo "========================================="
if [ -f ./compile-worker-wasm.sh ]; then
    ./compile-worker-wasm.sh
else
    echo "Error: compile-worker-wasm.sh not found."
    exit 1
fi
echo "✅ Worker for WASM compiled successfully."
echo ""

echo "========================================="
echo " All components compiled successfully! "
echo "========================================="
