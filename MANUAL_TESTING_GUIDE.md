# Manual Testing Guide

This guide provides step-by-step processes to manually test the distributed matrix multiplication application.

## Testing Options

1. **[Browser Workers PoC](#browser-workers-poc)** - NEW! ⭐ **Recommended for quick testing**
   - Simplest approach, pure browser-based workers
   - No compilation needed
   - Works on any machine with a browser
   - Perfect for demos and testing the coordination pattern

2. **[Native Workers (WASM)](#native-workers-wasm)** - Original architecture
   - Workers run as native Dana processes
   - Requires compilation and Dana runtime
   - Better performance for production use
   - More complex setup

**Quick Start:** If you just want to see it working, go with option 1 (Browser Workers PoC).

---

# Browser Workers PoC

## Overview

Simple proof of concept where **workers run entirely in browsers** on different machines. Workers poll a coordinator for tasks instead of listening on ports.

**Why Browser Workers?**
- ✅ Browsers **can't listen on TCP ports** (security restriction)
- ✅ Solution: Workers **poll** for tasks via HTTP GET
- ✅ No server deployment needed for workers
- ✅ True distributed computing - any browser, anywhere

**Architecture:**
```
┌─────────────────────────────────────────┐
│  Express Server (localhost:8080)        │
│  • Serves static files                  │
│  • Coordinator API (task queue)         │
│  • Endpoints: /task, /task/next, etc    │
└─────────────────────────────────────────┘
            ↑
            │ HTTP: Poll & Submit
            │
┌───────────┴──────────┬──────────┬───────┐
│ Browser Worker 1     │ Worker 2 │ ... N │
│ (Machine A)          │ (Mach B) │       │
│ • Poll /task/next    │ Same     │ Same  │
│ • Compute (JS)       │          │       │
│ • Submit result      │          │       │
└──────────────────────┴──────────┴───────┘
```

## Prerequisites

- **Node.js**: For running the Express server
- **Modern Web Browser**: Chrome, Firefox, Safari, or Edge

## Step 1: Start the Express Server

```bash
cd webserver
npm start
```

Or use the shortcut:
```bash
./run-coordinator.sh
```

The server will start on `http://localhost:8080`

You should see:
```
✅ Server with COOP/COEP headers running at http://localhost:8080
```

## Step 2: Open Worker Pages

Open `worker.html` in multiple browsers/tabs/machines:

**Same machine (multiple tabs):**
```
http://localhost:8080/worker.html
```

**Different machines:**
```
http://SERVER_IP:8080/worker.html
```

On each worker page:
1. You'll see a unique Worker ID
2. Click **"Start Worker"** button
3. Worker will start polling for tasks every 2 seconds

**Tip:** Open 2-3 worker tabs to see distributed processing in action!

## Step 3: Submit Tasks

You have two options to submit tasks:

### Option A: Use Coordinator API (Recommended for PoC)

See Step 4 below for using curl or any HTTP client to submit tasks directly to the coordinator.

### Option B: Use xdana.html (requires native workers)

**Note:** The current `xdana.html` uses the old architecture and forwards requests to native Dana workers on ports 8081/8082. To use it with Browser Workers, you would need to:

1. Start native workers (see Native Workers section)
2. Or modify `xdana.html` to submit tasks via `/task` endpoint instead of `/matmul`

For testing the Browser Workers PoC, **use Option A** (Step 4).

## Step 4: Test with Coordinator API Directly

You can test the coordinator API directly:

**Submit a task:**
```bash
curl -X POST http://localhost:8080/task \
  -H "Content-Type: application/json" \
  -d '{"A":"[[1,2],[3,4]]","B":"[[5,6],[7,8]]"}'
```

Response:
```json
{"taskId": 1}
```

**Watch workers pick it up!** Check the worker browser tabs - you'll see them:
1. Poll and receive the task
2. Compute the matrix multiplication
3. Submit the result

**Get the result:**
```bash
curl http://localhost:8080/result/1
```

Response:
```json
{
  "taskId": 1,
  "status": "completed",
  "result": [[19,22],[43,50]]
}
```

**View statistics:**
```bash
curl http://localhost:8080/stats
```

Response:
```json
{
  "totalTasks": 1,
  "completedTasks": 1,
  "activeTasks": 0,
  "queueSize": 0,
  "uptime": 123.45
}
```

## Step 5: Test Distributed Processing

1. Keep Express server running
2. Open worker.html on **different machines**:
   - Machine 1: `http://SERVER_IP:8080/worker.html` → Start Worker
   - Machine 2: `http://SERVER_IP:8080/worker.html` → Start Worker
   - Machine 3: `http://SERVER_IP:8080/worker.html` → Start Worker

3. Submit multiple tasks:
```bash
for i in {1..10}; do
  curl -X POST http://localhost:8080/task \
    -H "Content-Type: application/json" \
    -d '{"A":"[[1,2],[3,4]]","B":"[[5,6],[7,8]]"}'
done
```

4. Watch tasks being distributed across workers!

## Troubleshooting

### Server won't start
- Check if port 8080 is in use: `lsof -i :8080`
- Try a different port: `PORT=3000 npm start`

### Workers not receiving tasks
- Check browser console (F12) for errors
- Verify server is running: `curl http://localhost:8080/stats`
- Check worker status indicator on the page

### CORS errors
- Ensure using same origin (server IP) for both workers and main app
- Server already has CORS headers configured

### Tasks stuck in queue
- Check that at least one worker is running and started
- Verify worker is polling: check browser Network tab (F12)
- Check server logs for errors

## What You Should See

When everything is working:

1. **Worker pages:**
   - Status shows "Working" (orange) or "Idle" (blue)
   - Task counter increments when work is done
   - Activity log shows task assignments and completions

2. **Server terminal:**
   - `[Coordinator] Task 1 submitted. Queue size: 1`
   - `[Coordinator] Task 1 assigned to worker worker-abc123`
   - `[Coordinator] Task 1 completed by worker worker-abc123`

3. **Browser DevTools (F12 → Network):**
   - Regular polling: `GET /task/next` every 2 seconds (returns 204 if no tasks)
   - When task available: `GET /task/next` returns 200 with task data
   - After compute: `POST /task/1/result` with result

## Summary

This PoC demonstrates:
- ✅ **Task Queue Pattern** - Coordinator manages work distribution
- ✅ **Browser-based Workers** - No server deployment for workers
- ✅ **Polling Architecture** - Works around browser TCP limitations
- ✅ **True Distribution** - Workers can run on any machine
- ✅ **Simple Setup** - Single Express server, no compilation needed

**Next Steps:**
- See `BROWSER_WORKERS_POC_README.md` for more details
- Test with workers on different machines/networks
- Try scaling to many workers (10+)
- Monitor statistics endpoint to see distribution in action

---

# Native Workers (WASM)

## Overview

Original architecture where workers run as **native Dana processes** on servers. WASM main app in browser makes HTTP requests to native workers.

## Prerequisites

Before starting, ensure you have the following installed and configured:

- **Dana Compiler (`dnc`)**: Installed and available in your PATH
- **Emscripten SDK**: Required for packaging WASM files (includes `file_packager` tool)
- **Node.js**: For running the web server
- **Modern Web Browser**: Chrome, Firefox, Safari, or Edge with WebAssembly support
- **DANA_WASM_HOME**: Environment variable set to your Dana installation directory (contains `components/`)

## Step 1: Compile to WASM

Compile all Dana source files to WebAssembly format:

```bash
./compile-wasm.sh
```

This will:
- Compile all `.dn` files to WebAssembly-compatible `.o` files
- Place compiled files in the `wasm_output/` directory
- Skip files in `wasm_output/`, `webserver/`, `.git/`, `results/`, `testing/`, `proxy_generator/`, and `resources/`

**Note**: 
- The WASM compiler uses `dnc -os ubc -chip 32` to generate WebAssembly-compatible binaries
- Remote workers (`app/RemoteRepo.dn`) are **NOT** compiled to WASM - they remain native and are handled separately
- If you encounter errors, ensure `dnc` is installed and available in your PATH

## Step 2: Package WASM Files

Package the compiled WASM files for browser deployment:

```bash
./package-wasm.sh
```

This will:
- Use Emscripten's `file_packager` to bundle WASM files
- Embed all compiled components into `webserver/file_system.js`
- Include the Dana standard library from `$DANA_WASM_HOME/components`
- Create the file system image required by the Dana WASM runtime

**Output files**:
- `webserver/dana.wasm` - The main WASM runtime
- `webserver/dana.js` - JavaScript loader for the WASM runtime
- `webserver/file_system.js` - File system containing all components

## Step 3: Start Remote Workers

Remote workers must run as **native** Dana processes (not WASM) because they need to listen on TCP sockets, which browsers don't allow.

Open two separate terminals and start the remote workers:

**Terminal 1:**
```bash
./run-remote-wasm.sh 8081
```

**Terminal 2:**
```bash
./run-remote-wasm.sh 8082
```

The `run-remote-wasm.sh` script will:
- Automatically check if `RemoteRepo.o` exists and compile it if missing
- Validate that required dependencies are compiled
- Start the worker on the specified port
- Provide clear feedback about the worker's role in the WASM setup

You should see output in each terminal indicating:
- The worker is listening on the specified port
- It's ready to accept HTTP requests from WASM applications

**Note**: These are native Dana processes that handle HTTP requests from the WASM application running in the browser.

## Step 4: Verify Remote Workers

Before starting the WASM app, verify the workers are responding correctly:

```bash
curl -X POST -H "Content-Type: application/json" -d '{
    "meta": [{"name": "method", "value": "multiply"}],
    "content": "{\"A\":\"[[1,2],[3,4]]\",\"B\":\"[[5,6],[7,8]]\"}"
}' http://localhost:8081/rpc --max-time 30
```

**Expected response**:
```json
{"meta":[],"content":"[[19,22],[43,50]]"}
```

If you receive this response, the worker is functioning correctly and ready to handle requests from the WASM application.

**Note**: If curl hangs or times out, check the worker logs. The worker may be processing the request correctly (you'll see logs showing successful processing and response sending), but curl may not receive the response due to a known TCP socket flushing issue in Dana's TCP implementation. This is a limitation at the Dana runtime level where `disconnect()` may close the socket before OS-level TCP buffers are fully flushed.

**Workaround**: 
- Check worker logs to confirm requests are being processed (look for "Sending response" messages)
- The WASM application may still work despite curl hanging, as browsers handle HTTP connections differently
- If curl consistently fails, you can proceed to Step 6 and test via the browser interface instead

## Step 5: Start the Web Server

In a new terminal, start the web server that will serve the WASM application:

**Option 1: Using Node.js**
```bash
cd webserver
node server.js
```

**Option 2: Using Dana's Web Server**
```bash
dana ws.core
```

The server will start on `http://localhost:8080` (or the port configured in your server).

## Step 6: Access and Test the WASM Application

1. **Open the Application in a Browser**:
   Navigate to:
   ```
   http://localhost:8080/xdana.html
   ```

2. **Perform a Calculation**:
   - The page will show two text boxes for "Matrix A" and "Matrix B," pre-filled with example 2x2 matrices
   - Click the **"Calculate A × B"** button

3. **Verify the Result**:
   - A "Result" section will appear below the button
   - The result matrix should be displayed correctly:
     ```json
     [
       [19, 22],
       [43, 50]
     ]
     ```
   - Check the browser's developer console (F12) for any errors or warnings
   - The WASM app makes HTTP requests to the native workers running on ports 8081 and 8082

## Architecture Overview - Native Workers

The WASM testing setup with native workers works as follows:

```
Browser → Web Server → WASM Main App (in browser)
                            ↓
                    [Makes HTTP Request]
                            ↓
                    Native Worker Server
                    (listening on TCP:8081/8082)
                            ↓
                    Process RPC Request
                            ↓
                    Return HTTP Response
                            ↓
                    WASM App receives response
```

**Key Points**:
- The main application runs as WASM in the browser
- Remote workers run as native Dana processes (cannot be WASM due to TCP socket restrictions)
- Communication happens via HTTP requests from WASM to native workers
- Workers listen on TCP ports and respond to HTTP POST requests at `/rpc`

**Comparison with Browser Workers PoC:**

| Aspect | Browser Workers PoC | Native Workers (WASM) |
|--------|-------------------|----------------------|
| Workers | Run in browsers (JavaScript) | Run as native Dana processes |
| Communication | Poll coordinator (HTTP GET) | Listen on TCP ports |
| Deployment | Any browser, any machine | Requires Dana runtime + server |
| Complexity | Simple (single Express server) | Complex (multiple processes) |
| Use Case | Testing, demos, edge computing | Production, high performance |

## Troubleshooting

### Workers Not Responding
- Ensure `run-remote-wasm.sh` successfully started and the workers are listening on the correct ports
- Check if ports 8081 and 8082 are already in use: `lsof -i :8081` or `lsof -i :8082`
- Verify workers are running: `curl http://localhost:8081/rpc`
- **If curl hangs or times out**: Check the worker terminal/logs. If you see "Sending response" messages, the worker is processing correctly but there's a known TCP socket flushing issue. The WASM browser app may still work despite curl hanging, as browsers handle HTTP differently than curl.

### WASM App Can't Connect to Workers
- Verify the proxy URLs in `matmul/Matmul.proxy.dn` point to `http://localhost:8081/rpc` and `http://localhost:8082/rpc`
- Check CORS headers if workers are on different origins
- Ensure workers are running before starting the web server
- Check browser console (F12) for network errors
- **If requests timeout**: This may be related to the TCP socket flushing issue. Check worker logs - if you see "Sending response" messages but the browser doesn't receive them, this indicates the known Dana TCP implementation limitation. The issue affects both curl and browser requests when the socket closes before OS-level buffers are flushed.

### Compilation Errors
- Ensure `compile-wasm.sh` completed successfully
- Check `wasm_output/` directory for compiled files
- Verify `dnc` is installed: `dnc --version`
- Review compilation output for specific error messages

### Packaging Errors
- Verify `DANA_WASM_HOME` environment variable is set correctly: `echo $DANA_WASM_HOME`
- Ensure `$DANA_WASM_HOME/components` directory exists
- Check that Emscripten's `file_packager` is available: `file_packager --help`
- Verify Emscripten SDK is properly installed and in PATH

### Browser Issues
- Ensure you're using a modern browser with WebAssembly support
- Check browser console (F12) for JavaScript errors
- Verify WASM files are being loaded correctly (check Network tab)
- Clear browser cache and reload the page

### Known Issue: TCP Socket Flushing

There is a known issue with Dana's TCP implementation where HTTP responses may not be received by clients (curl, browsers) even though the worker successfully processes requests and sends responses. This occurs because:

1. The worker processes requests correctly (logs show "Sending response")
2. The worker calls `send()` which writes to OS-level TCP buffers
3. The worker immediately calls `disconnect()` which closes the socket
4. The OS may not have flushed the TCP send buffers before the socket closes
5. Clients (curl/browsers) don't receive the response

**Symptoms**:
- curl hangs or times out when testing workers
- Browser requests timeout in the WASM app
- Worker logs show successful processing but clients don't receive responses

**Current Status**:
- A `flushSocket()` function has been implemented to attempt to flush buffers before disconnect
- However, this is a workaround - the root cause requires fixes at Dana's TCP runtime level
- The issue affects both Step 4 (curl verification) and Step 6 (WASM browser testing)

**Workarounds**:
- Check worker logs to verify requests are being processed correctly
- Try multiple times - sometimes the delay allows buffers to flush
- Use browser developer tools to monitor network requests and see if responses arrive intermittently
