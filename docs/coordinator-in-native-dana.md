# Coordinator in Native Dana - Migration Plan

## Overview
Replace Node.js coordinator (`webserver/coordinator.js`) with a **standalone native Dana coordinator** that runs as a native Dana server (not WASM).

## Architecture

**Current:**
```
Main WASM (browser) → HTTP → Node.js Coordinator (server.js) → HTTP → Worker WASM (browser)
```

**Target:**
```
Main WASM (browser) → HTTP → Native Dana Coordinator (coordinator.o) → HTTP → Worker WASM (browser)
```

## Key Requirements

1. **Native Dana Server** (not WASM)
   - Can listen on TCP port (e.g., 8080)
   - Uses `net.TCPServer` or `net.http.HTTPServer` from Dana standard library
   - Runs with: `dana coordinator.o [port]`

2. **Same HTTP Endpoints** (compatible with existing WASM clients)
   - `POST /task` - Submit task (from Main WASM)
   - `GET /task/next?workerId=X` - Get next task (from Worker WASM)
   - `POST /task/:id/result` - Submit result (from Worker WASM)
   - `GET /result/:id` - Get result (from Main WASM)
   - `GET /stats` - Statistics
   - `GET /health` - Health check

3. **CORS Headers** (for browser clients)
   - `Cross-Origin-Opener-Policy: same-origin`
   - `Cross-Origin-Embedder-Policy: require-corp`
   - `Access-Control-Allow-Origin: *`

## Implementation Plan

### Phase 1: Create Standalone Coordinator Component

**File: `app/CoordinatorApp.dn`**
- Entry point: `App:main()` that starts HTTP server
- Accepts port as command-line argument
- Uses `net.TCPServer` or `net.http.HTTPServer`

**File: `server/CoordinatorServer.dn`**
- HTTP request handler
- Routes requests to `server.Coordinator` interface
- Adds CORS headers to all responses
- Handles HTTP parsing/response building

**Reuse: `server/CoordinatorController.dn`**
- Already implements `server.Coordinator` interface
- Task queue management
- Task storage and retrieval
- No changes needed

### Phase 2: Testing Infrastructure

**Created Files:**
- `test-coordinator.sh` - Automated test script for all endpoints
- `COORDINATOR_TESTING.md` - Comprehensive testing guide
- `run-coordinator-native.sh` - Convenience script to start coordinator

**Testing Coverage:**
- Health check endpoint
- Task submission and retrieval
- Worker task polling
- Result submission and retrieval
- Statistics endpoint
- CORS preflight (OPTIONS)
- Error handling (404s)

**Manual Testing:**
- All endpoints can be tested with `netcat` or `curl`
- End-to-end test scenarios documented
- Integration testing with WASM clients (Main and Worker)

### Phase 3: Compilation & Running

**Compile:**
```bash
dnc app/CoordinatorApp.dn
dnc server/CoordinatorServer.dn
dnc server/CoordinatorController.dn
```

**Run:**
```bash
dana CoordinatorApp.o 8080
```

### Phase 4: Update WASM Clients (No Changes Needed)

- Main WASM already calls `POST /task` and `GET /result/:id`
- Worker WASM already calls `GET /task/next` and `POST /task/:id/result`
- **No changes required** - same HTTP endpoints

## Files to Create/Modify

### New Files
- `app/CoordinatorApp.dn` - Main entry point
- `server/CoordinatorServer.dn` - HTTP server wrapper
- `resources/server/CoordinatorServer.dn` - Interface definition
- `test-coordinator.sh` - Automated test script
- `COORDINATOR_TESTING.md` - Testing documentation
- `run-coordinator-native.sh` - Run script
- `errors-coordinator.md` - Error documentation and debugging guide

### Reuse Existing
- `server/CoordinatorController.dn` - Task coordination logic (already exists)
- `resources/server/Coordinator.dn` - Interface (already exists)

### Remove
- `webserver/coordinator.js` - Node.js coordinator (after migration)

## Implementation Checklist

- [x] Phase 1: Create `app/CoordinatorApp.dn` entry point
- [x] Phase 1: Create `server/CoordinatorServer.dn` HTTP handler
- [x] Phase 1: Create `resources/server/CoordinatorServer.dn` interface
- [x] Phase 1: Integrate with existing `server.Coordinator` interface
- [x] Phase 1: Add CORS headers to all responses
- [x] Phase 1: Test compilation of all components
- [x] Phase 2: Create test script (`test-coordinator.sh`)
- [x] Phase 2: Create testing documentation (`COORDINATOR_TESTING.md`)
- [ ] Phase 2: Test with Main WASM (submit task, poll result)
- [ ] Phase 2: Test with Worker WASM (get task, submit result)
- [ ] Phase 3: Update documentation and run scripts
- [ ] Phase 4: Remove Node.js coordinator

## Key Differences from WASM

| Aspect | WASM Coordinator | Native Dana Coordinator |
|--------|----------------|------------------------|
| **Runtime** | Browser (WASM) | Native Dana |
| **TCP Listen** | ❌ Cannot listen | ✅ Can listen on port |
| **Compilation** | `-os ubc -chip 32` | Native (default) |
| **Running** | Loaded in browser | `dana coordinator.o` |
| **HTTP Server** | Not possible | `net.TCPServer` |

## Benefits

1. **Pure Dana**: All backend logic in Dana (no Node.js)
2. **Consistency**: Same language as WASM clients
3. **Native Performance**: No JavaScript overhead
4. **Simpler Deployment**: Single binary, no npm dependencies
5. **Better Integration**: Can integrate with other Dana components