# Main App in WASM - Pure Dana Implementation Plan

## Overview

Migrate the main application from JavaScript to **Pure Dana WASM** using Dana's UI framework. This ensures consistency with the worker implementation and keeps all logic in Dana.

## Critical Constraint

**JavaScript CANNOT call Dana code in WASM.**

This constraint requires a pure Dana solution:
- Dana WASM runtime does not export JavaScript-callable functions
- `Module.cwrap` and `Module.ccall` are NOT available
- Dana ProcessLoop runs independently - JavaScript only loads the runtime
- No JavaScript bridge exists to communicate with Dana components

**Conclusion**: We must use Dana's UI framework and handle everything in Dana's ProcessLoop.

**Reference**: `BROWSER_WASM_STATUS.md` and `WASM_WORKER_MIGRATION.md`

## Current Architecture

**Current State (JavaScript Client):**
```
xdana.html (JavaScript)
    ↓ fetch('/matmul')
Node.js Server (server.js)
    ↓ Returns {taskId: 1}
JavaScript polls: fetch('/result/1')
    ↓
Displays result in HTML
```

**Files:**
- `webserver/xdana.html` - Pure JavaScript client (no Dana WASM)
- All HTTP logic in JavaScript

## Target Architecture

**Target State (Pure Dana WASM):**
```
xdana.html (HTML canvas only)
    ↓
Dana WASM (main.o + Dana UI)
    ↓ HTTP POST /matmul
Node.js Server (server.js)
    ↓ Returns {taskId: 1}
Dana WASM polls: HTTP GET /result/1
    ↓
Dana UI displays result
```

**Key Points:**
- Dana UI handles all user interaction (Window, Button, TextArea, Label)
- HTTP requests made from Dana's async context (same pattern as worker)
- No JavaScript interaction needed
- Consistent with worker architecture

## Implementation Plan

### Phase 1: Create MainAppLoop Components

**File: `resources/MainAppLoop.dn` (Interface)**
```dana
interface MainAppLoop extends lang.ProcessLoop {
    MainAppLoop()
}
```

**File: `app/MainAppLoopImpl.dn` (Implementation)**

Components needed:
- `ui.IOLayer` - System-level UI framework
- `ui.Window` - Main application window
- `ui.TextArea` - Input fields for matrices A and B
- `ui.Button` - Submit button
- `ui.Label` - Display result and status

Implementation pattern (follow `BrowserWorkerLoopImpl.dn`):
- Use `ProcessLoop` for non-blocking operation
- Make HTTP requests in async context: `asynch::executeHttpRequest()`
- Use state machine to track request/response cycles
- Parse JSON responses using `data.json.JSONParser`
- Handle UI events using Dana's event system (`eventsink`, `sinkevent`)

**State Machine:**
- `0` = idle (waiting for user input)
- `1` = submitting task (HTTP POST in progress)
- `2` = polling for result (HTTP GET in progress)
- `3` = result received (display result)

**HTTP Endpoints:**
- POST `/matmul` - Submit task with matrices A and B
- GET `/result/:taskId` - Poll for result

### Phase 2: Update main.dn Entry Point

**File: `app/main.dn` (Modified)**

```dana
component provides App requires io.Output out, System system, MainAppLoop {
    int App:main(AppParam params[]) {
        out.println("[MainApp] Initializing...")
        
        // Set ProcessLoop - Dana will automatically resolve MainAppLoopImpl
        system.setProcessLoop(new MainAppLoop())
        
        out.println("[MainApp] ProcessLoop registered")
        return 0
    }
}
```

### Phase 3: Compilation & Packaging

**File: `compile-main-wasm.sh`**

Compile components:
- `app/MainAppLoopImpl.dn` → `wasm_output/app/MainAppLoopImpl.o`
- `app/main.dn` → `wasm_output/app/main.o`

**File: `package-main-wasm.sh`**

Package with `file_packager`:
- Embed compiled components
- Include Dana standard library
- Create `file_system.js`

### Phase 4: Update HTML Loader

**File: `webserver/xdana.html` (Simplified)**

Remove all JavaScript HTTP code. Keep only:
- HTML structure for Dana UI canvas
- Dana WASM loading (`app/main.o`)
- Minimal Module configuration

## Architecture Comparison

**Before (JavaScript Client):**
```
xdana.html (JavaScript) → HTTP → server.js → Worker WASM
```

**After (Pure Dana WASM):**
```
xdana.html (HTML canvas) → Dana WASM (main.o + UI) → HTTP → server.js → Worker WASM
```

## Key Requirements

1. **UI Framework**: Use Dana's UI components
   - `ui.IOLayer` - System-level UI framework
   - `ui.Window` - Main window
   - `ui.TextArea` - Matrix input fields
   - `ui.Button` - Submit button
   - `ui.Label` - Result display

2. **HTTP Request Pattern** (follow `BrowserWorkerLoopImpl.dn`):
   - Use `ProcessLoop` for non-blocking operation
   - Make HTTP requests in async context: `asynch::executeHttpRequest()`
   - Use state machine to track request/response cycles
   - Parse JSON responses using `data.json.JSONParser`

3. **Event Handling**: Use Dana's event system
   - `eventsink` for receiving events
   - `sinkevent` for subscribing to events
   - Handle button clicks, window events in Dana

## Challenges

1. **UI Framework**: Must use Dana UI instead of HTML
   - **Solution**: Use `ui.IOLayer`, `ui.Window`, `ui.Button`, etc. (see `howto.md` examples)

2. **Async HTTP in ProcessLoop**: HTTP requests must be async in WASM
   - **Solution**: Use `asynch::executeHttpRequest()` pattern (same as worker)

3. **JSON Parsing**: Need to parse nested JSON structures
   - **Solution**: Use `data.json.JSONParser` (same as worker)

