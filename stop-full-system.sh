#!/bin/bash

# Stop Full System: Coordinator + Static File Server

echo "Stopping full system..."

if [ -f ".coordinator.pid" ]; then
    COORDINATOR_PID=$(cat .coordinator.pid)
    if kill -0 $COORDINATOR_PID 2>/dev/null; then
        kill $COORDINATOR_PID
        echo "✓ Stopped coordinator (PID: $COORDINATOR_PID)"
    else
        echo "⚠ Coordinator process not running"
    fi
    rm .coordinator.pid
else
    echo "⚠ No coordinator PID file found"
fi

if [ -f ".static.pid" ]; then
    STATIC_PID=$(cat .static.pid)
    if kill -0 $STATIC_PID 2>/dev/null; then
        kill $STATIC_PID
        echo "✓ Stopped static file server (PID: $STATIC_PID)"
    else
        echo "⚠ Static file server process not running"
    fi
    rm .static.pid
else
    echo "⚠ No static server PID file found"
fi

echo "Done!"

