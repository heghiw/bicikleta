import os
import uuid
import aiofiles
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.orm import Session

from database import get_db
from auth import get_current_user, require_admin
import models
import schemas
from models import _haversine

UPLOAD_DIR = os.getenv("UPLOAD_DIR", "data/uploads")
router = APIRouter(prefix="/api/bikes", tags=["bikes"])


def _bike_out(bike: models.Bike, dist: Optional[float] = None) -> schemas.BikeOut:
    return schemas.BikeOut(
        id=bike.id,
        owner_id=bike.owner_id,
        title=bike.title,
        description=bike.description,
        photo_urls=bike.photo_urls,
        type=bike.type,
        brand=bike.brand,
        frame_size=bike.frame_size,
        hourly_price=bike.hourly_price,
        daily_price=bike.daily_price,
        deposit=bike.deposit,
        current_lat=bike.current_lat,
        current_lon=bike.current_lon,
        status=bike.status,
        avg_rating=round(bike.avg_rating(), 1),
        review_count=len(bike.reviews),
        distance_from_user=round(dist, 2) if dist is not None else None,
        created_at=bike.created_at,
    )


# ---------------------------------------------------------------------------
# Owner CRUD
# ---------------------------------------------------------------------------

@router.post("/", response_model=schemas.BikeOut, status_code=status.HTTP_201_CREATED)
def create_bike(
    body: schemas.BikeCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Any verified user can list their bike."""
    if not current_user.verified:
        raise HTTPException(status_code=403, detail="Account not verified")
    bike = models.Bike(owner_id=current_user.id, **body.model_dump())
    db.add(bike)
    db.commit()
    db.refresh(bike)
    return _bike_out(bike)


@router.post("/{bike_id}/photos", response_model=schemas.BikeOut)
async def upload_photos(
    bike_id: int,
    photos: List[UploadFile] = File(...),
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    bike = _get_or_403(db, bike_id, current_user.id)
    dest = os.path.join(UPLOAD_DIR, "bike_photos")
    os.makedirs(dest, exist_ok=True)
    urls = list(bike.photo_urls)
    for photo in photos:
        ext = os.path.splitext(photo.filename or "")[-1] or ".jpg"
        filename = f"{uuid.uuid4().hex}{ext}"
        filepath = os.path.join(dest, filename)
        async with aiofiles.open(filepath, "wb") as f:
            await f.write(await photo.read())
        urls.append(f"/uploads/bike_photos/{filename}")
    bike.photo_urls = urls
    db.commit()
    db.refresh(bike)
    return _bike_out(bike)


@router.patch("/{bike_id}", response_model=schemas.BikeOut)
def update_bike(
    bike_id: int,
    body: schemas.BikeUpdate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    bike = _get_or_403(db, bike_id, current_user.id)
    for field, val in body.model_dump(exclude_none=True).items():
        setattr(bike, field, val)
    db.commit()
    db.refresh(bike)
    return _bike_out(bike)


@router.delete("/{bike_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_bike(
    bike_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    bike = _get_or_403(db, bike_id, current_user.id)
    db.delete(bike)
    db.commit()


# ---------------------------------------------------------------------------
# Public / search
# ---------------------------------------------------------------------------

@router.get("/", response_model=List[schemas.BikeOut])
def list_bikes(
    status: Optional[str] = None,
    db: Session = Depends(get_db),
    _: models.User = Depends(get_current_user),
):
    q = db.query(models.Bike)
    if status:
        q = q.filter(models.Bike.status == status)
    return [_bike_out(b) for b in q.all()]


@router.get("/mine", response_model=List[schemas.BikeOut])
def list_my_bikes(
    current_user: models.User = Depends(get_current_user),
):
    return [_bike_out(b) for b in current_user.bikes]


@router.get("/{bike_id}", response_model=schemas.BikeOut)
def get_bike(
    bike_id: int,
    db: Session = Depends(get_db),
    _: models.User = Depends(get_current_user),
):
    return _bike_out(_get_or_404(db, bike_id))


@router.post("/search", response_model=List[schemas.BikeOut])
def search_bikes(
    body: schemas.BikeSearchRequest,
    db: Session = Depends(get_db),
    _: models.User = Depends(get_current_user),
):
    """Find available bikes within radius, with optional type/price filters."""
    bikes = (
        db.query(models.Bike)
        .filter(models.Bike.status == models.BikeStatus.available)
        .all()
    )
    results = []
    for bike in bikes:
        dist = bike.distance_to(body.user_lat, body.user_lon)
        if dist > body.radius_km:
            continue
        if body.type and bike.type != body.type:
            continue
        if body.max_hourly_price is not None and bike.hourly_price > body.max_hourly_price:
            continue
        if body.max_daily_price is not None and bike.daily_price > body.max_daily_price:
            continue
        results.append(_bike_out(bike, dist=dist))
    results.sort(key=lambda b: b.distance_from_user or 0)
    return results


@router.get("/{bike_id}/reviews", response_model=List[schemas.ReviewOut])
def get_bike_reviews(
    bike_id: int,
    db: Session = Depends(get_db),
    _: models.User = Depends(get_current_user),
):
    bike = _get_or_404(db, bike_id)
    return bike.reviews


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_or_404(db: Session, bike_id: int) -> models.Bike:
    bike = db.query(models.Bike).filter(models.Bike.id == bike_id).first()
    if not bike:
        raise HTTPException(status_code=404, detail="Bike not found")
    return bike


def _get_or_403(db: Session, bike_id: int, user_id: int) -> models.Bike:
    bike = _get_or_404(db, bike_id)
    if bike.owner_id != user_id:
        raise HTTPException(status_code=403, detail="Not your bike")
    return bike
