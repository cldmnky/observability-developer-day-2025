# Observability Developer Day 2025

A multi-service stack demonstration featuring Go, Node.js, and Quarkus (Java 21) services working together to generate and visualize rainbow-colored ASCII art.

## Architecture

- **Go Service** (port 8080) - Name generator API that creates whimsical adjective-animal combinations and ASCII art
- **Node.js Web UI** (port 3000) - Beautiful web interface with terminal emulator and optional lolcat colorization
- **Quarkus Service** (port 8081) - Lolcat colorization API that adds rainbow colors to text using ANSI codes

## Prerequisites

- **Go** 1.20+
- **Node.js** 18+
- **Java** 21 (installed at `/opt/homebrew/opt/openjdk@21`)
- **Maven** 3.8.8 (installed at `/opt/apache-maven-3.8.8`)
- **tmux** (optional, for running all services together)

### Installing Prerequisites

```bash
# macOS with Homebrew
brew install go node openjdk@21 tmux

# Install Maven 3.8.8 (if not already installed)
cd /tmp
curl -O https://archive.apache.org/dist/maven/maven-3/3.8.8/binaries/apache-maven-3.8.8-bin.tar.gz
tar xzf apache-maven-3.8.8-bin.tar.gz
sudo mv apache-maven-3.8.8 /opt
```

## Quick Start

### Using Make (Recommended)

```bash
# Install all dependencies
make install

# Start all services in development mode (requires tmux)
make dev

# Check service status
make status

# Stop all services
make stop
```

### Manual Start

```bash
# Terminal 1: Start Go service
cd go
PORT=8080 go run ./cmd/api

# Terminal 2: Start Quarkus service
cd quarkus
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
export PATH=/opt/apache-maven-3.8.8/bin:$PATH
mvn quarkus:dev

# Terminal 3: Start Node.js service
cd node
PORT=3000 npm start
```

## Makefile Commands

| Command | Description |
|---------|-------------|
| `make` or `make help` | Show available commands |
| `make install` | Install dependencies for all services |
| `make test` | Run tests for all services |
| `make dev` | Start all services in tmux (development mode) |
| `make start` | Alias for `make dev` |
| `make stop` | Stop all services |
| `make status` | Check if services are running |
| `make build` | Build all services |
| `make clean` | Clean build artifacts |
| `make demo` | Run a quick API demo |
| `make go-service` | Start only the Go service |
| `make node-service` | Start only the Node.js service |
| `make quarkus-service` | Start only the Quarkus service |

## Using tmux

When you run `make dev`, all services start in a tmux session named `observability-dev`:

```bash
# Attach to the tmux session
tmux attach -t observability-dev

# Detach from session (keep services running)
# Press: Ctrl+B, then D

# Kill the session (stop all services)
tmux kill-session -t observability-dev
# or
make stop
```

## Service Endpoints

Once all services are running:

- **Web UI**: http://localhost:3000 (check the "🌈 Use Lolcat Colors" checkbox to enable rainbow colorization!)
- **Go API**: http://localhost:8080
  - Health: `GET /healthz`
  - Generate names: `GET /api/name?count=3`
  - ASCII art: `POST /api/figlet`
- **Quarkus API**: http://localhost:8081
  - Colorize text: `POST /api/lolcat`
  - Health: `GET /q/health`

## Example API Calls

### Generate a random name

```bash
curl http://localhost:8080/api/name
```

### Generate multiple names with a seed

```bash
curl "http://localhost:8080/api/name?count=3&seed=demo"
```

### Create ASCII art

```bash
curl -X POST http://localhost:8080/api/figlet \
  -H "Content-Type: application/json" \
  -d '{"names":["happy-hippo"]}'
```

### Colorize text

```bash
curl -X POST http://localhost:8081/api/lolcat \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello World","seed":0.0,"spread":3.0,"freq":0.1}'
```

## Java 21 Upgrade

This project has been upgraded to Java 21 (LTS). Key changes:

- Updated `pom.xml` with `maven.compiler.release=21`
- Fixed dependency artifacts for Quarkus 3.17.3:
  - `quarkus-rest` (replaces `quarkus-resteasy-reactive`)
  - `quarkus-rest-jackson` (replaces `quarkus-resteasy-reactive-jackson`)
- Added `quarkus-vertx-http` for HTTP/CORS support
- Fixed test compatibility with Java 21's stricter null handling

## Development

### Running Tests

```bash
# Test all services
make test

# Test individual services
cd go && go test ./...
cd node && npm test
cd quarkus && mvn test
```

### Hot Reload

All services support hot reload in development mode:

- **Go**: Changes require restart
- **Node.js**: Automatic reload with nodemon
- **Quarkus**: Live coding enabled (instant reload)

## Configuration

### Environment Variables

```bash
# Change service ports
GO_PORT=8080 make go-service
NODE_PORT=3000 make node-service
QUARKUS_PORT=8081 make quarkus-service

# Or set them for all services
export GO_PORT=9000
export NODE_PORT=4000
export QUARKUS_PORT=9001
make dev
```

### Java/Maven Paths

Edit the Makefile if your Java or Maven installations are in different locations:

```makefile
JAVA_HOME ?= /opt/homebrew/opt/openjdk@21
MAVEN_PATH ?= /opt/apache-maven-3.8.8/bin
```

## Troubleshooting

### Port Already in Use

```bash
# Check what's running on a port
lsof -i :8080
lsof -i :3000
lsof -i :8081

# Kill a process on a port
kill -9 $(lsof -t -i:8080)
```

### Java Version Issues

```bash
# Verify Java 21 is installed
/opt/homebrew/opt/openjdk@21/bin/java -version

# Should output: openjdk version "21.0.x"
```

### Maven Issues

```bash
# Verify Maven 3.8.8 is installed
/opt/apache-maven-3.8.8/bin/mvn --version

# Clear Maven cache if needed
rm -rf ~/.m2/repository
```

### tmux Not Found

```bash
# Install tmux
brew install tmux

# Or run services manually in separate terminals
```

## Project Structure

```
.
├── Makefile              # Main build and run commands
├── README.md             # This file
├── go/                   # Go name generator service
│   ├── cmd/api/          # Main application
│   ├── data/             # Word lists (CSV)
│   └── pkg/              # Shared packages
├── node/                 # Node.js web frontend
│   ├── src/              # Source files
│   ├── public/           # Static assets
│   └── package.json      # Dependencies
└── quarkus/              # Quarkus lolcat service (Java 21)
    ├── src/              # Source code
    ├── pom.xml           # Maven configuration
    └── target/           # Build output
```

## License

See individual service directories for licensing information.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `make test`
5. Submit a pull request

## Learn More

- [Go Documentation](https://golang.org/doc/)
- [Node.js Documentation](https://nodejs.org/docs/)
- [Quarkus Documentation](https://quarkus.io/guides/)
- [Java 21 Features](https://openjdk.org/projects/jdk/21/)
