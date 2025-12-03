#!/bin/bash

# Compile the Dana WebServer with explicit component wiring

set -e

echo "========================================="
echo "  Compiling Dana WebServer"
echo "========================================="
echo ""

# Compile all components
echo "Compiling Coordinator..."
dnc server/CoordinatorController.dn

echo "Compiling StaticFileServer..."
dnc server/StaticFileServerImpl.dn

echo "Compiling WebServer..."
dnc server/WebServerImpl.dn

echo "Compiling WebServerProcessLoop..."
dnc server/WebServerProcessLoop.dn

echo "Compiling WebServerApp (linking all components)..."
dnc app/WebServerApp.dn -o app/WebServerApp.o \
    server/WebServerProcessLoop.o \
    server/WebServerImpl.o \
    server/CoordinatorController.o \
    server/StaticFileServerImpl.o

echo ""
echo "✅ Compilation complete!"
echo ""
echo "Run with: dana app/WebServerApp.o 3"
echo ""

