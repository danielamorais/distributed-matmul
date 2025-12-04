# Browser Workers PoC - Quick Start

Simple proof of concept for distributed matrix multiplication using browser-based workers.

## Architecture

```
┌─────────────────────────────────────────┐
│  Express Server (port 8080)             │
│  • Serves static files                  │
│  • Coordinator API endpoints            │
│  • Task queue (in-memory)               │
└─────────────────────────────────────────┘
            ↑
            │ HTTP (poll & submit)
            │
┌───────────┴─────────────────────────────┐
│  Browser Workers (worker.html)          │
│  • Poll GET /task/next                  │
│  • Compute matrix multiplication (JS)   │
│  • Submit POST /task/:id/result         │
└─────────────────────────────────────────┘
```

## Why This Works

**The Problem:** Browsers can't listen on TCP ports (security restriction)

**The Solution:** Workers **poll** for tasks instead of listening
- Coordinator manages task queue
- Workers request tasks via HTTP GET
- Workers compute and submit results via HTTP POST

## Quick Start

### 1. Start the Server

```bash
cd webserver
npm start
# or use: ./run-coordinator.sh
```

Server runs on `http://localhost:8080`

### 2. Open Workers (in Different Browsers/Machines)

Open multiple browser tabs/windows to:
```
http://localhost:8080/worker.html
```

Or on different machines:
```
http://SERVER_IP:8080/worker.html
```

Click **"Start Worker"** on each worker page.

### 3. Submit Tasks (Main App)

Open in another browser:
```
http://localhost:8080/xdana.html
```

Enter matrices and click **"Calculate"**. The coordinator will:
1. Queue the task
2. Assign it to an available worker
3. Return the result when complete

### 4. Monitor (Optional)

View coordinator statistics:
```
http://localhost:8080/stats
```

Returns JSON:
```json
{
  "totalTasks": 5,
  "completedTasks": 3,
  "activeTasks": 2,
  "queueSize": 0,
  "uptime": 123.45
}
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/task` | Submit new task |
| GET | `/task/next?workerId=abc` | Get next pending task |
| POST | `/task/:id/result` | Submit task result |
| GET | `/result/:id` | Get task result |
| GET | `/stats` | View statistics |

## Files

**Created for PoC:**
- `webserver/worker.html` - Worker UI
- `webserver/worker-client.js` - Worker polling logic
- `webserver/server.js` - Coordinator endpoints (added)

**Modified:**
- `webserver/server.js` - Added coordinator endpoints
- `run-coordinator.sh` - Simplified to start Express

## Testing

1. Start server: `cd webserver && npm start`
2. Open 2-3 worker tabs: `http://localhost:8080/worker.html`
3. Click "Start Worker" on each
4. Open main app: `http://localhost:8080/xdana.html`
5. Submit matrix multiplication tasks
6. Watch workers pick up and complete tasks

## What's In Scope (PoC)

✅ Task queue and assignment  
✅ Browser workers polling  
✅ Matrix multiplication computation  
✅ Result submission and retrieval  
✅ Basic statistics  

## What's Out of Scope (PoC)

❌ WebSockets (using polling)  
❌ Redis/database (in-memory only)  
❌ Worker heartbeat/health checks  
❌ Task timeouts/retry logic  
❌ Load balancing algorithms  
❌ Authentication/security  

## Architecture Notes

- **Simple:** Express server handles everything (static files + coordinator API)
- **No separate Dana coordinator process** - keeps it simple for PoC
- **In-memory storage** - tasks reset when server restarts
- **No persistence** - good enough for testing
- **Poll interval:** 2 seconds (configurable in `worker-client.js`)

## Next Steps (Beyond PoC)

If this works well, consider:
1. Implement coordinator in Dana (for learning purposes)
2. Add persistent storage (Redis/database)
3. Implement WebSocket for real-time updates
4. Add worker registration and health checks
5. Implement task timeout and retry logic

---

**Remember:** This is a **proof of concept**. Keep it simple. Get it working. Iterate later.



