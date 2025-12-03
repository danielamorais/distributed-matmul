# Running Two Servers in WebAssembly

## Architecture Overview

In WASM, you **cannot** listen on TCP sockets directly (browsers don't allow this). Instead:

1. **Main WASM App** (in browser): Makes HTTP requests OUT to remote workers
2. **Remote Workers** (native Dana servers): Listen on HTTP endpoints and handle requests

## Setup Instructions

### Step 1: Compile Remote Workers (Native, NOT WASM)

Remote workers must be compiled as **native** Dana applications:

```bash
# Compile remote worker (native)
dnc app/RemoteRepo.dn
dnc server/Remote.matmul.dn
dnc matmul/Matmul.dn

# You should have: RemoteRepo.o, Remote.matmul.o, Matmul.o
```

### Step 2: Run Remote Workers

Start remote workers as separate native processes on different ports:

**Terminal 1 - Worker 1:**
```bash
dana RemoteRepo.o 8081
```

**Terminal 2 - Worker 2:**
```bash
dana RemoteRepo.o 8082
```

Each worker will:
- Bind to the specified port
- Listen for HTTP POST requests to `/rpc`
- Process RPC requests and return JSON responses

### Step 3: Update Proxy URLs (if needed)

The proxy is configured with these URLs in `matmul/Matmul.proxy.dn`:

```dana
char remotes[] = new char[](
    "http://dana-remote-1:8081/rpc", 
    "http://dana-remote-2:8082/rpc"
)
```

**For local development**, update these to:
```dana
char remotes[] = new char[](
    "http://localhost:8081/rpc", 
    "http://localhost:8082/rpc"
)
```

**For Docker**, use Docker hostnames (e.g., `dana-remote-1`, `dana-remote-2`).

### Step 4: Compile and Run WASM App

```bash
# Compile main app for WASM
./compile-wasm.sh

# Package for WASM
./package-wasm.sh

# Start web server (or use any HTTP server)
cd webserver
# Use ws.core or any web server
dana ws.core
```

### Step 5: Access Application

Open browser to: `http://localhost:8080/xdana.html`

The WASM app will:
- Make HTTP requests to remote workers
- Workers process requests and return responses
- App receives responses and continues processing

## How It Works

### Request Flow

```
Browser → Web Server → WASM Main App
                            ↓
                    [Makes HTTP Request]
                            ↓
                    Native Worker Server
                    (listening on TCP:8081)
                            ↓
                    Process RPC Request
                            ↓
                    Return HTTP Response
                            ↓
                    WASM App receives response
```

### Remote Worker HTTP Server

The `RemoteRepo.dn` component:
1. Binds to TCP port (8081, 8082, etc.)
2. Accepts HTTP connections
3. Parses HTTP requests
4. Extracts JSON body
5. Calls `service.processHTTPRequest(HTTPMessage)`
6. Gets HTTP response string
7. Sends response back to client
8. Closes connection

### WASM Proxy

The `Matmul.proxy.dn` component:
1. Receives matrix multiplication request
2. Serializes to JSON
3. Makes HTTP POST to worker URL
4. Waits for HTTP response
5. Deserializes JSON response
6. Returns result

## Testing

### Test Remote Worker Directly

```bash
# Start worker
dana RemoteRepo.o 8081

# In another terminal, test with curl:
curl -X POST http://localhost:8081/rpc \
  -H "Content-Type: application/json" \
  -d '{"meta":[{"key":"method","value":"multiply"}],"content":"..."}'
```

### Test WASM App

1. Start both workers:
   ```bash
   dana RemoteRepo.o 8081
   dana RemoteRepo.o 8082
   ```

2. Start WASM app (via web server)

3. Send matrix multiplication request to WASM app

4. WASM app will distribute work to workers via HTTP

## Docker Setup (Optional)

If using Docker, update `docker-compose.yml` to:
- Expose ports 8081, 8082 for workers
- Use service names as hostnames
- Keep proxy URLs pointing to Docker service names

## Troubleshooting

### Worker won't start
- Check if port is already in use: `lsof -i :8081`
- Ensure native Dana runtime is installed (not WASM)

### WASM can't connect to workers
- Check CORS headers (if workers are on different origin)
- Verify worker URLs are correct (`localhost` vs Docker hostnames)
- Check network connectivity

### Workers not receiving requests
- Verify workers are running: `curl http://localhost:8081/rpc`
- Check proxy URLs match worker ports
- Ensure HTTP requests are POST (not GET)


