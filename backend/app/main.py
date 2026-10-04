import time
from collections import defaultdict
from contextlib import asynccontextmanager
from typing import Dict, List

from fastapi import FastAPI, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1.router import api_router
from app.core.config import settings
from app.db.session import create_tables

# Simple in-memory sliding window rate limiter
_request_records: Dict[str, List[float]] = defaultdict(list)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: ensure tables are created
    create_tables()
    yield
    # Shutdown logic if needed


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Privacy-preserving backend services for Bucket Goal-Based UPI Wallet.",
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan,
)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def security_and_rate_limit_middleware(request: Request, call_next):
    # Rate Limiting Check
    client_ip = request.client.host if request.client else "127.0.0.1"
    now = time.time()
    window_start = now - 60.0

    # Prune expired timestamps
    _request_records[client_ip] = [
        t for t in _request_records[client_ip] if t > window_start
    ]

    # Exclude openapi/docs and health check from strict rate limiting
    path = request.url.path
    if not (path.startswith("/docs") or path.startswith("/openapi") or path.endswith("/health")):
        if len(_request_records[client_ip]) >= settings.RATE_LIMIT_REQUESTS_PER_MINUTE:
            return JSONResponse(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                content={"detail": "Rate limit exceeded. Please try again later."},
                headers={"Retry-After": "60"},
            )
        _request_records[client_ip].append(now)

    response: Response = await call_next(request)

    # Security Headers
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate"

    return response


app.include_router(api_router, prefix=settings.API_V1_STR)


@app.get("/")
async def root():
    return {
        "message": "Welcome to Bucket API",
        "docs": "/docs",
        "health": f"{settings.API_V1_STR}/health",
        "version": settings.VERSION,
    }
