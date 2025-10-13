package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"

	"github.com/cldmnky/observability-developer-day-2025/go/pkg/namer"
)

type fakeGenerator struct {
	names []namer.Name
}

func (f *fakeGenerator) Name() namer.Name {
	if len(f.names) == 0 {
		return namer.Name{Adjective: "mock", Animal: "animal", Combined: "mock-animal"}
	}
	n := f.names[0]
	f.names = f.names[1:]
	return n
}

func (f *fakeGenerator) Names(count int) []namer.Name {
	if count <= 0 {
		return []namer.Name{}
	}
	result := make([]namer.Name, count)
	for i := 0; i < count; i++ {
		result[i] = f.Name()
	}
	return result
}

func TestHealthEndpoint(t *testing.T) {
	server := NewServer(&fakeGenerator{})

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rr := httptest.NewRecorder()

	server.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rr.Code)
	}
}

func TestNameEndpoint(t *testing.T) {
	generator := &fakeGenerator{names: []namer.Name{{Adjective: "Brave", Animal: "Badger", Combined: "brave-badger"}}}
	server := NewServer(generator)

	req := httptest.NewRequest(http.MethodGet, "/api/name?count=1", nil)
	rr := httptest.NewRecorder()

	server.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rr.Code)
	}

	var resp namesResponse
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if len(resp.Names) != 1 {
		t.Fatalf("expected 1 name, got %d", len(resp.Names))
	}
	if resp.Names[0].Combined != "brave-badger" {
		t.Fatalf("unexpected name: %#v", resp.Names[0])
	}
}

func TestNameEndpointInvalidCount(t *testing.T) {
	server := NewServer(&fakeGenerator{})

	req := httptest.NewRequest(http.MethodGet, "/api/name?count=-1", nil)
	rr := httptest.NewRecorder()

	server.ServeHTTP(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", rr.Code)
	}
}

func TestNameEndpointSeededDeterministic(t *testing.T) {
	server := NewServer(&fakeGenerator{})

	adjectives := []string{"Alpha", "Brisk"}
	animals := []string{"Cat", "Dog"}

	server.newGenerator = func(seed int64) (NameGenerator, error) {
		return namer.NewGenerator(adjectives, animals, seed)
	}

	seed := "my-seed"
	expectedGenerator, err := namer.NewGenerator(adjectives, animals, seedStringToInt64(seed))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	expected := expectedGenerator.Names(3)
	path := "/api/name?count=3&seed=" + seed

	for i := 0; i < 2; i++ {
		req := httptest.NewRequest(http.MethodGet, path, nil)
		rr := httptest.NewRecorder()

		server.ServeHTTP(rr, req)

		if rr.Code != http.StatusOK {
			t.Fatalf("expected status 200, got %d", rr.Code)
		}

		var resp namesResponse
		if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
			t.Fatalf("failed to decode response: %v", err)
		}

		if !reflect.DeepEqual(resp.Names, expected) {
			t.Fatalf("expected deterministic response, got %#v", resp.Names)
		}
	}
}

func TestNameEndpointDifferentSeeds(t *testing.T) {
	server := NewServer(&fakeGenerator{})

	adjectives := []string{"Alpha", "Brisk"}
	animals := []string{"Cat", "Dog"}

	server.newGenerator = func(seed int64) (NameGenerator, error) {
		return namer.NewGenerator(adjectives, animals, seed)
	}

	reqA := httptest.NewRequest(http.MethodGet, "/api/name?count=2&seed=seed-a", nil)
	rrA := httptest.NewRecorder()
	server.ServeHTTP(rrA, reqA)

	if rrA.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rrA.Code)
	}

	reqB := httptest.NewRequest(http.MethodGet, "/api/name?count=2&seed=seed-b", nil)
	rrB := httptest.NewRecorder()
	server.ServeHTTP(rrB, reqB)

	if rrB.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rrB.Code)
	}

	var respA, respB namesResponse
	if err := json.Unmarshal(rrA.Body.Bytes(), &respA); err != nil {
		t.Fatalf("failed to decode response A: %v", err)
	}
	if err := json.Unmarshal(rrB.Body.Bytes(), &respB); err != nil {
		t.Fatalf("failed to decode response B: %v", err)
	}

	if reflect.DeepEqual(respA.Names, respB.Names) {
		t.Fatalf("expected different seeds to produce different outputs")
	}
}

func TestFigletEndpointSuccess(t *testing.T) {
	server := NewServer(&fakeGenerator{})

	req := httptest.NewRequest(http.MethodPost, "/api/figlet", strings.NewReader(`{"names":["Agile Albatross"]}`))
	rr := httptest.NewRecorder()

	server.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rr.Code)
	}

	var resp figletResponse
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if len(resp.Art) != 1 {
		t.Fatalf("expected art for 1 name, got %d", len(resp.Art))
	}
	if resp.Art[0].Name != "Agile Albatross" {
		t.Fatalf("unexpected name: %q", resp.Art[0].Name)
	}
	if resp.Art[0].Figure == "" {
		t.Fatalf("expected figure to be populated")
	}
}

func TestFigletEndpointInvalidMethod(t *testing.T) {
	server := NewServer(&fakeGenerator{})

	req := httptest.NewRequest(http.MethodGet, "/api/figlet", nil)
	rr := httptest.NewRecorder()

	server.ServeHTTP(rr, req)

	if rr.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected status 405, got %d", rr.Code)
	}
}

func TestFigletEndpointInvalidPayload(t *testing.T) {
	server := NewServer(&fakeGenerator{})

	req := httptest.NewRequest(http.MethodPost, "/api/figlet", strings.NewReader(`{"names":[]}`))
	rr := httptest.NewRecorder()

	server.ServeHTTP(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", rr.Code)
	}
}

func TestFigletEndpointEmptyName(t *testing.T) {
	server := NewServer(&fakeGenerator{})

	req := httptest.NewRequest(http.MethodPost, "/api/figlet", strings.NewReader(`{"names":[" "]}`))
	rr := httptest.NewRecorder()

	server.ServeHTTP(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", rr.Code)
	}
}
