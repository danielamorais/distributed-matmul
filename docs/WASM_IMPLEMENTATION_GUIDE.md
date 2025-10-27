# WASM Implementation Guide - Code Examples

This document provides specific code examples for migrating to WASM.

## 1. Create HTTP RPC Interface

**File: `resources/network/http/HTTPRPCUtil.dn`**

```dana
interface HTTPRPCUtil {
    Response makeHTTPRPC(char url[], Request req)
    bool isValidResponse(Response res)
}
```

## 2. Create HTTP RPC Implementation

**File: `network/http/HTTPRPCUtil.dn`**

```dana
component provides network.http.HTTPRPCUtil requires io.Output out,
        net.http.HTTPRequest http, data.json.JSONEncoder je, data.json.JSONParser jp {

    Response makeHTTPRPC(char url[], Request req) {
        // Serialize request to JSON
        char requestBody[] = je.jsonFromData(req)
        
        // Build HTTP request
        HTTPRequest request = new HTTPRequest()
        request.url = url
        request.method = "POST"
        request.content = requestBody
        request.setHeader("Content-Type", "application/json")
        
        // Make async HTTP request
        // Note: In WASM, this must be called from an async context
        asynch::execute(request)
        
        // Wait for response (non-blocking polling)
        while (!request.ready()) {
            // Return control to browser
            // This will be called multiple times via ProcessLoop
        }
        
        if (!request.failed()) {
            return jp.jsonToData(request.response, typeof(Response))
        }
        
        // Return error response
        return new Response("500", "Internal Server Error", new Request(), "")
    }
    
    bool isValidResponse(Response res) {
        return res != null && res.statusCode != "500"
    }
}
```

## 3. Create Server ProcessLoop

**File: `server/ServerProcessLoop.dn`**

```dana
component provides ServerProcessLoop extends lang.ProcessLoop 
        requires io.Output out, server.Server server, data.IntUtil iu {
    
    bool processing = false
    int requestCount = 0
    
    ServerProcessLoop:ServerProcessLoop() {
        // Initialize server components
        server.initialize()
    }
    
    bool loop() {
        // This function is called repeatedly by the WASM runtime
        // Return true to continue, false to exit
        
        if (processing) {
            // Still processing last request
            return true
        }
        
        // Check for new HTTP requests
        // In real implementation, this would be connected to the web server
        HTTPMessage request = getPendingRequest()
        
        if (request != null) {
            processing = true
            requestCount++
            
            // Process request asynchronously
            asynch::handleRequest(request)
            
            processing = false
        }
        
        return true
    }
    
    HTTPMessage getPendingRequest() {
        // This would connect to the web server's request queue
        // Implementation depends on web server integration
        return null
    }
    
    void handleRequest(HTTPMessage request) {
        server.process(request)
    }
}
```

## 4. Modify Server to Remove TCP

**File: `server/Server.dn` (Modified)**

```dana
component provides server.Server requires io.Output out, 
        network.http.HTTPUtil httpUtil, data.IntUtil iu,
        composition.Adapt adapter, composition.RecursiveLoader loader,
        monitoring.ResponseTime rt, time.Timer timer {
    
    bool adaptation = false
    MatmulController mc
    LoadedComponents matmul = loader.load("matmul/Matmul.o")
    LoadedComponents matmulProxy = loader.load("matmul/Matmul.proxy.o")
    LoadedComponents matmulController = loader.load("server/MatmulController.o")
    int lastResponseTime = 0
    Mutex lock = new Mutex()
    
    // REMOVED: TCP Server initialization
    
    void Server:initialize() {
        // Initialize without TCP sockets
        matmulController.mainComponent.wire("matmul.Matmul", matmul.mainComponent, "matmul.Matmul")
        mc = new MatmulController() from matmulController.mainComponent
        
        out.println("Server initialized (WASM mode)")
    }
    
    void Server:adaptRepository(opt bool useProxy) {
        rt.markStartTime()
        if(isset useProxy && useProxy) {
            adapter.adaptRequiredInterface(matmulController.mainComponent, "matmul.Matmul", matmulProxy.mainComponent)
        } else {
            adapter.adaptRequiredInterface(matmulController.mainComponent, "matmul.Matmul", matmul.mainComponent)
        }
        rt.markFinishTime()
        rt.clearTime()
    }
    
    void Server:process(HTTPMessage request) {
        Response res = null
        res = mc.handle(request)
        if (res != null) {
            sendHTTPResponse(request, res)
        } else {
            sendHTTPResponse(request, build404(request))
        }
    }
    
    Response build404(HTTPMessage request) {
        return new Response(
            404,
            "Not Found",
            httpUtil.SERVER_NAME,
            0,
            request.mimeType,
            ""
        )
    }
    
    void Server:sendHTTPResponse(HTTPMessage request, Response response) {
        // Send response via web server
        // Implementation depends on web server integration
        // This replaces the TCP socket send()
    }
}
```

## 5. Update Server Interface

**File: `resources/server/Server.dn`**

```dana
// REMOVE: void Server:init()
// REMOVE: void Server:initWithProxy()
// REMOVE: void Server:scaleToProxy()
// REMOVE: void handleRequest(store TCPSocket client)

interface Server extends Adapter {
    void initialize()
    void process(HTTPMessage request)
    void adaptRepository(opt bool useProxy)
}
```

## 6. Modify Proxy to Use HTTP

**File: `matmul/Matmul.proxy.dn`**

