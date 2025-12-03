#!/bin/bash
# Run coordinator using ws.core web framework

PORT=${1:-8080}

echo "========================================"
echo "  Dana Coordinator (ws.core)"
echo "========================================"
echo "Starting coordinator on port $PORT"
echo "Using ws.core web framework"
echo ""
echo "Endpoints:"
echo "  POST /task           - Submit new task"
echo "  GET  /task/next      - Worker requests next task"
echo "  POST /task/:id/result - Worker submits result"
echo "  GET  /result/:id     - Get task result"
echo "  GET  /stats          - View statistics"
echo "  GET  /health         - Health check"
echo "  GET  /*              - Static files (HTML, WASM, JS)"
echo "========================================"
echo ""

# Run ws.core with the compiled Web.o component
dana ws.core -p $PORT

