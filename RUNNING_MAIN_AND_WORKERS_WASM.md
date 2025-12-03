# Running Main App WASM with Workers WASM - Complete Guide

## Current Status Check

### Are Workers Running?

**Check for running workers:**
```bash
# Check for browser workers (they run in browser tabs, not as processes)
# Open browser console at http://localhost:8080/worker-dana-wasm.html
# Look for: "[@BrowserWorkerWASM] Worker ID: worker-wasm-0"

# Check for remote workers (separate processes)
ps aux | grep -E "(dana|RemoteRepo)" | grep -v grep
```

**Current Status:** No workers are currently running (as of last check).

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│ Browser Tab 1: Main App WASM (xdana.html)                 │
│   └─> app/main.o (MainAppLoop)                              │
│       └─> Submits tasks via HTTP POST /matmul               │
│       └─> Polls results via HTTP GET /result/:id            │
└─────────────────────────────────────────────────────────────┘
                          ↓ HTTP
┌─────────────────────────────────────────────────────────────┐
│ Node.js Server (server.js)                                  │
│   └─> Coordinator endpoints:                                │
│       - POST /matmul → Creates task                         │
│       - GET /task/next → Workers poll for tasks              │
│       - POST /task/:id/result → Workers submit results      │
│       - GET /result/:id → Main app polls for results       │
└─────────────────────────────────────────────────────────────┘
                          ↓ HTTP
┌─────────────────────────────────────────────────────────────┐
│ Browser Tab 2: Worker WASM (worker-dana-wasm.html)         │
│   └─> app/BrowserWorkerWasm.o (BrowserWorkerLoop)          │
│       └─> Polls coordinator via GET /task/next             │
│       └─> Computes with matmul.Matmul                      │
│       └─> Submits results via POST /task/:id/result        │
└─────────────────────────────────────────────────────────────┘
```

## Step-by-Step Setup

### Step 1: Compile Main App for WASM

```bash
# Compile main app components
dnc app/main.dn -os ubc -chip 32 -sp resources -o wasm_output/app/main.o
dnc app/MainAppLoop.dn -os ubc -chip 32 -sp resources -o wasm_output/app/MainAppLoop.o

# Also compile matmul (if not already compiled)
dnc matmul/Matmul.dn -os ubc -chip 32 -sp resources -o wasm_output/matmul/Matmul.o
```

**Or use the compilation script (if it exists):**
```bash
./compile-main-wasm.sh  # Create this if it doesn't exist
```

### Step 2: Package Main App for WASM

```bash
# Get Dana WASM runtime location
DANA_WASM_DIR="${DANA_WASM_DIR:-$HOME/Downloads/dana_wasm_32_[272]}"

# Package main app with file_packager
file_packager dana.wasm \
    --embed wasm_output/app/main.o@app/main.o \
    --embed wasm_output/app/MainAppLoop.o@app/MainAppLoop.o \
    --embed wasm_output/matmul/Matmul.o@matmul/Matmul.o \
    --embed "$DANA_WASM_DIR/components/@components" \
    --js-output=file_system_main.js

# Copy to webserver
cp "$DANA_WASM_DIR/dana.js" webserver/dana_main.js
cp "$DANA_WASM_DIR/dana.wasm" webserver/dana_main.wasm
cp file_system_main.js webserver/
```

**Or use the packaging script (if it exists):**
```bash
./package-main-wasm.sh  # Create this if it doesn't exist
```

### Step 3: Compile Workers for WASM

```bash
# Compile worker components
./compile-worker-wasm.sh
```

This creates:
- `wasm_output/app/BrowserWorkerWasm.o`
- `wasm_output/app/BrowserWorkerLoop.o`
- `wasm_output/matmul/Matmul.o`

### Step 4: Package Workers for WASM

```bash
# Package workers with file_packager
./package-worker-wasm.sh
```

This creates `webserver/file_system.js` with worker components.

### Step 5: Update HTML Files

**Update `webserver/xdana.html` to load main app:**
```html
<script>
Module['arguments'] = ['-dh', '.', 'app/main.o'];
</script>
<script src="file_system_main.js"></script>
<script async src="dana_main.js"></script>
```

**Verify `webserver/worker-dana-wasm.html` loads workers:**
```html
<script>
Module['arguments'] = ['-dh', '.', 'app/BrowserWorkerWasm.o'];
</script>
<script src="file_system.js"></script>
<script async src="dana.js"></script>
```

### Step 6: Start Node.js Server

```bash
cd webserver
node server.js
```

The server will:
- Listen on port 8080
- Handle coordinator endpoints (`/matmul`, `/task/next`, `/result/:id`)
- Serve HTML files for main app and workers

### Step 7: Open Browser Tabs

**Tab 1: Main App (Submit Tasks)**
```
http://localhost:8080/xdana.html
```
- Opens Dana WASM main app
- Shows UI with matrix input fields
- Submits tasks and polls for results

**Tab 2: Worker (Process Tasks)**
```
http://localhost:8080/worker-dana-wasm.html
```
- Opens Dana WASM worker
- Polls coordinator for tasks
- Computes matrix multiplication
- Submits results back

**You can open multiple worker tabs** to have multiple workers processing tasks in parallel!

## Verification

### Check Main App is Running

1. Open `http://localhost:8080/xdana.html`
2. Check browser console for:
   ```
   [@MainAppWASM] Initializing MainAppLoop...
   [@MainAppWASM] ProcessLoop registered
   [@MainAppWASM] IOLayer initialized
   ```
3. You should see a Dana UI window with:
   - TextArea for matrix A
   - TextArea for matrix B
   - Submit button
   - Status and result labels