```dana
component provides matmul.Matmul(AdaptEvents) requires 
        network.http.HTTPRPCUtil rpc, data.IntUtil iu, 
        data.json.JSONEncoder je, data.StringUtil su {
    
    Address remotes[] = new Address[](
        new Address("http://localhost:8081", "worker1"),
        new Address("http://localhost:8082", "worker2")
    )
    int addressPointer = 0
    Mutex pointerLock = new Mutex()
    
    Matrix Matmul:multiply(Matrix A, Matrix B) {
        MultiplyParamsFormat params = new MultiplyParamsFormat(
            matrixToChar(A), matrixToChar(B)
        )
        char requestBody[] = je.jsonFromData(params)
        
        Request req = new Request(
            buildMetaForMethod("multiply"), 
            requestBody
        )
        
        // Use HTTP instead of TCP
        Response res = distributeHTTP(req)
        return charToMatrix(res.content)
    }
    
    // ... other methods ...
    
    Response distributeHTTP(Request r) {
        // Round-robin to next worker
        mutex(pointerLock) {
            char url[] = remotes[addressPointer].host
            addressPointer++
            if(addressPointer >= remotes.arrayLength) {
                addressPointer = 0
            }
        }
        
        // Make HTTP RPC call
        return rpc.makeHTTPRPC(url, r)
    }
    
    void AdaptEvents:active() {
        // Called when this component becomes active
    }
    
    void AdaptEvents:inactive() {
        // Called when this component is being replaced
    }
}
```

## 7. Update Main Application

**File: `app/main.dn`**

```dana
component provides App requires server.ServerProcessLoop loop,
        io.Output out, System system {
    
    int App:main(AppParam params[]) {
        // Create and set the process loop
        // main() must return immediately in WASM
        system.setProcessLoop(loop)
        
        out.println("Server started in WASM mode")
        
        // Return immediately - ProcessLoop will handle requests
        return 0
    }
}
```

## 8. Address Data Type

**File: `resources/network/http/Address.dn`**

```dana
data Address {
    char host[]  // URL instead of hostname
    char name[]  // Worker identifier
}
```

## 9. Request/Response Data Types

**File: `resources/network/http/Request.dn`**

```dana
data Metadata {
    char key[]
    char value[]
}

data Request {
    Metadata meta[]
    char content[]
}

data Response {
    char statusCode[]
    char statusMessage[]
    Request request
    char content[]
}
```

## 10. Web Server Integration

Since WASM cannot bind to TCP sockets, we need a web server integration. The server would:

1. Accept HTTP requests from browser
2. Queue them for the WASM module
3. Poll WASM module via ProcessLoop
4. Return responses to browser

**Example integration with Dana's ws.core:**

```dana
// In web server configuration
// Routes /api/matmul to WASM handler
// WASM handler puts requests into queue
// ProcessLoop polls queue and processes
```

## 11. Compile for WASM

**File: `compile-wasm.sh` (Updated)**

```bash
#!/bin/bash

echo "Compiling for WASM (UBC/32)..."

# Compile main application
dnc app/main.dn -os ubc -chip 32 -o wasm_output/App.o

# Compile server components
dnc server/ServerProcessLoop.dn -os ubc -chip 32 -o wasm_output/ServerProcessLoop.o
dnc server/Server.dn -os ubc -chip 32 -o wasm_output/Server.o
dnc server/MatmulController.dn -os ubc -chip 32 -o wasm_output/MatmulController.o

# Compile network layer
dnc network/http/HTTPRPCUtil.dn -os ubc -chip 32 -o wasm_output/HTTPRPCUtil.o

# Compile matmul components
dnc matmul/Matmul.dn -os ubc -chip 32 -o wasm_output/Matmul.o
dnc matmul/Matmul.proxy.dn -os ubc -chip 32 -o wasm_output/Matmul.proxy.o

# Compile monitoring
dnc monitoring/ResponseTime.dn -os ubc -chip 32 -o wasm_output/ResponseTime.o

echo "WASM compilation complete"
```

## 12. Package for Browser

**File: `package-wasm.sh` (Updated)**

```bash
#!/bin/bash

FILE_PACKAGER_PATH="path/to/emsdk/upstream/emscripten/tools/file_packager.py"

python3 $FILE_PACKAGER_PATH dana.wasm \
    --embed wasm_output/App.o@App.o \
    --embed wasm_output/ServerProcessLoop.o@ServerProcessLoop.o \
    --embed wasm_output/Server.o@Server.o \
    --embed wasm_output/MatmulController.o@MatmulController.o \
    --embed wasm_output/HTTPRPCUtil.o@HTTPRPCUtil.o \
    --embed wasm_output/Matmul.o@Matmul.o \
    --embed wasm_output/Matmul.proxy.o@Matmul.proxy.o \
    --embed wasm_output/ResponseTime.o@ResponseTime.o \
    --embed components/@components \
    --js-output=webserver/file_system.js
```

## Key Differences Summary

### Before (Native):
- Uses `net.TCPServerSocket` to listen
- Uses `net.TCPSocket` for connections
- Blocking `while (true)` loops
- Direct RPC via TCP sockets

### After (WASM):
- Uses `ProcessLoop` for request handling
- Uses `net.http.HTTPRequest` for communication
- Non-blocking polling in `loop()` method
- HTTP-based RPC calls

## Testing Checklist

- [ ] WASM builds successfully
- [ ] ProcessLoop starts and runs
- [ ] HTTP requests can be made
- [ ] Matrix multiplication works locally
- [ ] Proxy mode makes HTTP requests
- [ ] Adaptation works correctly
- [ ] Multiple requests can be handled
- [ ] Browser shows no errors in console
- [ ] Performance is acceptable

## Deployment

1. Build native workers as usual (`dnc app/RemoteRepo.dn`)
2. Build WASM server (`./compile-wasm.sh`)
3. Package WASM files (`./package-wasm.sh`)
4. Deploy WASM files to web server
5. Deploy native workers separately (Docker/K8s)
6. Configure workers to accept HTTP requests
7. Test end-to-end from browser

