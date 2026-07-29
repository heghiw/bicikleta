"""Bike Rental & Redistribution Platform — FastAPI backend.

Start: uvicorn main:app --reload --port 8000
Docs:  http://localhost:8000/docs
Web:   http://localhost:8000/
"""
import os
import logging

from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from database import engine
from sqlalchemy import inspect, text
import models

from routers.auth_router import router as auth_router
from routers.users_router import router as users_router
from routers.bikes_router import router as bikes_router
from routers.rentals_router import router as rentals_router
from routers.delivery_router import router as delivery_router
from routers.shop_router import router as shop_router
from routers.location_router import router as location_router
from routers.gamification_router import router as gamification_router
from routers.tracker_router import router as tracker_router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

models.Base.metadata.create_all(bind=engine)
def _add_missing_columns(table, definitions):
    existing = {column["name"] for column in inspect(engine).get_columns(table)}
    with engine.begin() as connection:
        for name, definition in definitions.items():
            if name not in existing:
                connection.execute(text(f"ALTER TABLE {table} ADD COLUMN {name} {definition}"))


_add_missing_columns("bikes", {
    "lock_type": "VARCHAR(20) NOT NULL DEFAULT 'manual'",
    "lock_instructions": "TEXT",
    "smart_lock_provider": "VARCHAR(80)",
    "smart_lock_device_id": "VARCHAR(200)",
    "smart_lock_status": "VARCHAR(30) NOT NULL DEFAULT 'not_connected'",
    "qr_version": "INTEGER NOT NULL DEFAULT 1",
})
_add_missing_columns("rentals", {
    "return_photo_url": "VARCHAR(512)",
    "lock_confirmed": "BOOLEAN NOT NULL DEFAULT 0",
    "payment_provider": "VARCHAR(30) NOT NULL DEFAULT 'demo'",
    "payment_intent_id": "VARCHAR(200)",
    "payment_status": "VARCHAR(40) NOT NULL DEFAULT 'not_started'",
    "authorized_amount": "FLOAT NOT NULL DEFAULT 0",
})

app = FastAPI(
    title="PedalShare API",
    description="Peer-to-peer bike rental & crowdsourced redistribution platform.",
    version="1.0.0",
)

UPLOAD_DIR = os.getenv("UPLOAD_DIR", "data/uploads")
FRONTEND_DIR = os.path.join(os.path.dirname(__file__), "frontend")
os.makedirs(UPLOAD_DIR, exist_ok=True)
BIKE_PHOTO_DIR = os.path.join(UPLOAD_DIR, "bike_photos")
os.makedirs(BIKE_PHOTO_DIR, exist_ok=True)

# Only listing photos are public. Identity documents and selfies are served by
# authorization-checked endpoints and must move to private object storage in
# production.
app.mount("/uploads/bike_photos", StaticFiles(directory=BIKE_PHOTO_DIR), name="bike_photos")


@app.get("/uploads/{private_path:path}", include_in_schema=False)
def reject_private_upload(private_path: str):
    raise HTTPException(status_code=404, detail="File not found")

_routers = (
    auth_router,
    users_router,
    bikes_router,
    rentals_router,
    delivery_router,
    shop_router,
    location_router,
    gamification_router,
    tracker_router,
)

# `/api/v1` is the stable mobile contract. Keep `/api` during the migration so
# the existing web client and previously released development builds continue
# to work while they move to the versioned endpoints.
for api_router in _routers:
    app.include_router(api_router, prefix="/api/v1")
    app.include_router(api_router, prefix="/api", include_in_schema=False)


@app.get("/api/health", tags=["health"])
def health():
    return {"status": "ok", "service": "PedalShare"}


@app.get("/api/v1/health", tags=["health"])
def health_v1():
    return health()


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
