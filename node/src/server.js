import express from 'express';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import client from 'prom-client';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Setup Prometheus metrics
const register = new client.Registry();
client.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const workerRequestsTotal = new client.Counter({
  name: 'worker_requests_total',
  help: 'Total number of background worker requests',
  labelNames: ['status'],
  registers: [register]
});

const app = express();
const PORT = process.env.PORT || 4002;
const GO_API_BASE = process.env.GO_API_BASE || 'http://localhost:4001';
const QUARKUS_API_BASE = process.env.QUARKUS_API_BASE || 'http://localhost:4003';
const PYTHON_API_BASE = process.env.PYTHON_API_BASE || 'http://localhost:4004';

// Statistics for background worker
const stats = {
  totalRequests: 0,
  successfulRequests: 0,
  failedRequests: 0,
  lastSeed: null,
  lastGeneratedName: null,
  lastTimestamp: null,
  startTime: Date.now()
};

// Background worker to continuously query seed API and generate names
async function backgroundWorker() {
  while (true) {
    try {
      stats.totalRequests++;
      
      // Get seed from Python API
      const seedResponse = await fetch(`${PYTHON_API_BASE}/api/seed`);
      if (seedResponse.ok) {
        const seedData = await seedResponse.json();
        stats.lastSeed = seedData.seed;
        stats.lastTimestamp = new Date(seedData.timestamp * 1000).toISOString();
        
        // Generate name from Go API using the seed
        const nameResponse = await fetch(`${GO_API_BASE}/api/name?seed=${seedData.seed}`);
        if (nameResponse.ok) {
          const nameData = await nameResponse.json();
          stats.lastGeneratedName = nameData.names[0]?.combined || 'unknown';
          stats.successfulRequests++;
          workerRequestsTotal.inc({ status: 'success' });
          
          console.log(`[Worker] Generated: ${stats.lastGeneratedName} (seed: ${stats.lastSeed})`);
        } else {
          stats.failedRequests++;
          workerRequestsTotal.inc({ status: 'failed' });
          console.error('[Worker] Failed to generate name');
        }
      } else {
        stats.failedRequests++;
        workerRequestsTotal.inc({ status: 'failed' });
        console.error('[Worker] Failed to fetch seed');
      }
    } catch (error) {
      stats.failedRequests++;
      workerRequestsTotal.inc({ status: 'error' });
      console.error('[Worker] Error:', error.message);
    }
    
    // Small delay before next request
    await new Promise(resolve => setTimeout(resolve, 100));
  }
}

// Parse JSON bodies
app.use(express.json());

// Serve static files from public directory
app.use(express.static(join(__dirname, '..', 'public')));

// Prometheus metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'name-generator-web' });
});

// Background worker statistics endpoint
app.get('/api/worker/stats', (req, res) => {
  const uptime = Math.floor((Date.now() - stats.startTime) / 1000);
  const successRate = stats.totalRequests > 0 
    ? ((stats.successfulRequests / stats.totalRequests) * 100).toFixed(2)
    : 0;
  
  res.json({
    ...stats,
    uptime,
    successRate: `${successRate}%`,
    requestsPerSecond: uptime > 0 ? (stats.totalRequests / uptime).toFixed(2) : 0
  });
});

// Proxy endpoint for Go API - Get names
app.get('/api/name', async (req, res) => {
  try {
    const queryParams = new URLSearchParams(req.query);
    const response = await fetch(`${GO_API_BASE}/api/name?${queryParams.toString()}`);
    
    if (!response.ok) {
      const errorText = await response.text();
      return res.status(response.status).json({ 
        error: 'Failed to fetch names from Go API',
        details: errorText 
      });
    }
    
    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error('Error proxying to Go API:', error);
    res.status(500).json({ 
      error: 'Failed to connect to Go API',
      message: error.message 
    });
  }
});

// Proxy endpoint for Go API - Figlet
app.post('/api/figlet', async (req, res) => {
  try {
    const response = await fetch(`${GO_API_BASE}/api/figlet`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(req.body)
    });
    
    if (!response.ok) {
      const errorText = await response.text();
      return res.status(response.status).json({ 
        error: 'Failed to generate figlet from Go API',
        details: errorText 
      });
    }
    
    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error('Error proxying to Go API:', error);
    res.status(500).json({ 
      error: 'Failed to connect to Go API',
      message: error.message 
    });
  }
});

// Proxy endpoint for Python API - Get seed
app.get('/api/seed', async (req, res) => {
  try {
    const response = await fetch(`${PYTHON_API_BASE}/api/seed`);
    
    if (!response.ok) {
      const errorText = await response.text();
      return res.status(response.status).json({ 
        error: 'Failed to fetch seed from Python API',
        details: errorText 
      });
    }
    
    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error('Error proxying to Python API:', error);
    res.status(500).json({ 
      error: 'Failed to connect to Python API',
      message: error.message 
    });
  }
});

// Proxy endpoint for Quarkus API - Lolcat
app.post('/api/lolcat', async (req, res) => {
  try {
    const response = await fetch(`${QUARKUS_API_BASE}/api/lolcat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(req.body)
    });
    
    if (!response.ok) {
      const errorText = await response.text();
      return res.status(response.status).json({ 
        error: 'Failed to colorize with Quarkus API',
        details: errorText 
      });
    }
    
    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error('Error proxying to Quarkus API:', error);
    res.status(500).json({ 
      error: 'Failed to connect to Quarkus API',
      message: error.message 
    });
  }
});

app.listen(PORT, () => {
  console.log(`
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   🎨 ASCII Name Generator Web App                        ║
║                                                           ║
║   Server running on: http://localhost:${PORT}              ║
║                                                           ║
║   Proxying to:                                           ║
║   - Go API:      ${GO_API_BASE}                    ║
║   - Quarkus API: ${QUARKUS_API_BASE}                    ║
║   - Python API:  ${PYTHON_API_BASE}                    ║
║                                                           ║
║   Background worker: ACTIVE                              ║
║   Stats endpoint: /api/worker/stats                      ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
  `);
  
  // Start background worker
  console.log('[Worker] Starting background worker...');
  backgroundWorker().catch(err => {
    console.error('[Worker] Fatal error:', err);
  });
});
