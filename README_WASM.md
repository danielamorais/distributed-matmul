# Running the Distributed Matrix Multiplication Project in WASM

This guide explains how to compile, package, and run the distributed matrix multiplication application with the current architecture:

- **Main App (WASM)**: `app/main.dn` + `app/MainAppLoopImpl.dn` - Runs in browser, submits tasks, displays results
- **Server (Native Dana)**: `app/CoordinatorApp.dn` - Runs natively, handles API endpoints and task coordination
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

### Step 1: Compile and Package Everything

Run the full system test script to compile and package all components:

```bash
./test-full-system.sh
```

This script will:
- ✅ Compile coordinator (native Dana) - `app/CoordinatorApp.o`
- ✅ Compile main app (WASM) - `wasm_output/app/main.o`
- ✅ Compile worker (WASM) - `wasm_output/app/BrowserWorkerWasm.o`
- ✅ Package main app (creates `webserver/file_system_main.js`)
- ✅ Package worker (creates `webserver/file_system_worker.js`)
- ✅ Set up initial `file_system.js` (main app version)

**Environment Variables**:
- `DANA_WASM_DIR`: Should point to your Dana WASM runtime directory (default: `$HOME/Downloads/dana_wasm_32_[272]`)

### Step 2: Start the System

```bash
./start-full-system.sh
```

This will:
- Start coordinator on port **8080** (API endpoints)
- Start static file server on port **8081** (HTML/WASM files)
- Set `file_system.js` to main app version

### Step 3: Open in Browser

**Tab 1: Main App (Submit Tasks)**
```
http://localhost:8081/xdana.html
```
- Opens Dana UI window
- Enter matrices and submit tasks
- Displays results when ready

**Tab 2: Worker (Process Tasks)**
```bash
# First, switch to worker version
./switch-to-worker.sh

# Then open in browser
http://localhost:8081/worker-dana-wasm.html
```
- Opens worker that polls for tasks
- Processes matrix multiplication
- Submits results back

**You can open multiple worker tabs** for parallel processing!

### Step 4: Stop the System

```bash
./stop-full-system.sh
```

## Manual Building (Alternative)

If you prefer to build components separately:

### Compile Coordinator (Native Dana)

```bash
dnc app/CoordinatorApp.dn
dnc server/CoordinatorController.dn
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
│   └── CoordinatorApp.dn           # Coordinator server (Native Dana)
├── server/                         # Server components
│   ├── CoordinatorController.dn    # Task coordination logic
│   └── CoordinatorServer.dn       # HTTP server wrapper
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
│   ├── file_system.js             # Active version (switched as needed)
│   ├── xdana.html                 # Main app HTML page
│   └── worker-dana-wasm.html      # Worker HTML page
├── test-full-system.sh             # Compile and package everything
├── start-full-system.sh           # Start coordinator + static server
├── stop-full-system.sh            # Stop all services
├── switch-to-main.sh              # Switch to main app file system
└── switch-to-worker.sh            # Switch to worker file system
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

### Component Details

1. **Main App (WASM)**: `app/main.dn` + `app/MainAppLoopImpl.dn`
   - Entry point for the WASM module
   - Sets up `ProcessLoop` for non-blocking operation
   - Returns immediately from `main()` to allow browser responsiveness
   - Submits tasks via HTTP POST to coordinator
   - Polls for results via HTTP GET

2. **Coordinator (Native Dana)**: `app/CoordinatorApp.dn`
   - Runs as native Dana process (not WASM)
   - Handles HTTP requests via TCP sockets
   - Manages task queue and coordination
   - Provides REST API endpoints

3. **Worker (WASM)**: `app/BrowserWorkerWasm.dn` + `app/BrowserWorkerLoopImpl.dn`
   - Runs in browser as WASM
   - Uses `ProcessLoop` pattern for non-blocking operation
   - Polls coordinator for tasks
   - Computes matrix multiplication using `matmul.Matmul`
   - Submits results back to coordinator

4. **Matrix Multiplication**: `matmul/Matmul.dn`
   - Pure Dana computation component
   - Used by workers to perform calculations
   - No network dependencies


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
- Ensure all components were compiled with `-os ubc -chip 32`
- Check that `wasm_output/` contains all necessary `.o` files
- Verify `webserver/file_system.js` includes all components

**Error**: `Module not defined` or `dana.wasm not found`
- Ensure you're serving files from the `webserver/` directory
- Check browser console for detailed error messages
- Verify CORS is configured if accessing from a different domain

**Error**: `ProcessLoop blocking browser`
- The `loop()` function must return quickly (don't use blocking operations)
- Use `timer.sleep(0)` to yield control back to browser
- Make async calls with `asynch::`

### Performance Issues

**Browser becomes unresponsive**:
- Ensure `ProcessLoop:loop()` returns quickly (within milliseconds)
- Don't perform long-running computations in a single `loop()` call
- Break work into smaller chunks across multiple `loop()` calls

**Slow HTTP requests**:
- HTTP has more latency than TCP sockets
- Consider batching multiple operations
- Use compression for large data

## Testing the Application

### Verify System is Running

1. **Check Coordinator:**
   ```bash
   curl http://localhost:8080/health
   ```
   Should return: `{"status": "ok"}`

2. **Check Static Server:**
   ```bash
   curl http://localhost:8081/xdana.html
   ```
   Should return HTML content

### Test End-to-End Flow

1. **Open Main App:**
   - Navigate to `http://localhost:8081/xdana.html`
   - Open browser console (F12)
   - Look for: `[@MainAppWASM] Initializing MainAppLoop...`

