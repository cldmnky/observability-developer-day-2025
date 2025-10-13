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
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

// Version information set by ldflags during build
// Required for OpenTelemetry Go auto-instrumentation
var (
	Version   = "dev"
	GitCommit = "unknown"
	BuildDate = "unknown"
)

// initTracer initializes OpenTelemetry tracing with OTLP HTTP exporter
func initTracer(ctx context.Context) (*sdktrace.TracerProvider, error) {
	// Get OTLP endpoint from environment or use default (sidecar collector)
	endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if endpoint == "" {
		endpoint = "localhost:4318"
	}

	log.Printf("Initializing OpenTelemetry with endpoint: %s", endpoint)

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

	// Set global propagator for distributed tracing
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	log.Println("OpenTelemetry tracing initialized successfully")
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
