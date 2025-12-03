# Coordinator Testing Guide

This guide explains how to test the native Dana coordinator server.

## Prerequisites

1. **Coordinator compiled and ready**
   ```bash
   dnc app/CoordinatorApp.dn
   dnc server/CoordinatorServer.dn
   ```

2. **Netcat installed** (for testing)
   ```bash
   # On Ubuntu/Debian
   sudo apt-get install netcat
   
   # On macOS
   brew install netcat
   ```

## Starting the Coordinator

```bash
# Start coordinator on default port 8080
dana CoordinatorApp.o 8080

# Or specify a different port
dana CoordinatorApp.o 3000
```

You should see:
```
========================================
  Dana Coordinator Server
========================================
Coordinator running at http://localhost:8080

Endpoints:
  POST /task           - Submit new task
  GET  /task/next      - Worker requests next task
  POST /task/:id/result - Worker submits result
  GET  /result/:id     - Get task result
  GET  /stats          - View statistics
  GET  /health         - Health check
========================================

[@CoordinatorApp] - HTTP server listening on port 8080
[@CoordinatorApp] - Waiting for connections...
```

## Quick Test Script

Run the automated test script:
```bash
chmod +x test-coordinator.sh
./test-coordinator.sh
```

This will test all endpoints and report results.

## Manual Testing

### 1. Health Check

```bash
echo -e "GET /health HTTP/1.1\r\nHost: localhost:8080\r\n\r\n" | nc localhost 8080
```

**Expected Response:**
```
HTTP/1.1 200 OK
Server: Dana Coordinator
Content-Length: 35
Content-Type: application/json
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
Access-Control-Allow-Origin: *

{"status":"ok","service":"coordinator"}
```

### 2. Submit a Task

```bash
echo -e "POST /task HTTP/1.1\r\nHost: localhost:8080\r\nContent-Type: application/json\r\nContent-Length: 33\r\n\r\n{\"A\":\"[[1,2],[3,4]]\",\"B\":\"[[5,6],[7,8]]\"}" | nc localhost 8080
```

**Expected Response:**
```
HTTP/1.1 200 OK
...
{"taskId":1}
```

### 3. Get Next Task (Worker Request)

```bash
echo -e "GET /task/next?workerId=worker1 HTTP/1.1\r\nHost: localhost:8080\r\n\r\n" | nc localhost 8080
```

**Expected Response:**
```
HTTP/1.1 200 OK
...
{"taskId":1,"data":{"A":"[[1,2],[3,4]]","B":"[[5,6],[7,8]]"}}
```

**Note:** If no tasks are available, you'll get:
```
HTTP/1.1 204 No Content
...
```

### 4. Submit Result

```bash
echo -e "POST /task/1/result HTTP/1.1\r\nHost: localhost:8080\r\nContent-Type: application/json\r\nContent-Length: 25\r\n\r\n{\"result\":\"[[19,22],[43,50]]\"}" | nc localhost 8080
```

**Expected Response:**
```
HTTP/1.1 200 OK
...
{"status":"success"}
```

### 5. Get Result

```bash
echo -e "GET /result/1 HTTP/1.1\r\nHost: localhost:8080\r\n\r\n" | nc localhost 8080
```

**Expected Response:**
```
HTTP/1.1 200 OK
...
{"taskId":1,"status":"completed","result":{"result":"[[19,22],[43,50]]"}}
```

### 6. Get Statistics

```bash
echo -e "GET /stats HTTP/1.1\r\nHost: localhost:8080\r\n\r\n" | nc localhost 8080
```

**Expected Response:**
```
HTTP/1.1 200 OK
...
{"totalTasks":1,"completedTasks":1,"activeTasks":0,"queueSize":0}
```

### 7. CORS Preflight (OPTIONS)

```bash
echo -e "OPTIONS /task HTTP/1.1\r\nHost: localhost:8080\r\n\r\n" | nc localhost 8080
```

**Expected Response:**
```
HTTP/1.1 200 OK
Server: Dana Coordinator
Content-Length: 0
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS
Access-Control-Allow-Headers: Content-Type

```

## Testing with Main WASM

The Main WASM app should be able to:
1. Submit tasks via `POST /task`
2. Poll for results via `GET /result/:id`

**Test Flow:**
1. Start coordinator: `dana CoordinatorApp.o 8080`
2. Open Main WASM app in browser
3. Submit a matrix multiplication task
4. Verify task is queued (check coordinator logs)
5. Wait for worker to process
6. Verify result is available

## Testing with Worker WASM

The Worker WASM app should be able to:
1. Poll for tasks via `GET /task/next?workerId=X`
2. Submit results via `POST /task/:id/result`

**Test Flow:**
1. Start coordinator: `dana CoordinatorApp.o 8080`
2. Open Worker WASM app in browser
3. Worker should start polling every ~2 seconds
4. Submit a task from Main WASM
5. Verify worker receives task
6. Verify worker submits result
7. Verify Main WASM receives result

## End-to-End Test Scenario

### Step 1: Start Coordinator
```bash
dana CoordinatorApp.o 8080
```

### Step 2: Submit Task (Main WASM simulation)
```bash
TASK_DATA='{"A":"[[1,2],[3,4]]","B":"[[5,6],[7,8]]"}'
echo -e "POST /task HTTP/1.1\r\nHost: localhost:8080\r\nContent-Type: application/json\r\nContent-Length: ${#TASK_DATA}\r\n\r\n$TASK_DATA" | nc localhost 8080
```

### Step 3: Worker Gets Task
```bash
echo -e "GET /task/next?workerId=wasm-worker-1 HTTP/1.1\r\nHost: localhost:8080\r\n\r\n" | nc localhost 8080
```

### Step 4: Worker Submits Result
```bash
RESULT_DATA='{"result":"[[19,22],[43,50]]"}'
echo -e "POST /task/1/result HTTP/1.1\r\nHost: localhost:8080\r\nContent-Type: application/json\r\nContent-Length: ${#RESULT_DATA}\r\n\r\n$RESULT_DATA" | nc localhost 8080
```

### Step 5: Main WASM Gets Result
```bash
echo -e "GET /result/1 HTTP/1.1\r\nHost: localhost:8080\r\n\r\n" | nc localhost 8080
```

## Troubleshooting

### Coordinator won't start
- Check if port 8080 is already in use: `lsof -i :8080`
- Try a different port: `dana CoordinatorApp.o 3000`

### No response from coordinator
- Check coordinator logs for errors
- Verify coordinator is actually running: `ps aux | grep CoordinatorApp`
- Test with netcat: `echo -e "GET /health HTTP/1.1\r\n\r\n" | nc localhost 8080`

### CORS errors in browser
- Verify CORS headers are present in responses
- Check browser console for specific error messages
- Ensure coordinator is running and accessible

### Tasks not being processed
- Check coordinator logs for task submission
- Verify worker is polling correctly
- Check `/stats` endpoint to see queue status

## Expected Behavior

### Task Lifecycle

1. **Submitted** → Task added to queue, status: `pending`
2. **Assigned** → Worker gets task, status: `processing`
3. **Completed** → Worker submits result, status: `completed`
4. **Retrieved** → Main WASM gets result

### Statistics

- `totalTasks`: Total tasks ever submitted
- `completedTasks`: Tasks that have been completed
- `activeTasks`: Tasks currently being processed
- `queueSize`: Tasks waiting in queue

## Next Steps

After verifying all endpoints work:
1. Test with actual Main WASM app
2. Test with actual Worker WASM app
3. Test with multiple workers
4. Test concurrent task submission
5. Verify CORS headers work in browser

