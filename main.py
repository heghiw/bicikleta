"""Bike Rental & Redistribution Platform — FastAPI backend.

Start: uvicorn main:app --reload --port 8000
Docs:  http://localhost:8000/docs
Web:   http://localhost:8000/
"""
import os
import logging

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from database import engine
import models

from routers.auth_router import router as auth_router
from routers.users_router import router as users_router
from routers.bikes_router import router as bikes_router
from routers.rentals_router import router as rentals_router
from routers.delivery_router import router as delivery_router
from routers.shop_router import router as shop_router
from routers.location_router import router as location_router
from routers.gamification_router import router as gamification_router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="PedalShare API",
    description="Peer-to-peer bike rental & crowdsourced redistribution platform.",
    version="1.0.0",
)

UPLOAD_DIR = os.getenv("UPLOAD_DIR", "data/uploads")
FRONTEND_DIR = os.path.join(os.path.dirname(__file__), "frontend")
os.makedirs(UPLOAD_DIR, exist_ok=True)

app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

app.include_router(auth_router)
app.include_router(users_router)
app.include_router(bikes_router)
app.include_router(rentals_router)
app.include_router(delivery_router)
app.include_router(shop_router)
app.include_router(location_router)
app.include_router(gamification_router)


@app.get("/api/health", tags=["health"])
def health():
    return {"status": "ok", "service": "PedalShare"}


# Serve the web SPA for all non-API routes
if os.path.isdir(FRONTEND_DIR):
    app.mount("/static", StaticFiles(directory=FRONTEND_DIR), name="frontend_static")

    @app.get("/{full_path:path}", include_in_schema=False)
    def serve_spa(full_path: str):
        index = os.path.join(FRONTEND_DIR, "index.html")
        if os.path.isfile(index):
            return FileResponse(index)
        return {"detail": "frontend not built"}


logger.info("PedalShare backend started.")
