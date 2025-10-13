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
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST, CollectorRegistry

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

class SeedResponse(BaseModel):
    seed: float
    timestamp: float

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
    
    seed_requests_counter.inc()
    
    # Add random delay to simulate processing time
    with seed_generation_duration.time():
        delay = random.uniform(0.1, 5.0)
        await asyncio.sleep(delay)
        seed = random.uniform(0.0, 1000.0)
    
    return SeedResponse(
        seed=round(seed, 2),
        timestamp=time.time()
    )

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
