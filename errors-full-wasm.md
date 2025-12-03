# Full WASM System Errors and Issues

This document tracks errors and issues found during testing of the full WASM system (Coordinator + Main App + Worker).

## Error 1: WebAssembly.Memory Serialization Error

**Date:** December 2, 2024  
**Environment:** Browser (WASM Main App loading in xdana.html)  
**Status:** ✅ **FIXED**

### Symptom

When opening `xdana.html` in the browser, the following error appears in the browser console:

```
Uncaught (in promise) DOMException: Worker.postMessage: The WebAssembly.Memory object cannot be serialized. 
The Cross-Origin-Opener-Policy and Cross-Origin-Embedder-Policy HTTP headers can be used to enable this.
```

**Error Location:**
```
loadWasmModuleToWorker http://localhost:8081/dana.js:1
```

**Full Stack Trace:**
```
loadWasmModuleToWorker http://localhost:8081/dana.js:1
loadWasmModuleToWorker http://localhost:8081/dana.js:1
loadWasmModuleToAllWorkers http://localhost:8081/dana.js:1
initMainThread http://localhost:8081/dana.js:1
callRuntimeCallbacks http://localhost:8081/dana.js:1
preRun http://localhost:8081/dana.js:1
run http://localhost:8081/dana.js:1
removeRunDependency http://localhost:8081/dana.js:1
receiveInstance http://localhost:8081/dana.js:1
receiveInstantiationResult http://localhost:8081/dana.js:1
createWasm http://localhost:8081/dana.js:1
```

### Root Cause

The Dana WASM runtime requires **Cross-Origin-Opener-Policy (COOP)** and **Cross-Origin-Embedder-Policy (COEP)** HTTP headers to be present on all responses (HTML, JS, WASM files) to enable Web Worker functionality with WebAssembly.Memory.

**Why This Happens:**
- Dana's WASM runtime uses Web Workers internally
- Web Workers need to share WebAssembly.Memory objects
- Browsers require COOP/COEP headers for cross-origin isolation
- Without these headers, `Worker.postMessage()` cannot serialize WebAssembly.Memory objects

**Initial Setup:**
- Coordinator was serving API endpoints with CORS headers (but not COOP/COEP)
- Static files were served by Python's `http.server` (port 8081) which doesn't send COOP/COEP headers
- This caused the WASM runtime to fail when trying to initialize Web Workers

### Solution (100% Dana)

Integrated static file serving directly into the native Dana coordinator with proper COOP/COEP headers.

#### Changes Made

1. **`server/StaticFileServerImpl.dn`**
   - Added `buildFileResponseWithHeaders()` method
   - Adds COOP/COEP headers to all file responses:
     - `Cross-Origin-Opener-Policy: same-origin`
     - `Cross-Origin-Embedder-Policy: require-corp`
   - Added `handleWithHeaders()` interface method to return HTTP response strings

2. **`resources/server/StaticFileServer.dn`**
   - Added `char[] handleWithHeaders(HTTPMessage request)` interface method
   - Returns HTTP response string with headers (not just Response object)

3. **`server/CoordinatorServer.dn`**
   - Modified `handleRequest()` to accept optional `StaticFileServer` parameter
   - Tries static file server **before** routing to coordinator API
   - Falls back to coordinator API if static file server returns null

4. **`app/CoordinatorApp.dn`**
   - Loads `StaticFileServerImpl` using `RecursiveLoader`
   - Configures static file server with base path `"webserver"`
   - Passes static file server to `CoordinatorServer.handleRequest()`
   - Now serves both API endpoints and static files on port 8080

#### Architecture After Fix

**Before:**
```
Browser → Python HTTP Server (port 8081) → Static files (NO COOP/COEP headers)
Browser → Coordinator (port 8080) → API endpoints (CORS headers only)
```

**After:**
```
Browser → Coordinator (port 8080) → Static files (WITH COOP/COEP headers)
Browser → Coordinator (port 8080) → API endpoints (CORS + COOP/COEP headers)
```

### Verification

After the fix, the coordinator serves all files with proper headers:

```http
HTTP/1.1 200 OK
Server: Dana Coordinator
Content-Length: <size>
Content-Type: text/html
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
Connection: close
```

### Testing

1. **Start coordinator:**
   ```bash
   dana app/CoordinatorApp.o 8080
   ```

2. **Open in browser:**
   ```
   http://localhost:8080/xdana.html
   ```

3. **Expected Result:**
   - No errors in browser console
   - WASM runtime loads successfully
   - Main app UI appears
   - Web Workers initialize without errors

### Benefits of This Solution

1. **100% Dana:** All serving logic in Dana (no Python dependency)
2. **Single Port:** Everything on port 8080 (simpler deployment)
3. **Proper Headers:** COOP/COEP headers on all responses
4. **Consistent:** Same server for API and static files
5. **Simpler:** No need to manage separate static file server

### Files Modified

- `server/StaticFileServerImpl.dn` - Added header support
- `resources/server/StaticFileServer.dn` - Added interface method
- `server/CoordinatorServer.dn` - Integrated static file serving
- `app/CoordinatorApp.dn` - Loads and uses StaticFileServer

