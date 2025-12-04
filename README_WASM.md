# Running the Distributed Matrix Multiplication Project in WASM

This guide explains how to compile, package, and run the distributed matrix multiplication application with the current architecture:

- **Main App (WASM)**: `app/main.dn` + `app/MainAppLoopImpl.dn` - Runs in browser, submits tasks, displays results
- **Server (Native Dana)**: `ws/CoordinatorWeb.dn` - Runs natively, handles API endpoints and task coordination
- **Worker (WASM)**: `app/BrowserWorkerWasm.dn` + `app/BrowserWorkerLoopImpl.dn` - Runs in browser, polls for tasks, computes results

## Prerequisites

Before building the WASM version, ensure you have:

1. **Dana Compiler**: Installed and in your PATH
   ```bash
   dnc --version
   ```

2. **Emscripten SDK**: Required for packaging WASM files
   - Download from: https://emscripten.org/docs/getting_started/downloads.html
   - Ensure `file_packager` tool is available in your PATH
   ```bash
   file_packager --help
   ```

3. **Node.js**: For running the web server
   ```bash
   node --version
   ```

4. **Python 3**: Used by the compiler and proxy generator
   ```bash
   python3 --version
   ```

5. **Web Browser**: Modern browser supporting WebAssembly (Chrome, Firefox, Safari, Edge)

## Quick Start

### Step 1: Compile Everything

Run the compile script to build all native and WASM components:

```bash
./compile-all.sh
```

This script will:
- ✅ Compile coordinator server (native Dana) - e.g., `ws/CoordinatorWeb.o`
- ✅ Compile main app (WASM) - `wasm_output/app/main.o`
- ✅ Compile worker (WASM) - `wasm_output/app/BrowserWorkerWasm.o`

### Step 2: Package and Run the System

Run the start-up script, which packages the WASM files and starts the server:

```bash
./run-all.sh 8081
```

This will:
- Package main app (creates `webserver/file_system_main.js`)
- Package worker (creates `webserver/file_system_worker.js`)
- Start the coordinator and static file server on port **8081**

### Step 3: Open in Browser

**Tab 1: Main App (Submit Tasks)**
```
http://localhost:8081/xdana.html
```
- Opens Dana UI window
- Enter matrices and submit tasks
- Displays results when ready

**Tab 2: Worker (Process Tasks)**
```
http://localhost:8081/worker-dana-wasm.html
```
- Opens a worker that polls for tasks
- Processes matrix multiplication
- Submits results back

**You can open multiple worker tabs** for parallel processing!

### Step 4: Stop the System

Press `Ctrl+C` in the terminal where `run-all.sh` is running to stop the server.

## Manual Building (Alternative)

If you prefer to build components separately:

### Compile Coordinator (Native Dana)

```bash
dnc server/CoordinatorController.dn
dnc server/StaticFileServerImpl.dn
dnc ws/CoordinatorWeb.dn
```

### Compile Main App (WASM)

```bash
./compile-main-wasm.sh
```

This compiles:
- `app/main.dn` → `wasm_output/app/main.o`
- `app/MainAppLoopImpl.dn` → `wasm_output/app/MainAppLoopImpl.o`

### Compile Worker (WASM)

```bash
./compile-worker-wasm.sh
```

This compiles:
- `app/BrowserWorkerWasm.dn` → `wasm_output/app/BrowserWorkerWasm.o`
- `app/BrowserWorkerLoopImpl.dn` → `wasm_output/app/BrowserWorkerLoopImpl.o`

### Package WASM Files

**Package Main App:**
```bash
./package-main-wasm.sh
```
Creates `webserver/file_system_main.js`

**Package Worker:**
```bash
./package-worker-wasm.sh
```
Creates `webserver/file_system_worker.js`

## Project Structure

```
distributed-matmul/
├── app/                          # Application entry points
│   ├── main.dn                    # Main app entry (WASM)
│   ├── MainAppLoopImpl.dn         # Main app ProcessLoop implementation
│   ├── BrowserWorkerWasm.dn       # Worker entry (WASM)
│   ├── BrowserWorkerLoopImpl.dn   # Worker ProcessLoop implementation
│   └── CoordinatorApp.dn           # (Legacy) Coordinator server
├── server/                         # Server components
│   ├── CoordinatorController.dn    # Task coordination logic
│   └── StaticFileServerImpl.dn    # Static file server logic
├── ws/                             # Web server main component
│   └── CoordinatorWeb.dn          # Main server component
├── matmul/                         # Matrix multiplication
│   └── Matmul.dn                  # Core computation component
├── wasm_output/                    # Compiled WASM components (.o files)
│   ├── app/
│   │   ├── main.o                 # Main app compiled
│   │   ├── MainAppLoopImpl.o
│   │   ├── BrowserWorkerWasm.o    # Worker compiled
│   │   └── BrowserWorkerLoopImpl.o
│   └── matmul/
│       └── Matmul.o
├── webserver/                      # Web-ready WASM package
│   ├── dana.wasm                  # Dana WASM runtime
│   ├── dana.js                    # JavaScript loader
│   ├── file_system_main.js        # Main app file system
│   ├── file_system_worker.js      # Worker file system
│   ├── xdana.html                 # Main app HTML page
│   └── worker-dana-wasm.html      # Worker HTML page
├── compile-all.sh                # Compile all components
└── run-all.sh                    # Package WASM and run server
```

