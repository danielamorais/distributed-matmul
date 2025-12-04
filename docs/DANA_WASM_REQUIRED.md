# Dana WASM Required - No JavaScript Fallback

## Current Status

**JavaScript computation has been REMOVED** from the browser worker. The system now **requires Dana WASM to work**.

## What Happens Now

When you test the system:

1. ✅ Dana WASM loads successfully in `worker-wasm.html`
2. ✅ Worker polls coordinator for tasks
3. ✅ `xdana.html` submits tasks to coordinator
4. ✅ Worker receives the task
5. ❌ **Worker tries to call `danaRequestHandler()` but it's not initialized**
6. ❌ **Error: "Dana WASM request handler not initialized. Cannot compute without Dana."**

## Why It Fails

The Dana WASM runtime (`dana.js`, `dana.wasm`) loads successfully, but:

```javascript
// This attempt fails:
danaRequestHandler = Module.cwrap('dana_http_handleRequest', 'string', ['string']);
```

**Reason:** Dana's WASM build doesn't export a `dana_http_handleRequest` function that JavaScript can call.

## How to Fix

You need to modify the **Dana compiler** to export JavaScript-callable functions when building for WASM.

### Required Changes to Dana Compiler

The Dana compiler needs to:

1. **Export HTTP Request Handler**:
   ```c
   // In Dana's C runtime or generated code:
   EMSCRIPTEN_KEEPALIVE
   char* dana_http_handleRequest(char* httpRequest) {
       // Call Dana's Server.handleRequest() function
       // Return HTTP response as string
   }
   ```

2. **Add to Emscripten Build Flags**:
   ```bash
   emcc ... -s EXPORTED_FUNCTIONS='["_dana_http_handleRequest","_malloc","_free"]' \
            -s EXPORTED_RUNTIME_METHODS='["cwrap","ccall"]'
   ```

3. **Alternative: Export Direct Multiply Function**:
   ```c
   EMSCRIPTEN_KEEPALIVE
   char* dana_multiply_matrices(char* matrixA_json, char* matrixB_json) {
       // Call Matmul component directly
       // Return result as JSON string
   }
   ```

### Quick Test to Verify Dana Exports

Run in browser console after Dana loads:

```javascript
// Check what Dana exports:
console.log(Object.keys(Module));
console.log(Module.asm); // Shows exported WASM functions

// Try to find any exported functions:
for (let key in Module) {
    if (key.startsWith('_')) console.log(key);
}
```

## Architecture (Working Parts)

```
✅ xdana.html → POST /matmul → Coordinator (Node.js)
                                    ↓
                          Creates task in queue
                                    ↓
✅ worker-wasm.html → GET /task/next → Gets task
         ↓
    Dana WASM loads ✅
         ↓
    Tries to call danaRequestHandler ❌ (Not exported)
         ↓
    ERROR: "Cannot compute without Dana"
```

## What You Need

**You need to work with the Dana compiler developers** to add JavaScript export support. This is not something that can be fixed in the application code - it requires changes to how Dana compiles to WASM.

### Alternative Approaches

Until Dana exports JavaScript-callable functions, you have 3 options:

1. **Use Native Dana Workers** (not WASM):
   - Worker runs as native Dana process: `dana app/RemoteRepo.o 8081`
   - xdana.html calls native worker via HTTP
   - This works NOW but defeats the purpose of browser workers

2. **Wait for Dana Compiler Update**:
   - Dana needs to add `EMSCRIPTEN_KEEPALIVE` exports
   - Dana needs to expose component functions to JavaScript
   - This is the proper solution

3. **Use WebAssembly Interface Types** (future):
   - When Dana supports WASI or Component Model
   - Direct JavaScript ↔ Dana function calls
   - Better type safety

## Current Files

- `worker-wasm.html`: Removed JavaScript fallback, requires Dana WASM
- `server.js`: Coordinator routes `/matmul` to task queue
- `BROWSER_WASM_STATUS.md`: Documents what works and what doesn't

## Testing

The system **will fail** when you try to compute because Dana cannot be called from JavaScript yet. This is expected and demonstrates that:

1. ✅ Architecture is correct
2. ✅ Dana loads successfully  
3. ❌ Dana ↔ JavaScript interface is missing (compiler issue)

The error message will clearly show: **"Dana WASM request handler not initialized. Cannot compute without Dana."**

This proves the system correctly enforces Dana-only computation.



