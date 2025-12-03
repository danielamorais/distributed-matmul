# Browser Workers Architecture (PoC)

## The Problem

Workers need to run in browsers on different machines, but **browsers can't listen on TCP ports**.

## The Solution

**Task Queue Pattern:** Workers poll a coordinator for tasks instead of listening for requests.

```
Coordinator (Dana)  ←  POST /task  ←  Main App (Browser)
        ↓
   Task Queue
        ↓
   GET /task/next  →  Workers (Browsers on different machines)
        ↓
   POST /result  ←  Workers (after computing)
```

## Architecture

```
┌─────────────────────────────────────┐
│  Machine A (Server)                 │
│  • Coordinator: Dana WASM -chip 64  │
│    Runtime: dana (native)           │
│    Port: 8080                       │
└─────────────────────────────────────┘
            ↓ HTTP
┌─────────────────────────────────────┐
│  Machine B (Browser)                │
│  • Worker: Dana WASM -chip 32       │
│    Runtime: browser                 │
│    Action: Poll → Compute → Submit  │
└─────────────────────────────────────┘
            ↓ HTTP
┌─────────────────────────────────────┐
│  Machine C (Browser)                │
│  • Worker: Dana WASM -chip 32       │
└─────────────────────────────────────┘
```

## Coordinator API (Dana Server)

Simple HTTP endpoints:

- `POST /task` - Submit task → returns `{taskId: 1}`
- `GET /task/next?workerId=abc` - Get next task → returns `{taskId: 1, data: {...}}`
- `POST /task/:id/result` - Submit result → returns `{status: "success"}`
- `GET /result/:id` - Get result → returns `{status: "completed", result: [...]}`
- `GET /stats` - Statistics

## Implementation Steps

### 1. Create Coordinator (Dana)

**File: `app/Coordinator.dn`**

Needs:
- Task queue (array of pending task IDs)
- Task storage (Map of taskId → task data)
- HTTP server on port 8080
- Handle 5 endpoints above

Compile: `dnc app/Coordinator.dn -os ubc -chip 64 -o wasm_output/app/Coordinator.o`

Run: `dana wasm_output/app/Coordinator.o 8080`

### 2. Create Worker Page (HTML/JS)

**File: `webserver/worker.html`**

Simple UI:
- Worker ID display
- Start/Stop button
- Task counter
- Activity log

**File: `webserver/worker-client.js`**

Logic:
```javascript
while (running) {
  task = await fetch('/task/next?workerId=' + workerId)
  if (task) {
    result = computeMatrix(task.data)
    await fetch('/task/' + task.id + '/result', {body: result})
  }
  await sleep(2000) // Poll every 2 seconds
}
```

### 3. Update Main App

Change from:
```dana
result = workerProxy.multiply(A, B)  // Direct call
```

To:
```dana
taskId = coordinator.submitTask(A, B)    // POST /task
result = coordinator.waitForResult(taskId) // Poll GET /result/:id
```

## Quick Start

```bash
# 1. Compile
./compile-wasm.sh

# 2. Start coordinator
dana wasm_output/app/Coordinator.o 8080

# 3. Open workers in browsers (different machines)
http://SERVER_IP:8080/worker.html

# 4. Open main app
http://SERVER_IP:8080/xdana.html
```

## Why This Works

| Component | Format | Runtime | Can Listen? | Why? |
|-----------|--------|---------|-------------|------|
| Coordinator | WASM -chip 64 | Dana native | ✅ Yes | Native runtime has OS access |
| Workers | WASM -chip 32 | Browser | ❌ No | Browser security restriction |

**Solution:** Workers don't listen, they **pull tasks** via HTTP GET requests.

## PoC Scope

**In Scope:**
- ✅ Basic coordinator (task queue, result storage)
- ✅ Simple worker page (polling, compute, submit)
- ✅ Main app integration (submit task, wait result)
- ✅ Test with 2-3 workers

**Out of Scope (for now):**
- ❌ WebSockets (use polling)
- ❌ Redis/database (use in-memory)
- ❌ Worker registration/heartbeat
- ❌ Task timeout/retry
- ❌ Load balancing algorithms
- ❌ Monitoring dashboard

Keep it simple. Get it working. Iterate later.

## Files Summary

**New Files:**
- `app/Coordinator.dn` - Dana coordinator server
- `webserver/worker.html` - Worker UI
- `webserver/worker-client.js` - Worker logic
- `run-coordinator.sh` - Startup script

**Modified Files:**
- `compile-wasm.sh` - Add coordinator compilation
- `app/mainWasm.dn` or client JS - Use coordinator API

That's it. Simple PoC for browser-based distributed workers.
