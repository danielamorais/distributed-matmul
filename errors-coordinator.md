# Coordinator Errors and Issues

This document tracks errors and issues found during testing of the native Dana coordinator.

## Test Results Summary

**Date:** December 2, 2024  
**Test Environment:** Native Dana coordinator (`app/CoordinatorApp.o`)

### Test Status
- ✅ **Passed:** 1 test (Health Check)
- ❌ **Failed:** 8 tests (Stats, Task Submission, Worker Polling, Result Submission, etc.)

## Issues Found

### Issue 1: Stats Endpoint Hangs

**Symptom:**
- `GET /health` endpoint works correctly and returns response immediately
- `GET /stats` endpoint hangs - no response is returned
- Connection appears to be open but no data is sent back

**Test Command:**
```bash
echo -e "GET /stats HTTP/1.1\r\nHost: localhost:8080\r\nConnection: close\r\n\r\n" | nc localhost 8080
```

**Expected Behavior:**
- Should return JSON with statistics: `{"totalTasks":0,"completedTasks":0,"activeTasks":0,"queueSize":0}`

**Actual Behavior:**
- No response received
- Connection hangs indefinitely
- Coordinator process remains running (doesn't crash)

**Root Cause Analysis:**
The issue likely stems from how `CoordinatorController` is being instantiated. The coordinator is using auto-instantiation via `requires server.Coordinator coordinator`, but `CoordinatorController` may need to be manually loaded using `RecursiveLoader` like in `server/Server.dn`.

**Evidence:**
- Health endpoint works (handled directly in `CoordinatorServer`, not routed to Coordinator)
- Stats endpoint fails (routed to `coordinator.handle(request)`, which may be null or not properly initialized)

### Issue 2: Task Submission Endpoint Hangs

**Symptom:**
- `POST /task` endpoint hangs - no response is returned
- Similar behavior to stats endpoint

**Test Command:**
```bash
TASK_DATA='{"A":"[[1,2],[3,4]]","B":"[[5,6],[7,8]]"}'
echo -e "POST /task HTTP/1.1\r\nHost: localhost:8080\r\nContent-Type: application/json\r\nContent-Length: ${#TASK_DATA}\r\n\r\n$TASK_DATA" | nc localhost 8080
```

**Expected Behavior:**
- Should return JSON with task ID: `{"taskId":1}`

**Actual Behavior:**
- No response received
- Connection hangs

**Root Cause:**
Same as Issue 1 - CoordinatorController not properly initialized.

### Issue 3: Worker Task Polling Hangs

**Symptom:**
- `GET /task/next?workerId=X` endpoint hangs

**Test Command:**
```bash
echo -e "GET /task/next?workerId=test-worker HTTP/1.1\r\nHost: localhost:8080\r\n\r\n" | nc localhost 8080
```

**Expected Behavior:**
- Should return task data or 204 No Content if no tasks available

**Actual Behavior:**
- No response received
- Connection hangs

### Issue 4: Result Submission Hangs

**Symptom:**
- `POST /task/:id/result` endpoint hangs

**Test Command:**
```bash
RESULT_DATA='{"result":"[[19,22],[43,50]]"}'
echo -e "POST /task/1/result HTTP/1.1\r\nHost: localhost:8080\r\nContent-Type: application/json\r\nContent-Length: ${#RESULT_DATA}\r\n\r\n$RESULT_DATA" | nc localhost 8080
```

**Expected Behavior:**
- Should return: `{"status":"success"}`

**Actual Behavior:**
- No response received
- Connection hangs

### Issue 5: Result Retrieval Hangs

**Symptom:**
- `GET /result/:id` endpoint hangs

**Test Command:**
```bash
echo -e "GET /result/1 HTTP/1.1\r\nHost: localhost:8080\r\n\r\n" | nc localhost 8080
```

**Expected Behavior:**
- Should return task result or 404 if not found

**Actual Behavior:**
- No response received
- Connection hangs

## Root Cause Analysis

### Primary Issue: CoordinatorController Not Properly Initialized

**Current Implementation:**
```dana
component provides App requires ... server.Coordinator coordinator {
    // coordinator is auto-instantiated
    char response[] = coordinatorServer.handleRequest(httpMsg, coordinator, httpUtil)
}
```

**Problem:**
Dana's auto-instantiation may not be finding or properly instantiating `CoordinatorController`. The component needs to be explicitly loaded using `RecursiveLoader` like in `server/Server.dn`:

```dana
LoadedComponents coordinatorComp = loader.load("server/CoordinatorController.o")
coordinator = new Coordinator() from coordinatorComp.mainComponent
```

**Evidence:**
1. Health endpoint works (bypasses Coordinator interface)
2. All Coordinator-handled endpoints hang (suggesting `coordinator` is null or not initialized)
3. No errors in logs (coordinator doesn't crash, just hangs)

### Secondary Issue: Error Handling

**Problem:**
If `coordinator.handle(request)` returns `null` or throws an exception, the code should handle it gracefully, but currently it may be hanging instead of returning an error response.

**Current Code:**
```dana
Response res = coordinator.handle(request)

if (res == null) {
    // 404 Not Found
    return build404Response(request, httpUtil)
}
```

**Issue:**
If `coordinator` is null or not initialized, calling `coordinator.handle(request)` may cause a hang rather than an exception.

## Working Endpoints

### ✅ Health Check (`GET /health`)

**Status:** ✅ Working

**Response:**
```
HTTP/1.1 200 OK
Server: Dana Coordinator
Content-Length: 39
Connection: close
Content-Type: application/json
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS
Access-Control-Allow-Headers: Content-Type

{"status":"ok","service":"coordinator"}
```

**Why it works:**
- Handled directly in `CoordinatorServer.buildHealthResponse()`
- Does not route through `Coordinator` interface
- No dependency on CoordinatorController

## Recommended Fixes

### Fix 1: Use RecursiveLoader for CoordinatorController

**File:** `app/CoordinatorApp.dn`

**Change:**
```dana
component provides App requires ... composition.RecursiveLoader loader {
    Coordinator coordinator
    
    int App:main(AppParam params[]) {
        // Load CoordinatorController explicitly
        LoadedComponents coordinatorComp = loader.load("server/CoordinatorController.o")
        coordinator = new Coordinator() from coordinatorComp.mainComponent
        
        // ... rest of code
    }
}
```

### Fix 2: Add Null Check Before Calling Coordinator

**File:** `server/CoordinatorServer.dn`

**Change:**
```dana
char[] CoordinatorServer:handleRequest(HTTPMessage request, Coordinator coordinator,
        HTTPUtil httpUtil) {
    
    // Handle OPTIONS (CORS preflight)
    if (request.command == "OPTIONS") {
        return buildCORSResponse(httpUtil)
    }
    
    // Handle health check
    if (request.resource == "/health" && request.command == "GET") {
        return buildHealthResponse(httpUtil)
    }
    
    // Check if coordinator is initialized
    if (coordinator == null) {
        char body[] = "{\"error\":\"Coordinator not initialized\"}"
        char serverName[] = "Dana Coordinator"
        Response res = new Response(
            500,
            "Internal Server Error",
            serverName,
            body.arrayLength,
            "application/json",
            body
        )
        return buildResponseWithCORS(res, httpUtil)
    }
    
    // Route to coordinator
    Response res = coordinator.handle(request)
    
    if (res == null) {
        return build404Response(request, httpUtil)
    }
    
    return buildResponseWithCORS(res, httpUtil)
}
```

### Fix 3: Add Error Logging

**File:** `app/CoordinatorApp.dn`

**Change:**
```dana
void handleHTTPRequest(TCPSocket client) {
    char request[] = client.recv(8192)
    
    if (request == null || request.arrayLength == 0) {
        out.println("$debugMSG - Warning: received empty request")
        client.disconnect()
        return
    }
    
    try {
        HTTPMessage httpMsg = httpUtil.readHTTPRequest(request)
        char response[] = coordinatorServer.handleRequest(httpMsg, coordinator, httpUtil)
        
        if (response == null || response.arrayLength == 0) {
            out.println("$debugMSG - Warning: server returned empty response")
            client.disconnect()
            return
        }
        
        int sent = client.send(response)
        // ... rest of code
    } catch (Exception e) {
        out.println("$debugMSG - Error handling request: $e")
        client.disconnect()
    }
}
```

## Testing Notes

### Successful Tests
- ✅ Coordinator starts and binds to port 8080
- ✅ Health endpoint responds correctly
- ✅ CORS headers are present in responses
- ✅ Server process remains stable (doesn't crash)

### Failed Tests
- ❌ Stats endpoint hangs
- ❌ Task submission hangs
- ❌ Worker polling hangs
- ❌ Result submission hangs
- ❌ Result retrieval hangs
- ❌ OPTIONS preflight hangs (when routed through coordinator)

### Test Environment
- **OS:** Linux (Fedora 42)
- **Dana Version:** Native runtime
- **Port:** 8080
- **Test Tool:** netcat (nc)
- **Coordinator Process:** Running, stable, no crashes

## Next Steps

1. **Implement Fix 1:** Use RecursiveLoader to explicitly load CoordinatorController
2. **Implement Fix 2:** Add null checks and better error handling
3. **Implement Fix 3:** Add error logging for debugging
4. **Re-test:** Run automated tests again after fixes
5. **Verify:** Test with actual Main WASM and Worker WASM clients

---

## Issues Resolved

**Date:** December 2, 2024  
**Status:** ✅ All issues fixed and tested

### Summary of Issues Found

1. **Primary Issue:** CoordinatorController not properly initialized (causing all endpoints to hang)
2. **Secondary Issue:** Missing null checks before calling coordinator methods
3. **Path Parsing Bug:** Incorrect array index used when extracting task IDs from URLs

### Solutions Implemented

#### Solution 1: Explicit Component Loading with RecursiveLoader

**Issue:** Auto-instantiation of `CoordinatorController` was failing, causing `coordinator` to be null or uninitialized.

**Fix Applied:** Modified `app/CoordinatorApp.dn` to use `RecursiveLoader` for explicit component loading:

```dana
component provides App requires ... composition.RecursiveLoader loader {
    Coordinator coordinator
    
    int App:main(AppParam params[]) {
        // Load CoordinatorController explicitly using RecursiveLoader
        out.println("$debugMSG - Loading CoordinatorController...")
        LoadedComponents coordinatorComp = loader.load("server/CoordinatorController.o")
        
        if (coordinatorComp == null || coordinatorComp.mainComponent == null) {
            out.println("$debugMSG - Error: Failed to load CoordinatorController")
            return 1
        }
        
        coordinator = new Coordinator() from coordinatorComp.mainComponent
        
        if (coordinator == null) {
            out.println("$debugMSG - Error: Failed to instantiate Coordinator")
            return 1
        }
        
        out.println("$debugMSG - CoordinatorController loaded successfully")
        // ... rest of initialization
    }
}
```

**Result:** CoordinatorController now loads and initializes correctly, resolving all hanging endpoints.

#### Solution 2: Null Check Before Coordinator Calls

**Issue:** If coordinator was null, calling `coordinator.handle(request)` would cause a hang instead of returning an error.

**Fix Applied:** Added null check in `server/CoordinatorServer.dn`:

```dana
char[] CoordinatorServer:handleRequest(HTTPMessage request, Coordinator coordinator,
        HTTPUtil httpUtil) {
    
    // Handle OPTIONS (CORS preflight)
    if (request.command == "OPTIONS") {
        return buildCORSResponse(httpUtil)
    }
    
    // Handle health check
    if (request.resource == "/health" && request.command == "GET") {
        return buildHealthResponse(httpUtil)
    }
    
    // Check if coordinator is initialized
    if (coordinator == null) {
        out.println("$debugMSG - Error: Coordinator not initialized")
        char body[] = "{\"error\":\"Coordinator not initialized\"}"
        char serverName[] = "Dana Coordinator"
        Response res = new Response(
            500,
            "Internal Server Error",
            serverName,
            body.arrayLength,
            "application/json",
            body
        )
        return buildResponseWithCORS(res, httpUtil)
    }
    
    // Route to coordinator
    Response res = coordinator.handle(request)
    // ... rest of code
}
```

**Result:** Proper error responses returned when coordinator is not initialized, preventing hangs.

#### Solution 3: Error Logging and Validation

**Issue:** Lack of error logging made debugging difficult.

**Fix Applied:** Added comprehensive error logging in `app/CoordinatorApp.dn`:

```dana
void handleHTTPRequest(TCPSocket client) {
    char request[] = client.recv(8192)
    
    if (request == null || request.arrayLength == 0) {
        out.println("$debugMSG - Warning: received empty request")
        client.disconnect()
        return
    }
    
    // Parse HTTP request
    HTTPMessage httpMsg = httpUtil.readHTTPRequest(request)
    
    if (httpMsg == null) {
        out.println("$debugMSG - Error: Failed to parse HTTP request")
        client.disconnect()
        return
    }
    
    // Process through coordinator server
    char response[] = coordinatorServer.handleRequest(httpMsg, coordinator, httpUtil)
    
    if (response == null || response.arrayLength == 0) {
        out.println("$debugMSG - Warning: server returned empty response")
        client.disconnect()
        return
    }
    
    // ... rest of code
}
```

**Result:** Better visibility into request processing and error conditions.

#### Solution 4: Path Parsing Bug Fix

**Issue:** Path extraction functions used incorrect array indices when parsing URLs.

**Root Cause:** When exploding `/task/1/result` by `/`, the `explode` function returns `["task", "1", "result"]` (no leading empty element). The code was checking `parts[2]` (which is "result") instead of `parts[1]` (which is "1").

**Fix Applied:** Corrected path parsing in `server/CoordinatorController.dn`:

```dana
int extractTaskIdFromPath(char path[]) {
    // Extract ID from /task/123/result
    // First, remove query string if present
    char cleanPath[] = path
    int qmark = su.find(path, "?", 0)
    if (qmark != StringUtil.NOT_FOUND) {
        cleanPath = su.subString(path, 0, qmark)
    }
    
    String parts[] = su.explode(cleanPath, "/")
    // For /task/123/result, explode gives: ["task", "123", "result"]
    // So the ID is at index 1, not 2
    if (parts.arrayLength >= 3) {
        char idStr[] = parts[1].string  // Changed from parts[2]
        if (su.isNumeric(idStr)) {
            return iu.intFromString(idStr)
        }
    }
    return INVALID_ID
}

int extractResultIdFromPath(char path[]) {
    // Extract ID from /result/123
    // First, remove query string if present
    char cleanPath[] = path
    int qmark = su.find(path, "?", 0)
    if (qmark != StringUtil.NOT_FOUND) {
        cleanPath = su.subString(path, 0, qmark)
    }
    
    String parts[] = su.explode(cleanPath, "/")
    // For /result/123, explode gives: ["result", "123"]
    // So the ID is at index 1, not 2
    if (parts.arrayLength >= 2) {  // Changed from >= 3
        char idStr[] = parts[1].string  // Changed from parts[2]
        if (su.isNumeric(idStr)) {
            return iu.intFromString(idStr)
        }
    }
    return INVALID_ID
}
```

**Result:** Task IDs and result IDs are now correctly extracted from URLs.

### Test Results After Fixes

**Date:** December 2, 2024  
**All Tests:** ✅ **PASSING**

| Test | Endpoint | Status | Response |
|------|----------|--------|----------|
| 1. Health Check | `GET /health` | ✅ Pass | `{"status":"ok","service":"coordinator"}` |
| 2. Stats | `GET /stats` | ✅ Pass | `{"totalTasks":0,"completedTasks":0,"activeTasks":0,"queueSize":0}` |
| 3. Submit Task | `POST /task` | ✅ Pass | `{"taskId":1}` |
| 4. Get Next Task | `GET /task/next?workerId=test` | ✅ Pass | `{"taskId":1,"data":{...}}` |
| 5. Submit Result | `POST /task/1/result` | ✅ Pass | `{"status":"success"}` |
| 6. Get Result | `GET /result/1` | ✅ Pass | `{"taskId":1,"status":"completed","result":{...}}` |
| 7. Final Stats | `GET /stats` | ✅ Pass | `{"totalTasks":1,"completedTasks":1,"activeTasks":0,"queueSize":0}` |
| 8. CORS Preflight | `OPTIONS /task` | ✅ Pass | 200 OK with CORS headers |

### Files Modified

1. **`app/CoordinatorApp.dn`**
   - Added `composition.RecursiveLoader` as required interface
   - Changed `coordinator` from auto-instantiated to manually loaded
   - Added explicit loading logic with error checking
   - Added error logging throughout request handling

2. **`server/CoordinatorServer.dn`**
   - Added null check for coordinator before routing requests
   - Added proper error response when coordinator is not initialized

3. **`server/CoordinatorController.dn`**
   - Fixed `extractTaskIdFromPath()` to use `parts[1]` instead of `parts[2]`
   - Fixed `extractResultIdFromPath()` to use `parts[1]` and check `>= 2` instead of `>= 3`
   - Added query string removal before path parsing

### Verification

All endpoints now respond correctly:
- ✅ No hanging connections
- ✅ Proper HTTP responses with correct status codes
- ✅ Valid JSON responses
- ✅ CORS headers present
- ✅ Task lifecycle works end-to-end (submit → assign → complete → retrieve)

## Related Files

- `app/CoordinatorApp.dn` - Main entry point (✅ Fixed)
- `server/CoordinatorServer.dn` - HTTP handler (✅ Fixed)
- `server/CoordinatorController.dn` - Task coordination logic (✅ Fixed)
- `server/Server.dn` - Reference implementation showing correct loading pattern