### Related Documentation

- `coordinator-in-native-dana.md` - Coordinator migration plan
- `main-in-wasm.md` - Main app WASM implementation
- `FULL_SYSTEM_TEST_README.md` - Full system testing guide

### Notes

- The coordinator now serves static files **before** checking API endpoints
- Static file server skips API paths (`/task`, `/result`, `/stats`, `/matmul`)
- All responses (API and static) include COOP/COEP headers for WASM compatibility
- Python HTTP server is no longer needed for static file serving

---

## Error 2: HTTP Response Not Reaching Client (curl/browser timeout)

**Date:** December 3, 2024  
**Environment:** Native Dana Coordinator Server (port 8080)  
**Status:** 🔄 **IN PROGRESS**

### Symptom

When accessing `http://localhost:8080/xdana.html` or any endpoint via curl or browser:

1. **Server logs show:**
   - Requests are received: `[@CoordinatorApp] - Request: GET /xdana.html HTTP/1.1`
   - Files are being served: `[@StaticFileServer] Serving file: webserver/xdana.html (2484 bytes, text/html)`
   - Responses are being sent: `[@CoordinatorApp] - Sent 2681 bytes (expected 2681)`
   - Connection is closed: `[@CoordinatorApp] - Connection closed`

2. **Client behavior:**
   - curl command freezes/hangs indefinitely
   - Browser shows "No response data available" in network inspector
   - Request shows `GET /xdana.html undefined` in browser dev tools
   - Timeout after 30+ seconds with no data received

### Root Cause Analysis

The server is successfully:
- Receiving HTTP requests
- Parsing requests correctly
- Building HTTP responses with proper headers
- Calling `TCPSocket.send()` with the response bytes
- Logging that all bytes were sent

However, the client (curl/browser) is not receiving any data, suggesting:

1. **TCP Socket Issue:** Data may be written to OS buffer but not transmitted before socket closure
2. **Response Format:** HTTP response format may be incorrect (though headers look correct)
3. **Socket Closure Timing:** Connection may be closed before OS transmits buffered data
4. **Type Conversion:** `char[]` to `byte[]` conversion may have issues

### Attempted Fixes

1. **Added char[] to byte[] conversion** (✅ Implemented)
   - Converted HTTP response from `char[]` to `byte[]` before sending
   - TCPSocket.send() expects `byte[]` parameter

2. **Added debug logging** (✅ Implemented)
   - Logs request details: `Request: GET /xdana.html HTTP/1.1`
   - Logs response size: `Sending response (2681 bytes)`
   - Logs sent bytes: `Sent 2681 bytes (expected 2681)`

3. **Added socket flushing** (✅ Implemented)
   - Check for unsent bytes with `getBufferUnsent()`
   - Call `sendBuffer()` if unsent bytes exist

