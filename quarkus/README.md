# Quarkus Lolcat API

A Quarkus-based REST API that applies rainbow lolcat styling to text using ANSI escape codes.

## Features

- Rainbow colorization using sine wave RGB calculation
- Supports custom seed, spread, and frequency parameters
- CORS enabled for browser integration
- Fast startup with Quarkus

## Building

```bash
cd quarkus
mvn clean package
```

## Running

### Development mode (with hot reload)
```bash
mvn quarkus:dev
```

### Production mode
```bash
java -jar target/quarkus-app/quarkus-run.jar
```

The API will start on `http://localhost:8081`

## API Endpoints

### POST /api/lolcat

Applies rainbow lolcat styling to input text.

**Request:**
```json
{
  "text": "Hello World",
  "seed": 0.0,
  "spread": 3.0,
  "freq": 0.1
}
```

**Parameters:**
- `text` (required): The text to colorize
- `seed` (optional, default: 0.0): Starting position for rainbow effect
- `spread` (optional, default: 3.0): Color variation intensity
- `freq` (optional, default: 0.1): Rainbow frequency (lower = wider color bands)

**Response:**
```json
{
  "original": "Hello World",
  "colorized": "\u001b[38;2;255;0;0mH\u001b[0m\u001b[38;2;255;85;0me\u001b[0m..."
}
```

**Example with curl:**
```bash
curl -X POST http://localhost:8081/api/lolcat \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello World"}'
```

**Example with figlet ASCII art:**
```bash
curl -X POST http://localhost:8081/api/lolcat \
  -H "Content-Type: application/json" \
  -d '{"text": "  _   _      _ _       \n | | | | ___| | | ___  \n | |_| |/ _ \\ | |/ _ \\ \n |  _  |  __/ | | (_) |\n |_| |_|\\___|_|_|\\___/ "}'
```

## Integration with Frontend

The Node.js frontend can call this API to colorize ASCII figlet art:

```javascript
const response = await fetch('http://localhost:8081/api/lolcat', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ text: asciiArt })
});
const data = await response.json();
// data.colorized contains the rainbow-colored text
```

## Running Tests

```bash
mvn test
```

## Configuration

Edit `src/main/resources/application.properties` to customize:
- Port number
- CORS settings
- Logging levels
