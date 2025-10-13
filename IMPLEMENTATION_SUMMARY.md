# Microservices Refactor - Implementation Summary

## Changes Overview

I've analyzed your codebase and prepared a comprehensive refactoring plan to restructure the API call chain. Here's what needs to be done:

## Current vs Target Architecture

**Current:** Frontend → Node API → Go/Python/Quarkus APIs (all called directly)

**Target:** Frontend → Node API → Go API → Python/Quarkus APIs

## Key Changes Required

### 1. **Go API (go/pkg/api/server.go)** - Major Changes

The Go API will become the central orchestrator:

- **Add HTTP Client with OpenTelemetry instrumentation** to make external calls while preserving trace context
- **Add new endpoints:**
  - `/api/seed` - Proxy to Python API for seed generation
  - `/api/lolcat` - Proxy to Quarkus API for colorization
- **Update `/api/figlet`** to optionally call Python for seed and Quarkus for colorization when `?lolcat=true` parameter is passed
- **Add comprehensive metrics:**
  - Request counters and duration histograms
  - External API call tracking
  - Seed fetch and lolcat call counters
- **Add helper methods:**
  - `fetchSeedFromPython(ctx)` - Gets seed from Python API with proper tracing
  - `colorizeWithLolcat(ctx, text, seed)` - Colorizes text via Quarkus API with proper tracing

**Tracing:** The Go app already has OpenTelemetry configured. The HTTP client will use `otelhttp.NewTransport()` which automatically propagates trace context via W3C Trace Context headers.

### 2. **Node.js API (node/src/server.js)** - Moderate Changes

Simplify to only call Go API:

- **Remove:** Direct proxy endpoints for Python (`/api/seed`) and Quarkus (`/api/lolcat`)
- **Keep:** Go API proxy endpoints for `/api/name` and `/api/figlet`
- **Update:** Background worker to fetch seeds via Go API instead of Python API directly
- **Add:** More custom metrics (name generations, figlet generations)
- **Update:** `/api/figlet` endpoint to pass `?lolcat=true` query parameter when lolcat is requested

### 3. **Python API (python/app.py)** - Minor Changes

Add more metrics for better observability:

- Request error counter (by error type)
- Response size histogram
- Active requests gauge
- Seed value distribution histogram
- Processing delay histogram
- Middleware to track active requests

### 4. **Quarkus API** - Minor Changes

Add metrics and health checks:

- Enable Micrometer metrics for Prometheus
- Add colorization counter
- Add error counter
- Add colorization duration timer
- Add liveness health check endpoint

## Distributed Tracing

The solution ensures proper span context propagation:

1. **Node.js** receives request from frontend (should have OpenTelemetry SDK configured)
2. **Go API** receives request with trace headers (already configured with `otelhttp.NewHandler`)
3. **Go API** makes calls to Python/Quarkus using `otelhttp.NewTransport` which:
   - Extracts trace context from incoming request
   - Creates child spans for outgoing requests
   - Injects trace headers into outgoing HTTP requests
4. **Python/Quarkus** should have OpenTelemetry instrumentation to continue the trace

## Implementation Steps

1. **Update Go API** (`go/pkg/api/server.go`)
   - Add all the metrics, HTTP client, and new methods
   - This is the most significant change

2. **Update Node.js API** (`node/src/server.js`)
   - Remove Python and Quarkus endpoints
   - Update worker and proxy logic

3. **Update Python API** (`python/app.py`)
   - Add enhanced metrics

4. **Update Quarkus API**
   - Add `application.properties` configuration
   - Update `LolcatResource.java` with metrics

5. **Test the chain**
   - Verify: Node → Go → Python (for seeds)
   - Verify: Node → Go → Quarkus (for lolcat)
   - Check distributed traces in your observability backend
   - Verify metrics in Prometheus

## Files to Modify

1. `/go/pkg/api/server.go` - Major rewrite with new functionality
2. `/node/src/server.js` - Simplify and redirect to Go API
3. `/python/app.py` - Add metrics
4. `/quarkus/src/main/resources/application.properties` - Add config
5. `/quarkus/src/main/java/com/github/cldmnky/lolcat/LolcatResource.java` - Add metrics

## Next Steps

Would you like me to:
1. Implement these changes directly in the code?
2. Start with a specific service (e.g., Go API first)?
3. Create a branch and implement all changes together?

The detailed implementation code for each change is available in `MICROSERVICES_REFACTOR_PLAN.md`.
