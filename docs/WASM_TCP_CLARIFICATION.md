# Clarification: WASM Format vs Execution Environment

## The Confusion

When we say "WASM workers", there are two different concepts:

1. **WASM Format** (compilation target): `-os ubc -chip 32`
2. **WASM Runtime** (execution environment): Browser WASM runtime vs Dana native runtime

## What We're Actually Doing

### Workers: WASM Format + Native Runtime

```
Compilation:  RemoteRepo.dn → (dnc -os ubc -chip 32) → RemoteRepo.o (WASM format)
Execution:    dana RemoteRepo.o → Runs with Dana NATIVE runtime (not browser)
Result:       TCP sockets WORK because it's running natively, not in browser
```

### Main App: WASM Format + Browser Runtime

```
Compilation:  main.dn → (dnc -os ubc -chip 32) → main.o (WASM format)
Execution:    Browser loads main.o → Runs in browser WASM runtime
Result:       TCP sockets DON'T work (browser restriction)
               → Makes HTTP requests instead
```

## Why This Works

1. **WASM Format** (`-os ubc -chip 32`) is just a compilation target
   - It's Dana's WASM-compatible bytecode format
   - Can be executed by Dana's native runtime OR browser WASM runtime

2. **Dana Native Runtime** can execute WASM-format files
   - When you run `dana RemoteRepo.o`, it uses the native runtime
   - Native runtime has full OS access (TCP sockets, file system, etc.)
   - NOT restricted by browser security model

3. **Browser WASM Runtime** is different
   - Restricted by browser security model
   - Cannot bind/listen on TCP sockets
   - Can only make outbound HTTP requests

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│ Browser (WASM Runtime - Restricted)                    │
│   └─ Main App (WASM format)                            │
│       └─ Makes HTTP requests (outbound only)           │
└─────────────────────────────────────────────────────────┘
                        ↓ HTTP Request
┌─────────────────────────────────────────────────────────┐
│ Server Machine (Native Runtime - Full Access)           │
│   └─ Worker (WASM format)                              │
│       └─ Listens on TCP socket (port 8081)              │
│       └─ Processes request                              │
│       └─ Returns HTTP response                          │
└─────────────────────────────────────────────────────────┘
```

## Key Point

**"WASM format" ≠ "Browser execution"**

- Workers: WASM format + Native runtime = TCP sockets work ✅
- Main app: WASM format + Browser runtime = TCP sockets don't work ❌

## Benefits of This Approach

1. **Unified Compilation**: All code uses same WASM format (`-os ubc -chip 32`)
2. **Native Capabilities**: Workers can use TCP sockets (running natively)
3. **Browser Compatibility**: Main app runs in browser (HTTP requests only)
4. **No Code Changes**: Same source code, different execution environments

## Verification

Check how workers run:
```bash
# This runs WASM-compiled file with NATIVE runtime
dana wasm_output/app/RemoteRepo.o 8081

# NOT running in browser - running natively on server
# Therefore TCP sockets are available
```

