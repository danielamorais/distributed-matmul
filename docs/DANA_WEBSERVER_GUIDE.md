# Dana WebServer - Pure Dana Backend Implementation

## Overview

This is a **complete native Dana web server** that replaces Express.js, providing all backend functionality in pure Dana:
- HTTP server with static file serving
- Task coordination for browser workers
- Matrix multiplication RPC service
- COOP/COEP headers for SharedArrayBuffer support

## Architecture

```
WebServerApp (app/WebServerApp.dn)
    └─ WebServerProcessLoop (server/WebServerProcessLoop.dn)
        └─ WebServerImpl (server/WebServerImpl.dn)
            ├─ CoordinatorController (server/CoordinatorController.dn)
            │   └─ In-memory task queue and coordination logic
            ├─ MatmulController (server/MatmulController.dn)
            │   └─ Matrix multiplication RPC handler
            └─ StaticFileServerImpl (server/StaticFileServerImpl.dn)
                └─ Serves HTML, JS, WASM, images, fonts, etc.
```

## Components Created

### 1. **Coordinator System**
- **Interface**: `resources/server/Coordinator.dn`
- **Implementation**: `server/CoordinatorController.dn`
- **Endpoints**:
  - `POST /task` - Submit new task
  - `GET /task/next?workerId=X` - Worker requests next task
  - `POST /task/:id/result` - Worker submits result
  - `GET /result/:id` - Get task result
  - `GET /stats` - Get statistics

### 2. **Static File Server**
- **Interface**: `resources/server/StaticFileServer.dn`
- **Implementation**: `server/StaticFileServerImpl.dn`
- **Features**:
  - Serves files from `webserver/` directory
  - MIME type detection (HTML, JS, WASM, CSS, images, fonts)
  - Directory index support (index.html)
  - 404 handling

### 3. **WebServer Integration**
- **Interface**: `resources/server/WebServer.dn`
- **Implementation**: `server/WebServerImpl.dn`
- **Features**:
  - Routes requests to appropriate controllers
  - Adds COOP/COEP headers to all responses
  - Supports local/proxy/adaptive modes
  - Integrates matmul, coordinator, and static serving

### 4. **Process Loop**
- **Implementation**: `server/WebServerProcessLoop.dn`
- Manages request/response queues
- Thread-safe processing with mutexes

### 5. **Main Application**
- **Implementation**: `app/WebServerApp.dn`
- Entry point for the Dana web server

## How to Run

### Quick Start

```bash
# Compile and run (uses default port 2001)
./run-webserver.sh

# Or compile manually and run with mode
dnc app/WebServerApp.dn
dana app/WebServerApp.o 3
```

### Server Modes

```bash
# Mode 1: Proxy mode (forwards to remote servers)
dana app/WebServerApp.o 1

# Mode 2: Adaptive mode (switches based on performance)
dana app/WebServerApp.o 2

# Mode 3: Local mode (processes locally) [DEFAULT]
dana app/WebServerApp.o 3
```

### Access the Application

Open your browser to:
```
http://localhost:2001/xdana.html
```

## Migration Comparison

### Before (Express.js)
```
┌─────────────────────────┐
│   Node.js + Express     │
│  - Static file serving  │
│  - COOP/COEP headers    │
│  - Task coordination    │
│  - RPC format conversion│
└────────┬────────────────┘
         │ HTTP Proxy
         ▼
┌─────────────────────────┐
│    Dana Native Server   │
│  - Matrix multiplication│
└─────────────────────────┘
```

**Start commands:**
```bash
cd webserver && npm start          # Port 8080 (Express)
dana app/main.o 3                  # Port 2001 (Dana)
```

### After (Pure Dana)
```
┌─────────────────────────┐
│  Dana WebServer (ALL)   │
│  - Static file serving  │
│  - COOP/COEP headers    │
│  - Task coordination    │
│  - Matrix multiplication│
└─────────────────────────┘
```

**Start command:**
```bash
dana app/WebServerApp.o 3          # Port 2001 (All-in-one)
```

## Benefits

1. ✅ **Single Runtime**: No Node.js dependency
2. ✅ **Single Process**: One server instead of two
3. ✅ **No RPC Conversion**: Direct processing, no format translation
4. ✅ **Simpler Deployment**: Single binary
5. ✅ **Consistent Logging**: Unified error handling
6. ✅ **Better Performance**: Remove proxy overhead