## Architecture Overview

```
┌─────────────────┐
│   Main App      │  (WASM in browser)
│  (xdana.html)   │
└────────┬────────┘
         │ HTTP POST /task
         │ HTTP GET /result/:id
         ▼
┌─────────────────┐
│ Coordinator and │  (Native Dana on a single port, e.g., 8081)
│ Static Server   │
└────────┬────────┘
         │ HTTP GET /task/next
         │ HTTP POST /task/:id/result
         ▲
┌─────────────────┐
│     Worker      │  (WASM in browser)
│ (worker-dana-   │
│   wasm.html)    │
└─────────────────┘

Static Files and API are served from the same port.
```

### Component Details

1. **Main App (WASM)**: `app/main.dn` + `app/MainAppLoopImpl.dn`
   - Entry point for the main WASM module.
   - Sets up `ProcessLoop` for non-blocking operation.
   - Submits tasks via HTTP POST to the coordinator.
   - Polls for results via HTTP GET.

2. **Coordinator (Native Dana)**: `ws/CoordinatorWeb.dn`
   - Runs as a native Dana process (not WASM).
   - Handles both API requests and serves static files (`.html`, `.js`, `.wasm`).
   - Manages the task queue and coordination.

3. **Worker (WASM)**: `app/BrowserWorkerWasm.dn` + `app/BrowserWorkerLoopImpl.dn`
   - Runs in a browser as a separate WASM module.
   - Uses the `ProcessLoop` pattern for non-blocking operation.
   - Polls the coordinator for tasks to process.
   - Computes matrix multiplication using `matmul.Matmul`.
   - Submits results back to the coordinator.

4. **Matrix Multiplication**: `matmul/Matmul.dn`
   - Pure Dana computation component.
   - Used by workers to perform calculations.
   - Has no network dependencies.


## Limitations in WASM

### ❌ Not Available in WASM

- `net.TCP`, `net.TCPServerSocket`, `net.TCPSocket`
- `net.UDP`, `net.DNS`, `net.SSL`
- Native libraries (`.dnl` files)
- Blocking I/O operations
- Direct socket binding/listening

### ✅ Available in WASM

- `net.http.HTTPRequest` for remote operations
- `ProcessLoop` pattern for non-blocking operations
- JSON parsing/serialization (`data.json.*`)
- Local computation (matrix multiplication)
- Composition and adaptation mechanisms
- Most `data.*` utilities

## Troubleshooting

### Compilation Errors

**Error**: `dnc command not found`
```bash
# Ensure Dana is installed and in PATH
export PATH=$PATH:/path/to/dana
```

**Error**: `file_packager command not found`
```bash
# Install Emscripten SDK
# See: https://emscripten.org/docs/getting_started/downloads.html
source emsdk_env.sh
```

### Runtime Errors

**Error**: `Cannot find component`
- Ensure all components were compiled with `-os ubc -chip 32` for WASM.
- Check that `wasm_output/` contains all necessary `.o` files.
- Verify `webserver/file_system_main.js` and `file_system_worker.js` include all required components.

**Error**: `Module not defined` or `dana.wasm not found`
- Ensure you're accessing the app via the server (e.g., `http://localhost:8081/xdana.html`).
- Check the browser console for detailed error messages.
- Verify CORS is configured if accessing from a different domain.

