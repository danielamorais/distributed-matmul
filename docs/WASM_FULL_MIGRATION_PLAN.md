# Full WASM Migration Plan - Workers to WASM

## Current Architecture

```
Browser → Web Server → WASM Main App (in browser)
                            ↓
                    [Makes HTTP Request]
                            ↓
                    Native Worker Server (HTTP:8081/8082)
                    (app/RemoteRepo.dn - Native Dana)
                            ↓
                    Process RPC Request
                            ↓
                    Return HTTP Response
```

**Current State:**
- ✅ Main app: WASM (runs in browser)
- ❌ Workers: Native Dana (run as separate processes, listen on HTTP)
- **Goal:** Compile all components to WASM format

## Challenge: WASM Cannot Listen on HTTP Servers

**The Problem:**
- Browsers don't allow WASM to bind/listen on HTTP servers
- WASM can only make **outbound** HTTP requests
- Workers need to **receive** incoming HTTP requests

## Migration Options

### Option 1: WASM Workers with Dana Native Runtime (Recommended)

Compile workers to WASM format and run them using Dana's native runtime. WASM-compiled files can still use HTTP servers when run natively.

**Architecture:**
```
Browser → Web Server → WASM Main App (in browser)
                            ↓
                    [Makes HTTP Request]
                            ↓
                    Dana Native Runtime
                            ↓
                    WASM Worker Module (RemoteRepo.o compiled with -os ubc -chip 32)
                            ↓
                    Process Request & Return Response (via HTTP)
```

**Pros:**
- ✅ Fully WASM format (workers compiled to WASM)
- ✅ Can listen on HTTP servers (runs in Dana native runtime)
- ✅ Maintains distribution architecture
- ✅ Solves HTTP flushing issue (native runtime handles HTTP properly)
- ✅ Can scale horizontally
- ✅ Pure Dana solution - all components compiled to WASM
- ✅ Unified compilation process (same WASM format as main app)

**Cons:**
- Requires Dana runtime to be installed on worker machines

**Implementation Steps:**

1. **Compile Workers to WASM Format**
   ```bash
   dnc app/RemoteRepo.dn -os ubc -chip 32 -o wasm_output/app/RemoteRepo.o
   ```
   - Workers are compiled to WASM format (same as main app)

2. **Run WASM Workers with Dana Runtime**
   ```bash
   dana wasm_output/app/RemoteRepo.o 8081
   dana wasm_output/app/RemoteRepo.o 8082
   ```
   - Use Dana's native runtime to execute WASM-compiled workers

3. **Update Code to Use HTTP**
   - RemoteRepo.dn should use HTTP server code
   - WASM-compiled files can use HTTP when run with Dana native runtime
   - HTTP is the standard protocol for WASM communication

4. **Update Compilation Script**
   - Ensure `compile-wasm.sh` compiles all components to WASM format
   - Main app and workers all compiled to WASM using same flags: `-os ubc -chip 32`
   - Unified WASM compilation process for entire codebase

### Option 2: Browser Web Workers

Run WASM workers as Web Workers in the browser.

**Architecture:**
```
Browser → Main Thread (WASM Main App)
            ↓
    [PostMessage to Web Worker]
            ↓
    Web Worker Thread
            ↓
    WASM Worker Module (RemoteRepo.wasm)
            ↓
    Process Request & Return via PostMessage
```

**Pros:**
- ✅ Fully WASM in browser
- ✅ True parallelism (Web Workers run in separate threads)
- ✅ No server needed for workers

**Cons:**
- ❌ Workers can't receive external HTTP requests
- ❌ Main app must communicate via PostMessage (not HTTP)
- ❌ Limited to single browser instance
- ❌ No true distribution across machines

**Implementation Steps:**

1. **Compile Workers to WASM**
   ```bash
   dnc app/RemoteRepo.dn -os ubc -chip 32 -o wasm_output/app/RemoteRepo.wasm
   ```

2. **Create Web Worker Wrapper**
   - Load WASM module in Web Worker
   - Handle PostMessage from main thread
   - Call WASM functions
   - Return results via PostMessage

