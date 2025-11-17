const express = require('express');
const path = require('path');
const app = express();
const port = process.env.PORT || 8080;

const fetchImpl = globalThis.fetch || ((...args) =>
  import('node-fetch').then(({ default: fetch }) => fetch(...args)));

const upstreamList = (process.env.MATMUL_UPSTREAMS || '')
  .split(',')
  .map((url) => url.trim())
  .filter((url) => url.length > 0);
let upstreamPointer = 0;

function pickUpstream() {
  if (upstreamList.length === 0) {
    return process.env.MATMUL_FALLBACK || 'http://127.0.0.1:9000/matmul';
  }
  const target = upstreamList[upstreamPointer];
  upstreamPointer = (upstreamPointer + 1) % upstreamList.length;
  return target;
}

async function forwardToUpstream(payload) {
  const endpoint = pickUpstream();
  try {
    const response = await fetchImpl(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(30000), // 30 second timeout
    });
    const contentType = response.headers.get('content-type') || 'application/json';
    const body = await response.text();
    return {
      status: response.status,
      contentType,
      body,
      endpoint, // Include endpoint in return
    };
  } catch (err) {
    // Provide more detailed error information
    if (err.code === 'ECONNREFUSED') {
      throw new Error(`Connection refused to ${endpoint}. Make sure the native Dana server is running. Start it with: dana app/main.o 3`);
    } else if (err.name === 'AbortError') {
      throw new Error(`Request timeout to ${endpoint}`);
    } else {
      throw new Error(`Failed to reach ${endpoint}: ${err.message}`);
    }
  }
}

// This is the crucial part: setting the headers for all responses
app.use((req, res, next) => {
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  next();
});

app.use(express.json({ limit: '2mb' }));

// Convert incoming payload to RPC Request format expected by Dana remote servers
function convertToRPCRequest(payload) {
  // Payload from HTML form has A and B as JSON strings (e.g., "[[1,2],[3,4]]")
  // We need to create an RPC Request with:
  // - meta: [{"name": "method", "value": "multiply"}]
  // - content: JSON string of MultiplyParamsFormat {"A": "...", "B": "..."}
  
  let matrixA, matrixB;
  
  // Handle different input formats
  if (typeof payload.A === 'string') {
    // A and B are already JSON strings
    matrixA = payload.A;
    matrixB = payload.B;
  } else if (Array.isArray(payload.A)) {
    // A and B are arrays - stringify them
    matrixA = JSON.stringify(payload.A);
    matrixB = JSON.stringify(payload.B);
  } else {
    throw new Error('Invalid payload format: A and B must be arrays or JSON strings');
  }
  
  // Create MultiplyParamsFormat as JSON string (content field must be a string)
  const multiplyParams = {
    A: matrixA,
    B: matrixB
  };
  
  // Create RPC Request
  const rpcRequest = {
    meta: [
      {
        name: "method",
        value: "multiply"
      }
    ],
    content: JSON.stringify(multiplyParams) // content must be a JSON string
  };
  
  return rpcRequest;
}

// Parse RPC Response to extract the actual result
function parseRPCResponse(responseBody) {
  try {
    const response = JSON.parse(responseBody);
    // RPC Response has structure: {meta: [...], content: "..."}
    // The content field contains the matrix result as a string
    if (response.content) {
      // Try to parse the content as JSON (it should be a matrix array)
      try {
        return JSON.parse(response.content);
      } catch (e) {
        // If parsing fails, content might be in a different format
        // Try to extract matrix from the string
        return response.content;
      }
    }
    return response;
  } catch (e) {
    // If response is not RPC format, return as-is
    return responseBody;
  }
}

app.post('/matmul', async (req, res) => {
  try {
    // Convert incoming payload to RPC Request format
    const rpcRequest = convertToRPCRequest(req.body);
    
    const upstreamResponse = await forwardToUpstream(rpcRequest);
    res.status(upstreamResponse.status);
    res.set('Content-Type', upstreamResponse.contentType);
    res.set('X-Upstream-Used', upstreamResponse.endpoint);
    
    // Parse RPC Response to extract the actual matrix result
    const result = parseRPCResponse(upstreamResponse.body);
    res.json(result);
  } catch (err) {
    console.error('Error forwarding /matmul request:', err);
    const errorMessage = err.message || 'Failed to reach upstream matmul service';
    res.status(502).json({ 
      error: errorMessage,
      hint: 'Make sure a native Dana server is running. Start it with: dana app/main.o 3'
    });
  }
});

// Serve static files from the current directory (which is 'webserver')
app.use(express.static(path.join(__dirname, '')));

app.listen(port, () => {
  console.log(`✅ Server with COOP/COEP headers running at http://localhost:${port}`);
  console.log(`   Serving files from: ${__dirname}`);
  console.log(`\n📡 Upstream configuration:`);
  if (upstreamList.length > 0) {
    console.log(`   Configured upstreams: ${upstreamList.join(', ')}`);
  } else {
    const fallback = process.env.MATMUL_FALLBACK || 'http://127.0.0.1:9000/matmul';
    console.log(`   Using fallback upstream: ${fallback}`);
    console.log(`   ⚠️  Make sure a native Dana server is running on that endpoint!`);
    console.log(`   Start it with: dana app/main.o 3`);
  }
  console.log(`\n🌐 Open http://localhost:${port}/xdana.html in your browser\n`);
});