# Quick Start: Dana Integrated Server

## 🎉 Express.js Migration Complete!

The Dana server now includes all functionality previously provided by Express.js:
- ✅ Static file serving
- ✅ Task coordination (queue management)
- ✅ COOP/COEP headers for SharedArrayBuffer
- ✅ Matrix multiplication

## Start the Server

```bash
# Compile everything
./compile.sh

# Start the integrated Dana server on port 2010
dana app/NetworkServerApp.o 3 2010
```

**Parameters**:
- `3` = Mode (1=proxy, 2=adaptive, 3=local)
- `2010` = Port number

## Available Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Main page (xdana.html) |
| `/stats` | GET | Queue statistics |
| `/task` | POST | Submit task |
| `/task/next` | GET | Get next task for worker |
| `/task/:id/result` | POST | Submit task result |
| `/result/:id` | GET | Get task result |
| `/matmul` | POST | Matrix multiplication |
| `/*.html`, `/*.js`, etc. | GET | Static files |

## Test It

### Using netcat (recommended for testing)
```bash
# Test stats endpoint
echo -e "GET /stats HTTP/1.0\r\nHost: localhost\r\n\r\n" | nc localhost 2010

# Test root page
echo -e "GET / HTTP/1.0\r\nHost: localhost\r\n\r\n" | nc localhost 2010
```

### Using a browser
```bash
# Open in your browser
open http://localhost:2010/xdana.html
```

## Example: Submit and Process a Task

### 1. Submit a task
```bash
echo -e "POST /task HTTP/1.0\r\nHost: localhost\r\nContent-Length: 13\r\n\r\n{\"data\":123}" | nc localhost 2010
```

Response: `{"taskId":1}`

### 2. Worker gets next task
```bash
echo -e "GET /task/next?workerId=worker1 HTTP/1.0\r\nHost: localhost\r\n\r\n" | nc localhost 2010
```

Response: `{"taskId":1,"data":{"data":123}}`

### 3. Worker submits result
```bash
echo -e "POST /task/1/result HTTP/1.0\r\nHost: localhost\r\nContent-Length: 18\r\n\r\n{\"result\":\"done\"}" | nc localhost 2010
```

Response: `{"status":"success"}`

### 4. Check stats
```bash
echo -e "GET /stats HTTP/1.0\r\nHost: localhost\r\n\r\n" | nc localhost 2010
```

Response: `{"totalTasks":1,"completedTasks":1,"activeTasks":0,"queueSize":0}`

## COOP/COEP Headers

All responses include these headers for SharedArrayBuffer support:
```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

## Architecture

```
                     ┌─────────────────────────────┐
Browser/Client  ──→  │   Dana NetworkServerApp     │
                     │       (Port 2010)           │
                     └──────────┬──────────────────┘
                                │
                     ┌──────────▼──────────────────┐
                     │      server.Server          │
                     │   (Integrated Router)       │
                     └──────┬────────┬────────┬────┘
                            │        │        │
                    ┌───────▼──┐  ┌──▼───┐  ┌▼────────────┐
                    │Coordinator│  │Matmul│  │StaticFile   │
                    │Controller │  │ Ctrl │  │Server       │
                    └───────────┘  └──────┘  └─────────────┘
```

## Troubleshooting

### Port already in use
```bash
# Find process using port 2010
lsof -i :2010

# Kill it
kill -9 <PID>
```

### Curl hangs
Use `netcat` instead for testing (curl has timing issues with Dana's socket handling):
```bash
echo -e "GET /stats HTTP/1.0\r\n\r\n" | nc localhost 2010
```

### Server won't start
```bash
# Check logs
tail -f /tmp/dana-integrated-server.log

# Recompile
./compile.sh
```

## What's Next?

- Start browser workers: `./run-remote-wasm.sh 8081`
- Test matrix multiplication through the browser UI
- Deploy to production (single Dana binary!)

## Files Changed

- **Modified**: `server/Server.dn` - Integrated routing
- **Created**: `app/NetworkServerApp.dn` - Network listener
- **Working**: `server/CoordinatorController.dn` - Task queue
- **Working**: `server/StaticFileServerImpl.dn` - File serving

See `MIGRATION_STATUS.md` for full details.