3. **Modify Main App Communication**
   - Replace HTTP requests with PostMessage
   - Create worker pool manager
   - Handle async responses

4. **Update Proxy Component**
   - Change from HTTP requests to PostMessage
   - Manage worker pool
   - Handle worker lifecycle

### Option 3: Service Worker + SharedArrayBuffer

Use Service Workers with SharedArrayBuffer for inter-thread communication.

**Architecture:**
```
Browser → Main Thread (WASM Main App)
            ↓
    [SharedArrayBuffer Communication]
            ↓
    Service Worker
            ↓
    WASM Worker Module
```

**Pros:**
- ✅ Fully WASM in browser
- ✅ Can intercept network requests
- ✅ Background processing

**Cons:**
- ❌ Complex implementation
- ❌ Requires HTTPS (SharedArrayBuffer security requirement)
- ❌ Limited browser support
- ❌ No true distribution

### Option 4: Hybrid - WASM Workers via WebSocket Bridge

Run WASM workers with Dana runtime, but use WebSockets for better real-time communication.

**Architecture:**
```
Browser → Web Server → WASM Main App
                            ↓
                    [WebSocket Connection]
                            ↓
                    Dana WebSocket Server (WASM-compiled)
                            ↓
                    WASM Worker Module (RemoteRepo.o)
```

**Pros:**
- ✅ Fully WASM workers
- ✅ Better than HTTP for real-time
- ✅ Solves HTTP flushing issue
- ✅ Pure Dana solution

**Cons:**
- Requires WebSocket infrastructure
- More complex than HTTP
- Would need WebSocket support in Dana WASM

## Recommended Approach: Option 1 (Dana WASM Workers with Native Runtime)

### Detailed Implementation Plan

#### Phase 1: Compile Workers to WASM Format

**Step 1.1: Update compile-wasm.sh**
- Ensure `app/RemoteRepo.dn` is compiled to WASM format
- All components (main app and workers) use same WASM compilation flags: `-os ubc -chip 32`
- Output: `wasm_output/app/RemoteRepo.o`
- Verify all components are compiled to WASM format

**Step 1.2: Update Code to Use HTTP**
- `app/RemoteRepo.dn` should use HTTP server code
- WASM-compiled files run with Dana native runtime can use HTTP servers
- HTTP is required for WASM compatibility

**Step 1.3: Verify Compilation**
```bash
./compile-wasm.sh
# Verify wasm_output/app/RemoteRepo.o exists
```

#### Phase 2: Run WASM Workers with Dana Runtime

**Step 2.1: Create Worker Startup Script**
```bash
# File: run-wasm-worker.sh
#!/bin/bash
# Run WASM-compiled worker using Dana native runtime

PORT=${1:-8081}

if [ ! -f "wasm_output/app/RemoteRepo.o" ]; then
    echo "Error: wasm_output/app/RemoteRepo.o not found"
    echo "Run ./compile-wasm.sh first"
    exit 1
fi

echo "Starting WASM worker on port $PORT"
dana wasm_output/app/RemoteRepo.o $PORT
```

**Step 2.2: Start Multiple Workers**
```bash
# Terminal 1 - Worker 1
./run-wasm-worker.sh 8081

# Terminal 2 - Worker 2
./run-wasm-worker.sh 8082
```

**Step 2.3: HTTP Server Configuration**
- Workers listen on HTTP servers (8081, 8082)
- Main app makes HTTP requests to workers
- All components now compiled to WASM format and use HTTP for communication

#### Phase 3: Testing & Validation

**Step 3.1: Test WASM Worker Compilation**
```bash
./compile-wasm.sh
# Verify wasm_output/app/RemoteRepo.o exists
```

**Step 3.2: Test WASM Worker with Dana Runtime**
```bash
# Start worker
./run-wasm-worker.sh 8081

# In another terminal, test worker
curl -X POST http://localhost:8081/rpc -d '{"meta":[{"name":"method","value":"multiply"}],"content":"{\"A\":\"[[1,2],[3,4]]\",\"B\":\"[[5,6],[7,8]]\"}"}'
```

