# Go Name Generator API

This Go service exposes an HTTP API that returns whimsical adjective + animal combinations powered by the CSV word lists in `go/data/`.

## Features

- `GET /healthz` — lightweight health probe returning `{ "status": "ok" }`.
- `GET /api/name` — returns one or more randomly generated names. Use the optional `count` query parameter (max 50) to request multiple results at once. Provide a string `seed` query parameter to make the response deterministic.
- `POST /api/figlet` — accepts a JSON payload of names and returns ASCII art renderings using [`go-figure`](https://github.com/common-nighthawk/go-figure).

Example response:

```json
{
  "names": [
    {
      "adjective": "agile",
      "animal": "Albatross",
      "combined": "agile-albatross"
    }
  ]
}
```

Deterministic request example:

```bash
curl "http://localhost:8080/api/name?count=2&seed=favorite-seed"
```

Figlet request example:

```bash
curl -X POST "http://localhost:8080/api/figlet" \
  -H "Content-Type: application/json" \
  -d '{"names":["agile-albatross"]}'
```

## Run the API

From the repository root:

```bash
cd go
go run ./cmd/api
```

Set the `PORT` environment variable to change the listening port (defaults to `8080`).

## Test

Run the test suite:

```bash
go test ./...
```

## Implementation Notes

- Word lists are embedded at build time with `//go:embed`, so no extra file I/O is required at runtime.
- Name generation is thread-safe and deterministic when a seed is provided.
- The API enforces a sensible maximum batch size and returns helpful error messages for invalid requests.
