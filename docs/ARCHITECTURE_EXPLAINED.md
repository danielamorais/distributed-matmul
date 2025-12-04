# What is "Architecture 4.1 vs 8.1"?

## The Format

Dana uses a **Major.Minor** versioning system for architectures:

```
Architecture X.Y
  │         │
  │         └─ Minor version (sub-version of the architecture)
  └─────────── Major version (bit-width indicator)
```

## What the Numbers Mean

### Architecture 4.1
- **Major: 4** = 32-bit architecture
- **Minor: 1** = Version 1
- **Created by:** `-chip 32` flag
- **Purpose:** 32-bit WASM format (for browsers)
- **Binary:** `0x0401` (bytes: `04 01`)

### Architecture 8.1
- **Major: 8** = 64-bit architecture  
- **Minor: 1** = Version 1
- **Created by:** `-chip 64` flag OR default native compilation
- **Purpose:** 64-bit native/WASM format (for servers)
- **Binary:** `0x0801` (bytes: `08 01`)

## Why They're Incompatible

```
┌─────────────────────────────────────┐
│ Architecture 4.1 (32-bit)          │
│ - Uses 32-bit pointers              │
│ - Uses 32-bit integers               │
│ - Memory layout optimized for 32-bit │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│ Native Runtime (64-bit)             │
│ - Expects 64-bit pointers           │
│ - Expects 64-bit integers           │
│ - Memory layout for 64-bit          │
└─────────────────────────────────────┘
              ↓
        ❌ INCOMPATIBLE!
```

## Real-World Analogy

Think of it like trying to run:
- **32-bit Windows program** on a **64-bit Windows system** → Usually works (compatibility mode)
- **64-bit Windows program** on a **32-bit Windows system** → Won't work (architecture mismatch)

But Dana is stricter - it checks the architecture **before** trying to run, so it rejects mismatches immediately.

## In Binary Files

When you look at the compiled `.o` file header:

```
Offset 12-13: Architecture identifier
  Chip 32:  04 01  → Architecture 4.1
  Chip 64:  08 01  → Architecture 8.1
```

The runtime reads these bytes and checks:
- "Is this file Architecture 8.1?" (what it expects)
- "No, it's Architecture 4.1" → **ERROR: Architecture mismatch**

## Summary

- **4.1** = 32-bit WASM (for browsers)
- **8.1** = 64-bit native/WASM (for servers)
- They're **fundamentally different** binary formats
- Runtime checks this **before** loading any code
- That's why you get the error immediately, even before TCPSocket is checked

