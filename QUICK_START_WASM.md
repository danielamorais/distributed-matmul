# Quick Start: Main App + Workers in WASM

## Current Status ✅

- ✅ Main app compiled: `wasm_output/app/main.o`
- ✅ Workers compiled: `wasm_output/app/BrowserWorkerWasm.o`
- ❌ Workers NOT running (need to open in browser)
- ❌ Main app NOT packaged (need to run packaging script)

## Quick Start (3 Steps)

### Step 1: Package Both Main App and Workers

```bash
./package-all-wasm.sh
```

This creates `webserver/file_system.js` with **both** main app and worker components.
(You can also package separately: `./package-main-wasm.sh` and `./package-worker-wasm.sh`, but they overwrite each other)

### Step 2: Start Server

```bash
cd webserver
node server.js
```

Server runs on `http://localhost:8080`

### Step 3: Open Browser Tabs

**Tab 1: Main App (Submit Tasks)**
```
http://localhost:8080/xdana.html
```
- Opens Dana UI window
- Enter matrices and submit tasks

**Tab 2: Worker (Process Tasks)**
```
http://localhost:8080/worker-dana-wasm.html
```
- Opens worker that polls for tasks
- Processes matrix multiplication
- Submits results back

**You can open multiple worker tabs** for parallel processing!

## Verify It's Working

### Check Main App Console
Look for:
```
[@MainAppWASM] Initializing MainAppLoop...
[@MainAppWASM] ProcessLoop registered
[@MainAppWASM] IOLayer initialized
```

### Check Worker Console
Look for:
```
[@BrowserWorkerWASM] Worker ID: worker-wasm-0
[@BrowserWorkerWASM] Polling for tasks...
```

### Test End-to-End
1. In main app: Enter matrices and click Submit
2. In worker: Should see "Received task #1" and "Task completed"
3. In main app: Should see result displayed

## Troubleshooting

**Main app not loading?**
- Check: `ls webserver/file_system.js` exists
- Check: Browser console for errors

**Workers not polling?**
- Check: `ls webserver/file_system.js` exists (from worker packaging)
- Check: Server is running on port 8080
- Check: Browser console for errors

**Tasks not processing?**
- Verify server is running: `curl http://localhost:8080/task/next`
- Check both tabs are open
- Check browser console for HTTP errors

## Full Details

See `RUNNING_MAIN_AND_WORKERS_WASM.md` for complete guide.