2. **Open Worker:**
   - Run `./switch-to-worker.sh` (if not already done)
   - Navigate to `http://localhost:8081/worker-dana-wasm.html`
   - Open browser console (F12)
   - Look for: `[@BrowserWorkerWASM] Worker ID: worker-wasm-0`

3. **Submit Task:**
   - In Main App: Enter matrices (e.g., `[[1,2],[3,4]]` and `[[5,6],[7,8]]`)
   - Click "Submit"
   - Main App will submit task and start polling for result

4. **Process Task:**
   - Worker will poll coordinator and receive task
   - Worker will compute result
   - Worker will submit result back to coordinator

5. **Receive Result:**
   - Main App will receive result and display it

### Check Logs

```bash
# Coordinator logs
tail -f coordinator.log

# Static server logs
tail -f static-server.log
```

### Test API Endpoints

```bash
# Submit a task
curl -X POST http://localhost:8080/task \
  -H "Content-Type: application/json" \
  -d '{"matrixA": "[[1,2],[3,4]]", "matrixB": "[[5,6],[7,8]]"}'

# Check stats
curl http://localhost:8080/stats

# Get next task (from worker perspective)
curl "http://localhost:8080/task/next?workerId=test-worker"
```

## Development Tips

### Rebuilding After Changes

```bash
# Clean and rebuild everything
rm -rf wasm_output/*
./test-full-system.sh

# Or rebuild specific components:
# Main app only
./compile-main-wasm.sh
./package-main-wasm.sh

# Worker only
./compile-worker-wasm.sh
./package-worker-wasm.sh

# Coordinator only
dnc app/CoordinatorApp.dn
dnc server/CoordinatorController.dn

# Restart system
./stop-full-system.sh
./start-full-system.sh

# Refresh browser (hard refresh: Ctrl+Shift+R)
```

### Debugging

- Use browser DevTools console for runtime errors
- Check Network tab for failed requests
- Use Performance tab to monitor `loop()` execution time

### Adding New Components

1. Create `.dn` file in appropriate directory
2. Run `./test-full-system.sh` (compiles and packages everything)
3. Or run specific compile/package scripts for the component
4. Restart system and refresh browser

## API Endpoints

The coordinator (native Dana server) provides these endpoints:

- `POST /task` - Submit new task (from Main App)
  - Body: `{"matrixA": "[[1,2],[3,4]]", "matrixB": "[[5,6],[7,8]]"}`
  - Response: `{"taskId": 1}`

- `GET /task/next?workerId=X` - Get next task (from Worker)
  - Response: `{"taskId": 1, "dataA": "[[1,2],[3,4]]", "dataB": "[[5,6],[7,8]]"}` or `204 No Content`

- `POST /task/:id/result` - Submit result (from Worker)
  - Body: `{"result": "[[19,22],[43,50]]"}`
  - Response: `{"status": "ok"}`

- `GET /result/:id` - Get result (from Main App)
  - Response: `{"taskId": 1, "status": "completed", "result": "[[19,22],[43,50]]"}`

- `GET /stats` - View statistics
  - Response: `{"pending": 0, "processing": 1, "completed": 5}`

- `GET /health` - Health check
  - Response: `{"status": "ok"}`

All endpoints include CORS headers for browser access.

## Next Steps

1. **Build**: Run `./test-full-system.sh` to compile and package everything
2. **Run**: Run `./start-full-system.sh` to start coordinator and static server
3. **Test**: Open main app and worker in browser tabs
4. **Monitor**: Check logs and browser console for debugging
5. **Deploy**: Package `webserver/` directory for production deployment

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
5. Make sure you've switched to the correct file system:
   - Main app: `./switch-to-main.sh`
   - Worker: `./switch-to-worker.sh`

### Worker Not Receiving Tasks

1. Verify coordinator is running: `curl http://localhost:8080/health`
2. Check coordinator logs: `tail -f coordinator.log`
3. Verify worker is polling: Check browser console for worker logs
4. Check task queue: `curl http://localhost:8080/stats`
5. Ensure main app has submitted a task first

## Resources

- [Full System Test Guide](FULL_SYSTEM_TEST_README.md) - Complete testing instructions
- [Quick Start WASM](QUICK_START_WASM.md) - Quick start guide
- [Running Main and Workers WASM](RUNNING_MAIN_AND_WORKERS_WASM.md) - Detailed setup
- [Architecture Documentation](ARQUITETURA_SISTEMA_COMPLETO.md) - Complete architecture (Portuguese)
- [Dana Language Documentation](.cursor/rules/)
- [Emscripten Documentation](https://emscripten.org/docs/)
- [Main Project README](README.md)

## Support

For issues or questions:
1. Check browser console for errors
2. Review the troubleshooting section above
3. Consult the WASM migration documentation
4. Review the main `README.md` for general project information
