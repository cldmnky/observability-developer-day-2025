package namer

import (
	"fmt"
	"math/rand"
	"strings"
	"sync"
	"time"

	"github.com/cldmnky/observability-developer-day-2025/go/data"
)

type Name struct {
	Adjective string `json:"adjective"`
	Animal    string `json:"animal"`
	Combined  string `json:"combined"`
}

type Generator struct {
	adjectives []string
	animals    []string
	rnd        *rand.Rand
	mu         sync.Mutex
}

func NewGenerator(adjectives, animals []string, seed int64) (*Generator, error) {
	if len(adjectives) == 0 {
		return nil, fmt.Errorf("adjective list cannot be empty")
	}
	if len(animals) == 0 {
		return nil, fmt.Errorf("animal list cannot be empty")
	}

	adjCopy := make([]string, len(adjectives))
	copy(adjCopy, adjectives)

	animalCopy := make([]string, len(animals))
	copy(animalCopy, animals)

	if seed == 0 {
		seed = time.Now().UnixNano()
	}

	return &Generator{
		adjectives: adjCopy,
		animals:    animalCopy,
		rnd:        rand.New(rand.NewSource(seed)),
	}, nil
}

func MustNewDefault() *Generator {
	g, err := NewGenerator(data.Adjectives(), data.Animals(), 0)
	if err != nil {
		panic(err)
	}
	return g
}

func (g *Generator) Name() Name {
	g.mu.Lock()
	defer g.mu.Unlock()

	adjective := g.adjectives[g.rnd.Intn(len(g.adjectives))]
	animal := g.animals[g.rnd.Intn(len(g.animals))]

	return Name{
		Adjective: adjective,
		Animal:    animal,
		Combined:  formatCombined(adjective, animal),
	}
}

func (g *Generator) Names(count int) []Name {
	if count <= 0 {
		return []Name{}
	}

	result := make([]Name, count)
	for i := 0; i < count; i++ {
		result[i] = g.Name()
	}
	return result
}

func formatCombined(adjective, animal string) string {
	adjective = strings.ToLower(strings.ReplaceAll(adjective, " ", "-"))
	animal = strings.ToLower(strings.ReplaceAll(animal, " ", "-"))
	return fmt.Sprintf("%s-%s", adjective, animal)
}
