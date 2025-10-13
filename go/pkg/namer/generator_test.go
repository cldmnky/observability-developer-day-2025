package namer

import "testing"

func TestNewGeneratorValidation(t *testing.T) {
	if _, err := NewGenerator([]string{}, []string{"fox"}, 1); err == nil {
		t.Fatal("expected error for empty adjective list")
	}
	if _, err := NewGenerator([]string{"quick"}, []string{}, 1); err == nil {
		t.Fatal("expected error for empty animal list")
	}
}

func TestDeterministicNames(t *testing.T) {
	adjectives := []string{"Quick", "Lazy"}
	animals := []string{"Fox", "Dog"}

	g1, err := NewGenerator(adjectives, animals, 42)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	g2, err := NewGenerator(adjectives, animals, 42)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	const n = 5
	names1 := g1.Names(n)
	names2 := g2.Names(n)

	for i := 0; i < n; i++ {
		if names1[i] != names2[i] {
			t.Fatalf("expected deterministic generator, mismatch at %d: %#v != %#v", i, names1[i], names2[i])
		}
		if names1[i].Combined == "" {
			t.Fatalf("expected combined name to be populated: %#v", names1[i])
		}
	}
}

func TestNamesCount(t *testing.T) {
	g, err := NewGenerator([]string{"Swift"}, []string{"Falcon"}, 1)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	names := g.Names(3)
	if len(names) != 3 {
		t.Fatalf("expected 3 names, got %d", len(names))
	}
	for _, name := range names {
		if name.Adjective == "" || name.Animal == "" || name.Combined == "" {
			t.Fatalf("expected all fields to be populated: %#v", name)
		}
	}

	if len(g.Names(0)) != 0 {
		t.Fatalf("expected empty slice for non-positive count")
	}
}