**Error**: `ProcessLoop blocking browser`
- The `loop()` function must return quickly (don't use blocking operations).
- Use `timer.sleep(0)` to yield control back to the browser.
- Make async calls with `asynch::`.

### Performance Issues

**Browser becomes unresponsive**:
- Ensure `ProcessLoop:loop()` returns quickly (within milliseconds).
- Don't perform long-running computations in a single `loop()` call.
- Break work into smaller chunks across multiple `loop()` calls.

**Slow HTTP requests**:
- HTTP has more latency than TCP sockets.
- Consider batching multiple operations.
- Use compression for large data.

## Testing the Application

### Verify System is Running

1. **Check Server:**
   ```bash
   curl http://localhost:8081/health
   ```
   Should return: `{"status": "ok"}`

2. **Check Static Content:**
   ```bash
   curl http://localhost:8081/xdana.html
   ```
   Should return HTML content.

### Test End-to-End Flow

1. **Open Main App:**
   - Navigate to `http://localhost:8081/xdana.html`
   - Open browser console (F12)
   - Look for: `[@MainAppWASM] Initializing MainAppLoop...`

2. **Open Worker:**
   - Navigate to `http://localhost:8081/worker-dana-wasm.html`
   - Open browser console (F12)
   - Look for: `[@BrowserWorkerWASM] Worker ID: worker-wasm-0`

3. **Submit Task:**
   - In Main App: Enter matrices (e.g., `[[1,2],[3,4]]` and `[[5,6],[7,8]]`)
   - Click "Submit"
   - The main app will submit the task and start polling for the result.

4. **Process Task:**
   - The worker will poll the coordinator and receive the task.
   - The worker will compute the result.
   - The worker will submit the result back to the coordinator.

5. **Receive Result:**
   - The Main App will receive the result and display it.

### Check Logs

The server prints logs directly to the console where `run-all.sh` was executed.

### Test API Endpoints

```bash
# Submit a task
curl -X POST http://localhost:8081/task \
  -H "Content-Type: application/json" \
  -d '{"matrixA": "[[1,2],[3,4]]", "matrixB": "[[5,6],[7,8]]"}'

# Check stats
curl http://localhost:8081/stats

# Get next task (from worker perspective)
curl "http://localhost:8081/task/next?workerId=test-worker"
```

## Development Tips

### Rebuilding After Changes

```bash
# Clean and rebuild everything
rm -rf wasm_output/* *.o server/*.o ws/*.o
./compile-all.sh
./run-all.sh

# Or rebuild specific components:
# Main app only
./compile-main-wasm.sh
./package-main-wasm.sh

# Worker only
./compile-worker-wasm.sh
./package-worker-wasm.sh

# Coordinator only
dnc ws/CoordinatorWeb.dn

# Restart server
# Press Ctrl+C and run ./run-all.sh again

# Refresh browser (hard refresh: Ctrl+Shift+R)
```

### Debugging

- Use browser DevTools console for runtime errors.
- Check the Network tab for failed requests.
- Use the Performance tab to monitor `loop()` execution time.

### Adding New Components

1. Create the `.dn` file in the appropriate directory.
2. Run `./compile-all.sh` to compile everything.
3. Run `./run-all.sh` to package and restart the server.
4. Refresh the browser.

## API Endpoints

The coordinator server provides these endpoints:

- `POST /task` - Submit a new task (from Main App)
  - Body: `{"matrixA": "[[1,2],[3,4]]", "matrixB": "[[5,6],[7,8]]"}`
  - Response: `{"taskId": 1}`

- `GET /task/next?workerId=X` - Get the next task (from Worker)
  - Response: `{"taskId": 1, "dataA": "[[1,2],[3,4]]", "dataB": "[[5,6],[7,8]]"}` or `204 No Content`

- `POST /task/:id/result` - Submit a result (from Worker)
  - Body: `{"result": "[[19,22],[43,50]]"}`
  - Response: `{"status": "ok"}`

- `GET /result/:id` - Get a result (from Main App)
  - Response: `{"taskId": 1, "status": "completed", "result": "[[19,22],[43,50]]"}`

- `GET /stats` - View statistics
  - Response: `{"pending": 0, "processing": 1, "completed": 5}`

- `GET /health` - Health check
  - Response: `{"status": "ok"}`

All endpoints include CORS headers for browser access.

## Next Steps

1. **Build**: Run `./compile-all.sh` to compile everything.
2. **Run**: Run `./run-all.sh` to package WASM files and start the server.
3. **Test**: Open the main app and worker in browser tabs.
4. **Monitor**: Check server logs and browser console for debugging.
5. **Deploy**: Package the `webserver/` directory for production deployment.

## Troubleshooting

### Port Already in Use

If the port (e.g., 8081) is already in use:

```bash
# Find process using the port
lsof -i :8081

# Kill the process (if needed)
kill <PID>

# Or use a different port
./run-all.sh 8082
```

### Coordinator Not Starting

Check server logs in the terminal.

Common issues:
- Missing compiled files: Run `./compile-all.sh` again.
- Port conflict: Use a different port.
- Permission issues: Check file permissions.

### WASM Not Loading

1. Check the browser console for errors.
2. Verify `file_system_main.js` and `file_system_worker.js` were created in `webserver/`.
3. Ensure the server is running and you are accessing it via `http://`.
4. Check that `dana.js` and `dana.wasm` are in the `webserver/` directory.
