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

// ============================================================================
// Coordinator State (In-Memory for PoC)
// ============================================================================
let tasks = [];
let nextTaskId = 1;
let pendingQueue = [];
let totalTasks = 0;
let completedTasks = 0;
let activeTasks = 0;

function findTask(taskId) {
  return tasks.find(t => t.id === taskId);
}

function getNextPendingTask() {
  if (pendingQueue.length === 0) return null;
  const taskId = pendingQueue.shift();
  return findTask(taskId);
}
// ============================================================================

function pickUpstream() {
  if (upstreamList.length === 0) {
    // Default to remote workers for WASM setup
    const defaultUpstreams = ['http://localhost:8081/rpc', 'http://localhost:8082/rpc'];
    const target = defaultUpstreams[upstreamPointer];
    upstreamPointer = (upstreamPointer + 1) % defaultUpstreams.length;
    return target;
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
      signal: AbortSignal.timeout(60000), // 60 second timeout (increased for TCP flush delay)
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

// ============================================================================
// Coordinator Endpoints (Browser Workers PoC)
// ============================================================================

// POST /task - Submit new task
app.post('/task', (req, res) => {
  const taskData = req.body;
  const task = {
    id: nextTaskId++,
    status: 'pending',
    data: taskData,
    result: null,
    workerId: null,
    createdAt: new Date(),
  };
  
  tasks.push(task);
  pendingQueue.push(task.id);
  totalTasks++;
  activeTasks++;
  
  console.log(`[Coordinator] Task ${task.id} submitted. Queue size: ${pendingQueue.length}`);
  
  res.json({ taskId: task.id });
});

// GET /task/next - Worker requests next task
app.get('/task/next', (req, res) => {
  const workerId = req.query.workerId || 'unknown';
  const task = getNextPendingTask();
  
  if (!task) {
    // No tasks available
    return res.status(204).send();
  }
  
  // Mark task as processing
  task.status = 'processing';
  task.workerId = workerId;
  task.startedAt = new Date();
  
  console.log(`[Coordinator] Task ${task.id} assigned to worker ${workerId}`);
  
  res.json({
    taskId: task.id,
    data: task.data
  });
});

// POST /task/:id/result - Worker submits result
app.post('/task/:id/result', (req, res) => {
  const taskId = parseInt(req.params.id);
  const result = req.body;
  
  const task = findTask(taskId);
  
  if (!task) {
    return res.status(404).json({ error: 'Task not found' });
  }
  
  task.result = result;
  task.status = 'completed';
  task.completedAt = new Date();
  
  completedTasks++;
  activeTasks--;
  
  console.log(`[Coordinator] Task ${task.id} completed by worker ${task.workerId}`);
  
  res.json({ status: 'success' });
});

// GET /result/:id - Get task result
app.get('/result/:id', (req, res) => {
  const taskId = parseInt(req.params.id);
  const task = findTask(taskId);
  
  if (!task) {
    return res.status(404).json({ error: 'Task not found' });
  }
  
  // If task is not completed yet, return 204 (No Content) to indicate "not ready"
  if (task.status !== 'completed') {
    return res.status(204).send();
  }
  
  // Task is completed - return just the result matrix
  // The result might be a string (JSON string) or already parsed
  let result = task.result;
  if (typeof result === 'string') {
    try {
      // Try to parse if it's a JSON string
      result = JSON.parse(result);
    } catch (e) {
      // If parsing fails, return as string
    }
  }
  
  // Return the result directly (as JSON array, e.g., [[19,22],[43,50]])
  res.json(result);
});

// GET /stats - Statistics
app.get('/stats', (req, res) => {
  res.json({
    totalTasks,
    completedTasks,
    activeTasks,
    queueSize: pendingQueue.length,
    uptime: process.uptime()
  });
});

// ============================================================================

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
    // Submit task to coordinator (for browser WASM workers to pick up)
    const taskData = req.body;
    const task = {
      id: nextTaskId++,
      status: 'pending',
      data: taskData,
      submittedAt: new Date().toISOString()
    };
    
    tasks.push(task);
    pendingQueue.push(task.id);
    totalTasks++;
    
    console.log(`[/matmul] Created task #${task.id}, returning taskId for client to poll`);
    
    // Return taskId immediately - client will poll /result/:id for the result
    // This allows the main app to submit and poll asynchronously
    return res.json({ taskId: task.id });
  } catch (err) {
    console.error('Error in /matmul endpoint:', err);
    res.status(500).json({ 
      error: err.message || 'Internal server error'
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