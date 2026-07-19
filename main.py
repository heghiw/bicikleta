"""Bike Redistribution App — FastAPI backend.

Start with:
    uvicorn main:app --reload

Interactive docs: http://localhost:8000/docs
"""
import os
import logging

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from database import engine
import models
from routers.auth_router import router as auth_router
from routers.users_router import router as users_router
from routers.bikes_router import router as bikes_router
from routers.trips_router import router as trips_router
from routers.shop_router import router as shop_router
from routers.location_router import router as location_router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create all tables on startup
models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Bike Redistribution App",
    description=(
        "Earn bonus points by transporting bikes to where they're needed. "
        "Spend points at partner discount shops."
    ),
    version="1.0.0",
)

# Serve uploaded files (ID photos, face photos)
UPLOAD_DIR = os.getenv("UPLOAD_DIR", "data/uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# Register routers
app.include_router(auth_router)
app.include_router(users_router)
app.include_router(bikes_router)
app.include_router(trips_router)
app.include_router(shop_router)
app.include_router(location_router)


@app.get("/", tags=["health"])
def health():
    return {"status": "ok", "service": "bike-redistribution-app"}


logger.info("Bike Redistribution App started.")
