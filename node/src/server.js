import express from 'express';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();
const PORT = process.env.PORT || 4002;
const GO_API_BASE = process.env.GO_API_BASE || 'http://localhost:4001';
const QUARKUS_API_BASE = process.env.QUARKUS_API_BASE || 'http://localhost:4003';

// Parse JSON bodies
app.use(express.json());

// Serve static files from public directory
app.use(express.static(join(__dirname, '..', 'public')));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'name-generator-web' });
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
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
  `);
});
