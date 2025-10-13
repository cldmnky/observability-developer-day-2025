# Microservices Architecture Refactor Plan

## Overview
Restructure the API call chain so that:
1. **Node API** → calls only → **Go API**
2. **Go API** → calls → **Python API** (for seeds) and **Quarkus API** (for lolcat when requested)
3. Ensure distributed tracing with proper span context propagation
4. Add comprehensive metrics across all services

## Current Architecture
```
Frontend → Node API → Go API (names)
                   → Python API (seeds)
                   → Quarkus API (lolcat)
```

## Target Architecture
```
Frontend → Node API → Go API → Python API (seeds)
                            → Quarkus API (lolcat)
```

---

## Changes Required

### 1. Go API Changes (go/pkg/api/server.go)

#### Add HTTP Client with OpenTelemetry Instrumentation
```go
import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
    "os"
    "time"
    
    "go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
    "go.opentelemetry.io/otel/codes"
    "go.opentelemetry.io/otel/trace"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)
```

#### Add Metrics
```go
var (
    httpRequestsTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "go_api_http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )
    
    httpRequestDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "go_api_http_request_duration_seconds",
            Help: "Duration of HTTP requests in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "endpoint"},
    )
    
    externalAPICallsTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "go_api_external_calls_total",
            Help: "Total number of external API calls",
        },
        []string{"service", "status"},
    )
    
    externalAPICallDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "go_api_external_call_duration_seconds",
            Help: "Duration of external API calls in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"service"},
    )
    
    seedFetchTotal = promauto.NewCounter(
        prometheus.CounterOpts{
            Name: "go_api_seed_fetch_total",
            Help: "Total number of seed fetches from Python API",
        },
    )
    
    lolcatCallsTotal = promauto.NewCounter(
        prometheus.CounterOpts{
            Name: "go_api_lolcat_calls_total",
            Help: "Total number of lolcat colorization calls",
        },
    )
)
```

#### Add External Service Client
```go
type Server struct {
    generator       NameGenerator
    newGenerator    func(seed int64) (NameGenerator, error)
    mux             *http.ServeMux
    maxCount        int
    httpClient      *http.Client
    pythonAPIBase   string
    quarkusAPIBase  string
    tracer          trace.Tracer
}

func NewServer(generator NameGenerator) *Server {
    pythonAPIBase := os.Getenv("PYTHON_API_BASE")
    if pythonAPIBase == "" {
        pythonAPIBase = "http://localhost:4004"
    }
    
    quarkusAPIBase := os.Getenv("QUARKUS_API_BASE")
    if quarkusAPIBase == "" {
        quarkusAPIBase = "http://localhost:4003"
    }
    
    // Create HTTP client with OpenTelemetry instrumentation
    httpClient := &http.Client{
        Timeout: 30 * time.Second,
        Transport: otelhttp.NewTransport(http.DefaultTransport),
    }
    
    s := &Server{
        generator:      generator,
        newGenerator:   defaultSeededGenerator,
        mux:            http.NewServeMux(),
        maxCount:       50,
        httpClient:     httpClient,
        pythonAPIBase:  pythonAPIBase,
        quarkusAPIBase: quarkusAPIBase,
        tracer:         otel.Tracer("go-api"),
    }
    
    s.mux.HandleFunc("/healthz", s.handleHealth)
    s.mux.HandleFunc("/api/name", s.handleName)
    s.mux.HandleFunc("/api/figlet", s.handleFiglet)
    s.mux.HandleFunc("/api/seed", s.handleSeedProxy)
    s.mux.HandleFunc("/api/lolcat", s.handleLolcatProxy)
    s.mux.Handle("/metrics", promhttp.Handler())
    
    return s
}
```

