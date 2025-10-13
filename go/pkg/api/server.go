package api

import (
	"encoding/json"
	"hash/fnv"
	"math/rand"
	"net/http"
	"strconv"
	"strings"
	"time"

	figure "github.com/common-nighthawk/go-figure"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	"github.com/cldmnky/observability-developer-day-2025/go/data"
	"github.com/cldmnky/observability-developer-day-2025/go/pkg/namer"
)

func init() {
	// Initialize random seed for error generation
	rand.Seed(time.Now().UnixNano())
}

type NameGenerator interface {
	Name() namer.Name
	Names(count int) []namer.Name
}

type Server struct {
	generator    NameGenerator
	newGenerator func(seed int64) (NameGenerator, error)
	mux          *http.ServeMux
	maxCount     int
}

func NewServer(generator NameGenerator) *Server {
	s := &Server{
		generator:    generator,
		newGenerator: defaultSeededGenerator,
		mux:          http.NewServeMux(),
		maxCount:     50,
	}

	s.mux.HandleFunc("/healthz", s.handleHealth)
	s.mux.HandleFunc("/api/name", s.handleName)
	s.mux.HandleFunc("/api/figlet", s.handleFiglet)
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

func (s *Server) handleName(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Simulate random failures (~5% of requests) for observability testing
	if rand.Float64() < 0.05 {
		http.Error(w, "internal service error: temporary name generation failure", http.StatusInternalServerError)
		return
	}

	count := 1
	if raw := r.URL.Query().Get("count"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed <= 0 {
			http.Error(w, "count must be a positive integer", http.StatusBadRequest)
			return
		}
		if parsed > s.maxCount {
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
			http.Error(w, "failed to create seeded generator", http.StatusInternalServerError)
			return
		}

		names = seededGenerator.Names(count)
	} else {
		names = s.generator.Names(count)
	}

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
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	defer r.Body.Close()
	var req figletRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid JSON payload", http.StatusBadRequest)
		return
	}

	if len(req.Names) == 0 {
		http.Error(w, "names must not be empty", http.StatusBadRequest)
		return
	}

	art := make([]figletArt, 0, len(req.Names))
	for _, raw := range req.Names {
		name := strings.TrimSpace(raw)
		if name == "" {
			http.Error(w, "names must not contain empty values", http.StatusBadRequest)
			return
		}
		fig := figure.NewFigure(name, "", false)
		art = append(art, figletArt{Name: name, Figure: fig.String()})
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(figletResponse{Art: art}); err != nil {
		http.Error(w, "failed to encode response", http.StatusInternalServerError)
	}
}
