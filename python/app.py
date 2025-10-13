"""
Python Seed Generator Service
Provides seed values for lolcat colorization
"""
import os
import random
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

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
    """
    import time
    seed = random.uniform(0.0, 1000.0)
    return SeedResponse(
        seed=round(seed, 2),
        timestamp=time.time()
    )

if __name__ == "__main__":
    port = int(os.getenv("PORT", "4004"))
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=port,
        log_level="info"
    )
