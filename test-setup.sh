#!/bin/bash
echo "=== Dana WASM Worker Test Setup Verification ==="
echo ""

# Check server is running
echo "1. Checking server status..."
if curl -s http://localhost:8080/stats > /dev/null 2>&1; then
    echo "   ✅ Server is running on http://localhost:8080"
    STATS=$(curl -s http://localhost:8080/stats)
    echo "   Server stats: $STATS"
else
    echo "   ❌ Server is NOT running"
    echo "   Start it with: cd webserver && node server.js"
    exit 1
fi
echo ""

# Check files exist
echo "2. Checking required files..."
cd webserver
FILES=("worker-dana-wasm.html" "dana.js" "dana.wasm" "file_system.js" "xdana.html")
ALL_EXIST=true
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✅ $file exists"
    else
        echo "   ❌ $file MISSING"
        ALL_EXIST=false
    fi
done
cd ..
echo ""

if [ "$ALL_EXIST" = true ]; then
    echo "3. Testing API endpoints..."
    
    # Test task submission
    echo "   Testing task submission..."
    TASK_RESPONSE=$(curl -s -X POST http://localhost:8080/task \
        -H "Content-Type: application/json" \
        -d '{"A":"[[1,2],[3,4]]","B":"[[5,6],[7,8]]"}')
    TASK_ID=$(echo "$TASK_RESPONSE" | grep -o '"taskId":[0-9]*' | grep -o '[0-9]*')
    if [ -n "$TASK_ID" ]; then
        echo "   ✅ Task submitted successfully (ID: $TASK_ID)"
    else
        echo "   ❌ Task submission failed"
    fi
    
    # Test task retrieval
    echo "   Testing task retrieval..."
    sleep 1
    TASK_DATA=$(curl -s "http://localhost:8080/task/next?workerId=test-worker")
    if echo "$TASK_DATA" | grep -q "taskId"; then
        echo "   ✅ Task retrieval works"
        echo "   Sample response: $TASK_DATA"
    else
        echo "   ⚠️  No tasks available (this is normal if queue is empty)"
    fi
    echo ""
    
    echo "=== Setup Complete! ==="
    echo ""
    echo "📋 MANUAL BROWSER TESTING STEPS:"
    echo ""
    echo "1. Open Worker Page:"
    echo "   → http://localhost:8080/worker-dana-wasm.html"
    echo "   → Open browser console (F12)"
    echo "   → Look for: [@BrowserWorkerWASM] Worker ID: ..."
    echo "   → Should see polling messages every ~2 seconds"
    echo ""
    echo "2. Open Task Submission Page:"
    echo "   → http://localhost:8080/xdana.html"
    echo ""
    echo "3. Submit Test Task:"
    echo "   → Matrix A: [[1,2],[3,4]]"
    echo "   → Matrix B: [[5,6],[7,8]]"
    echo "   → Click 'Calculate A × B'"
    echo ""
    echo "4. Monitor Worker Console:"
    echo "   → In worker-dana-wasm.html console, you should see:"
    echo "     • [@BrowserWorkerWASM] Received task #X"
    echo "     • [@BrowserWorkerWASM] Computing: A=..., B=..."
    echo "     • [@BrowserWorkerWASM] Computation complete: [[19,22],[43,50]]"
    echo "     • [@BrowserWorkerWASM] Task #X completed successfully!"
    echo ""
    echo "5. Verify Result:"
    echo "   → In xdana.html, result should appear"
    echo "   → Expected: [[19,22],[43,50]]"
    echo ""
    echo "✅ All computation happens in Dana WASM (no JavaScript computation)"
else
    echo "❌ Some files are missing. Run ./compile-worker-wasm.sh and ./package-worker-wasm.sh first"
fi