### Check Workers are Running

1. Open `http://localhost:8080/worker-dana-wasm.html`
2. Check browser console for:
   ```
   [@BrowserWorkerWASM] Initializing...
   [@BrowserWorkerWASM] ProcessLoop registered
   [@BrowserWorkerWASM] Worker ID: worker-wasm-0
   [@BrowserWorkerWASM] Polling for tasks...
   ```
3. You should see periodic polling messages every ~2 seconds

### Test End-to-End

1. **In Main App tab:**
   - Enter matrix A: `[[1,2],[3,4]]`
   - Enter matrix B: `[[5,6],[7,8]]`
   - Click Submit

2. **In Worker tab:**
   - Should see: `[@BrowserWorkerWASM] Received task #1`
   - Should see: `[@BrowserWorkerWASM] Computing...`
   - Should see: `[@BrowserWorkerWASM] Task #1 completed successfully!`

3. **In Main App tab:**
   - Should see result displayed in result label
   - Status should show "Result received"

## Troubleshooting

### Issue: Main App Not Loading

**Symptoms:**
- Browser console shows errors loading `app/main.o`
- `file_system_main.js` not found

**Solution:**
1. Verify compilation: `ls wasm_output/app/main.o`
2. Verify packaging: `ls webserver/file_system_main.js`
3. Check HTML file references correct file names

### Issue: Workers Not Polling

**Symptoms:**
- Worker tab shows no polling messages
- Console shows errors

**Solution:**
1. Verify worker compilation: `ls wasm_output/app/BrowserWorkerWasm.o`
2. Verify packaging: `ls webserver/file_system.js`
3. Check server is running: `curl http://localhost:8080/task/next`

### Issue: Tasks Not Being Processed

**Symptoms:**
- Main app submits task but no result
- Workers not receiving tasks

**Solution:**
1. Check server logs for errors
2. Verify coordinator endpoints are working:
   ```bash
   # Test task submission
   curl -X POST http://localhost:8080/matmul \
     -H "Content-Type: application/json" \
     -d '{"A":[[1,2],[3,4]],"B":[[5,6],[7,8]]}'
   
   # Test worker polling
   curl http://localhost:8080/task/next?workerId=test-worker
   ```
3. Check browser console for HTTP errors (CORS, network, etc.)

### Issue: Multiple Workers Not Working

**Solution:**
- Each worker tab is independent
- Each worker gets a unique ID automatically
- Open multiple tabs with `worker-dana-wasm.html`
- All workers will poll and process tasks in parallel

## Quick Start Script

Create `start-all-wasm.sh`:

```bash
#!/bin/bash

echo "=== Starting Distributed Matrix Multiplication (WASM) ==="

# Step 1: Compile
echo "1. Compiling main app..."
dnc app/main.dn -os ubc -chip 32 -sp resources -o wasm_output/app/main.o
dnc app/MainAppLoop.dn -os ubc -chip 32 -sp resources -o wasm_output/app/MainAppLoop.o

echo "2. Compiling workers..."
./compile-worker-wasm.sh

# Step 2: Package
echo "3. Packaging main app..."
./package-main-wasm.sh  # Create this script

echo "4. Packaging workers..."
./package-worker-wasm.sh

# Step 3: Start server
echo "5. Starting Node.js server..."
cd webserver
node server.js &
SERVER_PID=$!

echo ""
echo "=== Setup Complete ==="
echo "Server running on http://localhost:8080"
echo ""
echo "Open in browser:"
echo "  - Main App: http://localhost:8080/xdana.html"
echo "  - Worker:   http://localhost:8080/worker-dana-wasm.html"
echo ""
echo "Press Ctrl+C to stop server (PID: $SERVER_PID)"
echo ""

# Wait for Ctrl+C
trap "kill $SERVER_PID; exit" INT TERM
wait $SERVER_PID
```

## Architecture Notes

### Why Two Separate file_system.js Files?

- **Main App** uses `file_system_main.js` with `app/main.o`
- **Workers** use `file_system.js` with `app/BrowserWorkerWasm.o`
- Each has different entry points and components
- Both can run simultaneously in different browser tabs

### Communication Flow

1. **Main App** → `POST /matmul` → **Server** (creates task)
2. **Server** → Returns `{taskId: 1}`
3. **Main App** → `GET /result/1` (polls for result)
4. **Worker** → `GET /task/next` → **Server** (gets task)
5. **Worker** → Computes with `matmul.Matmul`
6. **Worker** → `POST /task/1/result` → **Server** (submits result)
7. **Server** → Stores result
8. **Main App** → `GET /result/1` → **Server** (gets result)
9. **Main App** → Displays result in UI

### Performance

- **Multiple Workers**: Open multiple `worker-dana-wasm.html` tabs for parallel processing
- **Task Distribution**: Server distributes tasks to available workers
- **Polling Interval**: Workers poll every ~2 seconds (configurable in `BrowserWorkerLoopImpl.dn`)

## Next Steps

1. ✅ Compile main app and workers
2. ✅ Package both for WASM
3. ✅ Start server
4. ✅ Open main app tab
5. ✅ Open worker tab(s)
6. ✅ Test end-to-end workflow
7. ✅ Monitor performance with multiple workers

## References

- `main-in-wasm.md` - Main app WASM migration plan
- `WASM_WORKER_MIGRATION.md` - Worker WASM migration guide
- `app/MainAppLoop.dn` - Main app ProcessLoop implementation
- `app/BrowserWorkerLoopImpl.dn` - Worker ProcessLoop implementation
- `webserver/server.js` - Coordinator server
- `webserver/howto.md` - Dana UI examples

