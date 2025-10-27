# Running the Distributed Matrix Multiplication Project in WASM

This guide explains how to compile, package, and run the distributed matrix multiplication application as a WebAssembly (WASM) module that runs in a web browser.

## Prerequisites

Before building the WASM version, ensure you have:

1. **Dana Compiler**: Installed and in your PATH
   ```bash
   dnc --version
   ```

2. **Emscripten SDK**: Required for packaging WASM files
   - Download from: https://emscripten.org/docs/getting_started/downloads.html
   - Ensure `file_packager` tool is available in your PATH
   ```bash
   file_packager --help
   ```

3. **Node.js**: For running the web server
   ```bash
   node --version
   ```

4. **Python 3**: Used by the compiler and proxy generator
   ```bash
   python3 --version
   ```

5. **Web Browser**: Modern browser supporting WebAssembly (Chrome, Firefox, Safari, Edge)

## Building for WASM

### Step 1: Compile Dana Components to WASM

Run the compilation script to build all components for WebAssembly:

```bash
cd /path/to/distributed-matmul
./compile-wasm.sh
```

This script will:
- Compile all `.dn` files to WebAssembly using `dnc -os ubc -chip 32`
- Generate `.o` files in the `wasm_output/` directory
- Skip proxy generator, results, and testing directories

**Output**: All compiled components are placed in `wasm_output/` with their original directory structure preserved.

### Step 2: Package WASM Files for Browser

Run the packaging script to create the browser-compatible file system:

```bash
./package-wasm.sh
```

This script will:
- Use Emscripten's `file_packager` to bundle WASM files
- Embed all compiled components into `webserver/file_system.js`
- Include the Dana standard library
- Create the file system image required by the Dana WASM runtime

**Environment Variables**:
- `DANA_WASM_HOME`: Should point to your Dana installation directory containing `components/`
- If not set, the script will look for components at the default location

**Output**:
- `webserver/dana.wasm` - The main WASM runtime
- `webserver/dana.js` - JavaScript loader for the WASM runtime
- `webserver/file_system.js` - File system containing all components
- `webserver/xdana.html` - Demo HTML page

## Project Structure for WASM

```
distributed-matmul/
├── compile-wasm.sh         # Script to compile components to WASM
├── package-wasm.sh          # Script to package WASM for browser
├── wasm_output/             # Compiled WASM components (.o files)
│   ├── App.o               # Main application entry point
│   ├── matmul/             # Matrix multiplication components
│   ├── server/             # Server components
│   ├── network/            # Network utilities
│   └── monitoring/         # Performance monitoring
├── webserver/              # Web-ready WASM package
│   ├── dana.wasm          # Dana WASM runtime
│   ├── dana.js            # JavaScript loader
│   ├── file_system.js     # Component file system
│   ├── xdana.html         # Demo web page
│   └── ws/                # Web server components
└── app/                    # Application entry points
    ├── main.dn            # Native main (for non-WASM)
    └── RemoteRepo.dn      # Remote worker (native only)
```

## Running the WASM Application

### Method 1: Using Dana's Web Server

Dana includes a simple web server for testing WASM applications:

```bash
# Compile the web server if needed
dnc ws

# Run the web server
dana ws.core
```

The server will start on `http://localhost:8080`

Open your browser and navigate to:
```
http://localhost:8080/xdana.html
```

### Method 2: Using Your Own Web Server

You can use any web server to host the WASM files:

```bash
# Using Python's simple HTTP server
cd webserver
python3 -m http.server 8000
```

Then open:
```
http://localhost:8000/xdana.html
```

### Method 3: Using Node.js

```bash
# Install a simple HTTP server
npm install -g http-server

# Run it
cd webserver
http-server -p 8080
```

Then open:
```
http://localhost:8080/xdana.html
```

## Architecture

### WASM Module Flow

```
Browser → Web Server → dana.wasm (WASM Module)
                           ↓
                    ProcessLoop (Non-blocking)
                           ↓
              ┌────────────┴────────────┐
              ↓                         ↓
      Local Computation         HTTP RPC to Workers
     (matmul/Matmul.dn)    (matmul/Matmul.proxy.dn)
```

### Key Components

1. **Main Application** (`app/main.dn`)
   - Entry point for the WASM module
   - Sets up `ProcessLoop` for non-blocking operation
   - Returns immediately from `main()` to allow browser responsiveness

2. **Server** (`server/Server.dn`)
   - Handles HTTP requests (not TCP sockets)
   - Manages runtime adaptation between local and distributed modes
   - Uses non-blocking ProcessLoop pattern

