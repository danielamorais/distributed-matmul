#!/bin/bash
# Git add commands for the current architecture:
# - Main App (WASM): app/main.dn + app/MainAppLoopImpl.dn
# - Server (Native Dana): app/CoordinatorApp.dn
# - Worker (WASM): app/BrowserWorkerWasm.dn + app/BrowserWorkerLoopImpl.dn

# Main App (WASM)
git add app/main.dn
git add app/MainAppLoopImpl.dn
git add resources/MainAppLoop.dn

# Server (Native Dana)
git add app/CoordinatorApp.dn
git add server/CoordinatorController.dn
git add server/CoordinatorServer.dn
git add server/StaticFileServerImpl.dn
git add resources/server/Coordinator.dn
git add resources/server/CoordinatorServer.dn
git add resources/server/StaticFileServer.dn

# Worker (WASM)
git add app/BrowserWorkerWasm.dn
git add app/BrowserWorkerLoopImpl.dn
git add resources/BrowserWorkerLoop.dn

# Common components
git add matmul/Matmul.dn
git add resources/matmul/Matmul.dn

# Compilation and packaging scripts
git add compile-main-wasm.sh
git add compile-worker-wasm.sh
git add package-main-wasm.sh
git add package-worker-wasm.sh

# System scripts
git add test-full-system.sh
git add start-full-system.sh
git add stop-full-system.sh

# HTML files
git add webserver/xdana.html
git add webserver/worker-dana-wasm.html

# Documentation
git add README_WASM.md

echo "All architecture files added to git staging area"

