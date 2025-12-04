# No Switching Required! 🎉

The system has been updated so that **main WASM and worker WASM can run simultaneously** without needing to switch `file_system.js` files.

## What Changed

### 1. HTML Files Updated
- **`webserver/xdana.html`** now uses `file_system_main.js` directly
- **`webserver/worker-dana-wasm.html`** now uses `file_system_worker.js` directly

### 2. New Startup Script
- **`start-servers.sh`** - Starts both coordinator and static file server with one command

## How to Use

### Quick Start
```bash
./start-servers.sh 8080 8081
```

This starts:
- **Coordinator API** on port 8080
- **Static File Server** on port 8081

### Access the Apps

Both apps can run **simultaneously** in different browser tabs:

1. **Main App**: http://localhost:8081/xdana.html
   - Uses `file_system_main.js` (contains main app components)
   - Submits tasks to coordinator

2. **Worker**: http://localhost:8081/worker-dana-wasm.html
   - Uses `file_system_worker.js` (contains worker components)
   - Polls coordinator for tasks

### No More Switching!

✅ **Before**: Had to run `./switch-to-main.sh` or `./switch-to-worker.sh`  
✅ **Now**: Both apps work simultaneously - just open both URLs!

## Architecture

```
Browser Tab 1 (Main)          Browser Tab 2 (Worker)
     ↓                              ↓
http://localhost:8081/xdana.html    http://localhost:8081/worker-dana-wasm.html
     ↓                              ↓
file_system_main.js                file_system_worker.js
     ↓                              ↓
     └──────────┬───────────────────┘
                ↓
        Coordinator API
        http://localhost:8080
```

## File Structure

```
webserver/
├── xdana.html              → Uses file_system_main.js
├── worker-dana-wasm.html   → Uses file_system_worker.js
├── file_system_main.js     → Main app WASM package
├── file_system_worker.js   → Worker WASM package
├── file_system.js         → (Not used anymore, can be deleted)
├── dana.js                → Dana WASM runtime
└── ...
```

## Benefits

1. **No Manual Switching** - Both apps work at the same time
2. **Easier Testing** - Open both tabs and test the full flow
3. **Better Development** - See both sides of the system simultaneously
4. **Cleaner Setup** - One script starts everything

## Stopping Servers

```bash
# Stop all servers
pkill -f 'ws.core|python3.*http.server.*8081'

# Or use the PIDs shown when starting
kill <coordinator_pid> <static_server_pid>
```

## Notes

- The `switch-to-main.sh` and `switch-to-worker.sh` scripts are **no longer needed**
- Both HTML files reference their specific `file_system_*.js` files directly
- You can still run them on different ports if desired (just modify the startup script)
- The coordinator handles requests from both apps simultaneously