## API Compatibility

The Dana WebServer maintains **full API compatibility** with the Express version:

### Coordinator API
- ✅ `POST /task` - Same request/response format
- ✅ `GET /task/next` - Same query params and response
- ✅ `POST /task/:id/result` - Same request/response
- ✅ `GET /result/:id` - Same response format
- ✅ `GET /stats` - Same statistics format

### Matrix Multiplication API
- ✅ `POST /matmul` - Same RPC format (handled by MatmulController)

### Static Files
- ✅ All files served from `webserver/` directory
- ✅ COOP/COEP headers added automatically
- ✅ MIME types detected correctly

## Testing

### 1. Test Static File Serving
```bash
curl http://localhost:2001/xdana.html
# Should return HTML content
```

### 2. Test Task Coordination
```bash
# Submit task
curl -X POST http://localhost:2001/task \
  -H "Content-Type: application/json" \
  -d '{"A":"[[1,2],[3,4]]","B":"[[5,6],[7,8]]"}'

# Get next task
curl http://localhost:2001/task/next?workerId=test-worker

# Submit result
curl -X POST http://localhost:2001/task/1/result \
  -H "Content-Type: application/json" \
  -d '[[19,22],[43,50]]'

# Get result
curl http://localhost:2001/result/1
```

### 3. Test Matrix Multiplication
```bash
curl -X POST http://localhost:2001/matmul \
  -H "Content-Type: application/json" \
  -d '{"A":"[[1,2],[3,4]]","B":"[[5,6],[7,8]]"}'
```

### 4. Test Browser Workers
1. Open `http://localhost:2001/xdana.html`
2. Submit a matrix multiplication
3. Check browser console for worker activity
4. Verify results are displayed correctly

## File Structure

```
app/
  └─ WebServerApp.dn           # Main entry point
server/
  ├─ CoordinatorController.dn  # Task coordination logic
  ├─ StaticFileServerImpl.dn   # Static file serving
  ├─ WebServerImpl.dn          # Main server integrator
  └─ WebServerProcessLoop.dn   # Request/response loop
resources/server/
  ├─ Coordinator.dn            # Coordinator interface
  ├─ StaticFileServer.dn       # Static server interface
  └─ WebServer.dn              # WebServer interface
```

## Configuration

### Change Port
The Dana server uses port **2001** by default (defined in the native layer). To use a different port, you'll need to set it through environment variables or command-line arguments when starting the Dana runtime.

### Change Static Files Directory
Edit `server/WebServerImpl.dn`:
```dana
staticServer.setBasePath("your/directory")
```

### Enable/Disable Features
Comment out controllers in `server/WebServerImpl.dn` `process()` method to disable specific features.

## Troubleshooting

### Port Already in Use
```bash
# Check what's using port 2001
lsof -i :2001

# Kill the process
kill -9 <PID>
```

### File Not Found Errors
- Ensure `webserver/` directory exists
- Check file paths are relative to execution directory
- Verify files have read permissions

### Compilation Errors
```bash
# Clean and recompile everything
rm -f *.o server/*.o app/*.o
dnc app/WebServerApp.dn
```

### COOP/COEP Headers Not Working
- Headers are added in `sendResponseWithHeaders()` in `WebServerImpl.dn`
- Check browser console for Cross-Origin errors
- Verify all resources are same-origin

## Performance Notes

- **In-memory storage**: Task queue uses simple arrays (fine for PoC, consider optimizing for production)
- **Thread safety**: All shared state protected by mutexes
- **Timestamps**: Uses monotonic counter (not wall-clock time)
- **File I/O**: Reads entire file into memory (fine for web assets, not suitable for large files)

## Future Enhancements (Post-PoC)

- [ ] Persistent task storage (Redis-like)
- [ ] Worker timeout and retry logic
- [ ] Request body size limits
- [ ] Compression (gzip)
- [ ] Caching with ETag support
- [ ] HTTPS/TLS support
- [ ] Authentication/authorization
- [ ] Rate limiting
- [ ] Metrics and monitoring
- [ ] Health check endpoint improvements

## License

Same as the parent project.



