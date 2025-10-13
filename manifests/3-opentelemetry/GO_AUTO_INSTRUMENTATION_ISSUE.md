# Go Auto-Instrumentation Issue

## Problem
The Go application is not generating traces due to a limitation in the OpenTelemetry Go auto-instrumentation.

## Root Cause
The Go auto-instrumentation (v0.22.1) is failing with error:
```
"failed to create instrumentation","error":"invalid semantic version"
```

This occurs because the Go auto-instrumentation requires the Go binary to be built with proper semantic version information embedded. The current Go application binary doesn't have this metadata.

## Evidence
1. ✅ Annotation is correct: `instrumentation.opentelemetry.io/inject-go: "demo-instrumentation"`
2. ✅ Target executable annotation added: `instrumentation.opentelemetry.io/otel-go-auto-target-exe: "/app/api"`
3. ✅ SecurityContextConstraints created with SYS_PTRACE capability
4. ✅ Instrumentation sidecar is injecting and finding the process (PID: 62)
5. ❌ Auto-instrumentation fails due to missing version metadata in the binary

## Current Status
- **Node.js**: ✅ Traces working
- **Python**: ✅ Traces working  
- **Quarkus (Java)**: ✅ Traces working
- **Go**: ❌ Auto-instrumentation failing

## Solutions

### Option 1: Fix the Binary Build (Recommended)
Rebuild the Go application with version information:

```bash
# In the Containerfile.go-app or build process, add version flags:
go build -ldflags="-X main.Version=1.0.0" -o api ./cmd/api
```

Or use Go 1.18+ with build info:
```bash
go build -buildvcs=true -o api ./cmd/api
```

### Option 2: Use Manual Instrumentation
Add the OpenTelemetry Go SDK directly to the code (most reliable):

```go
// Add to go.mod:
// go.opentelemetry.io/otel v1.32.0
// go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp v1.32.0
// go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.57.0

// Update main.go to initialize tracing
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    "go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

func initTracer() {
    exporter, _ := otlptracehttp.New(context.Background(),
        otlptracehttp.WithEndpoint("localhost:4318"),
        otlptracehttp.WithInsecure(),
    )
    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
    )
    otel.SetTracerProvider(tp)
}

// Wrap HTTP server with otelhttp middleware
httpServer := &http.Server{
    Addr:    addr,
    Handler: otelhttp.NewHandler(server, "go-api"),
}
```

### Option 3: Wait for Auto-Instrumentation Fix
Go auto-instrumentation is **Technology Preview** in RHOSDT and has known limitations. A future version may fix this issue.

## Temporary Workaround
For now, to continue with the workshop/demo:
1. Accept that Go traces won't work with auto-instrumentation
2. Focus on the working languages (Node.js, Python, Java)
3. Add manual instrumentation to Go when time permits

## References
- Red Hat OpenTelemetry Go Auto-Instrumentation Docs: https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html-single/red_hat_build_of_opentelemetry/index#otel-configuration-of-go-auto-instrumentation_otel-configuration-of-instrumentation
- Go auto-instrumentation is Technology Preview only
- Known issue with semantic versioning requirements in Go auto-instrumentation v0.22.x