#### Add Method to Fetch Seed from Python API
```go
type SeedResponse struct {
    Seed      float64 `json:"seed"`
    Timestamp float64 `json:"timestamp"`
}

func (s *Server) fetchSeedFromPython(ctx context.Context) (*SeedResponse, error) {
    ctx, span := s.tracer.Start(ctx, "fetchSeedFromPython")
    defer span.End()
    
    timer := prometheus.NewTimer(externalAPICallDuration.WithLabelValues("python"))
    defer timer.ObserveDuration()
    
    seedFetchTotal.Inc()
    
    url := fmt.Sprintf("%s/api/seed", s.pythonAPIBase)
    span.SetAttributes(attribute.String("http.url", url))
    
    req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
    if err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        externalAPICallsTotal.WithLabelValues("python", "error").Inc()
        return nil, fmt.Errorf("failed to create request: %w", err)
    }
    
    resp, err := s.httpClient.Do(req)
    if err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        externalAPICallsTotal.WithLabelValues("python", "error").Inc()
        return nil, fmt.Errorf("failed to call Python API: %w", err)
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != http.StatusOK {
        span.SetStatus(codes.Error, fmt.Sprintf("HTTP %d", resp.StatusCode))
        externalAPICallsTotal.WithLabelValues("python", "error").Inc()
        return nil, fmt.Errorf("Python API returned status %d", resp.StatusCode)
    }
    
    var seedResp SeedResponse
    if err := json.NewDecoder(resp.Body).Decode(&seedResp); err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        externalAPICallsTotal.WithLabelValues("python", "error").Inc()
        return nil, fmt.Errorf("failed to decode response: %w", err)
    }
    
    externalAPICallsTotal.WithLabelValues("python", "success").Inc()
    span.SetAttributes(attribute.Float64("seed.value", seedResp.Seed))
    
    return &seedResp, nil
}
```

#### Add Method to Call Quarkus Lolcat API
```go
type LolcatRequest struct {
    Text   string   `json:"text"`
    Seed   *float64 `json:"seed,omitempty"`
    Spread *float64 `json:"spread,omitempty"`
    Freq   *float64 `json:"freq,omitempty"`
}

type LolcatResponse struct {
    Original  string `json:"original"`
    Colorized string `json:"colorized"`
}

func (s *Server) colorizeWithLolcat(ctx context.Context, text string, seed float64) (string, error) {
    ctx, span := s.tracer.Start(ctx, "colorizeWithLolcat")
    defer span.End()
    
    timer := prometheus.NewTimer(externalAPICallDuration.WithLabelValues("quarkus"))
    defer timer.ObserveDuration()
    
    lolcatCallsTotal.Inc()
    
    url := fmt.Sprintf("%s/api/lolcat", s.quarkusAPIBase)
    span.SetAttributes(attribute.String("http.url", url))
    
    spread := 3.0
    freq := 0.1
    reqBody := LolcatRequest{
        Text:   text,
        Seed:   &seed,
        Spread: &spread,
        Freq:   &freq,
    }
    
    bodyBytes, err := json.Marshal(reqBody)
    if err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        externalAPICallsTotal.WithLabelValues("quarkus", "error").Inc()
        return "", fmt.Errorf("failed to marshal request: %w", err)
    }
    
    req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(bodyBytes))
    if err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        externalAPICallsTotal.WithLabelValues("quarkus", "error").Inc()
        return "", fmt.Errorf("failed to create request: %w", err)
    }
    req.Header.Set("Content-Type", "application/json")
    
    resp, err := s.httpClient.Do(req)
    if err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        externalAPICallsTotal.WithLabelValues("quarkus", "error").Inc()
        return "", fmt.Errorf("failed to call Quarkus API: %w", err)
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != http.StatusOK {
        span.SetStatus(codes.Error, fmt.Sprintf("HTTP %d", resp.StatusCode))
        externalAPICallsTotal.WithLabelValues("quarkus", "error").Inc()
        bodyBytes, _ := io.ReadAll(resp.Body)
        return "", fmt.Errorf("Quarkus API returned status %d: %s", resp.StatusCode, string(bodyBytes))
    }
    
    var lolcatResp LolcatResponse
    if err := json.NewDecoder(resp.Body).Decode(&lolcatResp); err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        externalAPICallsTotal.WithLabelValues("quarkus", "error").Inc()
        return "", fmt.Errorf("failed to decode response: %w", err)
    }
    
    externalAPICallsTotal.WithLabelValues("quarkus", "success").Inc()
    
    return lolcatResp.Colorized, nil
}
```

