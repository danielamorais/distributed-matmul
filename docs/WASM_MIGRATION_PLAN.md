# WASM Migration Plan for Distributed Matrix Multiplication

## Executive Summary

This document outlines the migration plan to port the distributed matrix multiplication system from native Dana to WebAssembly (WASM). The main challenges are the unavailability of TCP sockets, blocking I/O operations, and native libraries in the WASM runtime.

## Current Architecture Analysis

### Unavailable Components in WASM
The following Dana standard library components are **NOT** available in WASM:
- `net.TCP`, `net.TCPSocket`, `net.TCPServerSocket`
- `net.UDP`, `net.DNS`
- `net.SSL`
- Native libraries (marked as `.dnl` files)
- Components depending on these (network.rpc.RPCUtil, network.tcp.TCPUtil)

### Current Architecture
```
Server (TCPServerSocket)
  └─ MatmulController
      └─ matmul.Matmul (local or proxy)
        └─ [If proxy] MatmulProxy → TCP connections → Remote Workers
           (RemoteRepo components listen on TCP sockets)
```

## Migration Strategy

### Phase 1: Replace TCP with HTTP (Server Side)

**Files to Modify:**
- `server/Server.dn`
- `resources/server/Server.dn`

**Changes Required:**

1. **Remove TCP Dependencies:**
   - Remove `requires net.TCPServerSocket, net.TCPSocket`
   - Remove blocking server loops (`while (true) { client.accept(host) }`)

2. **Use HTTP Server Pattern:**
   - WASM can only use `net.http.HTTPRequest` for remote operations
   - For incoming HTTP requests in WASM, we need to use a web server that hosts the WASM
   - The WASM application cannot listen on sockets directly

3. **Create ProcessLoop-based Server:**
   ```dana
   interface ServerProcessLoop extends lang.ProcessLoop {
       ServerProcessLoop()
   }
   ```

### Phase 2: Replace TCP Proxy Communication with HTTP

**Files to Modify:**
- `matmul/Matmul.proxy.dn`
- `network/rpc/RPCUtil.dn` (or create WASM-compatible version)

**Changes Required:**

1. **Replace RPCUtil with HTTP Requests:**
   - Current: `connection.connect(address)` uses TCP
   - New: Use `net.http.HTTPRequest` to send HTTP POST requests

2. **Update Remote Worker Interface:**
   - Change from TCP socket listener to HTTP endpoint
   - Workers should accept HTTP POST requests instead of raw TCP

3. **Implement HTTP-based RPC:**
   ```dana
   component provides network.http.HTTPRPCUtil
   ```

### Phase 3: Restructure Server to Use ProcessLoop

**Files to Create/Modify:**
- `server/ServerProcessLoop.dn` (new)
- `app/main.dn`

**Architecture Change:**

Instead of blocking server loop:
```dana
void Server:init() {
    while (true) {
        TCPSocket client = new TCPSocket()
        if(client.accept(host)) asynch::handleRequest(client)
    }
}
```

Use ProcessLoop:
```dana
interface ServerProcessLoop extends lang.ProcessLoop {
    ServerProcessLoop()
}

component provides ServerProcessLoop requires io.Output out {
    bool loop() {
        // Process pending HTTP requests
        // Return true to continue, false to exit
        return true
    }
}
```

### Phase 4: Remote Worker Architecture

**Files to Modify:**
- `app/RemoteRepo.dn`
- `server/Remote.matmul.dn`

**Changes Required:**

Remote workers cannot use TCP sockets in WASM. Options:

1. **Option A: Separate Native Workers**
   - Keep remote workers as native Dana applications (NOT WASM)
   - WASM server communicates with them via HTTP
   - This maintains the distributed architecture

2. **Option B: Pure WASM with HTTP Endpoints**
   - Convert remote workers to accept HTTP requests
   - Host multiple WASM instances (one per worker)
   - Complex, but fully WASM

**Recommended: Option A** - Maintain hybrid architecture

## Implementation Plan

### Step 1: Create WASM-Compatible Network Layer

Create `network/http/HTTPRPCUtil.dn`:
- Provide RPC-like interface using HTTP
- Wrap `net.http.HTTPRequest` calls
- Handle JSON serialization/deserialization
- Implement connection pooling for multiple workers

### Step 2: Create Server ProcessLoop

Create `server/ServerProcessLoop.dn`:
- Implements `lang.ProcessLoop` interface
- Polls for incoming requests (via web server)
- Processes requests asynchronously
- Returns `true` to continue, `false` to exit

### Step 3: Modify Proxy to Use HTTP

Update `matmul/Matmul.proxy.dn`:
- Replace `RPCUtil connection` with `HTTPRPCUtil`
- Change connection logic from TCP to HTTP
- Update `distribute()` to make HTTP POST requests