4. **Event Handling**: UI events must be handled in Dana
   - **Solution**: Use Dana's event system (`eventsink`, `sinkevent`)

5. **Matrix Input**: Need to parse matrix input from TextArea
   - **Solution**: Use `data.json.JSONParser` to parse JSON matrix format

## Benefits

1. **Pure Dana**: All logic in Dana (consistent with worker)
2. **Consistency**: Same pattern as worker (ProcessLoop + async HTTP)
3. **Maintainability**: Single language for business logic
4. **Testability**: Can test Dana components independently
5. **No JavaScript Bridge**: No need for complex bridge mechanisms

## Implementation Checklist

- [ ] Phase 1: Create MainAppLoop interface and implementation
  - [ ] Create `resources/MainAppLoop.dn` interface
  - [ ] Create `app/MainAppLoopImpl.dn` with Dana UI components
  - [ ] Implement ProcessLoop pattern
  - [ ] Implement HTTP POST to `/matmul` (async)
  - [ ] Implement HTTP GET polling to `/result/:id` (async)
  - [ ] Implement JSON parsing for responses
  - [ ] Add state machine for request/response handling
  - [ ] Handle UI events (button clicks) in Dana
- [ ] Phase 2: Update `app/main.dn` to use MainAppLoop
- [ ] Phase 3: Create compilation and packaging scripts
  - [ ] Create `compile-main-wasm.sh`
  - [ ] Create `package-main-wasm.sh`
- [ ] Phase 4: Update `xdana.html` to load Dana WASM (remove JS HTTP code)
- [ ] Phase 5: Test end-to-end (UI → submit → poll → display)
- [ ] Phase 6: Update documentation

## Issues Found During Implementation

### Issue 1: Component File Name Must Match Interface Name

**Error:**
```
[Dana] Error: No default component found to satisfy required interface 'MainAppLoop' of component 'app/main.o'
```

**Root Cause:**
Dana's auto-linking requires the component file name to exactly match the interface name it provides. We had:
- Interface: `MainAppLoop` in `resources/MainAppLoop.dn`
- Component: `MainAppLoopImpl.dn` (different name!)

**Solution:**
Rename the component file to match the interface name:
- `resources/MainAppLoopImpl.dn` → `app/MainAppLoop.dn`
- Update compilation and packaging scripts to use the new name

**Reference:** See `No-default-component-error.md` for detailed investigation.

### Issue 2: Blocking Operations in ProcessLoop

**Error:**
```
"This page is slowing down Firefox..."
Script terminated by timeout
```

**Root Cause:**
The ProcessLoop's `loop()` function must return quickly and cannot block. We had `timer.sleep(2000)` in `handlePollResponse()`, which blocked the browser.

**Solution:**
Replace blocking delays with non-blocking loop counter checks:
```dana
// ❌ Blocking (causes browser freeze)
timer.sleep(2000)

// ✅ Non-blocking (uses loop counter)
int resultReceivedLoop = 0
const int RESULT_DISPLAY_LOOPS = 200 // ~2 seconds

// In loop():
if (state == 3) {
    if (loopCount - resultReceivedLoop >= RESULT_DISPLAY_LOOPS) {
        state = 0
        // Reset to idle
    }
}
```

### Issue 3: IOLayer Constructor Blocking in main()

**Error:**
```
[Dana] [MainApp] Initializing...
// Freezes here, never reaches "ProcessLoop registered"
```

**Root Cause:**
Creating `IOLayer` in the constructor (called from `App:main()`) can block because `IOLayer()` calls `lib.initMediaLayer()`, which may block in WASM. This prevents `main()` from returning, so the ProcessLoop never starts.

**Solution:**
Defer IOLayer initialization to the first `loop()` call:
```dana
// ❌ Blocking in constructor
MainAppLoop:MainAppLoop() {
    coreui = new IOLayer() // Blocks!
}

// ✅ Non-blocking - initialize in loop()
bool MainAppLoop:loop() {
    if (!iolayerInitialized) {
        coreui = new IOLayer()
        iolayerInitialized = true
        return true // Let next loop process UI
    }
    // ... rest of loop
}
```

### Issue 4: IOLayer.loop() Returning True During Startup

**Error:**
```
[Dana] [@MainAppWASM] IOLayer initialized
[Dana] [@MainAppWASM] IOLayer ready event received!
[Dana] [@MainAppWASM] Initializing UI...
[Dana] [@MainAppWASM] IOLayer requested exit
// ProcessLoop stops, UI disappears
```

**Root Cause:**
In WASM, `IOLayer.loop()` may return `true` (indicating "done") during initialization or when there's nothing to process. This doesn't mean we should exit - it's just the normal state during startup.

**Solution:**
Ignore the return value of `coreui.loop()` and only exit on explicit shutdown events:
```dana
// ❌ Exits prematurely
bool uiDone = coreui.loop()
if (uiDone) {
    return false // Stops ProcessLoop!
}

// ✅ Continue running, exit only on window close
coreui.loop() // Process events, ignore return value

// Check explicit exit flag set by window close event
if (shouldExit) {
    return false
}
```

Set `shouldExit = true` only when receiving `Window.[close]` event.

## References

- `app/BrowserWorkerLoopImpl.dn` - Reference implementation for HTTP requests in WASM
- `webserver/howto.md` - Dana UI examples for WASM (see "Example app UI" section)
- `WASM_WORKER_MIGRATION.md` - Worker migration guide (same pattern)
- `BROWSER_WASM_STATUS.md` - JavaScript cannot call Dana code (critical constraint)
- `WASM_ARCHITECTURE.md` - Overall architecture documentation
- `No-default-component-error.md` - Detailed investigation of component naming issues