#### Update handleFiglet to Support Lolcat
```go
func (s *Server) handleFiglet(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    ctx, span := s.tracer.Start(ctx, "handleFiglet")
    defer span.End()
    
    timer := prometheus.NewTimer(httpRequestDuration.WithLabelValues(r.Method, "/api/figlet"))
    defer timer.ObserveDuration()
    
    if r.Method != http.MethodPost {
        httpRequestsTotal.WithLabelValues(r.Method, "/api/figlet", "405").Inc()
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
        return
    }
    
    defer r.Body.Close()
    var req figletRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        httpRequestsTotal.WithLabelValues(r.Method, "/api/figlet", "400").Inc()
        http.Error(w, "invalid JSON payload", http.StatusBadRequest)
        return
    }
    
    if len(req.Names) == 0 {
        httpRequestsTotal.WithLabelValues(r.Method, "/api/figlet", "400").Inc()
        http.Error(w, "names must not be empty", http.StatusBadRequest)
        return
    }
    
    // Check if lolcat is requested
    useLolcat := r.URL.Query().Get("lolcat") == "true"
    span.SetAttributes(attribute.Bool("lolcat.enabled", useLolcat))
    
    var seed float64
    if useLolcat {
        // Fetch seed from Python API
        seedResp, err := s.fetchSeedFromPython(ctx)
        if err != nil {
            log.Printf("Failed to fetch seed from Python API: %v", err)
            // Continue without lolcat on error
            useLolcat = false
        } else {
            seed = seedResp.Seed
            span.SetAttributes(attribute.Float64("seed.value", seed))
        }
    }
    
    art := make([]figletArt, 0, len(req.Names))
    for _, raw := range req.Names {
        name := strings.TrimSpace(raw)
        if name == "" {
            httpRequestsTotal.WithLabelValues(r.Method, "/api/figlet", "400").Inc()
            http.Error(w, "names must not contain empty values", http.StatusBadRequest)
            return
        }
        
        fig := figure.NewFigure(name, "", false)
        figureText := fig.String()
        
        // Apply lolcat if requested
        if useLolcat {
            colorized, err := s.colorizeWithLolcat(ctx, figureText, seed)
            if err != nil {
                log.Printf("Failed to colorize with lolcat: %v", err)
                // Use plain figlet on error
                art = append(art, figletArt{Name: name, Figure: figureText})
            } else {
                art = append(art, figletArt{Name: name, Figure: colorized})
            }
        } else {
            art = append(art, figletArt{Name: name, Figure: figureText})
        }
    }
    
    httpRequestsTotal.WithLabelValues(r.Method, "/api/figlet", "200").Inc()
    w.Header().Set("Content-Type", "application/json")
    if err := json.NewEncoder(w).Encode(figletResponse{Art: art}); err != nil {
        http.Error(w, "failed to encode response", http.StatusInternalServerError)
    }
}
```

#### Add Proxy Endpoints
```go
func (s *Server) handleSeedProxy(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    ctx, span := s.tracer.Start(ctx, "handleSeedProxy")
    defer span.End()
    
    timer := prometheus.NewTimer(httpRequestDuration.WithLabelValues(r.Method, "/api/seed"))
    defer timer.ObserveDuration()
    
    if r.Method != http.MethodGet {
        httpRequestsTotal.WithLabelValues(r.Method, "/api/seed", "405").Inc()
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
        return
    }
    
    seedResp, err := s.fetchSeedFromPython(ctx)
    if err != nil {
        httpRequestsTotal.WithLabelValues(r.Method, "/api/seed", "502").Inc()
        http.Error(w, fmt.Sprintf("failed to fetch seed: %v", err), http.StatusBadGateway)
        return
    }
    
    httpRequestsTotal.WithLabelValues(r.Method, "/api/seed", "200").Inc()
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(seedResp)
}

func (s *Server) handleLolcatProxy(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    ctx, span := s.tracer.Start(ctx, "handleLolcatProxy")
    defer span.End()
    
    timer := prometheus.NewTimer(httpRequestDuration.WithLabelValues(r.Method, "/api/lolcat"))
    defer timer.ObserveDuration()
    
    if r.Method != http.MethodPost {
        httpRequestsTotal.WithLabelValues(r.Method, "/api/lolcat", "405").Inc()
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
        return
    }
    
    defer r.Body.Close()
    bodyBytes, err := io.ReadAll(r.Body)
    if err != nil {
        httpRequestsTotal.WithLabelValues(r.Method, "/api/lolcat", "400").Inc()
        http.Error(w, "failed to read request body", http.StatusBadRequest)
        return
    }
    
    var lolcatReq LolcatRequest
    if err := json.Unmarshal(bodyBytes, &lolcatReq); err != nil {
        httpRequestsTotal.WithLabelValues(r.Method, "/api/lolcat", "400").Inc()
        http.Error(w, "invalid JSON payload", http.StatusBadRequest)
        return
    }
    
    seed := 0.0
    if lolcatReq.Seed != nil {
        seed = *lolcatReq.Seed
    }
    
    colorized, err := s.colorizeWithLolcat(ctx, lolcatReq.Text, seed)
    if err != nil {
        httpRequestsTotal.WithLabelValues(r.Method, "/api/lolcat", "502").Inc()
        http.Error(w, fmt.Sprintf("failed to colorize: %v", err), http.StatusBadGateway)
        return
    }
    
    httpRequestsTotal.WithLabelValues(r.Method, "/api/lolcat", "200").Inc()
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(LolcatResponse{
        Original:  lolcatReq.Text,
        Colorized: colorized,
    })
}
```