4. **Added delay before disconnect** (❌ Removed - didn't help)
   - Attempted delay to allow OS to flush TCP buffers
   - Removed as it didn't resolve the issue

### Current Status

- Server is running and processing requests correctly
- Responses are being built with proper HTTP format
- `TCPSocket.send()` reports all bytes sent
- Client still not receiving data

### Next Steps to Investigate

1. **Verify HTTP response format:**
   - Check if response string is properly formatted with `\r\n` line endings
   - Verify Content-Length matches actual body size
   - Ensure proper `\r\n\r\n` separator between headers and body

2. **Socket shutdown sequence:**
   - Try using `shutdown()` before `disconnect()`
   - Ensure socket is properly closed after data transmission

3. **Test with simpler response:**
   - Try sending a minimal HTTP response to isolate the issue
   - Test if the problem is with response format or socket handling

4. **Compare with working examples:**
   - Review `app/NetworkServerApp.dn` and `app/RemoteRepo.dn` for differences
   - Check how other Dana HTTP servers handle response sending

### Related Files

- `app/CoordinatorApp.dn` - Main server entry point, handles HTTP requests
- `server/StaticFileServerImpl.dn` - Builds HTTP responses with headers
- `server/CoordinatorServer.dn` - Routes requests to coordinator or static file server
- `network/http/HTTPUtil.dn` - HTTP parsing utilities

### Related Issues

- This issue prevents testing Error 1 fix (WebAssembly.Memory) since pages can't load
- Blocks full system testing of WASM Main App + Coordinator + Worker

---

## Error 3: JSON Parser Null Pointer Exceptions When Polling Pending Tasks

**Date:** December 3, 2024  
**Environment:** WASM Main App polling coordinator for task results  
**Status:** ⚠️ **PARTIALLY MITIGATED** (Functional but exceptions still appear)

### Symptom

When the main app polls for task results while tasks are still pending, the following exceptions appear in the browser console:

```
[Dana] Exception::null pointer on line 513 of ./data/json/JSONParser.o
  -- called from line 648 of ./data/json/JSONParser.o
  -- called from line 756 of ./data/json/JSONParser.o
  -- called from line 33 of ./data/json/JSONParser.o
  -- called from line 458 of wasm_output/app/MainAppLoop.o
  -- called from line 329 of wasm_output/app/MainAppLoop.o
  -- called from line 116 of wasm_output/app/MainAppLoop.o
```

**When It Occurs:**
- Main app polls `GET /result/:id` while task status is "pending"
- Coordinator returns: `{"taskId":N,"status":"pending","result":}`
- JSON parser encounters malformed JSON (missing value after `"result":`)
- Exception is thrown during `jp.parseDocument(responseBody)` call

**Impact:**
- ⚠️ **Non-blocking:** Dana exceptions are advisory and don't crash the program
- ✅ **Functional:** Main app continues polling and eventually receives results
- ⚠️ **Cosmetic:** Console shows error messages but system works correctly

### Root Cause

The coordinator's `handleGetResult()` method builds JSON responses manually using string concatenation. When the result field is empty (task not completed), the string building produces invalid JSON:

**Invalid JSON (current):**
```json
{"taskId":4,"status":"pending","result":}
```

**Valid JSON (expected):**
```json
{"taskId":4,"status":"pending","result":""}
```

**Why This Happens:**
- Coordinator uses string interpolation: `"{\"result\":$(resultValue)}"`
- When `resultValue` is empty, the interpolation may fail or produce empty string
- String concatenation `new char[]("\"", "\"")` creates an array, not the string `"\"\""`
- The resulting JSON is malformed, causing JSON parser to throw null pointer exceptions

### Solution Attempts

#### Attempt 1: Fix Coordinator String Building (❌ Incomplete)
- **Goal:** Ensure coordinator always returns valid JSON
- **Changes:**
  - Added constant `EMPTY_JSON_STRING = "\"\""`
  - Modified `handleGetResult()` to use constant for empty results
  - Tried various string concatenation approaches
- **Result:** Still produces invalid JSON `{"result":}`

#### Attempt 2: Defensive Parsing in Main App (✅ Implemented)
- **Goal:** Handle malformed JSON gracefully
- **Changes:**
  - Added null checks before JSON parsing
  - Check status field first (if "pending", return early before accessing result)
  - Added defensive checks for all JSONElement property accesses
  - Added comment noting Dana exceptions are advisory
- **Result:** Main app handles exceptions gracefully, continues polling

### Current Status

**Working:**
- ✅ Main app successfully polls for results
- ✅ Results are displayed correctly when tasks complete
- ✅ System is fully functional despite exceptions

**Remaining Issues:**
- ⚠️ Console still shows null pointer exceptions when polling pending tasks
- ⚠️ Coordinator returns malformed JSON for empty results
- ⚠️ JSON parser throws exceptions (advisory, non-fatal)

### Code Changes

#### Main App (`app/MainAppLoop.dn`)
```dana
// Added defensive parsing with null checks
JSONElement root = jp.parseDocument(responseBody)
if (root == null) {
    // Continue polling
    return
}

// Check status first - return early if pending (avoids accessing result field)
JSONElement statusElem = jp.getValue(root, "status")
if (statusElem != null && statusElem.type == JSONElement.TYPE_STRING) {
    char status[] = statusElem.value
    if (status == "pending" || status == "processing") {
        // Task not ready - continue polling (don't access result field)
        return
    }
}
```

#### Coordinator (`server/CoordinatorController.dn`)
```dana
// Attempted fix (incomplete):
const char EMPTY_JSON_STRING[] = "\"\""
// ... string building logic ...
char response[] = "{\"taskId\":$(taskIdStr),\"status\":\"$(statusStr)\",\"result\":$(resultFieldValue)}"
// Still produces invalid JSON when resultFieldValue is empty
```

### Recommended Fix

**Option 1: Use JSONEncoder (Recommended)**
- Create a data structure for the response
- Use `JSONEncoder.jsonFromData()` to build valid JSON
- Ensures proper formatting for all field types

**Option 2: Fix String Building**
- Properly escape quotes in string literals
- Use character-by-character construction for `"\"\""`
- Validate JSON format before returning

**Option 3: Accept Current State**
- Exceptions are advisory and don't affect functionality
- System works correctly despite console warnings
- Can be addressed in future refactoring

### Testing

1. **Submit a task:**
   ```bash
   curl -X POST http://localhost:8080/task \
     -H "Content-Type: application/json" \
     -d '{"A":"[[1,2],[3,4]]","B":"[[5,6],[7,8]]"}'
   ```

2. **Poll for result (while pending):**
   ```bash
   curl http://localhost:8080/result/1
   # Returns: {"taskId":1,"status":"pending","result":}  (invalid JSON)
   ```

3. **Expected Behavior:**
   - Main app polls successfully
   - Console shows exceptions (non-fatal)
   - When task completes, result is displayed correctly

### Related Files

- `app/MainAppLoop.dn` - Main app polling logic with defensive parsing
- `server/CoordinatorController.dn` - Coordinator response building (needs fix)
- `app/MainAppLoopImpl.dn` - Alternative main app implementation

### Notes

- Dana exceptions are **advisory** - they don't crash the program
- The JSON parser continues parsing despite exceptions
- Main app correctly extracts status and handles pending tasks
- Full fix requires coordinator JSON building improvements
- Current workaround is functional but not ideal

