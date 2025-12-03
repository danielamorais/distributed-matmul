# Full System Test: Coordinator + Main + Worker

## Overview

This document explains how to test the complete system with:
- **Coordinator**: Native Dana server (handles API endpoints)
- **Main App**: WASM application (submits tasks, displays results)
- **Worker**: WASM application (polls for tasks, computes results)

## Quick Start

### 1. Compile and Package Everything

```bash
./test-full-system.sh
```

This script will:
- ✅ Compile coordinator (native Dana)
- ✅ Compile main app (WASM)
- ✅ Compile worker (WASM)
- ✅ Package main app (creates `file_system_main.js`)
- ✅ Package worker (creates `file_system_worker.js`)
- ✅ Set up initial `file_system.js` (main app version)

### 2. Start the System

```bash
./start-full-system.sh
```

This will:
- Start coordinator on port **8080** (API endpoints)
- Start static file server on port **8081** (HTML/WASM files)
- Set `file_system.js` to main app version

### 3. Test in Browser

**Open Main App:**
```
http://localhost:8081/xdana.html
```

**Open Worker (in separate tab):**
```bash
# First, switch to worker version
./switch-to-worker.sh

# Then open in browser
http://localhost:8081/worker-dana-wasm.html
```

### 4. Stop the System

```bash
./stop-full-system.sh
```

## Architecture

```
┌─────────────────┐
│   Main App      │  (WASM in browser)
│  (xdana.html)   │
└────────┬────────┘
         │ HTTP POST /task
         │ HTTP GET /result/:id
         ▼
┌─────────────────┐
│   Coordinator   │  (Native Dana on port 8080)
│   (API Server)  │
└────────┬────────┘
         │ HTTP GET /task/next
         │ HTTP POST /task/:id/result
         ▲
┌─────────────────┐
│     Worker      │  (WASM in browser)
│ (worker-dana-   │
│   wasm.html)    │
└─────────────────┘

Static Files: Port 8081 (HTML, WASM, file_system.js)
```

## File System Setup

The system uses different `file_system.js` files for main app and worker:

- `webserver/file_system_main.js` - Main app WASM components
- `webserver/file_system_worker.js` - Worker WASM components
- `webserver/file_system.js` - Active version (switched as needed)

### Helper Scripts

- `./switch-to-main.sh` - Switch to main app version
- `./switch-to-worker.sh` - Switch to worker version

## Manual Testing Steps

### Step 1: Start Coordinator

```bash
# Option 1: Use start script (recommended)
./start-full-system.sh

# Option 2: Manual start
dana app/CoordinatorApp.o 8080 &
cd webserver && python3 -m http.server 8081 &
```

### Step 2: Test Main App

1. Ensure `file_system.js` is set to main app:
   ```bash
   ./switch-to-main.sh
   ```

2. Open in browser:
   ```
   http://localhost:8081/xdana.html
   ```

3. Enter matrices (e.g., `[[1,2],[3,4]]` and `[[5,6],[7,8]]`)

4. Click "Submit"

5. Main app will:
   - Submit task to `http://localhost:8080/task`
   - Poll for result at `http://localhost:8080/result/:id`
   - Display result when ready

### Step 3: Test Worker

1. Switch `file_system.js` to worker version:
   ```bash
   ./switch-to-worker.sh
   ```

2. Open in browser:
   ```
   http://localhost:8081/worker-dana-wasm.html
   ```

3. Worker will:
   - Poll coordinator at `http://localhost:8080/task/next`
   - Receive task (matrices A and B)
   - Compute result using Dana `matmul.Matmul` component
   - Submit result to `http://localhost:8080/task/:id/result`

### Step 4: Verify End-to-End Flow

1. **Main App** submits task → Coordinator stores task
2. **Worker** polls coordinator → Receives task
3. **Worker** computes result → Submits result to coordinator
4. **Main App** polls for result → Displays result

## API Endpoints

The coordinator provides these endpoints:

- `POST /task` - Submit new task (from Main App)
- `GET /task/next?workerId=X` - Get next task (from Worker)
- `POST /task/:id/result` - Submit result (from Worker)
- `GET /result/:id` - Get result (from Main App)
- `GET /stats` - View statistics
- `GET /health` - Health check

All endpoints include CORS headers for browser access.

## Troubleshooting

### Port Already in Use

If port 8080 or 8081 is already in use:

```bash
# Find process using port
lsof -i :8080
lsof -i :8081

# Kill process (if needed)
kill <PID>

# Or use different ports
./start-full-system.sh 8082 8083
```

### Coordinator Not Starting

Check logs:
```bash
cat coordinator.log
```

Common issues:
- Missing compiled files: Run `./test-full-system.sh` again
- Port conflict: Use different port
- Permission issues: Check file permissions

### WASM Not Loading

1. Check browser console for errors
2. Verify `file_system.js` is correct version:
   ```bash
   ls -lh webserver/file_system*.js
   ```
3. Ensure static file server is running on port 8081
4. Check that `dana.js` and `dana.wasm` are in `webserver/` directory

### Worker Not Receiving Tasks

1. Verify coordinator is running: `curl http://localhost:8080/health`
2. Check coordinator logs: `tail -f coordinator.log`
3. Verify worker is polling: Check browser console for worker logs
4. Check task queue: `curl http://localhost:8080/stats`

## Files Created

After running `test-full-system.sh`:

**Compiled Files:**
- `app/CoordinatorApp.o` - Coordinator entry point
- `server/CoordinatorServer.o` - HTTP server wrapper
- `server/CoordinatorController.o` - Task coordination logic
- `wasm_output/app/main.o` - Main app entry point
- `wasm_output/app/MainAppLoop.o` - Main app ProcessLoop
- `wasm_output/app/BrowserWorkerWasm.o` - Worker entry point
- `wasm_output/app/BrowserWorkerLoop.o` - Worker ProcessLoop
- `wasm_output/matmul/Matmul.o` - Matrix multiplication component

**Packaged Files:**
- `webserver/file_system_main.js` - Main app WASM package
- `webserver/file_system_worker.js` - Worker WASM package
- `webserver/file_system.js` - Active version
- `webserver/dana.js` - Dana WASM runtime
- `webserver/dana.wasm` - Dana WASM binary

## Scripts

- `test-full-system.sh` - Compile and package everything
- `start-full-system.sh` - Start coordinator and static file server
- `stop-full-system.sh` - Stop all services
- `switch-to-main.sh` - Switch file_system.js to main app
- `switch-to-worker.sh` - Switch file_system.js to worker

## Next Steps

1. Test with different matrix sizes
2. Test with multiple workers
3. Monitor performance and response times
4. Check coordinator statistics endpoint
5. Test error handling (invalid matrices, network issues)

## Notes

- The coordinator runs as a **native Dana** process (not WASM)
- Main app and worker run as **WASM** in the browser
- Both WASM apps make HTTP requests to the coordinator API
- Static files (HTML, WASM, JS) are served by Python's HTTP server
- You need to switch `file_system.js` between main and worker versions

