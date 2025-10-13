package data

import (
	"encoding/csv"
	"fmt"
	"strings"

	_ "embed"
)

//go:embed adjectives.csv
var adjectivesCSV string

//go:embed animals.csv
var animalsCSV string

var (
	adjectives []string
	animals    []string
)

func init() {
	var err error

	if adjectives, err = parseCSVColumn(adjectivesCSV, "adjective"); err != nil {
		panic(fmt.Errorf("failed to parse adjectives.csv: %w", err))
	}

	if animals, err = parseCSVColumn(animalsCSV, "name"); err != nil {
		panic(fmt.Errorf("failed to parse animals.csv: %w", err))
	}
}

func parseCSVColumn(data string, column string) ([]string, error) {
	reader := csv.NewReader(strings.NewReader(data))
	reader.TrimLeadingSpace = true

	records, err := reader.ReadAll()
	if err != nil {
		return nil, err
	}

	if len(records) == 0 {
		return nil, fmt.Errorf("csv has no records")
	}

	header := records[0]
	columnIndex := -1
	for i, name := range header {
		if strings.EqualFold(name, column) {
			columnIndex = i
			break
		}
	}

	if columnIndex == -1 {
		return nil, fmt.Errorf("column %q not found", column)
	}

	result := make([]string, 0, len(records)-1)
	for _, row := range records[1:] {
		if columnIndex >= len(row) {
			continue
		}
		value := strings.TrimSpace(row[columnIndex])
		if value == "" {
			continue
		}
		result = append(result, value)
	}

	if len(result) == 0 {
		return nil, fmt.Errorf("no data found in column %q", column)
	}

	return result, nil
}

func Adjectives() []string {
	out := make([]string, len(adjectives))
	copy(out, adjectives)
	return out
}

func Animals() []string {
	out := make([]string, len(animals))
	copy(out, animals)
	return out
}
