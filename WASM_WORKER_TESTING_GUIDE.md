# WASM Worker Testing Guide

This guide provides step-by-step instructions to test and verify that the pure Dana WASM worker is working correctly.

## Prerequisites

Before testing, ensure you have:

1. **Dana Compiler** installed and in PATH
   ```bash
   dnc --version
   ```

2. **Emscripten SDK** with `file_packager` tool
   ```bash
   file_packager --help
   ```

3. **Node.js** installed
   ```bash
   node --version
   ```

4. **Dana WASM Runtime** available
   - Set `DANA_WASM_DIR` environment variable if needed
   - Default location: `$HOME/Downloads/dana_wasm_32_[272]`

## Step 1: Compile the Worker

Compile all Dana components for WASM:

```bash
cd /home/danielamorais/Documents/distributed-matmul
./compile-worker-wasm.sh
```

**Expected Output:**
```
=== Compiling Dana WASM Worker ===
Compiling Matmul component...
Compiling BrowserWorkerLoopImpl component...
Compiling BrowserWorkerWasm (App entry point)...

=== Compilation Complete ===
Output files:
  - wasm_output/resources/BrowserWorkerLoop.o
  - wasm_output/app/BrowserWorkerLoopImpl.o
  - wasm_output/app/BrowserWorkerWasm.o
```

**Verify:**
- Check that all `.o` files were created
- No compilation errors should appear

---

## Step 2: Package for WASM

Package all components into the WASM file system:

```bash
./package-worker-wasm.sh
```

**Expected Output:**
```
=== Packaging Dana WASM Worker ===
Using Dana WASM runtime from: /path/to/dana_wasm_32_[272]
Creating file_system.js...
Copying Dana runtime files to webserver...

=== Packaging Complete ===
Files copied to webserver/:
  - dana.js
  - dana.wasm
  - file_system.js
```

**Verify:**
- Check that `webserver/file_system.js` exists and is not empty
- Check that `webserver/dana.js` and `webserver/dana.wasm` exist

---

## Step 3: Start the Coordinator Server

Start the Node.js server that manages tasks:

```bash
cd webserver
node server.js
```

**Expected Output:**
```
Server running on http://localhost:8080
Coordinator ready to receive tasks
```

**Keep this terminal open** - the server must be running for the worker to connect.

---

## Step 4: Open the Worker in Browser

1. Open your web browser (Chrome, Firefox, Edge, or Safari)

2. Navigate to:
   ```
   http://localhost:8080/worker-dana-wasm.html
   ```

3. **Open Browser Developer Console:**
   - **Chrome/Edge:** Press `F12` or `Ctrl+Shift+I` (Windows/Linux) / `Cmd+Option+I` (Mac)
   - **Firefox:** Press `F12` or `Ctrl+Shift+K` (Windows/Linux) / `Cmd+Option+K` (Mac)
   - **Safari:** Enable Developer menu, then press `Cmd+Option+C`

4. **Do a Hard Refresh** to ensure latest files are loaded:
   - **Chrome/Edge:** `Ctrl+Shift+R` (Windows/Linux) / `Cmd+Shift+R` (Mac)
   - **Firefox:** `Ctrl+F5` (Windows/Linux) / `Cmd+Shift+R` (Mac)

---

## Step 5: Verify Worker Initialization

In the browser console, you should see:

### ✅ Success Indicators:

```
[Dana] ===== Dana WASM Worker =====
[Dana] Worker will run entirely within Dana ProcessLoop
[Dana] Check console for Dana worker output
[Dana] Worker will poll http://localhost:8080/task/next every 2 seconds
[Dana] ============================
[Dana] [@BrowserWorkerWASM] Initializing...
[Dana] [@BrowserWorkerWASM] ProcessLoop registered
[Dana] [@BrowserWorkerWASM] Worker ID: worker-wasm-0
[Dana] [@BrowserWorkerWASM] Polling for tasks...
```

### ❌ Error Indicators (If Something is Wrong):

- `Error: No default component found to satisfy required interface 'BrowserWorkerLoop'`
  - **Fix:** Check that `BrowserWorkerLoopImpl` is in `resources/` directory
  
- `RuntimeError: index out of bounds`
  - **Fix:** Ensure you're using automatic resolution (not manual loaders)

- No console output at all
  - **Fix:** Check browser console for JavaScript errors, verify `file_system.js` loaded

---

## Step 6: Verify Worker Polling

After initialization, you should see repeated polling messages:

```
[Dana] [@BrowserWorkerWASM] Polling for tasks...
[Dana] [@BrowserWorkerWASM] Polling for tasks...
[Dana] [@BrowserWorkerWASM] Polling for tasks...
```

These should appear approximately every 2 seconds.

