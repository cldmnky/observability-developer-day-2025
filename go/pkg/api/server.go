package api

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"hash/fnv"
	"io"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	figure "github.com/common-nighthawk/go-figure"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"

	"github.com/cldmnky/observability-developer-day-2025/go/data"
	"github.com/cldmnky/observability-developer-day-2025/go/pkg/namer"
)

func init() {
	// Initialize random seed for error generation
	rand.Seed(time.Now().UnixNano())
}

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
			Name:    "go_api_http_request_duration_seconds",
			Help:    "Duration of HTTP requests in seconds",
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
			Name:    "go_api_external_call_duration_seconds",
			Help:    "Duration of external API calls in seconds",
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

type NameGenerator interface {
	Name() namer.Name
	Names(count int) []namer.Name
}

type Server struct {
	generator      NameGenerator
	newGenerator   func(seed int64) (NameGenerator, error)
	mux            *http.ServeMux
	maxCount       int
	httpClient     *http.Client
	pythonAPIBase  string
	quarkusAPIBase string
	tracer         trace.Tracer
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
		Timeout:   30 * time.Second,
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

func (s *Server) Handler() http.Handler {
	return s.mux
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// Enable CORS for web clients
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	// Handle preflight requests
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	s.mux.ServeHTTP(w, r)
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"ok"}`))
}

// fetchSeedFromPython fetches a seed value from the Python API with proper tracing
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

// colorizeWithLolcat sends text to Quarkus API for lolcat colorization with proper tracing
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

type namesResponse struct {
	Names []namer.Name `json:"names"`
}

type figletRequest struct {
	Names []string `json:"names"`
}

type figletArt struct {
	Name   string `json:"name"`
	Figure string `json:"figure"`
}

type figletResponse struct {
	Art []figletArt `json:"art"`
}

// SeedResponse represents the response from Python seed API
type SeedResponse struct {
	Seed      float64 `json:"seed"`
	Timestamp float64 `json:"timestamp"`
}

// LolcatRequest represents a request to the Quarkus lolcat API
type LolcatRequest struct {
	Text   string   `json:"text"`
	Seed   *float64 `json:"seed,omitempty"`
	Spread *float64 `json:"spread,omitempty"`
	Freq   *float64 `json:"freq,omitempty"`
}

// LolcatResponse represents a response from the Quarkus lolcat API
type LolcatResponse struct {
	Original  string `json:"original"`
	Colorized string `json:"colorized"`
}

func (s *Server) handleName(w http.ResponseWriter, r *http.Request) {
	timer := prometheus.NewTimer(httpRequestDuration.WithLabelValues(r.Method, "/api/name"))
	defer timer.ObserveDuration()

	if r.Method != http.MethodGet {
		httpRequestsTotal.WithLabelValues(r.Method, "/api/name", "405").Inc()
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Simulate random failures (~5% of requests) for observability testing
	if rand.Float64() < 0.05 {
		httpRequestsTotal.WithLabelValues(r.Method, "/api/name", "500").Inc()
		http.Error(w, "internal service error: temporary name generation failure", http.StatusInternalServerError)
		return
	}

	count := 1
	if raw := r.URL.Query().Get("count"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed <= 0 {
			httpRequestsTotal.WithLabelValues(r.Method, "/api/name", "400").Inc()
			http.Error(w, "count must be a positive integer", http.StatusBadRequest)
			return
		}
		if parsed > s.maxCount {
			httpRequestsTotal.WithLabelValues(r.Method, "/api/name", "400").Inc()
			http.Error(w, "count exceeds maximum", http.StatusBadRequest)
			return
		}
		count = parsed
	}

	seedParam := r.URL.Query().Get("seed")
	var names []namer.Name

	if seedParam != "" {
		seededGenerator, err := s.newGenerator(seedStringToInt64(seedParam))
		if err != nil {
			httpRequestsTotal.WithLabelValues(r.Method, "/api/name", "500").Inc()
			http.Error(w, "failed to create seeded generator", http.StatusInternalServerError)
			return
		}

		names = seededGenerator.Names(count)
	} else {
		names = s.generator.Names(count)
	}

	httpRequestsTotal.WithLabelValues(r.Method, "/api/name", "200").Inc()
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(namesResponse{Names: names}); err != nil {
		http.Error(w, "failed to encode response", http.StatusInternalServerError)
	}
}

func defaultSeededGenerator(seed int64) (NameGenerator, error) {
	return namer.NewGenerator(data.Adjectives(), data.Animals(), seed)
}

func seedStringToInt64(seed string) int64 {
	h := fnv.New64a()
	_, _ = h.Write([]byte(seed))
	return int64(h.Sum64())
}

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

// handleSeedProxy proxies seed requests to Python API
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

// handleLolcatProxy proxies lolcat colorization requests to Quarkus API
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
