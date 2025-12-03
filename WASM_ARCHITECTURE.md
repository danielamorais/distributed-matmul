# WASM Architecture Overview

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Browser Tab 1                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  xdana.html (Main Application)                        │  │
│  │  ┌────────────────────────────────────────────────┐ │  │
│  │  │  Dana WASM Runtime                              │ │  │
│  │  │  ┌────────────────────────────────────────────┐ │ │  │
│  │  │  │  app/main.o (Main WASM App)               │ │ │  │
│  │  │  │  - User submits matrix multiplication      │ │ │  │
│  │  │  │  - Makes HTTP POST to /matmul              │ │ │  │
│  │  │  │  - Polls GET /result/:id for result        │ │ │  │
│  │  │  └────────────────────────────────────────────┘ │ │  │
│  │  └────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────┘  │
└───────────────────────┬─────────────────────────────────────┘
                        │ HTTP
                        │ POST /matmul
                        │ GET /result/:id
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              Node.js Server (server.js)                      │
│              Port: 8080                                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Coordinator                                          │  │
│  │  - Task Queue Management                              │  │
│  │  - Task Assignment                                    │  │
│  │  - Result Storage                                     │  │
│  │                                                       │  │
│  │  Endpoints:                                           │  │
│  │  - POST /matmul → Creates task, returns taskId       │  │
│  │  - GET /task/next → Returns next pending task        │  │
│  │  - POST /task/:id/result → Receives result           │  │
│  │  - GET /result/:id → Returns task result             │  │
│  └──────────────────────────────────────────────────────┘  │
└───────────────────────┬─────────────────────────────────────┘
                        │ HTTP
                        │ GET /task/next
                        │ POST /task/:id/result
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                    Browser Tab 2                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  worker-dana-wasm.html (Worker)                       │  │
│  │  ┌────────────────────────────────────────────────┐ │  │
│  │  │  Dana WASM Runtime                              │ │  │
│  │  │  ┌────────────────────────────────────────────┐ │ │  │
│  │  │  │  app/BrowserWorkerWasm.o (Worker WASM)    │ │ │  │
│  │  │  │  ┌──────────────────────────────────────┐ │ │ │  │
│  │  │  │  │  BrowserWorkerLoop (ProcessLoop)     │ │ │ │  │
│  │  │  │  │  - Polls GET /task/next every 2s     │ │ │ │  │
│  │  │  │  │  - Receives task (matrices A, B)      │ │ │ │  │
│  │  │  │  │  - Computes: matmul.multiply(A, B)   │ │ │ │  │
│  │  │  │  │  - POST /task/:id/result with result │ │ │ │  │
│  │  │  │  └──────────────────────────────────────┘ │ │ │  │
│  │  │  └────────────────────────────────────────────┘ │  │
│  │  └────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Component Breakdown

### 1. Main Application (WASM)
- **File:** `webserver/xdana.html`
- **Component:** `app/main.o` (Dana WASM)
- **Purpose:** User interface for submitting matrix multiplication tasks
- **Behavior:**
  - Loads Dana WASM runtime
  - User enters matrices A and B
  - Submits task via `POST /matmul` to coordinator
  - Polls `GET /result/:id` to get computed result
  - Displays result to user

### 2. Coordinator (Node.js)
- **File:** `webserver/server.js`
- **Runtime:** Node.js (JavaScript)
- **Purpose:** Task queue management and coordination
- **Endpoints:**
  - `POST /matmul` - Receives task submission from main app
  - `GET /task/next?workerId=X` - Returns next task to worker
  - `POST /task/:id/result` - Receives result from worker
  - `GET /result/:id` - Returns result to main app
- **State Management:**
  - Task queue (pending tasks)
  - Task storage (task data and results)
  - Task status tracking

### 3. Worker (WASM)
- **File:** `webserver/worker-dana-wasm.html`
- **Component:** `app/BrowserWorkerWasm.o` (Dana WASM)
- **Purpose:** Process matrix multiplication tasks
- **Behavior:**
  - Loads Dana WASM runtime
  - Runs `BrowserWorkerLoop` ProcessLoop
  - Polls coordinator every ~2 seconds for tasks
  - Receives task with matrices A and B
  - Computes result using `matmul.Matmul` component (pure Dana)
  - Submits result back to coordinator

## Data Flow

### Task Submission Flow
```
1. User enters matrices in xdana.html
   ↓
2. Main WASM app (app/main.o) sends:
   POST /matmul
   Body: { A: "1,2;3,4", B: "5,6;7,8" }
   ↓
3. Coordinator (server.js) creates task:
   - Generates taskId
   - Stores task in queue
   - Returns { taskId: 1 }
   ↓
4. Main WASM app receives taskId
   ↓
5. Main WASM app polls:
   GET /result/1
   (Repeats until result is available)
```

