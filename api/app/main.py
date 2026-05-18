from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import httpx

from .config import settings
from .routers import health, workflows

app = FastAPI(
    title="AIOS Foundry Vending — Admin API",
    description="FastAPI middleware that triggers GitHub Actions workflows for Foundry project provisioning across AMR, EMEA, and APAC hubs.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(workflows.router)


@app.exception_handler(httpx.HTTPStatusError)
async def http_status_error_handler(request: Request, exc: httpx.HTTPStatusError):
    return JSONResponse(
        status_code=502,
        content={
            "detail": f"Upstream GitHub error: {exc.response.status_code}",
            "github_error": exc.response.text,
        },
    )
