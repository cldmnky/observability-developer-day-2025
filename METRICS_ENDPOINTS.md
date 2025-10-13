# Prometheus Metrics Endpoints

This document describes the `/metrics` endpoints that have been added to all four applications.

## Overview

All applications now expose Prometheus-compatible metrics at the `/metrics` endpoint. These endpoints can be scraped by Prometheus or other monitoring tools for observability.

## Applications

### 1. Go Application (Port 4001)

**Endpoint:** `http://localhost:4001/metrics`

**Implementation:**
- Uses `github.com/prometheus/client_golang/prometheus/promhttp`
- Added to `go/pkg/api/server.go`
- Provides default Go metrics (goroutines, memory, GC stats, etc.)

**Dependencies Added:**
```go
github.com/prometheus/client_golang v1.23.2
```

**Usage:**
```bash
curl http://localhost:4001/metrics
```

---

### 2. Node.js Application (Port 4002)

**Endpoint:** `http://localhost:4002/metrics`

**Implementation:**
- Uses `prom-client` library
- Added to `node/src/server.js`
- Collects default Node.js metrics (CPU, memory, event loop, etc.)
- Custom metrics:
  - `http_request_duration_seconds` - Histogram for HTTP request durations
  - `worker_requests_total` - Counter for background worker requests with labels (status: success/failed/error)

**Dependencies Added:**
```json
"prom-client": "^15.1.3"
```

**Usage:**
```bash
curl http://localhost:4002/metrics
```

---

### 3. Python Application (Port 4004)

**Endpoint:** `http://localhost:4004/metrics`

**Implementation:**
- Uses `prometheus_client` library
- Added to `python/app.py`
- Provides default Python metrics (process stats, etc.)
- Custom metrics:
  - `seed_requests_total` - Counter for total seed generation requests
  - `seed_generation_duration_seconds` - Histogram for seed generation time

**Dependencies Added:**
```txt
prometheus-client==0.21.0
```

**Usage:**
```bash
curl http://localhost:4004/metrics
```

---

### 4. Quarkus Application (Port 4003)

**Endpoint:** `http://localhost:4003/metrics`

**Implementation:**
- Uses Quarkus Micrometer with Prometheus registry
- Added dependency in `quarkus/pom.xml`
- Configured in `quarkus/src/main/resources/application.properties`
- Provides JVM metrics, HTTP metrics, and more

**Dependencies Added:**
```xml
<dependency>
  <groupId>io.quarkus</groupId>
  <artifactId>quarkus-micrometer-registry-prometheus</artifactId>
</dependency>
```

**Configuration Added:**
```properties
quarkus.micrometer.export.prometheus.enabled=true
quarkus.micrometer.export.prometheus.path=/metrics
```

**Usage:**
```bash
curl http://localhost:4003/metrics
```

---

## Testing All Endpoints

You can verify all metrics endpoints are working with these commands:

```bash
# Go API
curl http://localhost:4001/metrics | head -20

# Node.js API
curl http://localhost:4002/metrics | head -20

# Quarkus API
curl http://localhost:4003/metrics | head -20

# Python API
curl http://localhost:4004/metrics | head -20
```

## Prometheus Configuration Example

To scrape these metrics with Prometheus, add the following to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'go-api'
    static_configs:
      - targets: ['localhost:4001']
    metrics_path: '/metrics'

  - job_name: 'node-api'
    static_configs:
      - targets: ['localhost:4002']
    metrics_path: '/metrics'

  - job_name: 'quarkus-api'
    static_configs:
      - targets: ['localhost:4003']
    metrics_path: '/metrics'

  - job_name: 'python-api'
    static_configs:
      - targets: ['localhost:4004']
    metrics_path: '/metrics'
```

## Next Steps

1. **Install dependencies:**
   ```bash
   # Python
   cd python && pip install -r requirements.txt
   
   # Node.js (already installed)
   cd node && npm install
   
   # Quarkus
   cd quarkus && mvn clean install
   
   # Go (already installed)
   cd go && go mod download
   ```

2. **Start all services** and verify metrics endpoints are accessible

3. **Set up Prometheus** to scrape these endpoints for monitoring

4. **Optional:** Add Grafana dashboards to visualize the metrics
