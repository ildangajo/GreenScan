from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import analysis, auth, calculate, diagnoses, favorites, map as map_routes, reference
from app.core.config import settings

from app.api.routes.health import router as health_router

app = FastAPI(title="GreenScan API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in settings.cors_allow_origins.split(",")],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(analysis.router, prefix="/api/v1")
app.include_router(auth.router, prefix="/api/v1")
app.include_router(reference.router, prefix="/api/v1")
app.include_router(diagnoses.router, prefix="/api/v1")
app.include_router(calculate.router, prefix="/api/v1")
app.include_router(favorites.router, prefix="/api/v1")
app.include_router(map_routes.router, prefix="/api/v1")


app.include_router(health_router)