---

### 2. Node.js Server Changes (node/src/server.js)

#### Update Server to Only Call Go API
```javascript
// Remove PYTHON_API_BASE and QUARKUS_API_BASE environment variables
const GO_API_BASE = process.env.GO_API_BASE || 'http://localhost:4001';

// Update background worker to only call Go API
async function backgroundWorker() {
  while (true) {
    try {
      stats.totalRequests++;
      
      // Get seed from Go API (which internally calls Python API)
      const seedResponse = await fetch(`${GO_API_BASE}/api/seed`);
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
    
    await new Promise(resolve => setTimeout(resolve, 100));
  }
}

// Remove Python and Quarkus proxy endpoints, keep only Go API proxies
// Update /api/figlet to pass lolcat parameter
app.post('/api/figlet', async (req, res) => {
  try {
    const useLolcat = req.query.lolcat === 'true' || req.body.useLolcat === true;
    const queryParams = useLolcat ? '?lolcat=true' : '';
    
    const response = await fetch(`${GO_API_BASE}/api/figlet${queryParams}`, {
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

// Add more custom metrics
const nameGenerationsTotal = new client.Counter({
  name: 'node_api_name_generations_total',
  help: 'Total number of name generation requests',
  registers: [register]
});

const figletGenerationsTotal = new client.Counter({
  name: 'node_api_figlet_generations_total',
  help: 'Total number of figlet generation requests',
  registers: [register]
});

// Update endpoints to increment metrics
app.get('/api/name', async (req, res) => {
  nameGenerationsTotal.inc();
  // ... rest of code
});

app.post('/api/figlet', async (req, res) => {
  figletGenerationsTotal.inc();
  // ... rest of code
});
```

---

### 3. Python API Changes (python/app.py)

#### Add More Metrics
```python
# Add more metrics
request_errors_counter = Counter(
    'seed_api_errors_total',
    'Total number of errors in seed API',
    ['error_type'],
    registry=metrics_registry
)

response_size_histogram = Histogram(
    'seed_api_response_size_bytes',
    'Size of API responses in bytes',
    registry=metrics_registry
)

active_requests_gauge = Gauge(
    'seed_api_active_requests',
    'Number of currently active requests',
    registry=metrics_registry
)

seed_value_histogram = Histogram(
    'seed_value_distribution',
    'Distribution of generated seed values',
    buckets=[0, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000],
    registry=metrics_registry
)

processing_delay_histogram = Histogram(
    'seed_processing_delay_seconds',
    'Simulated processing delay',
    registry=metrics_registry
)

# Add middleware to track active requests
@app.middleware("http")
async def track_active_requests(request, call_next):
    if request.url.path == "/api/seed":
        active_requests_gauge.inc()
    try:
        response = await call_next(request)
        return response
    finally:
        if request.url.path == "/api/seed":
            active_requests_gauge.dec()

# Update seed endpoint to track more metrics
@app.get("/api/seed")
async def get_seed():
    import time
    import asyncio
    
    seed_requests_counter.inc()
    
    try:
        with seed_generation_duration.time():
            delay = random.uniform(0.1, 5.0)
            processing_delay_histogram.observe(delay)
            await asyncio.sleep(delay)
            seed = random.uniform(0.0, 1000.0)
            seed_value_histogram.observe(seed)
        
        response = SeedResponse(
            seed=round(seed, 2),
            timestamp=time.time()
        )
        
        # Track response size
        import json
        response_json = json.dumps(response.dict())
        response_size_histogram.observe(len(response_json))
        
        return response
    except Exception as e:
        request_errors_counter.labels(error_type=type(e).__name__).inc()
        raise
```