**Check Server Logs:**
In the terminal where `server.js` is running, you should see:
```
GET /task/next?workerId=worker-wasm-0 204
GET /task/next?workerId=worker-wasm-0 204
GET /task/next?workerId=worker-wasm-0 204
```

The `204` status means "No Content" - no tasks available yet, which is expected.

---

## Step 7: Submit a Test Task

1. **Open a new browser tab** and navigate to:
   ```
   http://localhost:8080/xdana.html
   ```

2. **Enter matrix dimensions:**
   - Matrix A: e.g., `2x2` or `3x3`
   - Matrix B: e.g., `2x2` or `3x3`
   - (Dimensions must be compatible for multiplication)

3. **Click "Compute" or "Submit"**

4. **Watch the worker console** - you should see:
   ```
   [Dana] [@BrowserWorkerWASM] Received task #1
   [Dana] [@BrowserWorkerWASM] Computing: A=..., B=...
   [Dana] [@BrowserWorkerWASM] Computation complete: ...
   [Dana] [@BrowserWorkerWASM] Submitting result for task #1
   [Dana] [@BrowserWorkerWASM] Task #1 completed successfully!
   [Dana] [@BrowserWorkerWASM] Total tasks completed: 1
   ```

5. **Check the result** - The `xdana.html` page should display the computed result

---

## Step 8: Verify Full Workflow

### Test Multiple Tasks:

1. Submit several tasks from `xdana.html`
2. Each task should be:
   - Received by the worker
   - Computed using Dana's `matmul.Matmul` component
   - Result submitted back to coordinator
   - Result displayed in `xdana.html`

### Check Server Logs:

In the server terminal, you should see:
```
GET /task/next?workerId=worker-wasm-0 200
POST /task/1/result 200
GET /task/next?workerId=worker-wasm-0 204
```

### Verify Computation is in Dana:

- All computation happens in Dana code (no JavaScript)
- Check browser console - you should see Dana log messages
- No JavaScript errors related to computation

---

## Troubleshooting

### Worker Doesn't Initialize

**Symptoms:**
- No console output
- Error messages in console

**Checks:**
1. Verify `file_system.js` is loading (check Network tab in DevTools)
2. Check for JavaScript errors in console
3. Verify all files are in `webserver/` directory:
   - `dana.js`
   - `dana.wasm`
   - `file_system.js`
   - `worker-dana-wasm.html`

### Worker Initializes But Doesn't Poll

**Symptoms:**
- See initialization messages
- No polling messages

**Checks:**
1. Verify server is running on `http://localhost:8080`
2. Check browser console for HTTP errors
3. Verify CORS is enabled on the server (if needed)

### Worker Receives Tasks But Doesn't Compute

**Symptoms:**
- See "Received task" messages
- No computation messages
- Tasks timeout

**Checks:**
1. Verify `matmul/Matmul.o` is packaged in `file_system.js`
2. Check for errors related to `matmul.Matmul` component
3. Verify matrix data format matches expected format

### Tasks Complete But Results Not Received

**Symptoms:**
- Worker says "Task completed"
- `xdana.html` doesn't show result

**Checks:**
1. Check server logs for POST requests to `/task/:id/result`
2. Verify server is processing results correctly
3. Check for errors in server console

---

## Success Criteria

The implementation is working correctly if:

✅ **Worker Initialization:**
- Worker starts without errors
- ProcessLoop is registered
- Worker ID is generated

✅ **Polling:**
- Worker polls coordinator every ~2 seconds
- Server responds with 204 (no tasks) or 200 (task available)

✅ **Task Processing:**
- Worker receives tasks from coordinator
- Worker computes matrix multiplication using Dana
- Worker submits results back to coordinator

✅ **End-to-End:**
- Tasks submitted from `xdana.html` are processed
- Results are displayed in `xdana.html`
- Multiple tasks can be processed sequentially

✅ **Pure Dana:**
- No JavaScript computation
- All logic runs in Dana ProcessLoop
- All computation uses Dana `matmul.Matmul` component

---

## Quick Test Script

For a quick verification, run this in your terminal:

```bash
# Terminal 1: Start server
cd /home/danielamorais/Documents/distributed-matmul/webserver
node server.js

# Terminal 2: Test worker (after opening in browser)
# Watch for polling messages in browser console

# Terminal 3: Submit test task
curl -X POST http://localhost:8080/matmul \
  -H "Content-Type: application/json" \
  -d '{"A": "1,2;3,4", "B": "5,6;7,8"}'
```

---

## Next Steps After Successful Testing

1. **Performance Testing:**
   - Test with larger matrices
   - Test with multiple concurrent tasks
   - Monitor resource usage

2. **Error Handling:**
   - Test with invalid input
   - Test with network failures
   - Test with server restarts

3. **Production Readiness:**
   - Optimize polling intervals
   - Add error recovery
   - Add monitoring/logging

---

*Last Updated: After implementing pure Dana WASM worker*

