# Python Seed Generator Service

A FastAPI-based service that generates random seed values for lolcat colorization.

## Features

- FastAPI framework for high performance
- Random seed generation (0.0 - 1000.0)
- Health check endpoint
- CORS enabled for cross-origin requests
- Configurable port via PORT environment variable

## Endpoints

- `GET /` - API information and available endpoints
- `GET /healthz` - Health check endpoint
- `GET /api/seed` - Generate a random seed value

## Running Locally

```bash
# Install dependencies
pip install -r requirements.txt

# Run the service (default port 4004)
python app.py

# Or with custom port
PORT=8000 python app.py
```

## API Response Example

```json
{
  "seed": 742.15,
  "timestamp": 1697213456.789
}
```

## Configuration

- `PORT` - Server port (default: 4004)

## Development

```bash
# Run with auto-reload
uvicorn app:app --reload --port 4004
```
