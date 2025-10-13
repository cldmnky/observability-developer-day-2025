# Go Manual Instrumentation - Quick Implementation Guide

## Current Situation
- Go auto-instrumentation v0.22.1 has a bug with version detection
- Error: "invalid semantic version" - this is a known upstream issue
- The tool cannot parse the Go module version information from the binary

## Recommended Solution: Manual Instrumentation

### Step 1: Update go.mod dependencies

```bash
cd go
go get go.opentelemetry.io/otel@v1.32.0
go get go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp@v1.32.0
go get go.opentelemetry.io/otel/sdk@v1.32.0
go get go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp@v0.57.0
```

### Step 2: Update main.go

```go
package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/cldmnky/observability-developer-day-2025/go/pkg/api"
	"github.com/cldmnky/observability-developer-day-2025/go/pkg/namer"
	
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.4.0"
)

// Version information
var (
	Version   = "1.0.0"
	GitCommit = "unknown"
	BuildDate = "unknown"
)

func initTracer(ctx context.Context) (*sdktrace.TracerProvider, error) {
	// Get OTLP endpoint from environment or use default
	endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if endpoint == "" {
		endpoint = "localhost:4318"
	}

	// Create OTLP trace exporter
	exporter, err := otlptracehttp.New(ctx,
		otlptracehttp.WithEndpoint(endpoint),
		otlptracehttp.WithInsecure(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create trace exporter: %w", err)
	}

	// Create resource with service information
	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceNameKey.String("go-api"),
			semconv.ServiceVersionKey.String(Version),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create resource: %w", err)
	}

	// Create trace provider
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
	)

	// Set global trace provider
	otel.SetTracerProvider(tp)
	
	// Set global propagator
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	return tp, nil
}

func main() {
	log.Printf("Starting Go API - Version: %s, Commit: %s, Built: %s", Version, GitCommit, BuildDate)
	
	// Initialize OpenTelemetry tracing
	ctx := context.Background()
	tp, err := initTracer(ctx)
	if err != nil {
		log.Fatalf("failed to initialize tracer: %v", err)
	}
	defer func() {
		if err := tp.Shutdown(ctx); err != nil {
			log.Printf("error shutting down tracer provider: %v", err)
		}
	}()

	generator := namer.MustNewDefault()
	server := api.NewServer(generator)

	port := os.Getenv("PORT")
	if port == "" {
		port = "4001"
	}

	addr := fmt.Sprintf(":%s", port)

	// Wrap the server with OpenTelemetry HTTP instrumentation
	httpServer := &http.Server{
		Addr:    addr,
		Handler: otelhttp.NewHandler(server, "go-api"),
	}

	go func() {
		log.Printf("starting name generator API on %s", addr)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	shutdown(httpServer)
}

func shutdown(server *http.Server) {
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)

	<-stop

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Printf("graceful shutdown failed: %v", err)
	}

	log.Println("server stopped")
}
```

### Step 3: Update go-api-deployment.yaml

Remove the Go auto-instrumentation annotation:

```yaml
    metadata:
      annotations:
        sidecar.opentelemetry.io/inject: sidecar
        # Remove this line - no longer using auto-instrumentation:
        # instrumentation.opentelemetry.io/inject-go: "demo-instrumentation"
        # instrumentation.opentelemetry.io/otel-go-auto-target-exe: "/app/api"
```

Add environment variable for OTLP endpoint:

```yaml
        env:
        - name: PORT
          value: "4001"
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "localhost:4318"  # Sidecar collector endpoint
```

### Step 4: Rebuild and Deploy

```bash
# Update dependencies
cd go && go mod tidy && cd ..

# Rebuild container
make container-build-go

# Push container
make container-push-go

# Restart deployment
oc rollout restart deployment/go-api -n observability-demo
```

## Why This Works

1. ✅ **Supported by Red Hat**: Manual instrumentation with official OpenTelemetry Go SDK
2. ✅ **Stable**: No dependency on Technology Preview auto-instrumentation
3. ✅ **Production Ready**: Used in production environments
4. ✅ **More Control**: Fine-grained control over what gets traced
5. ✅ **Works with Sidecar**: Still uses the sidecar collector pattern

## Alternative: Wait for Auto-Instrumentation Fix

The Go auto-instrumentation is **Technology Preview** and will be improved in future releases. For now, manual instrumentation is the recommended production approach.