### Task Processing Flow
```
1. Worker WASM (BrowserWorkerLoop) polls:
   GET /task/next?workerId=worker-wasm-0
   ↓
2. Coordinator returns task (if available):
   { taskId: 1, data: { A: "1,2;3,4", B: "5,6;7,8" } }
   ↓
3. Worker receives task
   ↓
4. Worker computes (pure Dana):
   result = matmul.multiply(A, B)
   ↓
5. Worker submits result:
   POST /task/1/result
   Body: { result: "19,22;43,50" }
   ↓
6. Coordinator stores result
   ↓
7. Main WASM app's next poll gets result:
   GET /result/1 → { status: "completed", result: "19,22;43,50" }
```

## Key Characteristics

### ✅ Pure Dana Computation
- **Main App:** Runs in Dana WASM (for UI and task submission)
- **Worker:** Runs in Dana WASM (for computation)
- **Computation:** All matrix multiplication happens in Dana code using `matmul.Matmul` component
- **No JavaScript Computation:** JavaScript only handles HTTP requests and UI

### ✅ Non-Blocking Architecture
- **Main App:** Uses HTTP polling (non-blocking)
- **Worker:** Uses ProcessLoop with async HTTP requests (non-blocking)
- **Coordinator:** Node.js handles requests asynchronously

### ✅ Decoupled Components
- Main app and worker are separate browser tabs/windows
- They communicate only through the coordinator
- No direct communication between main and worker
- Multiple workers can process tasks in parallel

## File Structure

```
distributed-matmul/
├── app/
│   ├── main.dn                    # Main WASM application
│   └── BrowserWorkerWasm.dn       # Worker WASM entry point
├── resources/
│   ├── BrowserWorkerLoop.dn       # Worker ProcessLoop interface
│   └── BrowserWorkerLoopImpl.dn   # Worker ProcessLoop implementation
├── matmul/
│   └── Matmul.dn                  # Matrix multiplication component
├── webserver/
│   ├── xdana.html                 # Main app HTML (loads app/main.o)
│   ├── worker-dana-wasm.html     # Worker HTML (loads app/BrowserWorkerWasm.o)
│   ├── server.js                  # Node.js coordinator
│   ├── dana.js                    # Dana WASM runtime
│   ├── dana.wasm                  # Dana WASM binary
│   └── file_system.js             # WASM file system (packaged components)
└── compile-worker-wasm.sh         # Compile worker components
└── package-worker-wasm.sh         # Package worker for WASM
```

## Communication Protocol

### HTTP Endpoints

| Endpoint | Method | From | To | Purpose |
|----------|--------|------|-----|---------|
| `/matmul` | POST | Main WASM | Coordinator | Submit task |
| `/task/next` | GET | Worker WASM | Coordinator | Get next task |
| `/task/:id/result` | POST | Worker WASM | Coordinator | Submit result |
| `/result/:id` | GET | Main WASM | Coordinator | Get result |

### Request/Response Examples

**Submit Task:**
```http
POST /matmul HTTP/1.1
Content-Type: application/json

{
  "A": "1,2;3,4",
  "B": "5,6;7,8"
}

Response:
{
  "taskId": 1
}
```

**Get Next Task:**
```http
GET /task/next?workerId=worker-wasm-0 HTTP/1.1

Response (task available):
{
  "taskId": 1,
  "data": {
    "A": "1,2;3,4",
    "B": "5,6;7,8"
  }
}

Response (no task):
204 No Content
```

**Submit Result:**
```http
POST /task/1/result HTTP/1.1
Content-Type: application/json

{
  "result": "19,22;43,50"
}

Response:
{
  "status": "success"
}
```

**Get Result:**
```http
GET /result/1 HTTP/1.1

Response:
{
  "taskId": 1,
  "status": "completed",
  "result": "19,22;43,50"
}
```

## Summary

**Yes, the architecture is:**

```
Main in WASM (xdana.html + app/main.o)
    ↕ HTTP
Node.js Server (server.js - Coordinator)
    ↕ HTTP
Worker in WASM (worker-dana-wasm.html + app/BrowserWorkerWasm.o)
```

**Key Points:**
- ✅ Main application runs in Dana WASM
- ✅ Coordinator runs in Node.js (JavaScript)
- ✅ Worker runs in Dana WASM
- ✅ All computation happens in Dana code
- ✅ Communication via HTTP through coordinator
- ✅ No direct JavaScript ↔ Dana function calls

---

*Last Updated: After implementing pure Dana WASM worker*