### Step 4: Update Main Application

Modify `app/main.dn`:
- Set up ProcessLoop in `App:main()`
- Use `System.setProcessLoop(serverLoop)` pattern
- Ensure `main()` returns immediately (doesn't block)

### Step 5: Create WASM Build Configuration

Update compilation scripts:
- `compile-wasm.sh`: Already has WASM compilation support
- Add specific flags: `-os ubc -chip 32`
- Package all components for `file_system.js`

## Architecture Comparison

### Current (Native):
```
User Request
    ↓
[TCP Server Listens on Port 8080]
    ↓
MatmulController
    ↓
Matmul (local OR proxy)
    ↓ (if proxy)
[TCP Connection to Remote]
    ↓
Remote Worker (TCP Server)
```

### Target (WASM):
```
Browser Request
    ↓
[Web Server] → dana.wasm
    ↓
[ProcessLoop Polls Requests]
    ↓
MatmulController
    ↓
Matmul (local OR HTTP proxy)
    ↓ (if proxy)
[HTTP Request to Remote]
    ↓
Remote Worker (HTTP Endpoint)
```

## Remote Worker Options

### Option 1: Native Dana Workers (Recommended)
- Remote workers remain as native Dana applications
- Use TCP/HTTP to communicate from WASM server
- Hosted in Docker/separate process
- Pros: Simple, maintains current worker architecture
- Cons: Not fully WASM

### Option 2: Convert Workers to WASM
- Each worker is a separate WASM module
- Each worker exposes HTTP endpoints
- Pros: Fully WASM
- Cons: Complex deployment, limited concurrency

### Option 3: Simulate Workers in WASM
- Implement worker logic in the main WASM
- Use threads/async for parallel computation
- Pros: Single WASM binary
- Cons: No true distributed computing

## File Changes Summary

### Files to Create:
1. `resources/network/http/HTTPRPCUtil.dn` - HTTP-based RPC interface
2. `network/http/HTTPRPCUtil.dn` - HTTP RPC implementation
3. `server/ServerProcessLoop.dn` - ProcessLoop for WASM server

### Files to Modify:
1. `server/Server.dn` - Remove TCP dependencies, use ProcessLoop
2. `matmul/Matmul.proxy.dn` - Replace RPCUtil with HTTPRPCUtil
3. `app/main.dn` - Setup ProcessLoop in main()
4. `compile-wasm.sh` - Add complete WASM build
5. `package-wasm.sh` - Package all components

### Files to Keep Native (Not WASM):
1. `app/RemoteRepo.dn` - Keep as native Dana
2. `server/Remote.matmul.dn` - Keep as native Dana

## Web Server Integration

Since WASM cannot listen on sockets, we need:

1. **Host Web Server:**
   - Use Dana's `ws.core` webserver
   - Or configure existing web server (nginx, Apache)
   - Route requests to WASM application

2. **WASM HTTP Handling:**
   - Browser sends requests to web server
   - Web server forwards to WASM module
   - WASM processes and returns response
   - Response sent back to browser

## Testing Strategy

1. **Unit Tests:**
   - Test HTTP RPC layer independently
   - Test ProcessLoop iteration
   - Test matrix operations

2. **Integration Tests:**
   - Test WASM server with native workers
   - Test HTTP communication end-to-end
   - Performance benchmarks

3. **Browser Testing:**
   - Test in multiple browsers
   - Verify async behavior
   - Memory profiling

## Migration Phases

### Phase 1: Proof of Concept (Week 1-2)
- [ ] Create HTTPRPCUtil
- [ ] Modify proxy to use HTTP
- [ ] Test basic HTTP communication

### Phase 2: Server Conversion (Week 2-3)
- [ ] Create ServerProcessLoop
- [ ] Modify Server component
- [ ] Update main application

### Phase 3: Integration (Week 3-4)
- [ ] Build WASM version
- [ ] Set up web server
- [ ] Test with browser

### Phase 4: Optimization (Week 4-5)
- [ ] Performance tuning
- [ ] Memory optimization
- [ ] Documentation

## Risk Assessment

### High Risk:
- ProcessLoop polling performance
- HTTP RPC overhead
- Adaptation in WASM context

### Medium Risk:
- Memory usage in browser
- Browser compatibility
- Threading limitations

### Low Risk:
- Matrix operations (pure computation)
- JSON serialization
- Local computation mode

## Conclusion

The migration requires significant architectural changes but is feasible. The key is:
1. Replace TCP with HTTP everywhere
2. Use ProcessLoop instead of blocking loops
3. Maintain hybrid architecture (native workers + WASM server)
4. Test thoroughly in browser environment

Estimated effort: 4-5 weeks with 1 developer.

