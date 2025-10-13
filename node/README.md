# Node Web App

A beautiful web application with a browser-based terminal that queries the Go name generator API and renders ASCII art in real-time.

## Prerequisites

- Node.js **18+** (for native `fetch` and ES modules)
- The Go API running locally on `http://localhost:8080`
- _(Optional)_ The Quarkus lolcat API running on `http://localhost:8081` for rainbow colorization

## Install

From the `node/` directory:

```bash
npm install
```

## Run

```bash
npm start
```

The web app will start on **http://localhost:3000**

Override the port:

```bash
PORT=4000 npm start
```

## Test

```bash
npm test
```

## Features

- 🎨 **Beautiful UI** – Gradient background with glassmorphism design
- 💻 **Browser Terminal** – Powered by [xterm.js](https://xtermjs.org/)
- 🎲 **Configurable Generation** – Set count and optional seed for deterministic results
- ⚡ **Real-time Updates** – Watch ASCII art render in the terminal as it's fetched
- 🌈 **Syntax Highlighting** – Color-coded terminal output for better readability
- 🦄 **Lolcat Integration** – Optional rainbow colorization using the Quarkus lolcat API

## How it works

1. User configures count and optional seed in the web UI
2. User can optionally enable "Use Lolcat Colors" checkbox for rainbow colorization
3. Browser sends requests to the Node.js server (all requests go through the proxy)
4. Node.js server proxies requests to the appropriate backend services:
   - `/api/name` → Go API (`http://localhost:8080/api/name`)
   - `/api/figlet` → Go API (`http://localhost:8080/api/figlet`)
   - `/api/lolcat` → Quarkus API (`http://localhost:8081/api/lolcat`)
5. Responses are sent back through the Node.js proxy to the browser
6. ASCII art responses are rendered in the xterm.js terminal with colors and styling

**Benefits of the proxy architecture:**

- No CORS issues - all requests are same-origin
- Backend services can be on different hosts/ports without browser restrictions
- Centralized error handling and logging
- Can add authentication, rate limiting, or other middleware easily

## Architecture

- **Express.js** – Serves the static web app and acts as an API proxy
- **xterm.js** – Browser terminal emulator
- **Vanilla JS** – No build step, runs directly in the browser
- **Proxy Endpoints** – All backend API calls are proxied through the Node.js server