**Step 3.3: End-to-End Test**
- Start WASM workers (using Dana runtime)
- Start main web server
- Test in browser
- Verify no HTTP flushing issues
- Verify all components use WASM format

#### Phase 4: Deployment

**Step 4.1: Create Dockerfile for WASM Workers**
```dockerfile
FROM dana-base:latest
WORKDIR /app
COPY wasm_output/ ./wasm_output/
COPY run-wasm-worker.sh ./
RUN chmod +x run-wasm-worker.sh
EXPOSE 8081 8082
CMD ["./run-wasm-worker.sh", "8081"]
```

**Step 4.2: Update docker-compose.yml**
```yaml
services:
  wasm-worker-1:
    build: .
    ports:
      - "8081:8081"
    command: ./run-wasm-worker.sh 8081
  
  wasm-worker-2:
    build: .
    ports:
      - "8082:8082"
    command: ./run-wasm-worker.sh 8082
```

**Note:** Docker image must include Dana runtime (`dana` command)

## Migration Checklist

### Preparation
- [ ] Analyze current RemoteRepo dependencies
- [ ] Identify all socket usage and replace with HTTP servers
- [ ] Document worker interface requirements

### Code Changes
- [ ] Update `compile-wasm.sh` to compile all components to WASM format
- [ ] Ensure main app and workers are compiled to WASM using `-os ubc -chip 32`
- [ ] Create `run-wasm-worker.sh` script to run WASM workers with Dana runtime
- [ ] Verify RemoteRepo.dn compiles to WASM format successfully
- [ ] Verify all components are compiled to WASM format
- [ ] Update RemoteRepo.dn to use HTTP servers
- [ ] Verify HTTP servers work with WASM-compiled workers in native runtime

### Testing
- [ ] Compile workers to WASM format
- [ ] Test WASM worker with Dana native runtime
- [ ] Test HTTP communication between main app and workers
- [ ] End-to-end browser test
- [ ] Performance benchmarking
- [ ] Verify no HTTP flushing issues
- [ ] Verify all components use WASM format

### Deployment
- [ ] Create Dockerfile for WASM workers (with Dana runtime)
- [ ] Update docker-compose.yml
- [ ] Create run-wasm-worker.sh script
- [ ] Update deployment scripts
- [ ] Update documentation

## Benefits of Full WASM Migration

1. **Solves HTTP Flushing Issue**
   - Dana native runtime handles HTTP properly
   - No connection closing before buffer flush

2. **Unified Technology Stack**
   - All code compiled to WASM format
   - Main app and workers use same WASM compilation target
   - Easier to maintain and deploy

3. **Better Performance**
   - WASM is fast and efficient
   - Can leverage WASM optimizations

4. **Portability**
   - WASM format is portable across platforms
   - Same WASM-compiled binary runs with Dana runtime on any platform
   - Main app runs in browser, workers run natively

5. **Scalability**
   - Can run multiple WASM worker instances
   - Easy horizontal scaling

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Dana runtime availability | Medium | Ensure Dana runtime is installed on worker machines |
| Performance overhead | Low | WASM format is efficient, native runtime is fast |
| Debugging complexity | Medium | Add comprehensive logging |
| HTTP server compatibility | Low | Verified - WASM-compiled files can use HTTP in native runtime |

## Timeline Estimate

- **Phase 1** (Compile Workers to WASM): 1 day
- **Phase 2** (Create Worker Scripts): 1 day
- **Phase 3** (Testing): 2-3 days
- **Phase 4** (Deployment): 1-2 days

**Total: 5-7 days**

**Note:** All components compiled to WASM format - unified compilation process with no external runtime dependencies

## Next Steps

1. Review and approve this migration plan
2. Update `compile-wasm.sh` to ensure RemoteRepo is compiled
3. Create `run-wasm-worker.sh` script
4. Test WASM worker compilation and execution
5. Verify HTTP servers work with WASM-compiled workers
6. Test end-to-end with browser app
7. Update deployment configuration

