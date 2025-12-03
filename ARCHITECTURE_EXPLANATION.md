# Why `-chip 32` Files Can't Run with Native Dana Runtime

## The Architecture Mismatch Explained

When Dana compiles code, it embeds an **architecture identifier** in the binary file header. This tells the runtime what kind of code it's dealing with.

### Architecture Codes

- **Architecture 4.1** = 32-bit WASM format (`-chip 32`)
- **Architecture 8.1** = 64-bit native format (`-chip 64` or default native)

### What Happens

1. **Compile with `-chip 32`:**
   ```bash
   dnc app/RemoteRepo.dn -os ubc -chip 32 -o RemoteRepo.o
   ```
   - File header contains: `Architecture 4.1`
   - This is optimized for browser WASM runtime

2. **Try to run with native `dana` runtime:**
   ```bash
   dana RemoteRepo.o 8081
   ```
   - Native `dana` runtime reads the file header
   - Sees: "Architecture 4.1"
   - Expects: "Architecture 8.1" (because it's a 64-bit native runtime)
   - **Error:** "File was compiled for a different architecture (4.1 vs 8.1)"

### Why This Happens

The native `dana` runtime is compiled for 64-bit systems and expects 64-bit code (architecture 8.1). When you compile with `-chip 32`, you're creating 32-bit WASM code (architecture 4.1) that's meant for browser execution, not native execution.

### The Solution

To run workers with native runtime AND use WASM format, you need:
- **`-chip 64`** = 64-bit WASM format (architecture 8.1)
- This matches what the native runtime expects
- Still uses WASM format (`-os ubc`), just 64-bit instead of 32-bit

### Visual Explanation

```
┌─────────────────────────────────────────┐
│ Compile with -chip 32                   │
│ → Architecture 4.1 (32-bit WASM)        │
│ → For browser WASM runtime               │
└─────────────────────────────────────────┘
              ↓ Try to run
┌─────────────────────────────────────────┐
│ Native dana runtime                     │
│ → Expects Architecture 8.1 (64-bit)      │
│ → Sees Architecture 4.1                 │
│ → ❌ MISMATCH ERROR                      │
└─────────────────────────────────────────┘
```

