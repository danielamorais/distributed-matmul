const express = require('express');
const path = require('path');
const app = express();
const port = process.env.PORT || 8080;

// In-memory storage (for production, consider Redis)
const tasks = new Map();      // taskId -> {status, data, result, workerId, timestamps}
const taskQueue = [];         // Array of pending task IDs
let taskIdCounter = 0;

// Worker tracking
const workers = new Map();    // workerId -> {lastSeen, tasksCompleted}

app.use(express.json({ limit: '10mb' }));

// CORS and security headers
app.use((req, res, next) => {
  // COOP/COEP headers for SharedArrayBuffer support
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  
  // CORS for cross-origin workers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: Date.now() });
});

// 1. Main app submits task
app.post('/task', (req, res) => {
  const taskId = ++taskIdCounter;
  const task = {
    id: taskId,
    status: 'pending',
    data: req.body,
    result: null,
    createdAt: Date.now(),
    assignedAt: null,
    completedAt: null,
    workerId: null
  };
  
  tasks.set(taskId, task);
  taskQueue.push(taskId);
  
  console.log(`📥 Task ${taskId} submitted (queue size: ${taskQueue.length})`);
  res.json({ taskId, status: 'queued', position: taskQueue.length });
});

// 2. Worker requests next task
app.get('/task/next', (req, res) => {
  const workerId = req.query.workerId || `anonymous-${Math.random().toString(36).substr(2, 9)}`;
  
  // Update worker last seen
  const worker = workers.get(workerId) || { tasksCompleted: 0 };
  worker.lastSeen = Date.now();
  workers.set(workerId, worker);
  
  if (taskQueue.length === 0) {
    return res.json({ status: 'no_tasks' });
  }
  
  const taskId = taskQueue.shift();
  const task = tasks.get(taskId);
  
  if (!task) {
    return res.status(404).json({ error: 'Task not found' });
  }
  
  task.status = 'processing';
  task.workerId = workerId;
  task.assignedAt = Date.now();
  
  console.log(`🔧 Task ${taskId} assigned to worker ${workerId} (queue: ${taskQueue.length})`);
  
  res.json({
    taskId: task.id,
    data: task.data
  });
});

// 3. Worker submits result
app.post('/task/:id/result', (req, res) => {
  const taskId = parseInt(req.params.id);
  const task = tasks.get(taskId);
  
  if (!task) {
    return res.status(404).json({ error: 'Task not found' });
  }
  
  task.status = 'completed';
  task.result = req.body;
  task.completedAt = Date.now();
  
  const duration = task.completedAt - task.assignedAt;
  
  // Update worker stats
  const worker = workers.get(task.workerId);
  if (worker) {
    worker.tasksCompleted = (worker.tasksCompleted || 0) + 1;
  }
  
  console.log(`✅ Task ${taskId} completed by worker ${task.workerId} (${duration}ms)`);
  
  res.json({ status: 'success' });
});

// 4. Main app retrieves result
app.get('/result/:id', (req, res) => {
  const taskId = parseInt(req.params.id);
  const task = tasks.get(taskId);
  
  if (!task) {
    return res.status(404).json({ error: 'Task not found' });
  }
  
  if (task.status === 'completed') {
    res.json({
      status: 'completed',
      result: task.result,
      duration: task.completedAt - task.assignedAt,
      workerId: task.workerId
    });
  } else {
    res.json({
      status: task.status,
      position: task.status === 'pending' ? taskQueue.indexOf(taskId) + 1 : null
    });
  }
});

// 5. Statistics endpoint
app.get('/stats', (req, res) => {
  const now = Date.now();
  const activeWorkers = Array.from(workers.entries())
    .filter(([_, worker]) => now - worker.lastSeen < 10000) // Active in last 10 seconds
    .length;
  
  const allTasks = Array.from(tasks.values());
  const stats = {
    totalTasks: tasks.size,
    pending: taskQueue.length,
    processing: allTasks.filter(t => t.status === 'processing').length,
    completed: allTasks.filter(t => t.status === 'completed').length,
    workers: {
      total: workers.size,
      active: activeWorkers,
      details: Array.from(workers.entries()).map(([id, worker]) => ({
        id,
        tasksCompleted: worker.tasksCompleted,
        lastSeen: now - worker.lastSeen,
        active: now - worker.lastSeen < 10000
      }))
    }
  };
  res.json(stats);
});

// 6. Worker registration endpoint (for tracking)
app.post('/worker/register', (req, res) => {
  const workerId = req.body.workerId || `worker-${Math.random().toString(36).substr(2, 9)}`;
  
  if (!workers.has(workerId)) {
    workers.set(workerId, {
      registeredAt: Date.now(),
      lastSeen: Date.now(),
      tasksCompleted: 0
    });
    console.log(`🔧 New worker registered: ${workerId}`);
  }
  
  res.json({ workerId, status: 'registered' });
});

// Cleanup old tasks (run every 5 minutes)
setInterval(() => {
  const now = Date.now();
  const maxAge = 60 * 60 * 1000; // 1 hour
  
  for (const [taskId, task] of tasks.entries()) {
    if (task.status === 'completed' && now - task.completedAt > maxAge) {
      tasks.delete(taskId);
      console.log(`🧹 Cleaned up old task ${taskId}`);
    }
  }
}, 5 * 60 * 1000);

// Timeout processing tasks (run every 30 seconds)
setInterval(() => {
  const now = Date.now();
  const timeout = 60 * 1000; // 60 seconds
  
  for (const [taskId, task] of tasks.entries()) {
    if (task.status === 'processing' && now - task.assignedAt > timeout) {
      console.log(`⏱️  Task ${taskId} timed out, requeueing...`);
      task.status = 'pending';
      task.workerId = null;
      task.assignedAt = null;
      taskQueue.push(taskId);
    }
  }
}, 30 * 1000);

// Serve static files (worker page, etc.)
app.use(express.static(path.join(__dirname, '')));

app.listen(port, () => {
  console.log(`\n🚀 Distributed Browser Worker Coordinator`);
  console.log(`═══════════════════════════════════════════`);
  console.log(`✅ Server running at http://localhost:${port}`);
  console.log(`📡 Endpoints:`);
  console.log(`   POST /task           - Submit new task`);
  console.log(`   GET  /task/next      - Worker requests task`);
  console.log(`   POST /task/:id/result - Worker submits result`);
  console.log(`   GET  /result/:id     - Retrieve result`);
  console.log(`   GET  /stats          - View statistics`);
  console.log(`\n🌐 Open worker page: http://localhost:${port}/worker.html`);
  console.log(`📊 View statistics: http://localhost:${port}/stats`);
  console.log(`\n⏳ Waiting for tasks and workers...\n`);
});

module.exports = app;


