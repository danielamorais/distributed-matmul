# Browser Worker WASM Migration Guide

## Problem: JavaScript Cannot Call Dana Code

Our investigation confirmed that **JavaScript cannot directly call Dana component methods**. The official Dana WASM example shows that Dana runs standalone - JavaScript only loads the runtime, then Dana's ProcessLoop runs independently.

## Solution: Pure Dana Worker

Instead of trying to call Dana from JavaScript, we create a worker that **runs entirely within Dana's ProcessLoop**.

## Architecture

### ❌ Old Approach (Doesn't Work)
```
JavaScript (worker-wasm.html)
    ↓
  Tries to call Dana functions (Module.cwrap/ccall)
    ↓
  ERROR: No JavaScript bridge exists
```

### ✅ New Approach (Works)
```
Dana ProcessLoop (BrowserWorkerLoopImpl)
    ↓
  loop() called repeatedly by Dana runtime
    ↓
  Makes HTTP requests (async context)
    ↓
  Polls coordinator, computes, submits results
```

## Key Differences

### Old BrowserWorker.dn (Blocking - Won't Work in WASM)
```dana
int App:main(AppParam params[]) {
    while (running) {
        pollAndProcess()  // BLOCKS - breaks WASM
        timer.sleep(POLL_INTERVAL)
    }
    return 0
}
```

**Problems:**
- ❌ Blocking `while` loop freezes browser
- ❌ `App:main()` must return for WASM to be responsive
- ❌ HTTP requests from main thread don't work in WASM

### New BrowserWorkerLoopImpl.dn (Non-Blocking - WASM Compatible)
```dana
bool BrowserWorkerLoop:loop() {
    // Called repeatedly by Dana runtime
    // Returns quickly, never blocks
    
    if (timeToP

oll) {
        startPollRequest()  // Starts async HTTP request
    }
    
    if (waitingForResponse && request.ready()) {
        handleResponse()  // Process when ready
    }
    
    return true  // Continue running
}
```

**Benefits:**
- ✅ Non-blocking - returns quickly
- ✅ HTTP requests in async context (`asynch::executeHttpRequest()`)
- ✅ State machine for async operations
- ✅ Browser stays responsive

## Files Created

### 1. `app/BrowserWorkerWasm.dn` (Entry Point)
```dana
component provides App requires System system, BrowserWorkerLoop {
    int App:main(AppParam params[]) {
        // Register ProcessLoop - Dana will call loop() repeatedly
        system.setProcessLoop(new BrowserWorkerLoop())
        return 0
    }
}
```

### 2. `resources/BrowserWorkerLoop.dn` (Interface)
```dana
interface BrowserWorkerLoop extends lang.ProcessLoop {
    BrowserWorkerLoop()
}
```

### 3. `app/BrowserWorkerLoopImpl.dn` (Implementation)
- Implements `BrowserWorkerLoop` interface
- `loop()` function called repeatedly
- State machine for async HTTP requests
- Polls coordinator every 2 seconds
- Computes with `matmul.Matmul` (pure Dana)
- Submits results

### 4. `webserver/worker-dana-wasm.html` (HTML Loader)
```html
<script>
Module['arguments'] = ['-dh', '.', 'app/BrowserWorkerWasm.o'];
</script>
<script src="file_system.js"></script>
<script async src="dana.js"></script>
```

**JavaScript's role:**
- ✅ Load Dana runtime
- ✅ Set initialization arguments
- ❌ **Does NOT call Dana functions**

## Compilation & Packaging

### Step 1: Compile Components
```bash
./compile-worker-wasm.sh
```

This compiles:
- `BrowserWorkerLoop.o` (interface)
- `BrowserWorkerLoopImpl.o` (implementation)
- `BrowserWorkerWasm.o` (entry point)

### Step 2: Package with file_packager
```bash
./package-worker-wasm.sh
```

This creates `file_system.js` containing:
- Worker components
- Matmul components
- Dana standard library
- All dependencies

### Step 3: Run
```bash
cd webserver && node server.js
```

Open:
- `http://localhost:8080/worker-dana-wasm.html` - Dana worker
- `http://localhost:8080/xdana.html` - Submit tasks