3. **Matrix Multiplication**
   - `matmul/Matmul.dn` - Local computation
   - `matmul/Matmul.proxy.dn` - Distributed computation via HTTP

4. **Network Layer**
   - Uses `net.http.HTTPRequest` for remote communication
   - HTTP-based RPC for distributed computation

## Limitations in WASM

### ❌ Not Available in WASM

- `net.TCP`, `net.TCPServerSocket`, `net.TCPSocket`
- `net.UDP`, `net.DNS`, `net.SSL`
- Native libraries (`.dnl` files)
- Blocking I/O operations
- Direct socket binding/listening

### ✅ Available in WASM

- `net.http.HTTPRequest` for remote operations
- `ProcessLoop` pattern for non-blocking operations
- JSON parsing/serialization (`data.json.*`)
- Local computation (matrix multiplication)
- Composition and adaptation mechanisms
- Most `data.*` utilities

## Troubleshooting

### Compilation Errors

**Error**: `dnc command not found`
```bash
# Ensure Dana is installed and in PATH
export PATH=$PATH:/path/to/dana
```

**Error**: `file_packager command not found`
```bash
# Install Emscripten SDK
# See: https://emscripten.org/docs/getting_started/downloads.html
source emsdk_env.sh
```

### Runtime Errors

**Error**: `Cannot find component`
- Ensure all components were compiled with `-os ubc -chip 32`
- Check that `wasm_output/` contains all necessary `.o` files
- Verify `webserver/file_system.js` includes all components

**Error**: `Module not defined` or `dana.wasm not found`
- Ensure you're serving files from the `webserver/` directory
- Check browser console for detailed error messages
- Verify CORS is configured if accessing from a different domain

**Error**: `ProcessLoop blocking browser`
- The `loop()` function must return quickly (don't use blocking operations)
- Use `timer.sleep(0)` to yield control back to browser
- Make async calls with `asynch::`

### Performance Issues

**Browser becomes unresponsive**:
- Ensure `ProcessLoop:loop()` returns quickly (within milliseconds)
- Don't perform long-running computations in a single `loop()` call
- Break work into smaller chunks across multiple `loop()` calls

**Slow HTTP requests**:
- HTTP has more latency than TCP sockets
- Consider batching multiple operations
- Use compression for large data

## Testing the Application

### Manual Testing

1. Open browser to `http://localhost:8080/xdana.html`
2. Open browser console (F12) to see output
3. The WASM module should load and start the ProcessLoop
4. Check for any error messages

### Loading Test

```bash
# Test if the module loads correctly
curl http://localhost:8080/xdana.html
```

### Network Request Test

```bash
# Test if HTTP requests work
curl -X POST http://localhost:8080/api/matmul \
  -H "Content-Type: application/json" \
  -d '{"matrixA": [[1,2],[3,4]], "matrixB": [[5,6],[7,8]]}'
```

## Development Tips

### Rebuilding After Changes

```bash
# Clean and rebuild
rm -rf wasm_output/*
./compile-wasm.sh
./package-wasm.sh

# Restart web server
# Refresh browser (hard refresh: Ctrl+Shift+R)
```

### Debugging

- Use browser DevTools console for runtime errors
- Check Network tab for failed requests
- Use Performance tab to monitor `loop()` execution time

### Adding New Components

1. Create `.dn` file in appropriate directory
2. Run `./compile-wasm.sh` (automatically compiles new files)
3. Run `./package-wasm.sh` (includes new components)
4. Refresh browser

## Remote Workers

**Important**: Remote workers (`app/RemoteRepo.dn`) remain as native Dana applications and are NOT compiled to WASM.

- They run in separate processes/containers
- Communication with WASM module is via HTTP
- Use Docker or Kubernetes to deploy remote workers
- See main `README.md` for deployment instructions

## Next Steps

1. **Build**: Run `./compile-wasm.sh` and `./package-wasm.sh`
2. **Run**: Start a web server and open `xdana.html` in browser
3. **Test**: Use browser console to verify WASM module loads
4. **Deploy**: Package `webserver/` directory for production deployment

## Resources

- [WASM Migration Summary](WASM_MIGRATION_SUMMARY.md)
- [WASM Implementation Guide](docs/WASM_IMPLEMENTATION_GUIDE.md)
- [Dana Language Documentation](.cursor/rules/)
- [Emscripten Documentation](https://emscripten.org/docs/)
- [Main Project README](README.md)

## Support

For issues or questions:
1. Check browser console for errors
2. Review the troubleshooting section above
3. Consult the WASM migration documentation
4. Review the main `README.md` for general project information
