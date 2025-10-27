# System Flow Diagrams

This document contains detailed Mermaid diagrams explaining the distributed matrix multiplication system flow, focusing on request processing and proxy adaptation mechanisms.

## Overview

The system performs distributed matrix multiplication with runtime adaptation capabilities. It can dynamically switch between local computation and distributed computation across multiple worker nodes based on performance metrics or explicit configuration.

**Key Capabilities:**
- Receive matrix multiplication requests via HTTP POST
- Switch between local and distributed computation at runtime
- Distribute workload to multiple remote worker nodes
- Monitor response time and adapt automatically

## Diagram Navigation

- **Diagram 1**: High-level system architecture
- **Diagram 2**: Complete request processing flow
- **Diagram 3**: Proxy adaptation decision process
- **Diagram 4**: Distributed computation flow with proxy
- **Diagram 5**: Runtime adaptation mechanism details
- **Diagram 6**: Remote worker node processing

---

## 1. System Architecture Overview

This diagram shows the high-level components and their relationships.

```mermaid
graph TB
    Client[HTTP Client]
    ServerComponent[Server Component]
    Controller[MatmulController]
    MatmulImpl[Matmul Implementation]
    MatmulProxy[Matmul Proxy]
    RemoteNodes[Remote Worker Nodes]

    Client -->|POST /matmul<br/>matrices in JSON| ServerComponent
    ServerComponent -->|routes request| Controller
    Controller -->|calls multiply| MatmulImpl
    ServerComponent -.->|runtime adaptation| MatmulProxy
    MatmulProxy -.->|distributes work| RemoteNodes

    style MatmulImpl fill:#e1f5e1
    style MatmulProxy fill:#fff4e1
    style RemoteNodes fill:#ffe1e1
```

## 2. Request Processing Flow

This diagram shows how a matrix multiplication request flows through the system.

```mermaid
sequenceDiagram
    participant Client
    participant Server
    participant Controller
    participant Matmul as Matmul (Local/Proxy)
    participant Worker as Remote Worker (if proxy)

    Client->>Server: POST /matmul<br/>{ A: [[1,2],[3,4]], B: [[5,6],[7,8]] }
    Server->>Server: Parse HTTP Request
    Server->>Controller: handle(request)
    Controller->>Controller: Parse JSON to matrix data
    Controller->>Matmul: multiply(matrixA, matrixB)
    
    alt Using Proxy
        Matmul->>Worker: Distribute calculation
        Worker-->>Matmul: Return result
    else Using Local
        Matmul->>Matmul: Compute locally
    end
    
    Matmul-->>Controller: Return result matrix
    Controller->>Controller: Convert matrix to JSON
    Controller-->>Server: HTTP 200 Response
    Server-->>Client: Send result
```

## 3. Proxy Adaptation Process

This diagram shows how the system switches between local computation and distributed computation via the proxy.

```mermaid
graph LR
    subgraph Initial State
        A[Server starts] --> B{Mode Selection}
    end

    subgraph Local Mode
        B -->|Mode 3<br/>Serial| C[Load Matmul.o]
        C --> D[Wire to Controller]
        D --> E[Local computation]
    end

    subgraph Proxy Mode
        B -->|Mode 1<br/>Proxy| F[Load Matmul.proxy.o]
        F --> G[Wire to Controller]
        G --> H[Distributed via proxy]
    end

    subgraph Adaptive Mode
        B -->|Mode 2<br/>Adaptive| I[Start with local]
        I --> J[Monitor response time]
        J --> K{Response time<br/>> 200ms?}
        K -->|Yes| L[Adapt to proxy]
        K -->|No| J
        L --> H
    end

    style E fill:#e1f5e1
    style H fill:#fff4e1
```

## 4. Distributed Computation Flow

This diagram shows how the proxy distributes matrix calculations to remote worker nodes.

```mermaid
sequenceDiagram
    participant Server
    participant Proxy as Matmul Proxy
    participant W1 as Worker Node 1
    participant W2 as Worker Node 2
    
    Server->>Proxy: multiply(matrixA, matrixB)
    
    Note over Proxy: Proxy serializes matrices to JSON
    
    loop For each row in matrixA
        Proxy->>W1: calcLine(row, matrixB)<br/>via RPC
        W1-->>Proxy: calculated row
        Proxy->>Proxy: Round-robin selection
        Proxy->>W2: calcLine(row, matrixB)<br/>via RPC
        W2-->>Proxy: calculated row
    end
    
    Proxy->>Proxy: Assemble complete result matrix
    Proxy-->>Server: Return result matrix
```

## 5. Runtime Adaptation Mechanism

This diagram details how the system performs runtime adaptation between implementations.