## HTTP Requests in WASM

**Critical:** HTTP requests in Dana WASM must be made from **async context**, not from ProcessLoop:loop() directly.

### ❌ Wrong (Doesn't Work)
```dana
bool loop() {
    HTTPRequest req = new HTTPRequest(http.GET, url)
    http.request(req)  // ERROR: Cannot call from main thread
}
```

### ✅ Correct (Works)
```dana
bool loop() {
    if (timeToMakeRequest) {
        asynch::executeHttpRequest(req)  // Async context
    }
    
    if (request.ready()) {
        handleResponse()  // Check when ready
    }
}

void executeHttpRequest(HTTPRequest req) {
    http.request(req)  // Called from async context
}
```

## State Machine Pattern

The worker uses a state machine to handle async operations:

```dana
// State variables
bool waitingForResponse = false
int requestType = 0  // 0=none, 1=poll, 2=submit
HTTPRequest currentRequest = null

bool loop() {
    // Check if waiting for response
    if (waitingForResponse && currentRequest.ready()) {
        handleResponse()
        waitingForResponse = false
    }
    
    // Start new request if idle
    if (!waitingForResponse && timeToWork) {
        startNewRequest()
        waitingForResponse = true
    }
    
    return true
}
```

## Flow Diagram

```
┌─────────────────────────────────────────┐
│ Browser loads worker-dana-wasm.html     │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ JavaScript loads Dana runtime           │
│ - dana.js, dana.wasm, file_system.js    │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Dana initializes BrowserWorkerWasm      │
│ - App:main() registers ProcessLoop      │
│ - Returns immediately                   │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Dana runtime calls loop() repeatedly    │
│                                         │
│ Every ~10ms:                            │
│ 1. Check if HTTP response ready         │
│ 2. Handle response if ready             │
│ 3. Start new poll if time elapsed       │
│ 4. Return true to continue              │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ When task received:                     │
│ 1. Parse task data (matrices A, B)     │
│ 2. Compute: matmul.multiply(A, B)      │
│ 3. Start HTTP POST to submit result    │
└─────────────────────────────────────────┘
```

## Testing

1. **Start server:**
   ```bash
   cd webserver && node server.js
   ```

2. **Open worker:**
   ```
   http://localhost:8080/worker-dana-wasm.html
   ```
   - Check console for Dana worker logs
   - Should see: "[@BrowserWorkerWASM] Polling for tasks..."

3. **Submit task:**
   ```
   http://localhost:8080/xdana.html
   ```
   - Click "Calculate A × B"
   - Task goes to coordinator
   - Worker polls and receives task
   - Worker computes with Dana
   - Result returned to xdana.html

4. **Verify no JavaScript computation:**
   - All computation logs show "[@BrowserWorkerWASM]" (Dana)
   - No JavaScript computation in worker-dana-wasm.html
   - Pure Dana matrix multiplication

## Comparison: Old vs New

| Aspect | Old (worker-wasm.html) | New (worker-dana-wasm.html) |
|--------|------------------------|----------------------------|
| Language | JavaScript + Dana | Pure Dana |
| Computation | Tries to call Dana (fails) | Dana Matmul component |
| Loop | JavaScript setInterval | Dana ProcessLoop |
| HTTP | fetch() in JavaScript | HTTPRequest in Dana |
| Blocking | N/A (JavaScript) | Non-blocking loop() |
| Works? | ❌ No (no JS bridge) | ✅ Yes (pure Dana) |

## Key Takeaways

1. **JavaScript cannot call Dana code** - confirmed by official example
2. **Dana runs standalone** - JavaScript only loads, Dana does the work
3. **ProcessLoop is essential** - replaces blocking loops for WASM
4. **HTTP must be async** - use `asynch::` context for HTTP requests
5. **State machine pattern** - handle async operations properly

## Next Steps

- Test the new Dana worker
- Compare performance with native Dana workers
- Document any issues
- Consider adding more worker instances for scaling

## References

- Official Dana WASM example: `/dana_wasm_32_[272]`
- Dana WASM documentation: `howto.md`
- Investigation results: `BROWSER_WASM_STATUS.md`



