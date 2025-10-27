# WASM Migration Summary for Distributed Matrix Multiplication

## Problem Statement

The current distributed matrix multiplication system uses:
- TCP sockets for server communication
- Blocking server loops
- TCP-based RPC for distributed computation
- Native network libraries unavailable in WASM

**Goal**: Migrate the system to WebAssembly while maintaining functionality.

## Key Constraints

### Available in WASM ✅
- `net.http.HTTPRequest` for remote operations
- `ProcessLoop` pattern for non-blocking operations
- JSON parsing/serialization
- Local computation (matmul)
- Composition and adaptation mechanisms
- Most `data.*` utilities

### Unavailable in WASM ❌
- `net.TCP`, `net.TCPServerSocket`, `net.TCPSocket`
- `net.UDP`, `net.DNS`, `net.SSL`
- Native libraries (`.dnl` files)
- Blocking I/O operations
- Direct socket binding/listening

## Migration Requirements

### 1. Replace TCP Server with HTTP + ProcessLoop

**Current Code** (`server/Server.dn`):
```dana
void Server:init() {
    TCPServerSocket host = new TCPServerSocket()
    host.bind(TCPServerSocket.ANY_ADDRESS, SERVER_PORT)
    
    while (true) {
        TCPSocket client = new TCPSocket()
        if(client.accept(host)) asynch::handleRequest(client)
    }
}
```

**WASM Solution**:
- Cannot bind to sockets in WASM
- Use `ProcessLoop` to handle requests non-blocking
- Requests come from web server (not direct sockets)

### 2. Replace RPC with HTTP Requests

**Current Code** (`matmul/Matmul.proxy.dn`):
```dana
component provides matmul.Matmul requires network.rpc.RPCUtil connection
    // ...
    connection.connect(address)  // TCP connection
    connection.make(request)
```

**WASM Solution**:
- Create `network/http/HTTPRPCUtil.dn` that uses `HTTPRequest`
- Make HTTP POST requests instead of TCP RPC
- Handle async HTTP responses

### 3. Architecture Change

**Current Architecture**:
```
Browser/HTTP → [WASM Ready?]
```

**Target Architecture**:
```
Browser → Web Server → dana.wasm (ProcessLoop)
                       ├─ Local computation (works)
                       └─ HTTP requests to native workers (distributed)
```

**Hybrid Approach**:
- WASM for main server
- Native Dana for remote workers
- Communication via HTTP

## Migration Steps

### Phase 1: Create WASM-Compatible Components

1. **Create HTTP RPC Interface**
   - File: `resources/network/http/HTTPRPCUtil.dn`
   - Provides RPC-like interface using HTTP

2. **Create HTTP RPC Implementation**
   - File: `network/http/HTTPRPCUtil.dn`
   - Uses `net.http.HTTPRequest`
   - Handles JSON serialization

3. **Create Server ProcessLoop**
   - File: `server/ServerProcessLoop.dn`
   - Implements `lang.ProcessLoop`
   - Non-blocking request handling

### Phase 2: Modify Existing Components

1. **Modify Server**
   - Remove `net.TCPServerSocket, net.TCPSocket` requirements
   - Remove blocking loops
   - Use ProcessLoop pattern

2. **Modify Proxy**
   - Replace `RPCUtil` with `HTTPRPCUtil`
   - Update `distribute()` to use HTTP
   - Change `Address` data structure to use URLs

### Phase 3: Update Main Application

1. **Modify main.dn**
   - Use `System.setProcessLoop()`
   - Return immediately from `main()`
   - No blocking operations

### Phase 4: Build & Package

1. **Update compile-wasm.sh**
   - Compile all components with `-os ubc -chip 32`
   - Include all necessary `.o` files

2. **Update package-wasm.sh**
   - Use `file_packager` to create `file_system.js`
   - Embed all compiled components
   - Include Dana standard library

## Files to Create

1. `resources/network/http/HTTPRPCUtil.dn` - Interface
2. `network/http/HTTPRPCUtil.dn` - Implementation
3. `server/ServerProcessLoop.dn` - ProcessLoop handler
4. `resources/network/http/Address.dn` - Updated for HTTP

## Files to Modify

1. `server/Server.dn` - Remove TCP, use ProcessLoop
2. `resources/server/Server.dn` - Update interface
3. `matmul/Matmul.proxy.dn` - Use HTTPRPCUtil
4. `app/main.dn` - Setup ProcessLoop
5. `compile-wasm.sh` - Complete WASM build
6. `package-wasm.sh` - Package all files

## Files to Keep Native (Not WASM)

1. `app/RemoteRepo.dn` - Remote workers (Docker/containerized)
2. `server/Remote.matmul.dn` - Worker implementation
3. All network utilities that use TCP (for native workers)

## Remote Workers Strategy

### Option 1: Keep Workers Native (Recommended)
- Deploy remote workers as separate native Dana applications
- Workers listen on HTTP endpoints
- WASM server makes HTTP requests to workers
- **Pros**: Simple, maintains distribution
- **Cons**: Not fully WASM

### Option 2: Convert Workers to WASM
- Each worker is a separate WASM module
- Multiple WASM instances running
- **Pros**: Fully WASM
- **Cons**: Complex deployment, limited true distribution

## Implementation Order

1. ✅ Create documentation (this file + guides)
2. ⏳ Create HTTP RPC layer
3. ⏳ Create ServerProcessLoop
4. ⏳ Modify Server component
5. ⏳ Modify Proxy to use HTTP
6. ⏳ Update Main application
7. ⏳ Build and test WASM
8. ⏳ Deploy and validate

## Testing Strategy

### Unit Tests
- Test HTTP RPC layer
- Test ProcessLoop iteration
- Test local matrix multiplication

### Integration Tests  
- WASM server + native worker communication
- HTTP end-to-end requests
- Adaptation between local/proxy

### Browser Tests
- Test in Chrome, Firefox, Safari
- Verify async behavior
- Memory profiling
- Performance benchmarks

## Expected Challenges

1. **ProcessLoop Polling Performance**
   - Must return quickly from `loop()`
   - Browser responsiveness at stake

2. **HTTP RPC Overhead**
   - More latency than TCP
   - Requires proper async handling

3. **Memory Constraints**
   - Browser limits WASM memory
   - Large matrices may cause issues

4. **Web Server Integration**
   - WASM cannot listen on sockets
   - Need web server to route requests
   - CORS configuration

## Success Criteria

- [ ] WASM builds without errors
- [ ] Server processes requests via ProcessLoop
- [ ] Local computation works
- [ ] HTTP RPC to workers works
- [ ] Adaptation between modes works
- [ ] Runs in browser without errors
- [ ] Performance is acceptable (< 2x latency)

## Documentation Created

1. `docs/WASM_MIGRATION_PLAN.md` - Comprehensive migration plan
2. `docs/WASM_IMPLEMENTATION_GUIDE.md` - Code examples and implementation details
3. `WASM_MIGRATION_SUMMARY.md` - This summary document

## Next Steps

1. Start with Phase 1 (Create WASM-compatible components)
2. Test each component independently
3. Integrate and test end-to-end
4. Benchmark and optimize
5. Deploy and document

## References

- Dana WASM Runtime documentation: `.cursor/rules/dana/web_assembly.mdc`
- Dana Native Libraries: `.cursor/rules/dana/native_libs.mdc`
- Emscripten SDK: https://emscripten.org/docs/getting_started/downloads.html
- Dana Standard Library: `components/` directory

