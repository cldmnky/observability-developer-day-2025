"""
Python Seed Generator Service
Provides seed values for lolcat colorization
"""
import os
import random
from fastapi import FastAPI, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST, CollectorRegistry

# Create a custom registry to avoid conflicts
metrics_registry = CollectorRegistry()

app = FastAPI(
    title="Seed Generator API",
    description="Generates seed values for lolcat colorization",
    version="1.0.0"
)

# Enable CORS for Node.js app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Prometheus metrics
seed_requests_counter = Counter(
    'seed_requests_total', 
    'Total number of seed generation requests',
    registry=metrics_registry
)
seed_generation_duration = Histogram(
    'seed_generation_duration_seconds',
    'Time spent generating seeds',
    registry=metrics_registry
)
request_errors_counter = Counter(
    'seed_api_errors_total',
    'Total number of errors in seed API',
    ['error_type'],
    registry=metrics_registry
)
response_size_histogram = Histogram(
    'seed_api_response_size_bytes',
    'Size of API responses in bytes',
    registry=metrics_registry
)
active_requests_gauge = Gauge(
    'seed_api_active_requests',
    'Number of currently active requests',
    registry=metrics_registry
)
seed_value_histogram = Histogram(
    'seed_value_distribution',
    'Distribution of generated seed values',
    buckets=[0, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000],
    registry=metrics_registry
)
processing_delay_histogram = Histogram(
    'seed_processing_delay_seconds',
    'Simulated processing delay',
    registry=metrics_registry
)

class SeedResponse(BaseModel):
    seed: float
    timestamp: float

# Middleware to track active requests
@app.middleware("http")
async def track_active_requests(request, call_next):
    if request.url.path == "/api/seed":
        active_requests_gauge.inc()
    try:
        response = await call_next(request)
        return response
    finally:
        if request.url.path == "/api/seed":
            active_requests_gauge.dec()

@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "service": "Seed Generator API",
        "version": "1.0.0",
        "endpoints": {
            "/api/seed": "Get a random seed value",
            "/healthz": "Health check endpoint"
        }
    }

@app.get("/healthz")
async def healthz():
    """Health check endpoint"""
    return {"status": "ok"}

@app.get("/api/seed")
async def get_seed():
    """
    Generate a random seed value for lolcat colorization
    Returns a seed between 0.0 and 1000.0
    Simulates processing delay between 0.1s and 5s
    """
    import time
    import asyncio
    import json
    
    seed_requests_counter.inc()
    
    try:
        # Add random delay to simulate processing time
        with seed_generation_duration.time():
            delay = random.uniform(0.1, 5.0)
            processing_delay_histogram.observe(delay)
            await asyncio.sleep(delay)
            seed = random.uniform(0.0, 1000.0)
            seed_value_histogram.observe(seed)
        
        response = SeedResponse(
            seed=round(seed, 2),
            timestamp=time.time()
        )
        
        # Track response size
        response_json = json.dumps(response.dict())
        response_size_histogram.observe(len(response_json))
        
        return response
    except Exception as e:
        request_errors_counter.labels(error_type=type(e).__name__).inc()
        raise

@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(content=generate_latest(metrics_registry), media_type=CONTENT_TYPE_LATEST)

if __name__ == "__main__":
    port = int(os.getenv("PORT", "4004"))
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=port,
        log_level="info"
    )