```mermaid
sequenceDiagram
    participant Controller
    participant OldImpl as Current Implementation
    participant Adapter
    participant NewImpl as New Implementation
    
    Note over Controller: System detects adaptation need
    
    Controller->>Adapter: adaptRequiredInterface(<br/>  component,<br/>  'matmul.Matmul',<br/>  newComponent<br/>)
    
    Adapter->>OldImpl: AdaptEvents.inactive()
    Note over OldImpl: Cleanup resources
    
    Adapter->>NewImpl: Instantiate new implementation
    NewImpl->>NewImpl: AdaptEvents.active()
    Note over NewImpl: Initialize state
    
    Adapter->>Adapter: Rewire dependencies
    
    Adapter-->>Controller: Adaptation complete
    
    Note over Controller: Subsequent calls use new implementation
```

## 6. Remote Worker Processing

This diagram shows how remote worker nodes process calculation requests from the proxy.

```mermaid
sequenceDiagram
    participant Proxy
    participant RPC as RPC Layer
    participant Worker
    participant MatmulComp as Matmul Component
    
    Proxy->>RPC: connect(remoteNode)
    Proxy->>RPC: make(RPCRequest with method + params)
    
    RPC->>Worker: TCP socket connection
    RPC->>Worker: Send: { method: "calcLine", params: {line, B} }
    
    Worker->>Worker: Parse JSON request
    Worker->>Worker: Extract method name
    
    alt Method is "calcLine"
        Worker->>MatmulComp: calcLine(charToLine(line), charToMatrix(B))
        MatmulComp->>MatmulComp: Calculate one result line
        MatmulComp-->>Worker: Return Line result
        Worker->>Worker: Convert Line to char array
        Worker-->>RPC: Send result as JSON
    else Method is "multiply"
        Worker->>MatmulComp: multiply(charToMatrix(A), charToMatrix(B))
        MatmulComp->>MatmulComp: Calculate full matrix
        MatmulComp-->>Worker: Return Matrix result
        Worker-->>RPC: Send result as JSON
    end
    
    RPC-->>Proxy: Return Response with result
    Proxy->>Proxy: Process next row (round-robin)
```

## Key Components Explained

### Server Component (`server/Server.dn`)
- Binds to TCP port 8080 and accepts HTTP connections
- Loads components dynamically: `Matmul.o` (local) and `Matmul.proxy.o` (distributed)
- Uses `composition.RecursiveLoader` to load components and wire dependencies
- Performs runtime adaptation using `composition.Adapt.adaptRequiredInterface()`
- Provides three initialization modes:
  - **Mode 1 (proxy)**: Start with distributed computation
  - **Mode 2 (adapt)**: Start local, switch to proxy if response time > 200ms
  - **Mode 3 (serial)**: Always use local computation

### MatmulController (`server/MatmulController.dn`)
- Extracts matrices from JSON request body (`MultiplyParamsFormat`)
- Calls `matmul.multiply()` on the current matmul implementation
- Converts result matrix back to JSON string for HTTP response
- Returns HTTP 200 with result or 404 for invalid requests

### Matmul Implementation - Local (`matmul/Matmul.dn`)
- Performs matrix multiplication locally (serial computation)
- Calculates each result line by iterating through rows of matrix A
- Uses `calcLine()` method to compute one row of the result matrix
- Includes conversion utilities: `matrixToChar`, `charToMatrix`, `lineToChar`, `charToLine`

### Matmul Proxy (`matmul/Matmul.proxy.dn`)
- Implements the same `Matmul` interface but delegates to remote workers
- Distributes `calcLine` operations to worker nodes via RPC
- Uses round-robin load balancing between available worker nodes
- Serializes matrices to JSON for network transmission
- Implements `AdaptEvents` interface for runtime adaptation callbacks
- Receives `active()` and `inactive()` lifecycle notifications

### Remote Worker Nodes (`server/Remote.matmul.dn`)
- Receives calculation requests via TCP socket connections
- Parses RPC requests containing method name and JSON parameters
- Routes to appropriate matmul method based on request:
  - `calcLine`: Calculates one line of result matrix
  - `multiply`: Calculates full matrix (alternative mode)
- Returns results as JSON-encoded responses
- Can run on multiple ports (8081, 8082, etc.) for horizontal scaling

## Proxy Adaptation Mechanism

### How Proxy is Changed

The system can switch between local and distributed computation at runtime without restarting:

1. **Initial Wiring**: Components are loaded and wired using `wire()` method
   ```dana
   matmulController.wire("matmul.Matmul", matmulProxy.mainComponent, "matmul.Matmul")
   ```

2. **Runtime Adaptation**: Uses Dana's `composition.Adapt` API
   ```dana
   adapter.adaptRequiredInterface(
       matmulController,      // component to adapt
       "matmul.Matmul",       // interface name to rewire
       matmulProxy            // new implementation
   )
   ```

3. **State Transfer**: The proxy implements `AdaptEvents` interface
   - `AdaptEvents:active()`: Called when proxy is activated
   - `AdaptEvents:inactive()`: Called when proxy is deactivated

4. **Transparent Switch**: All subsequent calls to `matmul.multiply()` go through the new implementation

