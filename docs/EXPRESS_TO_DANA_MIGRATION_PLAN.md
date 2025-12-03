# Express.js to Dana Migration Plan (PoC)

## Current State
- **Express.js server** (`webserver/server.js`): Handles static files, COOP/COEP headers, RPC format conversion, and upstream forwarding
- **Express.js coordinator** (`webserver/coordinator.js`): Browser worker task coordination with in-memory state
- **Dana servers**: Native matrix multiplication service with HTTP/RPC interface

## Migration Goal
Replace Express.js with native Dana servers for all backend functionality, creating a pure Dana distributed system.

---

## Phase 1: Dana HTTP Server PoC ✓ (Already Implemented)
**Status**: The Dana HTTP server with RPC already exists and works

**What Exists**:
- `server/Server.dn` - HTTP request handler with adaptive mode
- `server/MatmulController.dn` - RPC controller for matmul operations
- `network/http/HTTPUtil.dn` - HTTP protocol utilities
- `network/rpc/RPCUtil.dn` - RPC serialization/deserialization

**Current Gap**: Express proxies requests to Dana servers, adding RPC format conversion overhead.

---

## Phase 2: Dana Coordinator Service (PoC Focus)
**Goal**: Replace `webserver/coordinator.js` with a native Dana coordinator

### 2.1 Create Coordinator Component
**File**: `server/Coordinator.dn`

**Minimal PoC Features**:
- Task submission endpoint (`POST /task`)
- Task polling for workers (`GET /task/next`)
- Result submission (`POST /task/:id/result`)
- Result retrieval (`GET /result/:id`)
- In-memory state (Map-based queue)

**Skip for PoC**:
- Worker registration/tracking
- Task timeout handling
- Statistics endpoint
- Cleanup routines

### 2.2 HTTP Route Handling
**File**: `server/CoordinatorController.dn`

**Implement**:
- Parse HTTP method and path
- Route to appropriate handler
- Return JSON responses
- Handle CORS headers (COOP/COEP for SharedArrayBuffer)

---

## Phase 3: Dana Static File Server (PoC)
**Goal**: Replace Express static file serving

### 3.1 Simple File Server
**File**: `server/StaticFileServer.dn`

**PoC Scope**:
- Serve `.html`, `.js`, `.wasm` files from `webserver/` directory
- Basic MIME type detection (html, js, wasm)
- Return 404 for missing files
- Add COOP/COEP headers

**Skip for PoC**:
- Advanced caching
- Compression
- Range requests
- Security hardening

---

## Phase 4: Integration & Testing
**Goal**: Wire everything together and validate

### 4.1 Create Main Server
**File**: `app/WebServer.dn`

**PoC Structure**:
```
WebServer
├─ StaticFileServer (handles /*.html, /*.js, /*.wasm)
├─ CoordinatorController (handles /task/*, /result/*)
└─ MatmulController (handles /matmul, /rpc)
```

### 4.2 Request Router
**Logic**:
- Check URL path prefix
- Route to appropriate controller
- Return first matching response

### 4.3 Testing Checklist
- [ ] Static file serving works (xdana.html loads)
- [ ] Coordinator task flow works (submit → poll → result)
- [ ] Matrix multiplication works via RPC
- [ ] Browser workers can connect and process tasks
- [ ] COOP/COEP headers present for SharedArrayBuffer

---

## Phase 5: Replace Express (PoC Deployment)
**Goal**: Run the system without Node.js

### 5.1 Update Launch Scripts
**Before**:
```bash
# Start Express proxy
cd webserver && npm start

# Start Dana servers
dana app/main.o 3
```

**After**:
```bash
# Start Dana web server (all-in-one)
dana app/WebServer.o 8080
```

### 5.2 Verify Functionality
- Open `http://localhost:8080/xdana.html`
- Submit matrix multiplication
- Verify worker distribution
- Check results match Express version

---

## PoC Success Criteria
✅ Dana server responds to HTTP requests  
✅ Static files served correctly  
✅ Task coordination works (browser workers)  
✅ Matrix multiplication executes  
✅ No Express.js dependency  

---

## Out of Scope (Post-PoC)
- Production error handling
- Request body size limits
- Connection pooling
- Detailed logging
- Metrics/monitoring endpoints
- Worker timeout/retry logic
- Persistent task storage (Redis replacement)
- Load balancing
- SSL/TLS support
- Authentication/authorization

---

## Quick Start Implementation Order
1. **Day 1**: Create `Coordinator.dn` with task queue logic
2. **Day 2**: Create `CoordinatorController.dn` with HTTP routing
3. **Day 3**: Create `StaticFileServer.dn` with basic file serving
4. **Day 4**: Create `WebServer.dn` to integrate all components
5. **Day 5**: Test and fix integration issues

---

## Key Technical Considerations
- **JSON Handling**: Use existing `data.json.JSONParser` in Dana
- **HTTP Parsing**: Reuse `HTTPUtil.readHTTPRequest()` 
- **State Management**: In-memory Map/Array structures (no external DB for PoC)
- **Concurrency**: Use Dana's mutex for thread-safe queue access
- **Headers**: COOP/COEP are critical for SharedArrayBuffer in workers

---

## Migration Benefits
1. **Single Language**: Pure Dana system (no Node.js runtime)
2. **Performance**: Remove RPC conversion overhead
3. **Simplicity**: One server process instead of two
4. **Consistency**: Unified error handling and logging
5. **Deployment**: Single binary, easier containerization