---

### 4. Quarkus API Changes

#### Add Metrics and Health Check
Add to `src/main/resources/application.properties`:
```properties
quarkus.micrometer.enabled=true
quarkus.micrometer.export.prometheus.enabled=true
quarkus.micrometer.export.prometheus.path=/metrics

# Health check
quarkus.smallrye-health.root-path=/healthz
```

Update `LolcatResource.java` to add metrics:
```java
package com.github.cldmnky.lolcat;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.health.HealthCheck;
import org.eclipse.microprofile.health.HealthCheckResponse;
import org.eclipse.microprofile.health.Liveness;

@Path("/api/lolcat")
public class LolcatResource {

    @Inject
    MeterRegistry registry;
    
    private Counter colorizationsCounter;
    private Counter errorsCounter;
    private Timer colorizationTimer;
    
    @jakarta.annotation.PostConstruct
    void init() {
        colorizationsCounter = registry.counter("lolcat.colorizations.total");
        errorsCounter = registry.counter("lolcat.errors.total");
        colorizationTimer = registry.timer("lolcat.colorization.duration");
    }

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public LolcatResponse colorize(LolcatRequest request) {
        return colorizationTimer.record(() -> {
            try {
                if (request.text == null || request.text.isEmpty()) {
                    errorsCounter.increment();
                    throw new IllegalArgumentException("text must not be empty");
                }

                String colorized = LolcatColorizer.colorize(
                    request.text,
                    request.seed != null ? request.seed : 0.0,
                    request.spread != null ? request.spread : 3.0,
                    request.freq != null ? request.freq : 0.1
                );

                colorizationsCounter.increment();
                return new LolcatResponse(request.text, colorized);
            } catch (Exception e) {
                errorsCounter.increment();
                throw e;
            }
        });
    }
    
    @Liveness
    @GET
    @Path("/health")
    @Produces(MediaType.APPLICATION_JSON)
    public HealthCheck liveness() {
        return () -> HealthCheckResponse.up("lolcat-service");
    }
}
```

---

## Environment Variables

### Go API
```bash
PYTHON_API_BASE=http://python-api:4004
QUARKUS_API_BASE=http://quarkus-api:4003
OTEL_EXPORTER_OTLP_ENDPOINT=localhost:4318
```

### Node API
```bash
GO_API_BASE=http://go-api:4001
```

---

## Testing the Changes

1. **Start all services**:
```bash
# Terminal 1 - Python API
cd python && python app.py

# Terminal 2 - Quarkus API
cd quarkus && ./mvnw quarkus:dev

# Terminal 3 - Go API
cd go && go run cmd/api/main.go

# Terminal 4 - Node API
cd node && npm start
```

2. **Test the call chain**:
```bash
# Test seed endpoint (Go -> Python)
curl http://localhost:4001/api/seed

# Test name generation
curl http://localhost:4001/api/name?count=3

# Test figlet with lolcat (Go -> Python -> Quarkus)
curl -X POST http://localhost:4001/api/figlet?lolcat=true \
  -H "Content-Type: application/json" \
  -d '{"names": ["cool-penguin"]}'

# Test via Node API
curl http://localhost:4002/api/name?count=3

curl -X POST http://localhost:4002/api/figlet \
  -H "Content-Type: application/json" \
  -d '{"names": ["awesome-tiger"]}'
```

3. **Check metrics**:
```bash
curl http://localhost:4001/metrics  # Go API metrics
curl http://localhost:4002/metrics  # Node API metrics
curl http://localhost:4004/metrics  # Python API metrics
curl http://localhost:4003/metrics  # Quarkus API metrics
```

4. **Verify distributed tracing**:
   - Check that trace context is propagated through: Node → Go → Python/Quarkus
   - Look for trace IDs in logs and OpenTelemetry backend

---

## Summary

This refactor:
1. ✅ Simplifies the Node API to only call Go API
2. ✅ Centralizes service orchestration in Go API
3. ✅ Ensures proper distributed tracing with OpenTelemetry context propagation
4. ✅ Adds comprehensive metrics across all services
5. ✅ Makes the architecture more maintainable and observable
6. ✅ Preserves existing functionality while improving the service mesh pattern
